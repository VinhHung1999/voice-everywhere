import AppKit
import Foundation

final class VoiceController: @unchecked Sendable {
    enum State {
        case idle
        case connecting
        case verifying  // NEW: Speaker verification before transcription
        case listening
        case finishing
        case error(String)
    }

    private let capture = AudioCapture()
    private let streamer = SonioxStreamer()
    private let injector = TextInjector()
    private let llmProcessor = LLMProcessor()
    private var activityToken: NSObjectProtocol?
    private var languageHints: [String]

    // Speaker verifier (initialized on demand to avoid actor isolation issues)
    private var verifier: SpeakerVerifier?

    // Speaker verification state
    private var verificationBuffer = Data()
    private var verificationStartTime: Date?
    private var verificationTimer: DispatchSourceTimer?
    private static let verificationDurationSec: Double = 2.0  // Buffer 2s for verification
    var onVerificationResult: ((Bool, Double) -> Void)?  // (verified, score)

    // Continuous verification state (STORY-008)
    private var continuousVerificationEnabled = false
    private var continuousVerificationBuffer = Data()
    private let continuousVerificationChunkSize = 16000 * 2  // 1s at 16kHz 16-bit
    private var consecutiveNonBossChunks = 0
    private var isVerifyingChunk = false

    /// Buffer for accumulating final text when LLM is enabled.
    /// Sent to LLM as one request when recording stops.
    private var llmBuffer: String = ""
    private var llmConfig: LLMProcessor.Config?

    var onStateChange: ((State) -> Void)?
    var onPartial: ((String) -> Void)?

    private var isAudioRunning = false
    private var isStopping = false
    private var finishingTimer: DispatchSourceTimer?
    private static let finishingTimeoutSec: Double = 5

    init(languageHints: [String]) {
        self.languageHints = languageHints

        let injectorRef = injector
        streamer.onFinalText = { [weak self] text in
            guard let self else { return }
            if self.llmConfig != nil {
                // LLM enabled: buffer text, inject later when session ends
                self.llmBuffer.append(text)
            } else {
                // LLM disabled: inject immediately (original behavior)
                DispatchQueue.main.async {
                    injectorRef.type(text)
                }
            }
        }

        streamer.onUtteranceEnd = { [weak self] in
            self?.flushLLMBuffer()
        }

        streamer.onPartialText = { [weak self] text in
            self?.onPartial?(text)
        }

        streamer.onStateChange = { [weak self] state in
            self?.handle(streamerState: state)
        }
    }

    func toggle() {
        switch currentState {
        case .idle, .error(_):
            start()
        case .connecting, .verifying, .listening, .finishing:
            stop()
        }
    }

    private(set) var currentState: State = .idle {
        didSet { onStateChange?(currentState) }
    }

    private func start() {
        let effectiveKey = UserDefaults.standard.string(forKey: "soniox_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !effectiveKey.isEmpty else {
            currentState = .error("Please configure your API key in Configure…")
            return
        }

        isStopping = false
        llmBuffer = ""
        llmConfig = llmProcessor.currentConfig()

        // STORY-008: Enable continuous verification if speaker verification is enabled
        continuousVerificationEnabled = UserDefaults.standard.bool(forKey: "speaker_verification_enabled")
        continuousVerificationBuffer = Data()
        consecutiveNonBossChunks = 0
        isVerifyingChunk = false

        if continuousVerificationEnabled {
            VELog.write("VoiceController: continuous verification enabled (1s chunks)")
        }

        currentState = .connecting
        activityToken = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: "Voice capture")

        let termsStr = UserDefaults.standard.string(forKey: "soniox_context_terms") ?? ""
        let general = UserDefaults.standard.string(forKey: "soniox_context_general") ?? ""
        let terms = termsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let context = (!terms.isEmpty || !general.isEmpty)
            ? SonioxStreamer.Context(terms: terms, general: general)
            : nil

        streamer.start(apiKey: effectiveKey, languageHints: languageHints, context: context)
    }

    func stop() {
        isStopping = true
        streamer.stopGracefully()
        if isAudioRunning {
            capture.stop()
            isAudioRunning = false
        }
        currentState = .finishing
        if let activityToken {
            ProcessInfo.processInfo.endActivity(activityToken)
            self.activityToken = nil
        }
        startFinishingTimeout()
    }

    private func startFinishingTimeout() {
        cancelFinishingTimeout()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.finishingTimeoutSec)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard case .finishing = self.currentState else { return }
            VELog.write("Finishing timeout reached (\(Self.finishingTimeoutSec)s), force closing")
            self.streamer.forceClose()
        }
        timer.resume()
        finishingTimer = timer
    }

    private func cancelFinishingTimeout() {
        finishingTimer?.cancel()
        finishingTimer = nil
    }

    /// Send buffered text to LLM and inject the result.
    /// Called per utterance (on <end>) and on session close.
    private func flushLLMBuffer() {
        let text = llmBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let config = llmConfig
        llmBuffer = ""

        guard !text.isEmpty, let config else { return }

        let injectorRef = injector
        let llmRef = llmProcessor
        Task {
            do {
                let processed = try await llmRef.process(text, config: config)
                DispatchQueue.main.async {
                    injectorRef.type(processed)
                }
            } catch {
                VELog.write("LLM processing failed, injecting raw text: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    injectorRef.type(text)
                }
            }
        }
    }

    private func handle(streamerState: SonioxStreamer.State) {
        switch streamerState {
        case .connecting:
            currentState = .connecting
        case .streaming:
            DispatchQueue.main.async { [weak self] in
                self?.startAudio()

                // Check if speaker verification is enabled
                let verificationEnabled = UserDefaults.standard.bool(forKey: "speaker_verification_enabled")

                if verificationEnabled {
                    // Enter verifying state, buffer audio first
                    self?.currentState = .verifying
                    self?.verificationBuffer = Data()
                    self?.verificationStartTime = Date()
                    self?.startVerificationTimer()
                    VELog.write("VoiceController: entering verification mode")
                } else {
                    // Skip verification, go straight to listening
                    self?.currentState = .listening
                }

                NSSound(named: "Tink")?.play()
            }
        case .finishing:
            currentState = .finishing
        case .closed:
            cancelFinishingTimeout()
            if isAudioRunning {
                capture.stop()
                isAudioRunning = false
            }
            if isStopping {
                DispatchQueue.main.async {
                    NSSound(named: "Blow")?.play()
                }
                isStopping = false
            }
            flushLLMBuffer()
            llmConfig = nil
            currentState = .idle
        case .failed(let error):
            cancelFinishingTimeout()
            if isAudioRunning {
                capture.stop()
                isAudioRunning = false
            }
            if isStopping {
                isStopping = false
                flushLLMBuffer()
                llmConfig = nil
                currentState = .idle
            } else {
                // Discard buffer on error
                llmBuffer = ""
                llmConfig = nil
                currentState = .error(error.localizedDescription)
            }
        case .idle:
            currentState = .idle
        }
    }

    private func startAudio() {
        guard !isAudioRunning else { return }
        do {
            try capture.start { [weak self] data in
                guard let self else { return }

                // If in verifying state (initial 2s verification), buffer audio
                if case .verifying = self.currentState {
                    self.verificationBuffer.append(data)
                } else if case .listening = self.currentState, self.continuousVerificationEnabled {
                    // STORY-008: Continuous verification mode
                    // Buffer audio in 1s chunks and verify each chunk
                    self.continuousVerificationBuffer.append(data)

                    // Check if chunk is complete (1 second)
                    if self.continuousVerificationBuffer.count >= self.continuousVerificationChunkSize {
                        // Verify and forward chunk asynchronously
                        Task {
                            await self.verifyAndForwardChunk()
                        }
                    }
                } else {
                    // Normal streaming to Soniox (continuous verification disabled)
                    self.streamer.sendAudio(data)
                }
            }
            isAudioRunning = true
        } catch {
            currentState = .error("Mic permission needed")
        }
    }

    // MARK: - Speaker Verification

    private func startVerificationTimer() {
        cancelVerificationTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + Self.verificationDurationSec)
        timer.setEventHandler { [weak self] in
            self?.performVerification()
        }
        timer.resume()
        verificationTimer = timer
    }

    private func cancelVerificationTimer() {
        verificationTimer?.cancel()
        verificationTimer = nil
    }

    private func performVerification() {
        cancelVerificationTimer()

        guard case .verifying = currentState else { return }

        VELog.write("VoiceController: performing speaker verification (\(verificationBuffer.count) bytes buffered)")

        // Create WAV file from buffered PCM data
        let wavData = createWAVData(pcmData: verificationBuffer)

        // Call verification service
        Task { [weak self] in
            guard let self else { return }

            // Initialize verifier on demand (MainActor context)
            if await self.verifier == nil {
                await MainActor.run {
                    self.verifier = SpeakerVerifier()
                }
            }

            do {
                guard let verifier = await self.verifier else { return }
                let result = try await verifier.verify(audioData: wavData)

                VELog.write("VoiceController: verification result - verified=\(result.verified), score=\(result.score)")

                await MainActor.run {
                    self.onVerificationResult?(result.verified, result.score)

                    if result.verified {
                        // Verification passed: send buffered audio first, then start streaming
                        VELog.write("VoiceController: verification passed, starting transcription")

                        // CRITICAL FIX: Send the buffered 2s audio to Soniox FIRST
                        // This ensures the first words aren't lost
                        self.streamer.sendAudio(self.verificationBuffer)
                        VELog.write("VoiceController: sent \(self.verificationBuffer.count) bytes of buffered audio to Soniox")

                        // Now transition to listening state
                        // Future audio will stream normally (not buffered)
                        self.currentState = .listening
                    } else {
                        // Verification failed: discard audio and return to idle
                        VELog.write("VoiceController: verification failed (score=\(result.score)), discarding audio")
                        self.stop()
                        self.currentState = .error("Voice not recognized (score: \(String(format: "%.2f", result.score)))")
                    }

                    // Clear verification buffer
                    self.verificationBuffer = Data()
                    self.verificationStartTime = nil
                }

            } catch {
                VELog.write("VoiceController: verification error - \(error.localizedDescription)")

                await MainActor.run {
                    self.stop()
                    self.currentState = .error("Verification service unavailable: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Continuous Verification (STORY-008)

    private func verifyAndForwardChunk() async {
        guard !isVerifyingChunk else {
            VELog.write("VoiceController: skipping chunk verification (already verifying)")
            return
        }

        isVerifyingChunk = true

        // Capture current chunk and reset buffer for next chunk
        let chunkData = continuousVerificationBuffer
        continuousVerificationBuffer = Data()

        // Create WAV from chunk
        let wavData = createWAVData(pcmData: chunkData)

        // Initialize verifier if needed
        if await verifier == nil {
            await MainActor.run {
                self.verifier = SpeakerVerifier()
            }
        }

        do {
            guard let verifier = await verifier else {
                isVerifyingChunk = false
                return
            }

            let startTime = Date()
            let result = try await verifier.verify(audioData: wavData)
            let verifyDuration = Date().timeIntervalSince(startTime) * 1000  // ms

            await MainActor.run {
                if result.verified {
                    // Boss's voice - send chunk to Soniox (automatic RESUME)
                    self.streamer.sendAudio(chunkData)
                    self.consecutiveNonBossChunks = 0

                    VELog.write("VoiceController: continuous verification PASSED (score=\(String(format: "%.2f", result.score)), \(Int(verifyDuration))ms) - sent to Soniox")
                } else {
                    // Non-Boss voice - drop chunk (automatic PAUSE)
                    self.consecutiveNonBossChunks += 1

                    VELog.write("VoiceController: continuous verification REJECTED (score=\(String(format: "%.2f", result.score)), \(Int(verifyDuration))ms) - paused (consecutive: \(self.consecutiveNonBossChunks))")
                }

                self.isVerifyingChunk = false
            }

        } catch {
            VELog.write("VoiceController: continuous verification error - \(error.localizedDescription), sending chunk anyway (fallback)")

            await MainActor.run {
                // Fallback: send chunk on verification error
                self.streamer.sendAudio(chunkData)
                self.isVerifyingChunk = false
            }
        }
    }

    private func createWAVData(pcmData: Data) -> Data {
        var data = Data()

        let audioDataSize = UInt32(pcmData.count)
        let audioFormat: UInt16 = 1 // PCM
        let sampleRate: Int32 = 16000
        let channels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = UInt16(channels) * UInt16(bitsPerSample / 8)

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: 36 + audioDataSize) { Array($0) })
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16)) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: channels) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: sampleRate) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample) { Array($0) })

        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: audioDataSize) { Array($0) })
        data.append(pcmData)

        return data
    }
}

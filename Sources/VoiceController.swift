import AppKit
import Foundation

final class VoiceController: @unchecked Sendable {
    enum State {
        case idle
        case connecting
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
        case .connecting, .listening, .finishing:
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
                self?.currentState = .listening
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
                self?.streamer.sendAudio(data)
            }
            isAudioRunning = true
        } catch {
            currentState = .error("Mic permission needed")
        }
    }
}

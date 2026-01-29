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
    private var activityToken: NSObjectProtocol?
    private var languageHints: [String]

    var onStateChange: ((State) -> Void)?
    var onPartial: ((String) -> Void)?

    private var isAudioRunning = false
    private var isStopping = false

    init(languageHints: [String]) {
        self.languageHints = languageHints

        let injectorRef = injector
        streamer.onFinalText = { text in
            DispatchQueue.main.async {
                injectorRef.type(text)
            }
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
            currentState = .idle
        case .failed(let error):
            if isAudioRunning {
                capture.stop()
                isAudioRunning = false
            }
            if isStopping {
                // Suppress error during user-initiated stop
                isStopping = false
                currentState = .idle
            } else {
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

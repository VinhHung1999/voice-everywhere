import Foundation
import OSLog

final class SonioxStreamer: NSObject, @unchecked Sendable {
    enum State {
        case idle
        case connecting
        case streaming
        case finishing
        case closed
        case failed(Error)
    }

    struct Token: Decodable {
        let text: String
        let isFinal: Bool?
        let language: String?

        enum CodingKeys: String, CodingKey {
            case text
            case isFinal = "is_final"
            case language
        }
    }

    struct Response: Decodable {
        let tokens: [Token]?
        let finished: Bool?
    }

    private let endpoint = URL(string: "wss://stt-rt.soniox.com/transcribe-websocket")!
    private let logger = Logger(subsystem: "VoiceEverywhere", category: "Soniox")
    private var task: URLSessionWebSocketTask?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue())
    }()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sendQueue = DispatchQueue(label: "voiceeverywhere.soniox.send")
    private var isGracefullyStopping = false

    var onStateChange: ((State) -> Void)?
    var onFinalText: ((String) -> Void)?
    var onPartialText: ((String) -> Void)?
    var onUtteranceEnd: (() -> Void)?

    private var finalBuffer: String = ""
    private var pendingApiKey: String = ""
    private var pendingLanguageHints: [String] = []

    struct Context {
        let terms: [String]
        let general: String
    }

    private var pendingContext: Context?

    func start(apiKey: String, languageHints: [String], context: Context? = nil) {
        guard task == nil else { return }
        pendingApiKey = apiKey
        pendingLanguageHints = languageHints
        pendingContext = context
        isGracefullyStopping = false

        let request = URLRequest(url: endpoint)
        task = session.webSocketTask(with: request)
        onStateChange?(.connecting)
        logger.info("Soniox: connecting to \(self.endpoint.absoluteString, privacy: .public)")
        VELog.write("Soniox connecting…")
        task?.resume()
        receiveLoop()
    }

    func sendAudio(_ data: Data) {
        sendQueue.async { [weak self] in
            guard let self, !self.isGracefullyStopping else { return }
            self.task?.send(.data(data)) { error in
                if let error, !self.isGracefullyStopping {
                    self.logger.error("Soniox: send audio failed: \(error.localizedDescription, privacy: .public)")
                    VELog.write("Soniox send audio failed: \(error.localizedDescription)")
                    self.onStateChange?(.failed(error))
                }
            }
        }
    }

    func stopGracefully() {
        sendQueue.async { [weak self] in
            guard let self else { return }
            self.isGracefullyStopping = true
            self.onStateChange?(.finishing)
            // Empty frame signals graceful finish
            self.logger.info("Soniox: sending graceful stop frame")
            VELog.write("Soniox sending stop frame")
            self.task?.send(.data(Data())) { _ in
                self.task?.cancel(with: .goingAway, reason: nil)
                self.task = nil
                self.onStateChange?(.closed)
            }
        }
    }

    private func sendConfig(apiKey: String, languageHints: [String]) {
        var config: [String: Any] = [
            "api_key": apiKey,
            "model": "stt-rt-v3",
            "audio_format": "pcm_s16le",
            "sample_rate": 16_000,
            "num_channels": 1,
            "language_hints": languageHints,
            "enable_language_identification": true,
            "enable_endpoint_detection": true,
            "max_non_final_tokens_duration_ms": 2000
        ]

        if let ctx = pendingContext {
            var contextDict: [String: Any] = [:]
            if !ctx.terms.isEmpty {
                contextDict["terms"] = ctx.terms
            }
            if !ctx.general.isEmpty {
                contextDict["text"] = ctx.general
            }
            if !contextDict.isEmpty {
                config["context"] = contextDict
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: config, options: []),
              let json = String(data: data, encoding: .utf8) else { return }

        logger.info("Soniox: sending config \(json, privacy: .public)")
        VELog.write("Soniox sending config: \(json)")
        sendQueue.async { [weak self] in
            self?.task?.send(.string(json)) { error in
                if let error {
                    self?.logger.error("Soniox: send config failed: \(error.localizedDescription, privacy: .public)")
                    VELog.write("Soniox send config failed: \(error.localizedDescription)")
                    self?.onStateChange?(.failed(error))
                } else {
                    self?.logger.info("Soniox: config sent, streaming ready")
                    VELog.write("Soniox config sent, streaming ready")
                    self?.onStateChange?(.streaming)
                }
            }
        }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handle(message)
                self.receiveLoop()
            case .failure(let error):
                self.logger.error("Soniox: receive failed: \(error.localizedDescription, privacy: .public)")
                VELog.write("Soniox receive failed: \(error.localizedDescription)")
                if self.isGracefullyStopping {
                    self.logger.info("Soniox: suppressing receive error during graceful stop")
                    VELog.write("Soniox suppressing receive error during graceful stop")
                } else {
                    self.onStateChange?(.failed(error))
                }
                self.task = nil
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parse(text.data(using: .utf8))
        case .data(let data):
            parse(data)
        @unknown default:
            break
        }
    }

    private func parse(_ data: Data?) {
        guard let data else { return }
        guard let response = try? decoder.decode(Response.self, from: data) else {
            if let text = String(data: data, encoding: .utf8) {
                logger.warning("Soniox: decode failed, raw: \(text, privacy: .public)")
                VELog.write("Soniox decode failed raw: \(text)")
            }
            return
        }

        if let tokens = response.tokens {
            let rawFinal = tokens.filter { $0.isFinal == true }
                .map { $0.text }
                .joined()
            let hasEnd = rawFinal.contains("<end>")
            let finalTokens = rawFinal.replacingOccurrences(of: "<end>", with: "")
            let partialTokens = tokens.filter { $0.isFinal != true }
                .map { $0.text }
                .joined()
                .replacingOccurrences(of: "<end>", with: "")

            if !finalTokens.isEmpty {
                finalBuffer.append(finalTokens)
                onFinalText?(finalTokens)
                VELog.write("Soniox final: \(finalTokens)")
            }

            if hasEnd {
                VELog.write("Soniox utterance end detected")
                onUtteranceEnd?()
            }

            if !partialTokens.isEmpty {
                onPartialText?(finalBuffer + partialTokens)
                VELog.write("Soniox partial: \(partialTokens)")
            }
        }

        if response.finished == true {
            logger.info("Soniox: finished flag received, closing")
            VELog.write("Soniox finished, closing")
            onStateChange?(.closed)
            task?.cancel(with: .goingAway, reason: nil)
            task = nil
        }
    }
}

extension SonioxStreamer: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("Soniox: websocket opened")
        VELog.write("Soniox websocket opened")
        sendConfig(apiKey: pendingApiKey, languageHints: pendingLanguageHints)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        if let reason, let text = String(data: reason, encoding: .utf8) {
            logger.info("Soniox: websocket closed \(closeCode.rawValue) reason: \(text, privacy: .public)")
            VELog.write("Soniox websocket closed \(closeCode.rawValue) reason: \(text)")
        } else {
            logger.info("Soniox: websocket closed \(closeCode.rawValue)")
            VELog.write("Soniox websocket closed \(closeCode.rawValue)")
        }
        onStateChange?(.closed)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            logger.error("Soniox: task completed with error: \(error.localizedDescription, privacy: .public)")
            VELog.write("Soniox task error: \(error.localizedDescription)")
            if isGracefullyStopping {
                logger.info("Soniox: suppressing error during graceful stop")
                VELog.write("Soniox suppressing error during graceful stop")
            } else {
                onStateChange?(.failed(error))
            }
        }
    }
}

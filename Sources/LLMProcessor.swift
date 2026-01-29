import Foundation

final class LLMProcessor: @unchecked Sendable {
    struct Config {
        let apiKey: String
        let model: String
        let outputLanguage: String
        let formatInstructions: String
        let context: String
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    var isEnabled: Bool {
        let key = UserDefaults.standard.string(forKey: "xai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lang = UserDefaults.standard.string(forKey: "output_language") ?? "As spoken (no LLM)"
        return !key.isEmpty && lang != "As spoken (no LLM)"
    }

    func currentConfig() -> Config? {
        guard UserDefaults.standard.bool(forKey: "llm_enabled") else { return nil }
        let key = UserDefaults.standard.string(forKey: "xai_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lang = UserDefaults.standard.string(forKey: "output_language") ?? "As spoken (no LLM)"
        guard !key.isEmpty, lang != "As spoken (no LLM)" else { return nil }

        let model = UserDefaults.standard.string(forKey: "xai_model")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "grok-3-mini-fast"
        let format = Self.activeFormatInstructions()
        let context = UserDefaults.standard.string(forKey: "soniox_context_general") ?? ""

        return Config(
            apiKey: key,
            model: model.isEmpty ? "grok-3-mini-fast" : model,
            outputLanguage: lang,
            formatInstructions: format,
            context: context
        )
    }

    private static func activeFormatInstructions() -> String {
        guard let activeName = UserDefaults.standard.string(forKey: "active_format_preset"),
              !activeName.isEmpty,
              activeName != "(None)",
              let data = UserDefaults.standard.data(forKey: "format_presets"),
              let presets = try? JSONDecoder().decode([FormatPreset].self, from: data),
              let match = presets.first(where: { $0.name == activeName }) else {
            return ""
        }
        return match.instructions
    }

    func process(_ text: String, config: Config) async throws -> String {
        let url = URL(string: "https://api.x.ai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var systemPrompt = "You are a speech-to-text post-processor.\nOutput language: \(config.outputLanguage)\n"
        if !config.formatInstructions.isEmpty {
            systemPrompt += "\(config.formatInstructions)\n"
        }
        if !config.context.isEmpty {
            systemPrompt += "Context: \(config.context)\n"
        }
        systemPrompt += "Rewrite the following spoken text. Output ONLY the processed text, nothing else."

        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        VELog.write("LLM processing: \(text.prefix(80))...")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "unknown"
            VELog.write("LLM API error \(httpResponse.statusCode): \(bodyStr)")
            throw LLMError.apiError(statusCode: httpResponse.statusCode, body: bodyStr)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }

        let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
        VELog.write("LLM result: \(result.prefix(80))...")
        return result
    }

    struct FormatPreset: Codable {
        let name: String
        let instructions: String
    }

    enum LLMError: LocalizedError {
        case invalidResponse
        case apiError(statusCode: Int, body: String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from xAI API"
            case .apiError(let code, let body):
                return "xAI API error \(code): \(body)"
            case .parseError:
                return "Failed to parse xAI API response"
            }
        }
    }
}

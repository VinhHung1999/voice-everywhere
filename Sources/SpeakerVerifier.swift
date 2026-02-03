import Foundation

/// Swift client for speaker verification service
/// Communicates with Python FastAPI service at localhost:8765
@MainActor
final class SpeakerVerifier {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: String = "http://127.0.0.1:8765") {
        self.baseURL = URL(string: baseURL)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5.0  // 5s timeout for verification
        self.session = URLSession(configuration: config)
    }

    /// Check if service is healthy and ready
    func healthCheck() async throws -> HealthStatus {
        let url = baseURL.appendingPathComponent("health")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VerificationError.serviceUnavailable
        }

        return try JSONDecoder().decode(HealthStatus.self, from: data)
    }

    /// Get detailed service status
    func getStatus() async throws -> ServiceStatus {
        let url = baseURL.appendingPathComponent("status")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw VerificationError.serviceUnavailable
        }

        return try JSONDecoder().decode(ServiceStatus.self, from: data)
    }

    /// Enroll speaker from recorded samples
    func enroll() async throws -> EnrollmentResult {
        let url = baseURL.appendingPathComponent("enroll")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VerificationError.invalidResponse
        }

        if httpResponse.statusCode == 404 {
            throw VerificationError.noEnrollmentSamples
        }

        guard httpResponse.statusCode == 200 else {
            throw VerificationError.enrollmentFailed
        }

        return try JSONDecoder().decode(EnrollmentResult.self, from: data)
    }

    /// Verify speaker from audio data
    func verify(audioData: Data, filename: String = "verify.wav") async throws -> VerificationResult {
        let url = baseURL.appendingPathComponent("verify")

        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VerificationError.invalidResponse
        }

        if httpResponse.statusCode == 400 {
            throw VerificationError.noEnrolledSpeaker
        }

        guard httpResponse.statusCode == 200 else {
            throw VerificationError.verificationFailed
        }

        return try JSONDecoder().decode(VerificationResult.self, from: data)
    }
}

// MARK: - Models

struct HealthStatus: Codable {
    let status: String
    let modelLoaded: Bool
    let enrolledSpeaker: Bool
    let threshold: Double

    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case enrolledSpeaker = "enrolled_speaker"
        case threshold
    }

    var isHealthy: Bool {
        status == "healthy" && modelLoaded
    }
}

struct ServiceStatus: Codable {
    let modelLoaded: Bool
    let enrollmentStatus: String
    let sampleCount: Int
    let threshold: Double
    let enrolledProfileExists: Bool

    enum CodingKeys: String, CodingKey {
        case modelLoaded = "model_loaded"
        case enrollmentStatus = "enrollment_status"
        case sampleCount = "sample_count"
        case threshold
        case enrolledProfileExists = "enrolled_profile_exists"
    }

    var isEnrolled: Bool {
        enrollmentStatus == "enrolled" && enrolledProfileExists
    }
}

struct EnrollmentResult: Codable {
    let status: String
    let samplesProcessed: Int
    let samplesFound: Int
    let processingTimeS: Double
    let profileSaved: String

    enum CodingKeys: String, CodingKey {
        case status
        case samplesProcessed = "samples_processed"
        case samplesFound = "samples_found"
        case processingTimeS = "processing_time_s"
        case profileSaved = "profile_saved"
    }
}

struct VerificationResult: Codable {
    let verified: Bool
    let score: Double
    let threshold: Double
    let audioSizeKb: Double
    let processingTimeMs: Double

    enum CodingKeys: String, CodingKey {
        case verified
        case score
        case threshold
        case audioSizeKb = "audio_size_kb"
        case processingTimeMs = "processing_time_ms"
    }
}

// MARK: - Errors

enum VerificationError: Error, LocalizedError {
    case serviceUnavailable
    case invalidResponse
    case noEnrollmentSamples
    case noEnrolledSpeaker
    case enrollmentFailed
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Verification service unavailable"
        case .invalidResponse:
            return "Invalid response from verification service"
        case .noEnrollmentSamples:
            return "No enrollment samples found. Record samples first."
        case .noEnrolledSpeaker:
            return "No enrolled speaker. Enroll first."
        case .enrollmentFailed:
            return "Enrollment failed"
        case .verificationFailed:
            return "Verification failed"
        }
    }
}

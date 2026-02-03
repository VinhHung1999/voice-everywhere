#!/usr/bin/env swift

/*
 Proof of Concept: Swift Client for Speaker Verification Service

 Demonstrates:
 - Swift → Python FastAPI HTTP communication
 - URLSession async/await pattern
 - Error handling for service calls
 - Health check before verification

 Usage:
   1. Start Python service: cd ../python-service && uvicorn verify_service:app --port 8765
   2. Run this PoC: swift SpeakerVerifierPoC.swift

 Note: This is a standalone script for PoC. In production, this would be
 integrated into VoiceEverywhere as a proper Swift class in Sources/.
*/

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Models

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

struct HealthStatus: Codable {
    let status: String
    let modelLoaded: Bool
    let enrolledSpeaker: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case enrolledSpeaker = "enrolled_speaker"
    }
}

// MARK: - Service Client

class SpeakerVerificationService {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: String = "http://127.0.0.1:8765") {
        self.baseURL = URL(string: baseURL)!

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    /// Check if Python service is healthy and ready
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("health")

        print("📡 Checking service health at \(url)...")

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        let healthStatus = try JSONDecoder().decode(HealthStatus.self, from: data)

        print("✅ Service health: \(healthStatus.status)")
        print("   Model loaded: \(healthStatus.modelLoaded)")
        print("   Speaker enrolled: \(healthStatus.enrolledSpeaker)")

        return healthStatus.status == "healthy"
    }

    /// Verify speaker from audio data
    func verify(audioData: Data, filename: String = "test.wav") async throws -> VerificationResult {
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

        print("\n🎤 Sending verification request...")
        print("   Audio size: \(Double(audioData.count) / 1024) KB")

        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let roundTripTime = Date().timeIntervalSince(startTime) * 1000

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ServiceError.httpError(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(VerificationResult.self, from: data)

        print("✅ Verification complete")
        print("   Verified: \(result.verified ? "✅ YES" : "❌ NO")")
        print("   Similarity score: \(String(format: "%.4f", result.score))")
        print("   Threshold: \(result.threshold)")
        print("   Processing time (server): \(String(format: "%.2f", result.processingTimeMs)) ms")
        print("   Round-trip time (total): \(String(format: "%.2f", roundTripTime)) ms")

        return result
    }
}

// MARK: - Errors

enum ServiceError: Error, CustomStringConvertible {
    case invalidResponse
    case httpError(statusCode: Int)
    case serviceNotReady

    var description: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from service"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serviceNotReady:
            return "Service not ready"
        }
    }
}

// MARK: - PoC Main

@main
struct SpeakerVerifierPoC {
    static func main() async {
        print("🚀 Speaker Verification PoC - Swift Client")
        print("=" * 50)

        let service = SpeakerVerificationService()

        do {
            // Step 1: Health check
            print("\n📋 Step 1: Health Check")
            print("-" * 50)

            let isHealthy = try await service.healthCheck()
            guard isHealthy else {
                print("❌ Service not healthy. Aborting.")
                throw ServiceError.serviceNotReady
            }

            // Step 2: Verify speaker with mock audio
            print("\n📋 Step 2: Speaker Verification")
            print("-" * 50)

            // Create mock audio data (in production, this would be real PCM audio)
            let mockAudioData = createMockAudioData(durationSeconds: 3.0)

            let result = try await service.verify(audioData: mockAudioData)

            // Step 3: Summary
            print("\n📊 Summary")
            print("-" * 50)
            print("Status: \(result.verified ? "✅ Speaker Verified" : "❌ Verification Failed")")
            print("Confidence: \(String(format: "%.1f%%", result.score * 100))")

            if result.verified {
                print("\n✅ SUCCESS: Swift successfully communicated with Python service!")
            } else {
                print("\n⚠️  Speaker not verified (this is expected in PoC with random results)")
            }

        } catch {
            print("\n❌ Error: \(error)")
            print("\nTroubleshooting:")
            print("1. Ensure Python service is running:")
            print("   cd python-service && uvicorn verify_service:app --port 8765")
            print("2. Check if port 8765 is available")
            print("3. Verify network connectivity to localhost:8765")
        }
    }

    /// Create mock audio data (placeholder for real PCM audio)
    static func createMockAudioData(durationSeconds: Double) -> Data {
        // Mock WAV header + data
        // In production, this would be real 16kHz PCM audio from AudioCapture
        let sampleRate = 16000
        let samples = Int(durationSeconds * Double(sampleRate))
        var data = Data(count: samples * 2) // 16-bit samples

        // Fill with random audio-like data
        for i in 0..<data.count {
            data[i] = UInt8.random(in: 0...255)
        }

        return data
    }
}

// Helper for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

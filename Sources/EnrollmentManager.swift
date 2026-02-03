import Foundation

/// Manages speaker enrollment: recording voice samples and saving as WAV files
@MainActor
final class EnrollmentManager {
    private let audioCapture = AudioCapture()
    private var recordingBuffer = Data()
    private var isRecording = false

    /// Directory where enrollment samples are saved
    static let enrollmentDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("VoiceEverywhere", isDirectory: true)
            .appendingPathComponent("voice_profile", isDirectory: true)
    }()

    /// Sample rate for all audio (must match AudioCapture)
    private static let sampleRate: Int32 = 16000

    /// Start recording a voice sample
    func startRecording() throws {
        guard !isRecording else {
            throw EnrollmentError.alreadyRecording
        }

        recordingBuffer = Data()
        isRecording = true

        try audioCapture.start { [weak self] audioData in
            Task { @MainActor in
                self?.recordingBuffer.append(audioData)
            }
        }

        VELog.write("EnrollmentManager: recording started")
    }

    /// Stop recording and save to WAV file
    func stopRecording(sampleNumber: Int) throws -> URL {
        guard isRecording else {
            throw EnrollmentError.notRecording
        }

        audioCapture.stop()
        isRecording = false

        let outputURL = try saveAsWAV(data: recordingBuffer, sampleNumber: sampleNumber)
        VELog.write("EnrollmentManager: saved sample \(sampleNumber) to \(outputURL.lastPathComponent)")

        recordingBuffer = Data()
        return outputURL
    }

    /// Cancel current recording without saving
    func cancelRecording() {
        if isRecording {
            audioCapture.stop()
            isRecording = false
            recordingBuffer = Data()
            VELog.write("EnrollmentManager: recording cancelled")
        }
    }

    /// Save PCM data as WAV file
    private func saveAsWAV(data: Data, sampleNumber: Int) throws -> URL {
        // Ensure directory exists
        try FileManager.default.createDirectory(
            at: Self.enrollmentDirectory,
            withIntermediateDirectories: true
        )

        let filename = "sample_\(sampleNumber).wav"
        let outputURL = Self.enrollmentDirectory.appendingPathComponent(filename)

        // Write WAV file
        let wavData = createWAVFile(pcmData: data, sampleRate: Self.sampleRate, channels: 1, bitsPerSample: 16)
        try wavData.write(to: outputURL)

        return outputURL
    }

    /// Create WAV file data from PCM samples
    private func createWAVFile(pcmData: Data, sampleRate: Int32, channels: Int16, bitsPerSample: Int16) -> Data {
        var data = Data()

        let audioDataSize = UInt32(pcmData.count)
        let audioFormat: UInt16 = 1 // PCM
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = UInt16(channels) * UInt16(bitsPerSample / 8)

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: 36 + audioDataSize) { Array($0) })
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16)) { Array($0) }) // chunk size
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

    /// Get current enrollment status
    static func getEnrollmentStatus() -> EnrollmentStatus {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: enrollmentDirectory.path) else {
            return .notEnrolled
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: enrollmentDirectory, includingPropertiesForKeys: nil)
            let wavFiles = files.filter { $0.pathExtension == "wav" }

            if wavFiles.isEmpty {
                return .notEnrolled
            }

            return .enrolled(sampleCount: wavFiles.count)
        } catch {
            VELog.write("EnrollmentManager: error reading enrollment directory: \(error)")
            return .notEnrolled
        }
    }

    /// Clear all enrollment samples
    static func clearEnrollment() throws {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: enrollmentDirectory.path) else {
            return
        }

        try fileManager.removeItem(at: enrollmentDirectory)
        VELog.write("EnrollmentManager: enrollment cleared")
    }
}

// MARK: - Types

enum EnrollmentStatus: Equatable {
    case notEnrolled
    case enrolled(sampleCount: Int)

    var isEnrolled: Bool {
        if case .enrolled = self {
            return true
        }
        return false
    }

    var displayText: String {
        switch self {
        case .notEnrolled:
            return "Not enrolled"
        case .enrolled(let count):
            return "Enrolled (\(count) samples)"
        }
    }
}

enum EnrollmentError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Already recording"
        case .notRecording:
            return "Not currently recording"
        case .saveFailed:
            return "Failed to save recording"
        }
    }
}

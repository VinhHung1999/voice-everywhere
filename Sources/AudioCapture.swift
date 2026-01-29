import AVFoundation

final class AudioCapture {
    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: 16_000,
                                             channels: 1,
                                             interleaved: true)!
    private var converter: AVAudioConverter?

    func start(onData: @escaping (Data) -> Void) throws {
        guard try micPermissionGranted() else {
            throw CaptureError.micPermissionDenied
        }

        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            VELog.write("AudioCapture: no input channels available")
            throw CaptureError.micPermissionDenied
        }
        converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        VELog.write("AudioCapture: input format \(inputFormat.sampleRate) Hz, \(inputFormat.channelCount)ch -> target 16kHz mono")

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter = self.converter else { return }
            guard let converted = self.convert(buffer: buffer, with: converter) else { return }
            guard let channelData = converted.int16ChannelData else { return }
            let frameLength = Int(converted.frameLength)
            let bytesPerFrame = Int(converted.format.streamDescription.pointee.mBytesPerFrame)
            let dataSize = frameLength * bytesPerFrame
            let audioData = Data(bytes: channelData[0], count: dataSize)
            onData(audioData)
        }

        engine.prepare()
        try engine.start()
        VELog.write("AudioCapture: engine started")
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        VELog.write("AudioCapture: engine stopped")
    }

    private func convert(buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return nil }

        var error: NSError?
        let status = converter.convert(to: pcmBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error {
            if let error {
                VELog.write("Audio convert error: \(error.localizedDescription)")
            }
            return nil
        }

        pcmBuffer.frameLength = pcmBuffer.frameCapacity
        return pcmBuffer
    }

    private func micPermissionGranted() throws -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { ok in
                granted = ok
                semaphore.signal()
            }
            semaphore.wait()
            return granted
        default:
            return false
        }
    }

    enum CaptureError: Error {
        case micPermissionDenied
    }
}

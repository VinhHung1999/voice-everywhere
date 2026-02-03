import Foundation

/// Manages Python verification service lifecycle
@MainActor
final class PythonServiceManager {
    private var process: Process?
    private var isRunning = false
    private let servicePort = 8765

    /// Path to Python service script
    private var servicePath: String {
        // Use bundled service if available, otherwise use development path
        if let bundlePath = Bundle.main.path(forResource: "verify_service", ofType: "py") {
            return bundlePath
        }
        // Development fallback
        return FileManager.default.currentDirectoryPath + "/python-service/verify_service.py"
    }

    /// Start verification service
    func start() async throws {
        guard !isRunning else {
            VELog.write("PythonServiceManager: service already running")
            return
        }

        VELog.write("PythonServiceManager: starting service...")

        // Find Python executable
        let pythonPath = try findPython()

        // Create process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [
            "-m", "uvicorn",
            "verify_service:app",
            "--port", "\(servicePort)",
            "--log-level", "info"
        ]

        // Set working directory to python-service
        let serviceDir = URL(fileURLWithPath: servicePath).deletingLastPathComponent()
        proc.currentDirectoryURL = serviceDir

        // Capture output for logging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        proc.standardOutput = outputPipe
        proc.standardError = errorPipe

        // Handle termination
        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                if process.terminationStatus != 0 {
                    VELog.write("PythonServiceManager: service terminated with status \(process.terminationStatus)")
                }
                self?.isRunning = false
            }
        }

        // Start process
        do {
            try proc.run()
        } catch {
            VELog.write("PythonServiceManager: failed to start process: \(error)")
            throw ServiceError.serviceFailed
        }

        process = proc
        isRunning = true

        VELog.write("PythonServiceManager: service started (PID: \(proc.processIdentifier))")

        // Log output asynchronously
        Task {
            await logOutput(pipe: outputPipe)
        }

        // Wait for service to be ready
        try await waitForServiceReady()

        VELog.write("PythonServiceManager: service ready")
    }

    /// Stop verification service
    func stop() {
        guard let proc = process, isRunning else {
            return
        }

        VELog.write("PythonServiceManager: stopping service...")

        proc.terminate()

        // Force kill after timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak proc] in
            if let proc, proc.isRunning {
                VELog.write("PythonServiceManager: force killing service")
                proc.interrupt()
            }
        }

        process = nil
        isRunning = false
    }

    /// Check if service is running and healthy
    func isHealthy() async -> Bool {
        guard isRunning else { return false }

        do {
            let verifier = SpeakerVerifier()
            let health = try await verifier.healthCheck()
            return health.isHealthy
        } catch {
            return false
        }
    }

    /// Wait for service to be ready (health check)
    private func waitForServiceReady(maxAttempts: Int = 30) async throws {
        let verifier = SpeakerVerifier()

        for attempt in 1...maxAttempts {
            do {
                let health = try await verifier.healthCheck()
                if health.isHealthy {
                    return
                }
            } catch {
                // Service not ready yet, wait and retry
            }

            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            VELog.write("PythonServiceManager: waiting for service... (attempt \(attempt)/\(maxAttempts))")
        }

        throw ServiceError.startupTimeout
    }

    /// Find Python executable
    private func findPython() throws -> String {
        // Try common Python paths
        let candidates = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Try 'which python3'
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["python3"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }

        throw ServiceError.pythonNotFound
    }

    /// Log process output
    private func logOutput(pipe: Pipe) async {
        let handle = pipe.fileHandleForReading

        do {
            for try await line in handle.bytes.lines {
                VELog.write("PythonService: \(line)")
            }
        } catch {
            VELog.write("PythonServiceManager: log output error: \(error)")
        }
    }
}

// MARK: - Errors

enum ServiceError: Error, LocalizedError {
    case pythonNotFound
    case startupTimeout
    case serviceFailed

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 not found. Please install Python 3."
        case .startupTimeout:
            return "Service startup timeout. Check if dependencies are installed."
        case .serviceFailed:
            return "Service failed to start"
        }
    }
}

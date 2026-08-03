import Foundation

final class SidecarProcessManager {
    private var process: Process?
    private let queue = DispatchQueue(label: "com.lauronjohn.WhisperClone.sidecar")
    var onCrash: ((String) -> Void)?

    func start() {
        queue.async { [weak self] in
            self?.launch()
        }
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
    }

    /// Polls for the socket file's existence (sidecar creates it only once
    /// the model is loaded and the server is listening), up to `timeout`.
    func waitUntilReady(timeout: TimeInterval = 60) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: SidecarPaths.socketURL.path) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return false
    }

    private func launch() {
        guard let uv = SidecarPaths.resolveUvExecutable() else {
            onCrash?("Could not locate the `uv` executable (checked common Homebrew/cargo/local paths).")
            return
        }

        try? FileManager.default.createDirectory(
            at: SidecarPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: SidecarPaths.socketURL)

        let task = Process()
        task.executableURL = uv
        task.arguments = ["run", "python", "-m", "whisperclone_sidecar"]
        task.currentDirectoryURL = SidecarPaths.sidecarProjectDirectory

        var env = ProcessInfo.processInfo.environment
        env[SidecarPaths.socketEnvVar] = SidecarPaths.socketURL.path
        // Required: uv's editable installs mark their .pth file UF_HIDDEN on this
        // machine, which this Python build's site.py silently skips, breaking the
        // import. Non-editable install sidesteps it. See PLAN.md setup prerequisites.
        env["UV_NO_EDITABLE"] = "1"
        task.environment = env

        FileManager.default.createFile(atPath: SidecarPaths.logURL.path, contents: nil)
        if let handle = FileHandle(forWritingAtPath: SidecarPaths.logURL.path) {
            task.standardOutput = handle
            task.standardError = handle
        }

        task.terminationHandler = { [weak self] _ in
            self?.handleTermination()
        }

        do {
            try task.run()
            process = task
        } catch {
            onCrash?("Failed to launch sidecar: \(error.localizedDescription)")
        }
    }

    /// M3 scope: just report. Crash auto-restart with a retry cap is M6 (PLAN.md).
    private func handleTermination() {
        process = nil
        onCrash?("Sidecar process exited. See \(SidecarPaths.logURL.path)")
    }
}

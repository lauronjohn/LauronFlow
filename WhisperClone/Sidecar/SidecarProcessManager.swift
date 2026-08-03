import Foundation

final class SidecarProcessManager {
    private var process: Process?
    private let queue = DispatchQueue(label: "com.lauronjohn.WhisperClone.sidecar")
    var onCrash: ((String) -> Void)?

    // Crash auto-restart (M6): retry a small, capped number of times with a short
    // backoff, then give up and report via `onCrash`. `generation` is bumped on every
    // launch attempt and on `stop()`, so a termination callback or a pending retry from
    // a since-superseded/intentionally-stopped attempt can be detected and ignored.
    private let maxRetries = 3
    private let retryBackoff: TimeInterval = 2.0
    private let sustainedRunResetWindow: TimeInterval = 30.0
    private var retryCount = 0
    private var generation = 0

    func start() {
        queue.async { [weak self] in
            self?.launch()
        }
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        queue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.retryCount = 0
        }
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
        generation += 1
        let myGeneration = generation

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
            self?.queue.async {
                self?.handleTermination(generation: myGeneration)
            }
        }

        do {
            try task.run()
            process = task
            scheduleRetryResetCheck(generation: myGeneration)
        } catch {
            onCrash?("Failed to launch sidecar: \(error.localizedDescription)")
        }
    }

    /// Runs on `queue`. Ignores stale callbacks from an attempt that's since been
    /// superseded by a newer launch or an intentional `stop()`. Retries up to
    /// `maxRetries` times with `retryBackoff` between attempts before giving up.
    private func handleTermination(generation: Int) {
        guard generation == self.generation else { return }
        process = nil

        guard retryCount < maxRetries else {
            onCrash?("Sidecar crashed repeatedly (\(maxRetries) attempts) — giving up. See \(SidecarPaths.logURL.path)")
            return
        }

        retryCount += 1
        let generationAtSchedule = self.generation
        queue.asyncAfter(deadline: .now() + retryBackoff) { [weak self] in
            guard let self, generationAtSchedule == self.generation else { return }
            self.launch()
        }
    }

    /// Runs on `queue`. If the process launched as `generation` is still the current,
    /// running one after `sustainedRunResetWindow`, treat it as healthy and forgive
    /// retries consumed by earlier, unrelated crashes — otherwise a transient crash
    /// storm at startup would leave the app permanently one crash away from giving up.
    private func scheduleRetryResetCheck(generation: Int) {
        queue.asyncAfter(deadline: .now() + sustainedRunResetWindow) { [weak self] in
            guard let self, generation == self.generation, self.process != nil else { return }
            self.retryCount = 0
        }
    }
}

import CryptoKit
import Foundation

final class SidecarProcessManager {
    private var process: Process?
    private let queue = DispatchQueue(label: "com.lauronjohn.LauronFlow.sidecar")
    var onCrash: ((String) -> Void)?

    /// Rotate `sidecar.log` once it passes this size: the sidecar logs to stderr on
    /// every request, so without a cap the file grows without bound across a long-lived
    /// install. Rotation is drop-oldest (delete and recreate) — the log is a debug aid,
    /// not a record worth keeping.
    private let logRotationThreshold: UInt64 = 2 * 1024 * 1024

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

    /// `UV_NO_EDITABLE=1` (see the comment on it in `launch()`) makes `uv run` treat the
    /// local `lauronflow-sidecar` package as static rather than auto-detecting source
    /// changes — without this, any sidecar code update would silently keep running
    /// whatever version was installed the first time this Mac ever launched the app,
    /// since `sidecarVenvURL` deliberately persists across reinstalls. Cheap: this only
    /// rebuilds our own handful of small .py files, not the heavy ML dependencies
    /// (mlx, parakeet-mlx, etc.), which stay untouched and cached. Runs synchronously —
    /// fine here since `launch()` already executes off the main thread on `queue`.
    private func resyncSidecarPackage(uv: URL, sidecarDir: URL) {
        let task = Process()
        task.executableURL = uv
        task.arguments = ["sync", "--reinstall-package", "lauronflow-sidecar"]
        task.currentDirectoryURL = sidecarDir

        var env = ProcessInfo.processInfo.environment
        env["UV_NO_EDITABLE"] = "1"
        env["UV_PROJECT_ENVIRONMENT"] = SidecarPaths.sidecarVenvURL.path
        task.environment = env
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        try? task.run()
        task.waitUntilExit()
    }

    /// SHA-256 of every file `uv sync` could reinstall (our `src/` python files,
    /// `pyproject.toml`, and `uv.lock`), so a launch can skip the sync step entirely
    /// when nothing changed since the last one. Stored next to the venv so it
    /// naturally goes stale if the venv is ever deleted.
    private func sidecarSourceHash(sidecarDir: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(
            at: sidecarDir.appendingPathComponent("src"),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        var hasher = SHA256()
        for case let file as URL in enumerator {
            guard file.pathExtension == "py" else { continue }
            guard let data = try? Data(contentsOf: file) else { return nil }
            hasher.update(data: data)
        }
        for filename in ["pyproject.toml", "uv.lock"] {
            if let data = try? Data(contentsOf: sidecarDir.appendingPathComponent(filename)) {
                hasher.update(data: data)
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// `uv sync` on every app launch costs real seconds of startup (uv re-checks the
    /// resolved environment) even when nothing changed. Only re-sync when the sidecar
    /// source has actually changed since the recorded hash — first launch and venv-less
    /// installs have no hash recorded, so they always sync.
    private func sidecarNeedsSync(sidecarDir: URL) -> Bool {
        guard let hash = sidecarSourceHash(sidecarDir: sidecarDir) else { return true }
        let stored = (try? String(contentsOf: SidecarPaths.sidecarSyncHashURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard stored == hash else { return true }
        // Hash matches, but the venv it was synced into must still exist.
        let venvPython = SidecarPaths.sidecarVenvURL.appendingPathComponent("bin/python")
        return !FileManager.default.isExecutableFile(atPath: venvPython.path)
    }

    private func recordSidecarSync(sidecarDir: URL) {
        guard let hash = sidecarSourceHash(sidecarDir: sidecarDir) else { return }
        try? FileManager.default.createDirectory(
            at: SidecarPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        try? hash.write(to: SidecarPaths.sidecarSyncHashURL, atomically: true, encoding: .utf8)
    }

    private func rotateLogIfNeeded() {
        let attributes = try? FileManager.default.attributesOfItem(atPath: SidecarPaths.logURL.path)
        guard let size = attributes?[.size] as? NSNumber,
              size.uint64Value > logRotationThreshold else { return }
        try? FileManager.default.removeItem(at: SidecarPaths.logURL)
    }

    private func launch() {
        generation += 1
        let myGeneration = generation

        guard let uv = SidecarPaths.resolveUvExecutable() else {
            onCrash?("Could not locate the `uv` executable (checked common Homebrew/cargo/local paths).")
            return
        }

        guard let sidecarDir = SidecarPaths.sidecarProjectDirectory else {
            onCrash?("Could not locate the sidecar project. If you moved the LauronFlow checkout, run `./configure-sidecar.sh /path/to/sidecar` from it and relaunch.")
            return
        }

        try? FileManager.default.createDirectory(
            at: SidecarPaths.supportDirectory,
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: SidecarPaths.socketURL)
        try? FileManager.default.removeItem(at: SidecarPaths.statusURL)
        if sidecarNeedsSync(sidecarDir: sidecarDir) {
            resyncSidecarPackage(uv: uv, sidecarDir: sidecarDir)
            recordSidecarSync(sidecarDir: sidecarDir)
        }

        let task = Process()
        task.executableURL = uv
        task.arguments = ["run", "python", "-m", "lauronflow_sidecar"]
        task.currentDirectoryURL = sidecarDir

        var env = ProcessInfo.processInfo.environment
        env[SidecarPaths.socketEnvVar] = SidecarPaths.socketURL.path
        env[SidecarPaths.statusEnvVar] = SidecarPaths.statusURL.path
        // Required: uv's editable installs mark their .pth file UF_HIDDEN on this
        // machine, which this Python build's site.py silently skips, breaking the
        // import. Non-editable install sidesteps it. See PLAN.md setup prerequisites.
        env["UV_NO_EDITABLE"] = "1"
        // Redirects uv's venv to a stable Application Support location, independent
        // of sidecarProjectDirectory — keeps uv from ever writing inside the app
        // bundle (that dir may be the bundled, read-only-in-spirit Resources/sidecar
        // copy) and means the resolved dependencies survive app reinstalls/updates.
        env["UV_PROJECT_ENVIRONMENT"] = SidecarPaths.sidecarVenvURL.path
        // GUI-launched apps (Finder/LaunchServices) get a minimal PATH
        // (/usr/bin:/bin:/usr/sbin:/sbin) with no Homebrew directories, unlike an
        // interactive shell. parakeet-mlx shells out to ffmpeg at transcribe time, so
        // without this the sidecar loads fine but every transcription fails with
        // "FFmpeg is not installed or not in your PATH" the moment it's launched from
        // /Applications instead of a Terminal-spawned `open`.
        let extraPathDirs = ["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.cargo/bin"]
        let existingPath = env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = (extraPathDirs + [existingPath]).joined(separator: ":")
        task.environment = env

        rotateLogIfNeeded()
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

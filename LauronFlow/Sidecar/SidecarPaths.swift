import Foundation

enum SidecarPaths {
    static let socketEnvVar = "LAURONFLOW_SOCKET_PATH"

    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LauronFlow", isDirectory: true)
    }

    static var socketURL: URL {
        supportDirectory.appendingPathComponent("sidecar.sock")
    }

    static var logURL: URL {
        supportDirectory.appendingPathComponent("sidecar.log")
    }

    /// Personal single-machine app: the sidecar is an independent uv-managed
    /// Python project living alongside the Xcode project, not embedded in
    /// the app bundle. Update this if the checkout moves.
    static var sidecarProjectDirectory: URL {
        URL(fileURLWithPath: "/Users/johnlauron/Desktop/LauronFlow/sidecar")
    }

    static func resolveUvExecutable() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
            NSHomeDirectory() + "/.local/bin/uv",
            NSHomeDirectory() + "/.cargo/bin/uv",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}

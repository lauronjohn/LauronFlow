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

    static var vocabularyURL: URL {
        supportDirectory.appendingPathComponent("vocabulary.json")
    }

    /// Path to `sidecar_path.txt`, written by install.sh with the absolute path of
    /// the sidecar checkout on *this* machine — needed because the sidecar is an
    /// independent uv-managed Python project living alongside the Xcode project,
    /// not embedded in the app bundle, so its location varies per user/checkout.
    static var sidecarPathConfigURL: URL {
        supportDirectory.appendingPathComponent("sidecar_path.txt")
    }

    /// Resolution order: explicit env override (dev convenience) > the path
    /// install.sh recorded at build time > the original single-machine default,
    /// kept as a last-resort fallback for pre-existing installs.
    static var sidecarProjectDirectory: URL {
        if let envPath = ProcessInfo.processInfo.environment["LAURONFLOW_SIDECAR_DIR"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath)
        }
        if let recorded = try? String(contentsOf: sidecarPathConfigURL, encoding: .utf8) {
            let trimmed = recorded.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return URL(fileURLWithPath: trimmed)
            }
        }
        return URL(fileURLWithPath: "/Users/johnlauron/Desktop/LauronFlow/sidecar")
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

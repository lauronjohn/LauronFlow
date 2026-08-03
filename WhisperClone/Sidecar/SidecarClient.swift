import Darwin
import Foundation

enum SidecarClientError: Error, LocalizedError {
    case socketCreationFailed
    case connectFailed(String)
    case writeFailed
    case readFailed
    case emptyResponse
    case malformedResponse(String)
    case sidecarError(String)

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed: return "Could not create a Unix domain socket."
        case .connectFailed(let detail): return "Could not connect to sidecar: \(detail)"
        case .writeFailed: return "Failed to write to sidecar socket."
        case .readFailed: return "Failed to read from sidecar socket."
        case .emptyResponse: return "Sidecar closed the connection without responding."
        case .malformedResponse(let line): return "Malformed sidecar response: \(line)"
        case .sidecarError(let message): return message
        }
    }
}

/// Talks to the Python sidecar over its Unix domain socket using raw BSD
/// sockets: one connection per utterance, newline-delimited JSON, an
/// SO_RCVTIMEO so a hung sidecar can't hang the caller indefinitely.
final class SidecarClient {
    private let receiveTimeout: TimeInterval

    init(receiveTimeout: TimeInterval = 30) {
        self.receiveTimeout = receiveTimeout
    }

    /// Blocking call — run off the main thread.
    func transcribe(wavPath: URL) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SidecarClientError.socketCreationFailed }
        defer { close(fd) }

        var timeout = timeval(tv_sec: Int(receiveTimeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = SidecarPaths.socketURL.path
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: ptr.pointee)) { cptr in
                path.withCString { strcpy(cptr, $0) }
            }
        }

        let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, addrSize)
            }
        }
        guard connectResult == 0 else {
            throw SidecarClientError.connectFailed(String(cString: strerror(errno)))
        }

        let request = wavPath.path + "\n"
        guard let requestData = request.data(using: .utf8) else { throw SidecarClientError.writeFailed }
        let bytesWritten = requestData.withUnsafeBytes { buf -> Int in
            write(fd, buf.baseAddress, buf.count)
        }
        guard bytesWritten == requestData.count else { throw SidecarClientError.writeFailed }

        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = buffer.withUnsafeMutableBytes { buf -> Int in
                read(fd, buf.baseAddress, buf.count)
            }
            if bytesRead < 0 {
                throw SidecarClientError.readFailed
            }
            if bytesRead == 0 { break }
            responseData.append(contentsOf: buffer[0..<bytesRead])
            if responseData.last == UInt8(ascii: "\n") { break }
        }

        guard !responseData.isEmpty else { throw SidecarClientError.emptyResponse }
        guard let line = String(data: responseData, encoding: .utf8) else {
            throw SidecarClientError.malformedResponse("<non-utf8 data>")
        }
        return try parse(line: line.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func parse(line: String) throws -> String {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? String
        else {
            throw SidecarClientError.malformedResponse(line)
        }
        switch status {
        case "ok":
            guard let text = json["text"] as? String else {
                throw SidecarClientError.malformedResponse(line)
            }
            return text
        case "error":
            let message = (json["message"] as? String) ?? "unknown sidecar error"
            throw SidecarClientError.sidecarError(message)
        default:
            throw SidecarClientError.malformedResponse(line)
        }
    }
}

import Foundation
import Darwin

public struct FolderSize: Sendable {
    public let bytes: Int64
    public let isComplete: Bool

    /// Logical file bytes, including hidden files and packages; never follows symbolic links.
    public static func measure(_ folder: URL, shouldCancel: @escaping () -> Bool = { Task<Never, Never>.isCancelled }) throws -> FolderSize {
        func checkCancellation() throws {
            if shouldCancel() { throw CancellationError() }
        }
        try checkCancellation()
        guard folder.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
        return try folder.withUnsafeFileSystemRepresentation { path in
            guard let path, let ownedPath = strdup(path) else { throw POSIXError(.ENOMEM) }
            defer { free(ownedPath) }
            var paths: [UnsafeMutablePointer<CChar>?] = [ownedPath, nil]
            return try paths.withUnsafeMutableBufferPointer { buffer in
                // Use one stat per entry instead of Foundation resource/URL metadata.
                // PHYSICAL excludes symlink targets; NOCHDIR makes parallel scans safe.
                guard let tree = fts_open(buffer.baseAddress!, FTS_PHYSICAL | FTS_NOCHDIR, nil) else {
                    throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
                }
                defer { fts_close(tree) }
                var total: Int64 = 0
                var complete = true
                while true {
                    try checkCancellation()
                    errno = 0
                    guard let pointer = fts_read(tree) else {
                        if errno != 0 { complete = false }
                        break
                    }
                    let entry = pointer.pointee
                    let kind = Int32(entry.fts_info)
                    if entry.fts_level == 0 && kind != FTS_D && kind != FTS_DP {
                        throw POSIXError(POSIXErrorCode(rawValue: entry.fts_errno) ?? .ENOTDIR)
                    }
                    switch kind {
                    case FTS_F:
                        if let metadata = entry.fts_statp { total += Int64(metadata.pointee.st_size) }
                        else { complete = false }
                    case FTS_DNR, FTS_ERR, FTS_NS, FTS_DC:
                        complete = false
                    default:
                        break
                    }
                }
                try checkCancellation()
                return FolderSize(bytes: total, isComplete: complete)
            }
        }
    }
}

import Foundation
import Darwin

public enum FileActions {
    public enum ActionError: LocalizedError {
        case invalidName, copyIntoSelf, collision(String), moveIntoSelf
        public var errorDescription: String? {
            switch self {
            case .invalidName: return "Enter a name without slashes, colons, or control characters."
            case .copyIntoSelf: return "A folder cannot be copied into itself or one of its subfolders."
            case .collision(let name): return "An item named ‘\(name)’ already exists. Nothing was replaced."
            case .moveIntoSelf: return "A folder cannot be moved into itself or one of its subfolders."
            }
        }
    }

    private static func destination(_ parent: URL, name: String) throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains(":"),
              name.rangeOfCharacter(from: .controlCharacters) == nil else { throw ActionError.invalidName }
        let url = parent.appendingPathComponent(name)
        // lstat-like lookup also detects dangling symbolic links.
        if (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil {
            throw ActionError.collision(name)
        }
        return url
    }

    @discardableResult public static func createFolder(in parent: URL, name: String) throws -> URL {
        let url = try destination(parent, name: name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        return url
    }

    @discardableResult public static func rename(_ source: URL, to name: String) throws -> URL {
        if source.lastPathComponent == name { return source }
        let url = try destination(source.deletingLastPathComponent(), name: name)
        try FileManager.default.moveItem(at: source, to: url)
        return url
    }

    @discardableResult public static func copy(_ source: URL, into parent: URL) throws -> URL {
        let original = source.resolvingSymlinksInPath().standardizedFileURL.path
        let target = parent.resolvingSymlinksInPath().standardizedFileURL.path
        guard target != original, !target.hasPrefix(original.hasSuffix("/") ? original : original + "/") else {
            throw ActionError.copyIntoSelf
        }
        let isDirectory = (try? source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let ext = isDirectory ? "" : source.pathExtension
        let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
        let extensionSuffix = ext.isEmpty ? "" : "." + ext
        var name = source.lastPathComponent
        var copyNumber = 1
        let url: URL
        while true {
            do {
                url = try destination(parent, name: name)
                break
            } catch ActionError.collision {
                name = stem + " copy" + (copyNumber == 1 ? "" : " \(copyNumber)") + extensionSuffix
                copyNumber += 1
            }
        }
        // FileManager refuses an existing destination; it never overwrites one.
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    public enum MoveConflict: Sendable { case fail, keepBoth, skip }

    public static func moveConflicts(_ sources: [URL], into parent: URL) -> [String] {
        sources.compactMap { source in
            let destination = parent.appendingPathComponent(source.lastPathComponent)
            if canonical(source).path == canonical(destination).path { return nil }
            return (try? FileManager.default.attributesOfItem(atPath: destination.path)) == nil ? nil : source.lastPathComponent
        }
    }

    private static func canonical(_ url: URL) -> URL {
        url.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(url.lastPathComponent)
    }

    @discardableResult public static func move(_ source: URL, into parent: URL, conflict: MoveConflict = .fail) throws -> URL {
        let original = canonical(source)
        let folder = parent.resolvingSymlinksInPath()
        var target = folder.appendingPathComponent(source.lastPathComponent)
        if original.path == target.path { return source }
        let attributes = try FileManager.default.attributesOfItem(atPath: original.path)
        if attributes[.type] as? FileAttributeType == .typeDirectory,
           folder.path == original.path || folder.path.hasPrefix(original.path.hasSuffix("/") ? original.path : original.path + "/") {
            throw ActionError.moveIntoSelf
        }
        if (try? FileManager.default.attributesOfItem(atPath: target.path)) != nil {
            switch conflict {
            case .fail: throw ActionError.collision(target.lastPathComponent)
            case .skip: return source
            case .keepBoth:
                let ext = attributes[.type] as? FileAttributeType == .typeDirectory ? "" : source.pathExtension
                let stem = ext.isEmpty ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent
                var index = 2
                repeat {
                    target = folder.appendingPathComponent(stem + " \(index)" + (ext.isEmpty ? "" : "." + ext))
                    index += 1
                } while (try? FileManager.default.attributesOfItem(atPath: target.path)) != nil
            }
        }
        try moveExclusively(original, to: target)
        return target
    }

    static func moveExclusively(_ source: URL, to destination: URL) throws {
        if renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) == 0 { return }
        let code = errno
        if code == EEXIST { throw ActionError.collision(destination.lastPathComponent) }
        if code == EXDEV {
            // Foundation copies across volumes before removing the source and refuses existing destinations.
            try FileManager.default.moveItem(at: source, to: destination)
            return
        }
        throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
}

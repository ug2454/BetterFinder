import Foundation
import Darwin

public enum FileUndo {
    public enum Kind: Sendable { case newFolder, rename, trash, move }
    public enum UndoError: LocalizedError {
        case changed, occupied, nonempty, missingTrashLocation
        public var errorDescription: String? {
            switch self {
            case .changed: return "The item or its parent folder has changed. Undo was stopped."
            case .occupied: return "The original name is already in use. Nothing was replaced."
            case .nonempty: return "The new folder now contains files. Undo will not delete them."
            case .missingTrashLocation: return "The item was trashed, but macOS did not return its Trash location. Undo is unavailable for this item."
            }
        }
    }

    fileprivate struct Identity: Sendable, Equatable {
        let volume: UInt64
        let inode: UInt64
        let created: Date?
        init(_ url: URL) throws {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let volume = attributes[.systemNumber] as? NSNumber,
                  let inode = attributes[.systemFileNumber] as? NSNumber else { throw UndoError.changed }
            self.volume = volume.uint64Value; self.inode = inode.uint64Value
            created = attributes[.creationDate] as? Date
        }
        func verify(_ url: URL) throws {
            guard (try? Identity(url)) == self else { throw UndoError.changed }
        }
    }

    // Resolve parent aliases while preserving the final component (which may itself be a symbolic link).
    private static func canonical(_ url: URL) -> URL {
        url.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(url.lastPathComponent)
    }

    public struct Preparation: Sendable {
        private let kind: Kind
        private let original: URL
        private let identity: Identity?
        private let parentIdentity: Identity

        public init(kind: Kind, source: URL) throws {
            self.kind = kind; original = FileUndo.canonical(source)
            identity = kind == .newFolder ? nil : try Identity(original)
            parentIdentity = try Identity(kind == .newFolder ? source.resolvingSymlinksInPath() : original.deletingLastPathComponent())
        }

        public func record(result: URL) throws -> Record? {
            let item = FileUndo.canonical(result)
            if kind != .newFolder && original.path == item.path { return nil }
            let itemIdentity = try Identity(item)
            if let identity, identity != itemIdentity {
                // A completed cross-volume move has a new filesystem identity.
                guard kind == .move, identity.volume != itemIdentity.volume,
                      (try? FileManager.default.attributesOfItem(atPath: original.path)) == nil else { throw UndoError.changed }
            }
            return try Record(item: item, restoreTo: kind == .newFolder ? nil : original,
                              identity: itemIdentity, originalParentIdentity: parentIdentity)
        }
    }

    public struct Record: Sendable {
        public let item: URL
        public var affectedFolders: [URL] {
            [item.deletingLastPathComponent()] + (restoreTo.map { [$0.deletingLastPathComponent()] } ?? [])
        }
        private let restoreTo: URL?
        private let identity: Identity
        private let currentParentIdentity: Identity
        private let originalParentIdentity: Identity

        fileprivate init(item: URL, restoreTo: URL?, identity: Identity, originalParentIdentity: Identity) throws {
            self.item = item; self.restoreTo = restoreTo; self.identity = identity
            currentParentIdentity = try Identity(item.deletingLastPathComponent())
            self.originalParentIdentity = originalParentIdentity
        }

        @discardableResult public func undo() throws -> URL? {
            try currentParentIdentity.verify(item.deletingLastPathComponent())
            try identity.verify(item)
            if let destination = restoreTo {
                try originalParentIdentity.verify(destination.deletingLastPathComponent())
                // Atomic exclusive rename also refuses dangling symlinks and destinations created during undo.
                try FileActions.moveExclusively(item, to: destination)
                return destination
            }
            try originalParentIdentity.verify(item.deletingLastPathComponent())
            // rmdir is deliberately nonrecursive: a concurrently added child makes undo fail safely.
            guard rmdir(item.path) == 0 else {
                let code = errno
                if code == ENOTEMPTY || code == EEXIST { throw UndoError.nonempty }
                throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
            }
            return nil
        }
    }

    public static func trash(_ source: URL) throws -> URL {
        var result: NSURL?
        try FileManager.default.trashItem(at: source, resultingItemURL: &result)
        guard let result else { throw UndoError.missingTrashLocation }
        return result as URL
    }
}

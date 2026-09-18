import Foundation

public struct FileEntry: Sendable, Identifiable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isSymbolicLink: Bool
    public let size: Int64
    public let modified: Date?
    public let created: Date?
    public var canBrowse: Bool { isDirectory && !isPackage }
}

public enum FileSort: String, Sendable { case name, modified, size }

public enum DirectoryReader {
    public static func read(_ url: URL, showHidden: Bool = false) throws -> [FileEntry] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey,
                                        .fileSizeKey, .contentModificationDateKey, .creationDateKey]
        let urls = try FileManager.default.contentsOfDirectory(at: url,
            includingPropertiesForKeys: Array(keys), options: showHidden ? [] : [.skipsHiddenFiles])
        return urls.map { child in
            // A file may disappear between enumeration and metadata lookup.
            let values = try? child.resourceValues(forKeys: keys)
            return FileEntry(url: child, name: child.lastPathComponent,
                isDirectory: values?.isDirectory ?? false, isPackage: values?.isPackage ?? false,
                isSymbolicLink: values?.isSymbolicLink ?? false, size: Int64(values?.fileSize ?? 0),
                modified: values?.contentModificationDate, created: values?.creationDate)
        }
    }

    public static func sorted(_ entries: [FileEntry], by key: FileSort, ascending: Bool, folderSizes: [URL: Int64] = [:]) -> [FileEntry] {
        entries.sorted { a, b in
            if a.canBrowse != b.canBrowse { return a.canBrowse }
            let comparison: ComparisonResult
            switch key {
            case .name: comparison = a.name.localizedStandardCompare(b.name)
            case .modified:
                comparison = (a.modified ?? .distantPast).compare(b.modified ?? .distantPast)
            case .size:
                let aSize = a.isDirectory && !a.isSymbolicLink ? folderSizes[a.url] : a.size
                let bSize = b.isDirectory && !b.isSymbolicLink ? folderSizes[b.url] : b.size
                if (aSize == nil) != (bSize == nil) { return aSize != nil }
                comparison = aSize == bSize ? .orderedSame : ((aSize ?? 0) < (bSize ?? 0) ? .orderedAscending : .orderedDescending)
            }
            if comparison == .orderedSame { return a.name.localizedStandardCompare(b.name) == .orderedAscending }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    public static func resolve(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }
}

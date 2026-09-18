import Foundation
import XCTest
@testable import DirectoryCore

final class FolderSizeTests: XCTestCase {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    func testIncludesNestedHiddenAndPackageFilesWithoutFollowingLinks() throws {
        let root = try fixture()
        let nested = root.appendingPathComponent("Nested/Test.app/Contents")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 11).write(to: root.appendingPathComponent("file"))
        try Data(repeating: 2, count: 7).write(to: root.appendingPathComponent(".hidden"))
        try Data(repeating: 3, count: 23).write(to: nested.appendingPathComponent("payload"))
        try FileManager.default.createSymbolicLink(at: nested.appendingPathComponent("loop"), withDestinationURL: root)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked-file"), withDestinationURL: root.appendingPathComponent("file"))
        let result = try FolderSize.measure(root)
        XCTAssertEqual(result.bytes, 41)
        XCTAssertTrue(result.isComplete)
    }

    func testEmptyUnavailableAndCancelledScans() throws {
        let root = try fixture()
        let empty = try FolderSize.measure(root)
        XCTAssertEqual(empty.bytes, 0)
        XCTAssertTrue(empty.isComplete)
        XCTAssertThrowsError(try FolderSize.measure(root.appendingPathComponent("missing")))
        try Data([1]).write(to: root.appendingPathComponent("file"))
        var checks = 0
        XCTAssertThrowsError(try FolderSize.measure(root, shouldCancel: { checks += 1; return checks > 1 })) {
            XCTAssertTrue($0 is CancellationError)
        }
    }

    func testUnreadableContentsAreNotReportedAsComplete() throws {
        let root = try fixture()
        let restricted = root.appendingPathComponent("Restricted")
        try FileManager.default.createDirectory(at: restricted, withIntermediateDirectories: false)
        try Data([1, 2, 3]).write(to: restricted.appendingPathComponent("secret"))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: restricted.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: restricted.path) }
        guard !FileManager.default.isReadableFile(atPath: restricted.path) else { throw XCTSkip("Permission restrictions are not enforced for this test user") }
        let result = try FolderSize.measure(root)
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.bytes, 0)
    }

    func testSizeSortingUsesCalculatedTotalsAndKeepsUnknownLast() throws {
        let root = try fixture()
        for name in ["Large", "Small", "Unknown"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: false)
        }
        let entries = try DirectoryReader.read(root)
        let sizes: [URL: Int64] = Dictionary(uniqueKeysWithValues: entries.filter { $0.name != "Unknown" }.map { ($0.url, $0.name == "Large" ? Int64(400) : Int64(10)) })
        XCTAssertEqual(DirectoryReader.sorted(entries, by: .size, ascending: true, folderSizes: sizes).map(\.name), ["Small", "Large", "Unknown"])
        XCTAssertEqual(DirectoryReader.sorted(entries, by: .size, ascending: false, folderSizes: sizes).map(\.name), ["Large", "Small", "Unknown"])
    }
}

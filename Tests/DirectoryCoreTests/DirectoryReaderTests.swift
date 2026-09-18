import Foundation
import XCTest
@testable import DirectoryCore

final class DirectoryReaderTests: XCTestCase {
    func testRealFolderEnumerationAndNaturalSorting() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Folder"), withIntermediateDirectories: true)
        for name in ["file10.txt", "file2.txt", ".hidden", "résumé 日本語.txt"] {
            try Data("example".utf8).write(to: root.appendingPathComponent(name))
        }
        let result = try DirectoryReader.read(root)
        XCTAssertEqual(result.count, 4)
        XCTAssertFalse(result.contains { $0.name == ".hidden" })
        XCTAssertEqual(try DirectoryReader.read(root, showHidden: true).count, 5)
        let sorted = DirectoryReader.sorted(result, by: .name, ascending: true)
        XCTAssertEqual(sorted.first?.name, "Folder")
        XCTAssertLessThan(sorted.firstIndex { $0.name == "file2.txt" }!, sorted.firstIndex { $0.name == "file10.txt" }!)
        XCTAssertEqual(DirectoryReader.sorted(result, by: .name, ascending: false).first?.name, "Folder")
        XCTAssertEqual(result.first { $0.name == "file2.txt" }?.size, 7)
    }

    func testUnavailableLocationReportsError() {
        XCTAssertThrowsError(try DirectoryReader.read(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")))
    }

    func testResolveTildeAndUnicode() {
        XCTAssertEqual(DirectoryReader.resolve("~/Documents/日本語").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/日本語").path)
    }
}

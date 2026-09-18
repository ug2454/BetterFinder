import Foundation
import XCTest
@testable import DirectoryCore

final class FileActionsTests: XCTestCase {
    func testCreateRenameAndCopyPreserveContentsAndRejectCollisions() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: root) }
        let folder = try FileActions.createFolder(in: root, name: "New Folder")
        XCTAssertThrowsError(try FileActions.createFolder(in: root, name: "New Folder"))
        let source = root.appendingPathComponent("original.txt")
        try Data("keep me".utf8).write(to: source)
        let renamed = try FileActions.rename(source, to: "résumé.txt")
        XCTAssertFalse(fm.fileExists(atPath: source.path))
        let copy = try FileActions.copy(renamed, into: folder)
        XCTAssertEqual(try Data(contentsOf: copy), Data("keep me".utf8))
        XCTAssertTrue(fm.fileExists(atPath: renamed.path))
        let duplicate = try FileActions.copy(renamed, into: folder)
        XCTAssertEqual(duplicate.lastPathComponent, "résumé copy.txt")
        XCTAssertEqual(try Data(contentsOf: duplicate), Data("keep me".utf8))
        XCTAssertEqual(try Data(contentsOf: copy), Data("keep me".utf8))
        try Data("other".utf8).write(to: source)
        XCTAssertThrowsError(try FileActions.rename(renamed, to: "original.txt"))
        XCTAssertEqual(try Data(contentsOf: source), Data("other".utf8))
    }

    func testPasteInSameFolderUsesNextAvailableCopyName() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: root) }
        for name in ["report.txt", "README", ".hidden"] {
            let source = root.appendingPathComponent(name)
            try Data("original".utf8).write(to: source)
            let stem = source.pathExtension.isEmpty ? name : source.deletingPathExtension().lastPathComponent
            let ext = source.pathExtension.isEmpty ? "" : "." + source.pathExtension
            let first = try FileActions.copy(source, into: root)
            XCTAssertEqual(first.lastPathComponent, stem + " copy" + ext)
            try Data("preserve duplicate".utf8).write(to: first)
            let second = try FileActions.copy(source, into: root)
            XCTAssertEqual(second.lastPathComponent, stem + " copy 2" + ext)
            XCTAssertEqual(try Data(contentsOf: second), Data("original".utf8))
            XCTAssertEqual(try Data(contentsOf: first), Data("preserve duplicate".utf8))
        }
        let folder = try FileActions.createFolder(in: root, name: "Folder.with.dots")
        try Data("nested".utf8).write(to: folder.appendingPathComponent("child.txt"))
        let duplicate = try FileActions.copy(folder, into: root)
        XCTAssertEqual(duplicate.lastPathComponent, "Folder.with.dots copy")
        XCTAssertEqual(try Data(contentsOf: duplicate.appendingPathComponent("child.txt")), Data("nested".utf8))
    }

    func testInvalidNamesAndRecursiveCopiesAreRejected() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: root) }
        for name in ["", " ", ".", "..", "../escape", "a/b", "a:b", "a\n"] {
            XCTAssertThrowsError(try FileActions.createFolder(in: root, name: name))
        }
        let child = try FileActions.createFolder(in: root, name: "child")
        XCTAssertThrowsError(try FileActions.copy(root, into: child))
        let link = root.appendingPathComponent("alias")
        try fm.createSymbolicLink(at: link, withDestinationURL: child)
        XCTAssertThrowsError(try FileActions.copy(root, into: link))
        let dangling = root.appendingPathComponent("dangling")
        try fm.createSymbolicLink(atPath: dangling.path, withDestinationPath: root.appendingPathComponent("missing").path)
        XCTAssertThrowsError(try FileActions.createFolder(in: root, name: "dangling"))
    }
}

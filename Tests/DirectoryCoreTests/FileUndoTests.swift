import Foundation
import XCTest
@testable import DirectoryCore

final class FileUndoTests: XCTestCase {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    func testRenameUndoRefusesCollisionAndCanBeRetried() throws {
        try fixture { root in
            let original = root.appendingPathComponent("original.txt")
            try Data("original data".utf8).write(to: original)
            let preparation = try FileUndo.Preparation(kind: .rename, source: original)
            let renamed = try FileActions.rename(original, to: "renamed.txt")
            let record = try XCTUnwrap(preparation.record(result: renamed))
            try Data("new data".utf8).write(to: original)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: original), Data("new data".utf8))
            XCTAssertEqual(try Data(contentsOf: renamed), Data("original data".utf8))
            try FileManager.default.removeItem(at: original)
            XCTAssertEqual(try record.undo()?.path, original.path)
            XCTAssertEqual(try Data(contentsOf: original), Data("original data".utf8))
        }
    }

    func testNewFolderUndoNeverRemovesChildren() throws {
        try fixture { root in
            let preparation = try FileUndo.Preparation(kind: .newFolder, source: root)
            let folder = try FileActions.createFolder(in: root, name: "New Folder")
            let record = try XCTUnwrap(preparation.record(result: folder))
            let child = folder.appendingPathComponent("keep.txt")
            try Data("keep".utf8).write(to: child)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: child), Data("keep".utf8))
            try FileManager.default.removeItem(at: child)
            XCTAssertNil(try record.undo())
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        }
    }

    func testUndoRefusesReplacedItemAndDanglingDestination() throws {
        try fixture { root in
            let fm = FileManager.default
            let original = root.appendingPathComponent("original")
            try Data("original".utf8).write(to: original)
            let preparation = try FileUndo.Preparation(kind: .rename, source: original)
            let renamed = try FileActions.rename(original, to: "renamed")
            let record = try XCTUnwrap(preparation.record(result: renamed))
            try fm.createSymbolicLink(atPath: original.path, withDestinationPath: root.appendingPathComponent("missing").path)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: renamed), Data("original".utf8))
            try fm.moveItem(at: renamed, to: root.appendingPathComponent("saved"))
            try Data("replacement".utf8).write(to: renamed)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: renamed), Data("replacement".utf8))
        }
    }

    func testTrashStyleRestoreAndMissingItem() throws {
        try fixture { root in
            let original = root.appendingPathComponent("file.txt")
            try Data("restore me".utf8).write(to: original)
            let trash = try FileActions.createFolder(in: root, name: "Simulated Trash")
            let preparation = try FileUndo.Preparation(kind: .trash, source: original)
            let moved = trash.appendingPathComponent("file.txt")
            try FileManager.default.moveItem(at: original, to: moved)
            let record = try XCTUnwrap(preparation.record(result: moved))
            XCTAssertEqual(try record.undo()?.path, original.path)
            XCTAssertEqual(try Data(contentsOf: original), Data("restore me".utf8))
            XCTAssertThrowsError(try record.undo())
        }
    }

    func testActualTrashRoundTrip() throws {
        try fixture { root in
            let original = root.appendingPathComponent("betterfinder-undo-test-\(UUID().uuidString).txt")
            try Data("disposable undo fixture".utf8).write(to: original)
            let preparation = try FileUndo.Preparation(kind: .trash, source: original)
            let trashed = try FileUndo.trash(original)
            defer { try? FileManager.default.removeItem(at: trashed) }
            XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))
            let record = try XCTUnwrap(preparation.record(result: trashed))
            _ = try record.undo()
            XCTAssertEqual(try Data(contentsOf: original), Data("disposable undo fixture".utf8))
            XCTAssertFalse(FileManager.default.fileExists(atPath: trashed.path))
        }
    }

    func testUndoRefusesReplacedParent() throws {
        try fixture { root in
            let fm = FileManager.default
            let parent = try FileActions.createFolder(in: root, name: "parent")
            let original = parent.appendingPathComponent("original.txt")
            try Data("original".utf8).write(to: original)
            let preparation = try FileUndo.Preparation(kind: .rename, source: original)
            let renamed = try FileActions.rename(original, to: "renamed.txt")
            let record = try XCTUnwrap(preparation.record(result: renamed))
            let saved = root.appendingPathComponent("saved-parent")
            try fm.moveItem(at: parent, to: saved)
            try fm.createDirectory(at: parent, withIntermediateDirectories: false)
            try Data("replacement".utf8).write(to: renamed)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: renamed), Data("replacement".utf8))
            XCTAssertEqual(try Data(contentsOf: saved.appendingPathComponent("renamed.txt")), Data("original".utf8))
        }
    }
}

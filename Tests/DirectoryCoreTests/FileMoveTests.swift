import Foundation
import XCTest
@testable import DirectoryCore

final class FileMoveTests: XCTestCase {
    private func fixture(_ body: (URL, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = try FileActions.createFolder(in: root, name: "destination")
        try body(root, destination)
    }

    func testMoveAndUndoPreserveFileAndNestedFolderContents() throws {
        try fixture { root, destination in
            let file = root.appendingPathComponent("résumé.txt")
            try Data("content".utf8).write(to: file)
            let folder = try FileActions.createFolder(in: root, name: "Folder")
            try Data("nested".utf8).write(to: folder.appendingPathComponent("child"))
            for source in [file, folder] {
                let preparation = try FileUndo.Preparation(kind: .move, source: source)
                let moved = try FileActions.move(source, into: destination)
                XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
                let record = try XCTUnwrap(preparation.record(result: moved))
                _ = try record.undo()
                XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
                XCTAssertFalse(FileManager.default.fileExists(atPath: moved.path))
            }
            XCTAssertEqual(try Data(contentsOf: file), Data("content".utf8))
            XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("child")), Data("nested".utf8))
        }
    }

    func testConflictPoliciesNeverOverwriteAndSkipRetainsSource() throws {
        try fixture { root, destination in
            let source = root.appendingPathComponent("report.txt")
            let existing = destination.appendingPathComponent("report.txt")
            try Data("incoming".utf8).write(to: source)
            try Data("existing".utf8).write(to: existing)
            XCTAssertEqual(FileActions.moveConflicts([source], into: destination), ["report.txt"])
            XCTAssertThrowsError(try FileActions.move(source, into: destination))
            XCTAssertEqual(try FileActions.move(source, into: destination, conflict: .skip), source)
            XCTAssertEqual(try Data(contentsOf: source), Data("incoming".utf8))
            try Data("keep second".utf8).write(to: destination.appendingPathComponent("report 2.txt"))
            let preparation = try FileUndo.Preparation(kind: .move, source: source)
            let moved = try FileActions.move(source, into: destination, conflict: .keepBoth)
            XCTAssertEqual(moved.lastPathComponent, "report 3.txt")
            XCTAssertEqual(try Data(contentsOf: existing), Data("existing".utf8))
            XCTAssertEqual(try Data(contentsOf: moved), Data("incoming".utf8))
            let record = try XCTUnwrap(preparation.record(result: moved))
            try Data("new occupant".utf8).write(to: source)
            XCTAssertThrowsError(try record.undo())
            XCTAssertEqual(try Data(contentsOf: source), Data("new occupant".utf8))
            XCTAssertEqual(try Data(contentsOf: moved), Data("incoming".utf8))
        }
    }

    func testSelfMovesDescendantsAndMissingDestination() throws {
        try fixture { root, destination in
            XCTAssertEqual(try FileActions.move(destination, into: root).path, destination.path)
            XCTAssertThrowsError(try FileActions.move(root, into: destination))
            let alias = root.appendingPathComponent("alias")
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: destination)
            XCTAssertThrowsError(try FileActions.move(root, into: alias))
            let source = root.appendingPathComponent("source")
            try Data("keep".utf8).write(to: source)
            XCTAssertThrowsError(try FileActions.move(source, into: root.appendingPathComponent("missing")))
            XCTAssertEqual(try Data(contentsOf: source), Data("keep".utf8))
        }
    }

    func testMoveSymbolicLinkWithoutMovingItsTarget() throws {
        try fixture { root, destination in
            let target = root.appendingPathComponent("target")
            try Data("keep target".utf8).write(to: target)
            let link = root.appendingPathComponent("link")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
            let preparation = try FileUndo.Preparation(kind: .move, source: link)
            let moved = try FileActions.move(link, into: destination)
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: moved.path), target.path)
            XCTAssertEqual(try Data(contentsOf: target), Data("keep target".utf8))
            let record = try XCTUnwrap(preparation.record(result: moved))
            _ = try record.undo()
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), target.path)
        }
    }
}

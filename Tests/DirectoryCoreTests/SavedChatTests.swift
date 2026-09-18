import XCTest
@testable import DirectoryCore

final class SavedChatTests: XCTestCase {
    func testWhatsAppNumberAndPersistenceRoundTrip() throws {
        let chat = try SavedChat(name: " Family ", service: .whatsapp, destination: "+44 (7700) 900-123")
        XCTAssertEqual(try chat.link().absoluteString, "https://wa.me/447700900123")
        let restored = try JSONDecoder().decode(SavedChat.self, from: JSONEncoder().encode(chat))
        XCTAssertEqual(restored.name, "Family")
        XCTAssertEqual(restored.id, chat.id)
        XCTAssertEqual(try restored.link(), try chat.link())
        for invalid in ["", "123", "07700900123", "+44abc7700900123", "44+7700900123", "https://wa.me/447700900123"] {
            XCTAssertThrowsError(try SavedChat(name: "Test", service: .whatsapp, destination: invalid))
        }
    }
    func testDiscordLinksAndUnsupportedDestinations() throws {
        for path in ["/channels/@me/123456789", "/channels/123456789/987654321", "/channels/@me/123456789/987654321"] {
            let chat = try SavedChat(name: "Chat", service: .discord, destination: "https://discord.com" + path)
            XCTAssertEqual(try chat.link().absoluteString, "https://discord.com" + path)
        }
        for invalid in ["https://discord.com.evil.test/channels/@me/123", "file:///tmp/file", "https://discord.com@evil.test/channels/@me/123", "https://discord.com/channels/@me/not-an-id", "https://discord.com/channels/@me/123?other=1", "http://discord.com/channels/@me/123", "https://discord.com/channels/@me/0"] {
            XCTAssertThrowsError(try SavedChat(name: "Chat", service: .discord, destination: invalid))
        }
        XCTAssertThrowsError(try SavedChat(name: " ", service: .whatsapp, destination: "447700900123"))
    }
}

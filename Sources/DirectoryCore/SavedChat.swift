import Foundation

public struct SavedChat: Codable, Identifiable, Sendable {
    public enum Service: String, Codable, Sendable { case whatsapp = "WhatsApp", discord = "Discord" }
    public let id: UUID
    public let name: String
    public let service: Service
    public let destination: String

    public enum ValidationError: LocalizedError {
        case name, phone, discord
        public var errorDescription: String? {
            switch self {
            case .name: return "Enter a name for this chat."
            case .phone: return "Enter the WhatsApp number with its country code, for example +44 7700 900123."
            case .discord: return "Paste an HTTPS discord.com/channels/… channel or message link. In Discord, right-click a message and choose Copy Message Link."
            }
        }
    }

    public init(name: String, service: Service, destination: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ValidationError.name }
        id = UUID(); self.name = name; self.service = service
        self.destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try link()
    }

    public func link() throws -> URL {
        switch service {
        case .whatsapp:
            let allowed = CharacterSet(charactersIn: "+0123456789 ()-.")
            guard destination.unicodeScalars.allSatisfy({ allowed.contains($0) }),
                  !destination.dropFirst().contains("+") else { throw ValidationError.phone }
            let digits = destination.filter { $0.isASCII && $0.isNumber }
            guard (7...15).contains(digits.count), digits.first != "0" else { throw ValidationError.phone }
            return URL(string: "https://wa.me/" + digits)!
        case .discord:
            guard let parts = URLComponents(string: destination), parts.scheme?.lowercased() == "https",
                  parts.host?.lowercased() == "discord.com", parts.user == nil, parts.password == nil,
                  parts.port == nil, parts.query == nil, parts.fragment == nil else { throw ValidationError.discord }
            let segments = parts.path.split(separator: "/", omittingEmptySubsequences: false)
            func validID(_ value: Substring) -> Bool {
                !value.isEmpty && value.count <= 20 && value.allSatisfy { $0.isASCII && $0.isNumber } && value.contains(where: { $0 != "0" })
            }
            guard (segments.count == 4 || segments.count == 5), segments[0].isEmpty, segments[1] == "channels",
                  (segments[2] == "@me" || validID(segments[2])), validID(segments[3]),
                  segments.count == 4 || validID(segments[4]) else { throw ValidationError.discord }
            return URL(string: "https://discord.com" + parts.path)!
        }
    }
}

import AppKit

@MainActor
enum DefaultFileViewer {
    private static let backupKey = "defaultViewer.previous"
    private static let handlersDomain = "com.apple.LaunchServices/com.apple.launchservices.secure" as CFString
    private static let folderType = "public.folder"

    private static func read(_ key: String, domain: CFString) -> Any? {
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        return CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    private static func write(_ value: Any?, key: String, domain: CFString) -> Bool {
        CFPreferencesSetValue(key as CFString, value as CFPropertyList?, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else { return false }
        return NSDictionary(dictionary: ["value": read(key, domain: domain) ?? NSNull()])
            .isEqual(to: ["value": value ?? NSNull()])
    }
    private static var viewer: String? {
        read("NSFileViewer", domain: kCFPreferencesAnyApplication) as? String
    }
    private static var handlers: [[String: Any]] {
        read("LSHandlers", domain: handlersDomain) as? [[String: Any]] ?? []
    }
    private static func isFolder(_ handler: [String: Any]) -> Bool {
        handler["LSHandlerContentType"] as? String == folderType
    }

    static func enable() async throws {
        var previous = UserDefaults.standard.dictionary(forKey: backupKey) ?? [:]
        // Migrate the backup from the earlier API, which failed before changing defaults.
        if previous["folderHandlers"] == nil {
            previous["folderHandlers"] = handlers.filter(isFolder)
            if let viewer { previous["viewer"] = viewer }
            UserDefaults.standard.set(previous, forKey: backupKey)
        }
        try apply(folderHandlers: [["LSHandlerContentType": folderType,
                                    "LSHandlerRoleAll": "dev.betterfinder.app"]], viewer: "dev.betterfinder.app")
    }
    static func restore() async throws {
        guard let previous = UserDefaults.standard.dictionary(forKey: backupKey) else { return }
        // A legacy backup means the earlier enable failed and no settings need restoring.
        guard let folderHandlers = previous["folderHandlers"] as? [[String: Any]] else {
            UserDefaults.standard.removeObject(forKey: backupKey)
            return
        }
        try apply(folderHandlers: folderHandlers, viewer: previous["viewer"] as? String)
        UserDefaults.standard.removeObject(forKey: backupKey)
    }
    private static func apply(folderHandlers: [[String: Any]], viewer newViewer: String?) throws {
        let oldHandlers = read("LSHandlers", domain: handlersDomain)
        let oldViewer = viewer
        let updated = handlers.filter { !isFolder($0) } + folderHandlers
        // macOS rejects public.folder with parameter error -50 through both handler APIs.
        // Save the scoped preferences used by file-viewer replacements; restart is required.
        guard write(updated, key: "LSHandlers", domain: handlersDomain),
              write(newViewer, key: "NSFileViewer", domain: kCFPreferencesAnyApplication) else {
            let restoredHandlers = write(oldHandlers, key: "LSHandlers", domain: handlersDomain)
            let restoredViewer = write(oldViewer, key: "NSFileViewer", domain: kCFPreferencesAnyApplication)
            let detail = restoredHandlers && restoredViewer
                ? "The previous preferences were restored."
                : "Some preferences could not be restored. Use Restore Previous File Viewer to retry."
            throw NSError(domain: "BetterFinder", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Couldn’t save the file-viewer preferences. \(detail)"])
        }
    }
}

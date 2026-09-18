import AppKit

public enum FullDiskAccessHelper {
    /// Checks whether BetterFinder currently has Full Disk Access.
    public static var isGranted: Bool {
        // Protected user directories that are restricted by TCC Full Disk Access.
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Library/Safari",
            "\(home)/Library/Mail",
            "\(home)/Library/Suggestions"
        ]

        for path in candidates {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                do {
                    _ = try FileManager.default.contentsOfDirectory(atPath: path)
                    return true
                } catch {
                    // Access denied or unreadable -> not granted
                }
            }
        }
        return false
    }

    /// Presents a guided alert and opens System Settings to Full Disk Access.
    public static func openSettings(for window: NSWindow?) {
        let alert = NSAlert()
        let granted = isGranted

        if granted {
            alert.messageText = "Full Disk Access is Active"
            alert.informativeText = "BetterFinder has Full Disk Access enabled. You can browse Desktop, Documents, Downloads, external volumes, and system directories without permission interruptions.\n\nYou can manage permissions anytime in System Settings."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Done")
        } else {
            alert.messageText = "Enable Full Disk Access for BetterFinder"
            alert.informativeText = "macOS restricts access to folders like Desktop, Documents, and Downloads. Granting Full Disk Access stops macOS from asking permission repeatedly for every folder.\n\n1. Click 'Open Settings' below.\n2. In Privacy & Security → Full Disk Access, toggle BetterFinder ON.\n3. (If BetterFinder is not in the list, drag BetterFinder.app from Finder into the list).\n4. Click 'Relaunch BetterFinder' to apply changes."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Relaunch BetterFinder")
            alert.addButton(withTitle: "Cancel")
        }

        let handleResponse: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn {
                // Reveal app bundle in Finder to facilitate drag-and-drop
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])

                // Deep link to System Settings -> Privacy & Security -> Full Disk Access
                let urlCandidates = [
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
                    URL(string: "x-apple.systempreferences:com.apple.preference.security")
                ].compactMap { $0 }

                var opened = false
                for url in urlCandidates {
                    if NSWorkspace.shared.open(url) {
                        opened = true
                        break
                    }
                }

                if !opened {
                    let fallback = NSAlert()
                    fallback.messageText = "Open System Settings Manually"
                    fallback.informativeText = "Please open System Settings → Privacy & Security → Full Disk Access, and enable BetterFinder."
                    fallback.runModal()
                }
            } else if response == .alertSecondButtonReturn && !granted {
                relaunchApp()
            }
        }

        if let window = window {
            alert.beginSheetModal(for: window, completionHandler: handleResponse)
        } else {
            let response = alert.runModal()
            handleResponse(response)
        }
    }

    /// Relaunches the current BetterFinder instance.
    public static func relaunchApp() {
        let bundleURL = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundleURL.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}

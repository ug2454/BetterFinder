# BetterFinder

First native macOS browsing increment based on the user-approved light design.

## Run

Requires macOS 14+ and Xcode Command Line Tools.

```sh
bash scripts/build-app.sh
open dist/BetterFinder.app
```

Open `Package.swift` in Xcode to work on the source. Run core checks with `swift test --disable-sandbox`.

## Included in this increment

- BetterFinder → Full Disk Access opens guided instructions and the macOS privacy setting, revealing the running app bundle so it can be added. Enable BetterFinder there and relaunch to cover protected folders together. Permission is granted by the user in macOS, not automatically by BetterFinder; ordinary filesystem restrictions still apply.
- Optional default file viewer: BetterFinder → Use BetterFinder as Default File Viewer sets the folder-opening association and file-viewer preference. Restore Previous File Viewer reverses these preferences. Restart other apps after enabling; some may require signing out. Compatible Reveal in Finder actions can then reveal files in BetterFinder; apps that explicitly target Finder and system Open/Save dialogs are unaffected. External folder opens and file-reveal Apple events are supported. The setting is not enabled automatically.
- Real local folders, expandable sidebar, mounted volume shortcuts.
- Native tabs: Cmd+T opens the current folder in a new tab, Cmd+W closes the active tab, Control+Tab / Control+Shift+Tab switches tabs. Open folders and the active tab restore on relaunch; navigation history stays independent during use.
- Back/forward/up, editable path, system folder picker, refresh.
- Sortable columns, natural filename order, folders first.
- Folder sizes calculate in the background and appear in the Size column and inspector. Includes nested/hidden files and packages, excludes symbolic links, and reports logical file bytes rather than allocated disk space. “≥” marks a partial total when some contents are unreadable. Size sorting uses complete totals, with unknown/partial totals last within each group. Navigation cancels old scans; Refresh recalculates sizes.
- Folder-size scans use lightweight filesystem metadata and up to three concurrent workers per tab, so one large folder does not hold up every other folder.
- Filename filtering within the current folder; multi-selection and file details.
- Double-click / Cmd+Down to open; Cmd+Up to go to parent.
- Flat unselected rows, one clear selection treatment, native file icons.
- Async folder loading and explicit access / missing-location errors.
- Right-click menus for files, empty file-list space, and sidebar folders.
- Saved Chats beside Share (also in the file context menu): add a name and a WhatsApp number with country code or a Discord channel/message link. Shortcuts persist locally across relaunches and are shared between tabs. Remove Chat deletes saved entries. Opening a shortcut follows its official HTTPS link using macOS routing; this may open the browser before the desktop app. Files are not automatically attached or sent.
- Saved Chats also offers Open WhatsApp and Open Discord; these app shortcuts remain available in the file context menu and File menu. They launch installed apps so you can choose a chat and drag files into it. They do not automatically attach or send files.
- Share selected files through the inspector's Share button, right-click → Share, or File → Share. Uses native macOS sharing services such as AirDrop and compatible installed extensions. Apps without sharing extensions use their own upload flow or existing file drag-and-drop; no automatic posting is performed.
- Native Quick Look: Space with the file list focused, Cmd+Y, or right-click → Quick Look. Supports selected files using installed macOS preview providers; Space/Escape dismisses the preview.
- New Folder (Cmd+Shift+N), Rename (Return with file-list focus), Copy/Paste (Cmd+C / Cmd+V), Move to Trash (Cmd+Delete).
- Duplicate (Cmd+D, File menu, or right-click) copies selected files/folders beside their originals, choosing available “copy” names and revealing the last completed duplicate. Keeps the clipboard unchanged. Duplicate Undo is not yet supported.
- Open selection (Cmd+O / Cmd+Down), Go to Folder (Cmd+Shift+G), Close Window (Cmd+W), and native Select All (Cmd+A).
- Name collisions report an error without replacing existing items. Failed copies may leave incomplete destinations; source files remain unchanged.
- Cmd+C → Option+Cmd+V moves copied items into the current folder. Move Items Here is also in Edit and file-area context menus. Drag files onto folders, sidebar locations, or another tab's file area; local drags move, Option-drag copies. Incoming external drags default to copying. Conflicts offer Keep Both, Skip, or Cancel, preserving existing items. Skipped/failed move-paste items remain on the clipboard.
- Cmd+Z / Edit → Undo reverses New Folder, Rename, Move to Trash, and completed moves in the receiving tab. History lasts until that tab closes. Undo restores only the recorded item, refuses occupied original paths, and removes new folders only if empty. Failed items stay available for retry; successfully undone items are removed from the batch. Text editing retains its standard Undo behavior. Copy Undo and Redo are not included yet.

This is an early prototype with basic file actions. Split view, recursive search, broader Undo/Redo, transfer queues, watchers, richer session persistence, and release notarization are later increments. Cross-volume moves use Foundation but have not yet been integration-tested; interrupted transfers may require inspecting both locations. The inspector currently displays the system file icon and metadata; content previews open in the native Quick Look panel. The first-launch location is this development project. Saved tabs restore their folders, but not navigation history or selection across relaunches. Folder enumeration runs off the main thread but currently returns a complete directory listing; the full performance budgets in SPEC.md are not yet certified.

The local app bundle uses an ad-hoc signature for development; it is not a distributable notarized release.

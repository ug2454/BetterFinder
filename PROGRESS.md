# Progress

Folder-size optimization: replaced per-file Foundation resource lookups with a physical, no-chdir POSIX traversal and bounded folder scans to three concurrent workers per tab. Keeps logical-byte totals, hidden/package contents, symlink exclusion, unreadable/partial results, cancellation, and generation checks. Seven focused tests pass. A temporary 12,000-file fixture returned identical totals; three alternating runs yielded median 0.0340s before and 0.00780s after (4.36×); this is a synthetic local benchmark, not a guarantee for user folders. No layout changes or stale size cache introduced. Interactive review pending.

Folder-access setting: added BetterFinder → Full Disk Access with instructions, a link to the macOS Full Disk Access panel, and app-bundle reveal for adding/dragging the correct build. Does not inspect protected user data to guess permission status or grant permissions automatically. User must enable BetterFinder in macOS and relaunch. Release build passes; interactive permission setup awaits user review.

Folder-size increment: recursive background totals in the existing Size column and inspector; size sorting uses complete calculated totals. Includes nested, hidden, and package contents without following symbolic links. Shows calculating, unavailable, or partial (≥) states; cancels on navigation/deallocation and rejects stale results. Totals are logical file bytes, refreshed with folder reloads. Seven focused tests pass for nested/hidden/package files, link loops, permissions, empty/missing folders, cancellation, sorting, and existing directory reads. Interactive review pending.

Duplicate increment: added Cmd+D, File → Duplicate, and file-context Duplicate. Reuses the existing collision-safe copy operation in each selected item's parent folder; reveals the last successful result and leaves the clipboard untouched. Release build and all three existing FileActionsTests pass, including same-folder naming and folder contents. Interactive shortcut/menu validation awaits user feedback.

Default-viewer repair paused at the user's request. Both NSWorkspace and Launch Services role APIs returned -50 for public.folder, including a no-op restore to Finder. A preference-based replacement was written and compiled before the interruption but is not runtime-validated or enabled. No further default-viewer work is being performed.

Saved Chats release build and two focused validation/persistence tests pass. Reopening for the user's first interactive review; no actual chat links opened during testing.

Default file viewer increment: added opt-in application-menu actions to set folder-opening and NSFileViewer preferences and restore their previous values. Registered public.folder as an alternate viewer, handles external open URLs and misc/mvis reveal events, reuses matching tabs and selects requested files. Release build passes; rebuilt app registered and reopened, and one explicit reveal Apple event for Resources/AppIcon.png completed successfully. No default preferences were changed during implementation. Cursor integration remains for user validation after enabling and restarting Cursor; system dialogs and apps explicitly targeting Finder remain unaffected.

Saved Chats increment: popup beside Share and a file-context submenu list saved WhatsApp numbers and Discord channel/message links. Add Chat collects a name, app, and destination; Remove Chat deletes a saved shortcut. Records persist in app preferences and are shared across tabs. Links are validated on save and open. Official HTTPS conversation links use normal system routing, which may open a browser or ask to continue in the desktop app. App launch shortcuts remain in the popup. No conversations were opened or messages sent during implementation. Validation and build pending.

Chat-app shortcuts: added Open App beside Share with Open WhatsApp and Open Discord, plus matching file/context-menu actions. Launches the installed app by its verified bundle identifier and prompts the user to choose a chat and drag files. Handles missing apps and launch errors. Does not attach files, change the clipboard, or send messages. Release build passes; interactive review pending.

Sharing increment: added Share to the selected-file context menu, File menu, and inspector. Uses the native macOS sharing picker with selected file URLs, including multi-selection. Available destinations are determined by macOS and installed sharing extensions; there is no direct Discord/social integration. Existing file dragging can be used with apps that accept file drops. No files were sent during implementation. Release build passes; interactive sharing awaits user review.

Move release build passes. Reopening for user feedback on move-paste and drag/drop interactions.

Move increment: added Cmd+C → Option+Cmd+V and Move Items Here menus, file-list dragging, folder/sidebar drop targets, and local move versus Option-copy behavior. Native tabs support switching destinations during a drag. Conflicts offer Keep Both, Skip, or Cancel; exclusive moves refuse replacement. Successful moves register Undo in the receiving tab and refresh affected source/destination tabs while preserving their view state. Clipboard updates retain skipped/failed items. Cross-volume moves use Foundation's move implementation and can be undone using the recorded destination identity. All 16 core tests pass, including file/folder moves, Undo, conflicts, symlinks, descendant rejection, and failure preservation. Cross-volume transfers and interactive drag/tab-hover behavior remain unverified. Packaging and user feedback pending.

Undo increment: added Cmd+Z / Edit → Undo for New Folder, Rename, and Move to Trash, with independent in-memory histories per tab. Successful operations record actual result paths and filesystem identities. Restore uses exclusive rename; new-folder undo uses nonrecursive rmdir. Changed/missing items or parents and occupied destinations are refused. Partial undo retains only failed records for retry. Native text-editing Undo keeps responder priority. Copy Undo, Redo, and history across tab closure/relaunch remain out of scope. Release build passes. Six Undo tests pass, including an actual Trash-and-restore round trip, collision retry, nonempty folder protection, replaced item/parent, dangling destination, and missing-item handling; existing six browsing/copy tests also passed. Interactive shortcut routing awaits user review.

Tabs increment: native macOS tab bar with New Tab (Cmd+T), Close Tab (Cmd+W), and Control+Tab / Control+Shift+Tab navigation. Each tab owns its explorer state and history. Session persistence saves folder paths, visual tab order, and active tab, restoring them at launch. Menu actions now resolve through the active tab's responder chain. Closing the final tab preserves it for reopening; unavailable saved locations retain an error state. Release build passes; interactive tab switching and relaunch restoration await user review.

Quick Look increment: added native macOS previews for selected files using Space, Cmd+Y, and the file context menu. The panel uses the responder-chain control lifecycle, supports multi-selection, follows changed file selection, and closes when selection clears. No layout changes or other proposed features added. Release build passes; interactive preview behavior awaits user review.

Storage graphic: added a compact drive name, usage bar, and “used of total” capacity label at the bottom of the sidebar. Reads actual capacity for the browsed volume off the main thread and updates with folder navigation/refresh. Unavailable capacity is explicitly labeled; stale results are ignored. Other layout and behavior preserved. First version awaiting user feedback.

Closed-app Dock icon follow-up: verified the bundle includes AppIcon.icns and the pinned Dock item points to this build. Refresh the bundle modification date and its Launch Services registration, then restart the Dock to discard the placeholder. Future builds now update the bundle modification date after packaging. Artwork unchanged.

App icon: generated one Finder-inspired blue/white smiling-folder icon using the built-in image tool; saved Resources/AppIcon.png and packaged Resources/AppIcon.icns. Bundle metadata and build script now include the icon, with Dock artwork loaded on launch. First version awaiting user feedback; no design iterations performed.

Trash sound patch: use the installed Finder “move to trash” sound once after a successful Trash operation, including Command-Delete and the context menu. Failed or partially failed operations do not play the success sound. No other behavior changed.

New Folder follow-up: after successful creation and list reload, select the created folder at its sorted position and scroll it into view. Applies only to New Folder and does not redirect the user if they have navigated elsewhere. Release build passes; awaiting user visual review.

## Approval

The user explicitly approved the designs in this conversation with “i approve the designs.” The latest user-supplied light-theme screenshot is the approved visual reference. It includes flat white file rows, a blue selected row, and column sort arrows. Previous local Figma construction records are historical and do not describe the user's final manual edits.

## Current increment

Phase 1 first working native browsing prototype. Use the existing specification for subsequent phases, but deliver this increment for feedback before extending it.

Figma and computer-use quota restrictions remain respected. No new Figma calls are needed to implement the approved screenshot.

Implemented: native AppKit window, real folder listing, expandable sidebar, editable path, back/forward/up navigation, sortable columns, current-folder filename filtering, hidden-file toggle, selection, file metadata, and opening in the default application. File rows are flat; selected rows are blue.

Verified: debug build and three directory-handling tests pass (enumeration/natural sorting/hidden files, Unicode and tilde paths, missing-location errors). Interactive UI behavior and the full Phase 1 performance gate remain unverified.

Remaining: user feedback on this first increment before further UI changes; later phases cover tabs, split panes, content previews, file operations, broader search, persistence, and release validation.

Sidebar alignment patch: wrapped each sidebar label in a table cell and centered it vertically within the selection row. Existing colors and spacing preserved. Awaiting user visual feedback.

User accepted sidebar alignment. Requested right-click menus and standard shortcuts. Added file/blank-space/sidebar context menus; New Folder, Rename, Copy/Paste, Move to Trash, standard Open, Go to Folder, and Close Window shortcuts. Right-clicking an unselected file selects it; right-clicking a selected file preserves the multi-selection. File actions run off the main thread and report per-item failures without overwriting existing destinations. Five core tests pass, covering browsing plus creation/rename/copy, collision preservation, invalid names, and recursive-copy rejection. Interactive menu/shortcut validation and Trash integration remain for review. Layout unchanged; move-paste, Quick Look, file undo, and transfer queues are not implemented.

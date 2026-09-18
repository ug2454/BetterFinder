# BetterFinder — product and delivery specification

Version 0.1 · 15 September 2026 · Design approved by user; first native browsing increment underway

## 1. Product promise

A beautiful, native macOS file explorer with the navigational clarity of Windows Explorer and stronger tools for moving, finding, and organizing files. The everyday experience should make three things obvious: where you are, what is selected, and what an operation will do.

BetterFinder is a working name. Public naming and trademark checks are deferred until release planning.

### Intended users and jobs

- People who prefer Windows Explorer's folder tree, address bar, and detailed file lists.
- Developers and creators moving between project folders, downloads, assets, and external disks.
- Keyboard users who want predictable selection, navigation, and file operations.
- Everyday users who need to locate a file, preview it, and move it without losing their place.

### Principles

1. Location is always visible: breadcrumbs, editable path, and a synchronized optional folder tree.
2. Beauty supports scanning: restrained surfaces, clear hierarchy, compact typography, meaningful color.
3. Speed is perceptual and measurable: immediate feedback, incremental loading, interruptible background work.
4. File operations earn trust: explicit destination, honest progress, visible failures, recoverability where feasible.
5. Mac integration is essential: native menus, Quick Look, drag and drop, accessibility, system appearance.
6. Local by default: no account, cloud backend, AI service, or telemetry required.

## 2. Scope and assumptions

Proposed platform: native macOS app, macOS 14+ as an initial compatibility target; validate supported OS and hardware during the foundation phase. Apple silicon is the primary performance baseline. Intel support is conditional on build and test coverage.

Proposed distribution: Developer ID signed, notarized direct download. A Mac App Store edition is a separate decision after validating sandbox constraints. Do not promise to replace every system Finder entry point, desktop management, or system Open/Save dialog.

The user requested Figma design and approval before implementation. This specification and design preparation are authorized now. Production implementation begins only after the user approves concrete Figma frames and flows. Approval must be recorded with date and design revision; silence is not approval.

### First usable release

Tree navigation, breadcrumbs/path input, tabs, details and icon views, sorting, selection, Quick Look, file info, copy/move/rename/new folder/Trash, transfer queue, collision handling, folder search, accessibility, and session restoration.

### Version 1.0 additions

Split panes, batch rename, workspace presets, saved searches, tags, mounted-volume resilience, cloud-placeholder behavior, packaging and release validation.

### Deferred

Built-in SFTP/FTP/object storage, cloud account integration, sync engine, terminal emulator, plugin marketplace, automatic duplicate deletion, AI organization, Windows/Linux clients, arbitrary shell automation, and permanent deletion UI. Archive creation/extraction and gallery/column views are post-1.0 candidates.

## 3. Information architecture and window layout

Primary design canvas: 1440 × 960 points. Also design 1280 × 800 and minimum 960 × 640 windows; allow larger screens and Retina scaling.

| Region | Contents and behavior |
| --- | --- |
| Title/tab row | Native traffic lights; draggable window region; reorderable, closable tabs; new-tab button; overflow menu. |
| Navigation toolbar | Back, forward, up; breadcrumb/path field; scoped search; view selector; split-pane toggle; inspector toggle. |
| Sidebar | Favorites; expandable folder tree; mounted volumes; saved searches and tags as later-phase sections. Each group collapsible. |
| Main pane | Details or icon view; stable selection; optional grouping; loading/error/empty states inside the pane. |
| Inspector | Toggleable preview, name, type, size, dates, location, tags, permissions summary, and Open action. |
| Status bar | Item count, selected count/size, hidden-item indicator, transfer activity. Expensive totals show calculating. |
| Transfer center | Compact activity indicator expands to queued/running/completed/failed operations and actionable errors. |

Sidebar default 224 pt, resizable 180–320. Inspector default 288 pt, resizable 240–400. File panes retain at least 320 pt. At narrow widths, hide inspector first; if two panes cannot fit, switch to one pane while retaining both locations. Never hide the active path or silently discard tab state.

Split mode uses one shared sidebar and two independently navigable panes. Each pane owns its tab strip, path, history, selection, search, and view settings. The active pane has a subtle accent border and accessible label; the sidebar tracks it. Closing split mode keeps the inactive pane's session for reopening.

## 4. Visual direction

Recommended direction: **Quiet Precision**. Warm graphite dark mode, soft porcelain light mode, muted blue accent, clean separators, and subtle macOS material only in chrome. File rows remain on stable opaque surfaces for legibility.

Typography: system SF family, 13 pt primary UI, 11–12 pt secondary metadata, 16–18 pt section/inspector titles. Use tabular numerals for sizes and transfer metrics. Avoid excessive rounded cards, heavy gradients, ornamental dashboards, and oversized toolbars.

Provisional tokens, to be adjusted after contrast testing in Figma:

| Token | Dark | Light |
| --- | --- | --- |
| Window | #17191D | #F5F6F8 |
| Content | #1D2025 | #FFFFFF |
| Elevated surface | #272B32 | #ECEFF3 |
| Primary text | #F2F4F7 | #17202C |
| Secondary text | #A7AFBC | #586474 |
| Accent | #8AB4FF | #245AC7 |
| Selection fill | #293C58 | #E4EDFF |

Spacing scale: 4/8/12/16/24/32 pt. Row density: comfortable 36 pt; compact 28 pt. Icons generally 16–20 pt; familiar folder/file glyphs with restrained color. Controls use modest 6–8 pt corner radii. Hover, selection, keyboard focus, inactive selection, and drop targets must be visually distinct. Motion 120–180 ms where useful, respecting Reduce Motion. Respect Increase Contrast and Reduce Transparency; color never carries status alone.

## 5. Functional requirements

### Navigation and browsing — NAV

- NAV-01: Back/forward/up preserve per-location scroll and selection where items still exist.
- NAV-02: Breadcrumb segments navigate directly; clicking the path field or Cmd+L switches to editable absolute path. Support pasted paths, spaces, Unicode, and `~`; invalid paths show inline errors without losing the current folder.
- NAV-03: Expand folders lazily; auto-reveal current folder is a preference. Avoid recursive traversal through symbolic links.
- NAV-04: Tabs support create, close, reorder, duplicate, reopen closed, and restore after relaunch. A missing or unmounted location displays recovery actions.
- NAV-05: Details columns include Name, Date modified, Size, Kind, and optional Tags/Date created. Resize/reorder columns; natural sort; folders first by default, configurable. Folder size is on-demand, not a blocking recursive scan.
- NAV-06: Icon view supports thumbnail size adjustment and lazy thumbnails. Broken/unsupported previews use file-type icons.
- NAV-07: Select with click, Cmd-click, Shift-click, keyboard ranges, and Cmd+A. Selection remains tied to item identity during refresh and sorting.
- NAV-08: Hidden files toggle with Cmd+Shift+Period; package bundles behave as single items unless Show Package Contents is chosen.
- NAV-09: Open uses the default application; Open With, Copy Path, Reveal in Finder, Get Info, and Quick Look are available in context menus.

### File operations — OPS

- OPS-01: New Folder and inline rename validate names and collisions; renaming preserves the extension selection convention and warns when changing extensions.
- OPS-02: Copy/paste and Cut/Move Here expose the pending move state visually. The default Mac profile supports Cmd+C followed by Cmd+Option+V; an optional Explorer profile adds Cmd+X then Cmd+V and F2 rename.
- OPS-03: Drag and drop shows destination and Copy/Move intent before release. Default copy across volumes, move within a volume; modifiers are reflected in the indicator. Reject moving a folder into itself or descendants.
- OPS-04: Operations continue while navigating. Closing a tab does not cancel transfers; quitting with work in progress offers keep running or stop and quit.
- OPS-05: Transfer cards show source, destination, item count, completed bytes, rate, and approximate remaining time only when meaningful. Preparation uses indeterminate progress. MVP supports queued-item cancellation and active-operation cancellation at safe boundaries; arbitrary byte-level pause/resume is deferred.
- OPS-06: Conflicts show both items, full locations, sizes, dates, and actions Skip, Keep Both, Replace, or Cancel. No automatic Replace. Apply to remaining conflicts is explicit and scoped to compatible conflict types. Folder merge is separately named; nested collisions still obey the chosen rule.
- OPS-07: Move to Trash is the default delete action. If Trash is unavailable, report failure and preserve the item; never silently fall back to permanent removal.
- OPS-08: Track operation outcomes per item. Partial failure leaves a clear list of successes, skipped items, and failures; Retry retries only failed items after revalidation.
- OPS-09: Undo supports eligible app-initiated rename/move/new-folder/copy operations after checking identity and external changes. Do not remove externally edited copies or nonempty newly created folders. Replacement undo is available only when a preserved original can be restored safely; otherwise label its limits before Replace. Trash restoration is conditional on a validated restorable item and original destination.
- OPS-10: Cross-volume moves copy into an app-owned temporary destination, finish and validate the destination, then remove the source. Source removal failure reports copied-but-not-moved. Never claim a multi-item operation is atomic.
- OPS-11: Preserve file metadata supported by the source and destination, including dates, extended attributes, and permissions where possible. Surface unsupported metadata and permission failures; do not claim identical semantics across APFS, exFAT, network mounts, and cloud providers.

### Search — SEARCH

- SEARCH-01: Default scope is current folder and descendants, visibly labeled. Offer This Folder and Indexed Mac locations; preserve scope during query edits.
- SEARCH-02: Folder search uses cancellable enumeration with incremental results. Mac-wide search uses system indexing where available; clearly disclose incomplete or unindexed locations.
- SEARCH-03: Filter by name, kind/extension, modified date, and size; expose active filters as removable chips. Literal filename search in MVP; advanced content search depends on index support and is later scope.
- SEARCH-04: Results include location, Open Containing Folder, and normal file operations. Clear search restores the prior folder state. Stale query results never overwrite a newer query.
- SEARCH-05: Saved searches store query and scope, not copied files; unavailable scopes show an explanation.

### Preview, organization, preferences — UX

- UX-01: Space opens Quick Look for the current selection; Escape closes it. Inspector follows selection and does not change keyboard focus unexpectedly.
- UX-02: Favorites reorder by dragging and persist references; missing locations can be repaired or removed.
- UX-03: Batch rename previews every resulting filename, highlights duplicates/invalid names, and requires Apply. Support replace text, prefix/suffix, and numbering first; regex later.
- UX-04: Workspace presets capture pane locations, tabs, and view settings. Loading a preset does not restart file operations.
- UX-05: Preferences: appearance, accent, density, folders-first, hidden files, startup location/session restore, keyboard profile, sidebar visibility, and optional diagnostics.
- UX-06: Tags integrate with filesystem metadata where supported; failures remain visible. Do not invent a parallel tag database without a separately approved requirement.

### Keyboard and accessibility

Mac profile defaults: Cmd+T new tab; Cmd+W close tab/window; Cmd+L edit path; Cmd+F search; Cmd+[ / Cmd+] back/forward; Cmd+Up parent; Cmd+Down open; Return rename; Space preview; Cmd+Shift+N new folder; Cmd+Delete Trash; Cmd+Z eligible undo. Cmd+C/V copy/paste; Cmd+Option+V move copied items. All shortcuts appear in menus; text fields keep standard editing behavior.

Provide VoiceOver names, sortable column announcements, selection counts, predictable focus order, full keyboard operation, and accessible transfer updates without announcing every progress tick. Target text contrast 4.5:1 and essential graphical/control contrast 3:1; validate both themes and increased-contrast variants. Minimum interaction target 24 pt, preferably 28–32 pt where density allows.

## 6. Error and edge-state contract

| Condition | Required behavior |
| --- | --- |
| Empty folder / no search results | Distinct messages; useful New Folder or Clear Filters action. |
| Access denied / permission revoked | Explain the affected location and provide an appropriate retry or access-grant path; preserve navigation. |
| Disk full / read-only destination | Stop affected writes, preserve sources, expose retry/change destination; clean only known app-owned temporary items. |
| External drive unplugged / network lost | Mark location unavailable; keep UI responsive; preserve operation journal; reconnect requires revalidation. |
| Cloud-only file | Show availability when observable; disclose download before operations that hydrate; provider-specific errors remain visible. |
| External rename/delete during operation | Revalidate item identity; do not operate on a different file that now occupies the same path. |
| Unicode / case-sensitive differences | Validate against destination behavior; handle case-only renames safely. |
| Symbolic link / alias / package | Distinct presentation; avoid cycles; explicit package browsing; do not recursively dereference links during copy by default. |
| App crash during transfer | Inspect journal on launch; label interrupted operations; never automatically repeat destructive steps. |
| Unsupported preview / enormous file | Lightweight fallback and Open action; bounded memory and cancellable thumbnail work. |

## 7. Proposed technical architecture

Use Swift with a native AppKit window and high-volume table/collection/outline views; SwiftUI may compose settings, inspector, and auxiliary surfaces. The AppKit/SwiftUI boundary is a prototype decision based on selection correctness, accessibility, and measured performance, rather than an all-SwiftUI requirement.

| Module | Responsibility |
| --- | --- |
| AppShell | Windows, tabs, pane sessions, menus, keyboard routing, preferences. |
| DirectoryService | Incremental enumeration, item identities, metadata, bounded caching, reconciliation. |
| FileOperationEngine | Validated plans, queue, conflict decisions, cancellation, results, journal, conditional undo. |
| SearchService | Folder enumeration and indexed search adapters; cancellation and scope. |
| PreviewService | Quick Look integration, thumbnails, bounded cache. |
| AccessService | Location access, permission errors, bookmark lifecycle where applicable. |
| SessionStore | Versioned local persistence for favorites, settings, layouts, and workspace presets. |

Represent files by URL plus available volume/resource identity; paths alone are insufficient for detecting external changes. Model each pane separately. Keep filesystem work off the main thread, bound concurrency, and reconcile filesystem notifications with fresh reads. File event streams are invalidation hints, not a guaranteed authoritative operation log.

Operation states: planned → validating → queued → running → awaiting conflict / completed / partially failed / cancelled / interrupted. Persist state transitions and per-item results before destructive follow-up work. The journal is recovery metadata, not a promise of general rollback. Do not persist file contents in logs. App state lives in Application Support; caches are disposable.

Proposed direct-distribution app uses ordinary OS permissions and respects protected-location restrictions. No root helper, Full Disk Access requirement at first launch, or shell-command-based file manipulation. If sandboxing is selected, user-selected directory grants and security-scoped bookmarks require their own compatibility validation. Apple's documentation confirms that sandbox grants do not override filesystem permissions or other mandatory access controls. [Apple: sandbox file access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

Use Foundation file APIs and validate their cancellation/metadata limitations before promising transfer features. Use NSWorkspace for application opening and system interactions, and Quick Look UI for previews. [FileManager](https://developer.apple.com/documentation/foundation/filemanager), [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace), [Quick Look UI](https://developer.apple.com/documentation/QuickLookUI)

## 8. Performance and quality budgets

Targets are acceptance budgets to measure, not current results. Baseline: Apple silicon Mac with 16 GB RAM and local APFS SSD, Release build, fixture sizes and cold/warm cache state recorded.

- Cold launch to interactive shell: p95 ≤ 1.5 seconds across 20 launches.
- A local directory of 10,000 entries: first usable rows p95 ≤ 300 ms warm / 1 second cold; enumerate and sort within 2 seconds warm / 5 seconds cold.
- 100,000-entry stress fixture: UI remains responsive and cancellable; progressive loading shown; no requirement to materialize thumbnails for all items.
- Interaction while browsing/copying: no sustained main-thread stall above 100 ms; target smooth scrolling on the baseline display.
- Idle: below 1% CPU after settling; memory target below 250 MB for three ordinary tabs, excluding exceptional preview-process costs, which are reported separately.
- Search cancellation and navigation feedback within 100 ms; remote storage and provider latency are reported separately from local budgets.
- No silent overwrites or source deletion before a successful cross-volume copy. Fault-injection tests must verify these invariants.

## 9. Delivery phases and exit criteria

Effort ranges assume one experienced native macOS engineer, with design work included separately. They are planning estimates, not calendar commitments; refine after technical spikes. Phases are sequential except approved independent design/test work.

| Phase | Scope and deliverables | Exit criterion | Estimate |
| --- | --- | --- | --- |
| 0 — Product and Figma approval | Spec; visual directions; components/tokens; high-fidelity screens; clickable core flows; user revisions. | User explicitly approves named Figma revision and MVP scope. | 4–7 working days |
| 1 — Native foundation | App skeleton; read-only enumeration; tree/list prototype; path bar; identity model; permissions spike; performance fixtures. | Browse 10k entries responsively, navigate with keyboard, demonstrate permission and missing-volume states. | 1–2 weeks |
| 2 — Everyday browsing | Tabs/history/session restore; details/icon views; sorting/selection; favorites; Quick Look/inspector; opening/context menus. | Complete browse → locate → preview → open flow with keyboard and VoiceOver. | 2–3 weeks |
| 3 — Trusted file operations | Copy/move/rename/new folder/Trash; drag/drop; queue; conflicts; cancellation; journal; conditional undo. | Fault matrix passes; partial failures truthful; no silent overwrite or premature source removal. Personal alpha candidate. | 3–4 weeks |
| 4 — Power workflows | Split panes; folder/indexed search; filters/saved searches; batch rename; workspace presets; tags. | Move files between panes, resolve collisions, recover eligible actions, run filtered search and batch rename with previews. Feature-complete beta. | 2–3 weeks |
| 5 — Reliability and release | Mounted/cloud locations; accessibility audit; performance tuning; migrations; signing/notarization; installer and clean-machine QA. | Release checklist passes and user accepts beta. | 2–3 weeks |
| 6 — Evidence-led expansion | Evaluate gallery/column views, archives, folder comparison, richer metadata, remote providers. | Separate approved scope and evidence from actual use. | Not estimated |

Expected foundation-through-release engineering range: 10–15 weeks, plus design and feedback. Deliver working increments at every phase; do not attempt every power feature before basic operations are reliable.

### Test strategy and release gate

- Unit tests: path/identity validation, destination name rules, conflict decision scoping, state transitions, rename previews, search generation cancellation.
- Integration tests in disposable directories/volumes: metadata, symlinks, nested copies, same/cross-volume moves, Trash behavior, external edits, insufficient space, access denial, unplug/disconnect, process interruption.
- UI tests: keyboard navigation, selection persistence, drag intent, tabs, split-pane targeting, focus restoration, conflict sheets, and error recovery.
- Manual matrix: supported OS versions, both themes/densities, VoiceOver, Reduce Motion/Transparency, APFS case-sensitive/insensitive, exFAT, mounted SMB, supported cloud-provider fixtures. Unsupported behavior is documented rather than guessed.
- Release requires zero known data-loss defects; no blocking navigation or accessibility failures; budgets measured; clean-install/update/uninstall validated; operation journals never cause automatic destructive replay.
- Direct releases require signing and notarization setup and validation on a clean machine. Apple's notarization guidance describes Developer ID signing, submission, and ticket stapling. [Apple: notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## 10. Design approval and open decisions

The Figma package is defined in DESIGN_BRIEF.md. Approval covers a concrete visual direction, light/dark main explorer, split pane, search, conflict/transfer flows, and narrow-window behavior. Each screen must show states beyond the happy path. Requested changes are incorporated before production work starts.

Proposed defaults pending review: Quiet Precision styling; Mac shortcuts with optional Explorer profile; macOS 14+; direct distribution; feature-complete 1.0 after Phase 5; no account or AI features. These assumptions permit spec/design work but do not count as design approval.

Status: user approved the designs on 15 September 2026. The latest user-supplied light-theme screenshot is the implementation reference, including flat rows, blue selection, and column sorting indicators. The first native browsing increment now compiles and passes three directory-handling tests. Remaining phase gates and unbuilt screens are future work; this approval does not imply those flows have been implemented or verified. FIGMA_STATE.json is a historical construction record and must not be replayed over the user's design edits. See PROGRESS.md for the current handoff.

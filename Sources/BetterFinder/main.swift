import AppKit
import Quartz
import Carbon
import DirectoryCore

private enum Theme {
    static let chrome = NSColor(hex: 0xF1F3F6)
    static let sidebar = NSColor(hex: 0xF7F8FA)
    static let text = NSColor(hex: 0x202A39)
    static let secondary = NSColor(hex: 0x627084)
    static let selection = NSColor(hex: 0xE3EDFF)
    static let accent = NSColor(hex: 0x275ECB)
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

private func label(_ text: String, size: CGFloat = 13, bold: Bool = false, secondary: Bool = false) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    field.textColor = secondary ? Theme.secondary : Theme.text
    field.lineBreakMode = .byTruncatingMiddle
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
}

private final class Surface: NSView {
    init(_ color: NSColor) { super.init(frame: .zero); wantsLayer = true; layer?.backgroundColor = color.cgColor }
    required init?(coder: NSCoder) { fatalError() }
}

private final class SelectionRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        Theme.selection.setFill()
        NSBezierPath(rect: bounds.insetBy(dx: 0, dy: 1)).fill()
    }
}

private final class FileTable: NSTableView {
    var openSelection: (() -> Void)?
    var goUp: (() -> Void)?
    var renameSelection: (() -> Void)?
    var previewSelection: (() -> Void)?
    var contextMenu: (() -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let index = row(at: convert(event.locationInWindow, from: nil))
        if index < 0 { deselectAll(nil) }
        else if !selectedRowIndexes.contains(index) { selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false) }
        window?.makeFirstResponder(self)
        return contextMenu?()
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.keyCode == 125 { openSelection?(); return }
        if event.modifierFlags.contains(.command), event.keyCode == 126 { goUp?(); return }
        if event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
           event.keyCode == 36 { renameSelection?(); return }
        if event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty,
           event.keyCode == 49 { if !event.isARepeat { previewSelection?() }; return }
        super.keyDown(with: event)
    }
}

private final class FolderOutline: NSOutlineView {
    var contextMenu: ((Int) -> NSMenu)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let index = row(at: convert(event.locationInWindow, from: nil))
        return contextMenu?(index)
    }
}

private final class FolderNode {
    let title: String
    let url: URL?
    var children: [FolderNode]?
    var loading = false
    init(_ title: String, url: URL? = nil, children: [FolderNode]? = nil) {
        self.title = title; self.url = url; self.children = children
    }
}

@MainActor
private final class ExplorerController: NSViewController, NSTableViewDataSource, NSTableViewDelegate,
    NSOutlineViewDataSource, NSOutlineViewDelegate, NSSearchFieldDelegate, NSMenuItemValidation, NSMenuDelegate,
    @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    private let table = FileTable()
    private let tree = FolderOutline()
    private let pathField = NSTextField()
    private let filterField = NSSearchField()
    private let titleField = label("", size: 22, bold: true)
    private let subtitle = label("", size: 12, secondary: true)
    private let status = label("", size: 11, secondary: true)
    private let storageName = label("Storage", size: 12, bold: true)
    private let storageDetails = label("Loading storage…", size: 11, secondary: true)
    private let storageBar = NSProgressIndicator()
    private let message = label("", size: 14, secondary: true)
    private let inspector = Surface(Theme.sidebar)
    private let previewIcon = NSImageView()
    private let inspectorName = label("Select a file", size: 16, bold: true)
    private let inspectorType = label("", size: 12, secondary: true)
    private let inspectorDetails = label("", size: 12, secondary: true)
    private let openButton = NSButton(title: "Open", target: nil, action: nil)
    private let shareButton = NSButton(title: "Share…", target: nil, action: nil)
    private var sharingPicker: NSSharingServicePicker?
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var inspectorWidth: NSLayoutConstraint!
    private var entries: [FileEntry] = []
    private var visibleEntries: [FileEntry] = []
    private var currentURL: URL?
    private var history: [URL] = []
    private var historyIndex = -1
    private var loadTask: Task<Void, Never>?
    private var folderSizeTask: Task<Void, Never>?
    private var folderSizes: [URL: FolderSize] = [:]
    private var unavailableFolderSizes: Set<URL> = []
    private var generation = UUID()
    private var showHidden = false
    private var sort: FileSort = .name
    private var ascending = true
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var roots: [FolderNode] = []
    private var operationInProgress = false
    private var fileUndoHistory: [(title: String, records: [FileUndo.Record])] = []
    private var previewURLs: [URL] = []
    private weak var controlledPreviewPanel: QLPreviewPanel?
    private let initialURL: URL
    var onLocationChange: (() -> Void)?
    var onMovedFiles: (([URL]) -> Void)?
    var sessionURL: URL { currentURL ?? initialURL }
    var hasPendingFileOperation: Bool { operationInProgress }
    private lazy var trashSound = NSSound(contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/finder/move to trash.aif", byReference: true)

    init(initialURL: URL) {
        self.initialURL = initialURL
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit { folderSizeTask?.cancel() }

    override func loadView() {
        view = Surface(.white)
        let favorites = ["Downloads", "Documents", "Desktop", "Pictures", "MyProjects"].map {
            FolderNode($0 == "MyProjects" ? "Projects" : $0, url: home.appendingPathComponent($0))
        }
        let volumes = (FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? [])
            .map { FolderNode($0.path == "/" ? "Macintosh HD" : $0.lastPathComponent, url: $0) }
        roots = [FolderNode("FAVORITES", children: [FolderNode("Home", url: home)] + favorites),
                 FolderNode("FOLDERS", children: [FolderNode(home.lastPathComponent, url: home)]),
                 FolderNode("LOCATIONS", children: volumes)]
        buildLayout()
        navigate(initialURL)
    }

    private func button(_ symbol: String, help: String, action: Selector) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: self, action: action)
        b.bezelStyle = .regularSquare; b.isBordered = false; b.contentTintColor = Theme.secondary
        b.toolTip = help; b.setAccessibilityLabel(help)
        b.widthAnchor.constraint(equalToConstant: 30).isActive = true
        b.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return b
    }

    private func buildLayout() {
        let toolbar = Surface(Theme.chrome), sidebar = Surface(Theme.sidebar), content = Surface(.white), footer = Surface(Theme.chrome)
        [toolbar, sidebar, content, inspector, footer].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        inspectorWidth = inspector.widthAnchor.constraint(equalToConstant: 280)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor), toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor), toolbar.heightAnchor.constraint(equalToConstant: 64),
            footer.bottomAnchor.constraint(equalTo: view.bottomAnchor), footer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: view.trailingAnchor), footer.heightAnchor.constraint(equalToConstant: 32),
            sidebar.topAnchor.constraint(equalTo: toolbar.bottomAnchor), sidebar.bottomAnchor.constraint(equalTo: footer.topAnchor),
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor), sidebar.widthAnchor.constraint(equalToConstant: 224),
            inspector.topAnchor.constraint(equalTo: toolbar.bottomAnchor), inspector.bottomAnchor.constraint(equalTo: footer.topAnchor),
            inspector.trailingAnchor.constraint(equalTo: view.trailingAnchor), inspectorWidth,
            content.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor), content.trailingAnchor.constraint(equalTo: inspector.leadingAnchor),
            content.topAnchor.constraint(equalTo: toolbar.bottomAnchor), content.bottomAnchor.constraint(equalTo: footer.topAnchor)
        ])
        backButton = button("chevron.left", help: "Back (⌘[)", action: #selector(goBack))
        forwardButton = button("chevron.right", help: "Forward (⌘])", action: #selector(goForward))
        pathField.font = .systemFont(ofSize: 13); pathField.isBezeled = false; pathField.drawsBackground = true
        pathField.backgroundColor = NSColor(hex: 0xE9EDF2); pathField.focusRingType = .exterior
        pathField.target = self; pathField.action = #selector(submitPath); pathField.setAccessibilityLabel("Folder path")
        filterField.placeholderString = "Filter this folder"; filterField.delegate = self
        filterField.setAccessibilityLabel("Filter filenames in the current folder")
        let nav = NSStackView(views: [backButton, forwardButton,
            button("arrow.up", help: "Parent folder (⌘↑)", action: #selector(goUp)), pathField, filterField,
            button("arrow.clockwise", help: "Refresh (⌘R)", action: #selector(refresh)),
            button("folder", help: "Choose folder", action: #selector(chooseFolder))])
        nav.spacing = 14; nav.translatesAutoresizingMaskIntoConstraints = false; toolbar.addSubview(nav)
        NSLayoutConstraint.activate([nav.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 18),
            nav.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -18), nav.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            pathField.heightAnchor.constraint(equalToConstant: 32), pathField.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            filterField.widthAnchor.constraint(equalToConstant: 220)])

        let treeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tree"))
        tree.addTableColumn(treeColumn); tree.outlineTableColumn = treeColumn; tree.headerView = nil
        tree.rowHeight = 32; tree.indentationPerLevel = 12; tree.backgroundColor = Theme.sidebar
        tree.style = .plain; tree.selectionHighlightStyle = .regular; tree.focusRingType = .none
        tree.dataSource = self; tree.delegate = self; tree.target = self; tree.action = #selector(selectFolder)
        tree.registerForDraggedTypes([.fileURL])
        tree.setAccessibilityLabel("Folders and favorites")
        tree.contextMenu = { [weak self] row in self?.sidebarMenu(row: row) ?? NSMenu() }
        let treeScroll = NSScrollView(); treeScroll.documentView = tree; treeScroll.hasVerticalScroller = true
        treeScroll.drawsBackground = false
        treeScroll.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(treeScroll)
        storageBar.style = .bar; storageBar.isIndeterminate = false
        storageBar.minValue = 0; storageBar.maxValue = 100; storageBar.controlSize = .small
        storageBar.setAccessibilityLabel("Storage used")
        let storage = NSStackView(views: [storageName, storageBar, storageDetails])
        storage.orientation = .vertical; storage.alignment = .leading; storage.spacing = 8
        storage.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(storage)
        NSLayoutConstraint.activate([
            treeScroll.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 10),
            treeScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            treeScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),
            treeScroll.bottomAnchor.constraint(equalTo: storage.topAnchor, constant: -20),
            storage.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            storage.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            storage.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -18),
            storageBar.widthAnchor.constraint(equalTo: storage.widthAnchor),
            storageBar.heightAnchor.constraint(equalToConstant: 6),
            storageName.widthAnchor.constraint(equalTo: storage.widthAnchor),
            storageDetails.widthAnchor.constraint(equalTo: storage.widthAnchor)
        ])
        roots.forEach { tree.expandItem($0) }

        let heading = NSStackView(views: [titleField, subtitle]); heading.orientation = .vertical
        heading.alignment = .leading; heading.spacing = 8; heading.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(heading)
        NSLayoutConstraint.activate([heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            heading.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24)])
        for (key, title, width) in [("name", "Name", 380.0), ("modified", "Modified", 180.0), ("size", "Size", 100.0)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(key))
            column.title = title; column.width = width; column.minWidth = key == "name" ? 160 : 80
            column.sortDescriptorPrototype = NSSortDescriptor(key: key, ascending: true)
            table.addTableColumn(column)
        }
        table.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        table.rowHeight = 40; table.intercellSpacing = NSSize(width: 12, height: 0)
        table.usesAlternatingRowBackgroundColors = false; table.backgroundColor = .white
        table.style = .plain; table.gridStyleMask = []; table.allowsMultipleSelection = true
        table.dataSource = self; table.delegate = self; table.target = self; table.doubleAction = #selector(openSelected)
        table.registerForDraggedTypes([.fileURL])
        table.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        table.setDraggingSourceOperationMask(.copy, forLocal: false)
        table.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        table.openSelection = { [weak self] in self?.openSelected() }
        table.goUp = { [weak self] in self?.goUp() }
        table.renameSelection = { [weak self] in self?.renameSelected() }
        table.previewSelection = { [weak self] in self?.toggleQuickLook() }
        table.contextMenu = { [weak self] in self?.fileMenu() ?? NSMenu() }
        content.menu = folderMenu()
        table.setAccessibilityLabel("Files")
        let scroll = NSScrollView(); scroll.documentView = table; scroll.hasVerticalScroller = true
        scroll.menu = folderMenu()
        scroll.autohidesScrollers = true; scroll.translatesAutoresizingMaskIntoConstraints = false; content.addSubview(scroll)
        NSLayoutConstraint.activate([scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 24),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)])
        message.translatesAutoresizingMaskIntoConstraints = false; message.maximumNumberOfLines = 4
        message.alignment = .center; content.addSubview(message)
        NSLayoutConstraint.activate([message.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            message.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, constant: -64)])
        previewIcon.imageScaling = .scaleProportionallyUpOrDown
        previewIcon.heightAnchor.constraint(equalToConstant: 180).isActive = true
        previewIcon.widthAnchor.constraint(equalToConstant: 220).isActive = true
        inspectorName.maximumNumberOfLines = 2
        inspectorDetails.maximumNumberOfLines = 0; inspectorDetails.lineBreakMode = .byWordWrapping
        openButton.target = self; openButton.action = #selector(openSelected); openButton.bezelStyle = .rounded
        openButton.isEnabled = false
        shareButton.target = self; shareButton.action = #selector(shareSelected(_:)); shareButton.bezelStyle = .rounded
        shareButton.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share selected files")
        shareButton.imagePosition = .imageLeading; shareButton.isEnabled = false
        let openApp = NSPopUpButton(frame: .zero, pullsDown: true)
        openApp.menu = makeSavedChatsMenu(popup: true)
        openApp.toolTip = "Open a saved conversation, then drag your files into it"
        let sharingActions = NSStackView(views: [shareButton, openApp])
        sharingActions.orientation = .horizontal; sharingActions.spacing = 8
        let details = NSStackView(views: [previewIcon, inspectorName, inspectorType,
            label("FILE DETAILS", size: 10, bold: true, secondary: true), inspectorDetails, openButton, sharingActions])
        details.orientation = .vertical; details.alignment = .leading; details.spacing = 22
        details.translatesAutoresizingMaskIntoConstraints = false; inspector.addSubview(details)
        let detailsTrailing = details.trailingAnchor.constraint(equalTo: inspector.trailingAnchor, constant: -24)
        detailsTrailing.priority = .defaultHigh
        NSLayoutConstraint.activate([details.topAnchor.constraint(equalTo: inspector.topAnchor, constant: 28),
            details.leadingAnchor.constraint(equalTo: inspector.leadingAnchor, constant: 24),
            detailsTrailing])
        status.translatesAutoresizingMaskIntoConstraints = false; footer.addSubview(status)
        NSLayoutConstraint.activate([status.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            status.centerYAnchor.constraint(equalTo: footer.centerYAnchor), status.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20)])
    }

    private func pin(_ child: NSView, to parent: NSView, inset: CGFloat) {
        child.translatesAutoresizingMaskIntoConstraints = false; parent.addSubview(child)
        NSLayoutConstraint.activate([child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset)])
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        let width: CGFloat = view.bounds.width < 1150 ? 0 : 280
        if inspectorWidth.constant != width { inspectorWidth.constant = width; inspector.isHidden = width == 0 }
    }

    private func navigate(_ url: URL, historyTarget: Int? = nil, addHistory: Bool = true, selecting selectionURL: URL? = nil, preserveViewState: Bool = false, selectingURLs: [URL] = []) {
        loadTask?.cancel(); folderSizeTask?.cancel(); let token = UUID(); generation = token
        let savedSelection = preserveViewState ? Set(selectedURLs.map { $0.path }) : []
        let savedFilter = preserveViewState ? filterField.stringValue : ""
        let savedScroll = table.enclosingScrollView?.contentView.bounds.origin
        message.stringValue = "Loading folder…"; message.isHidden = false
        let hidden = showHidden
        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { Result { try DirectoryReader.read(url, showHidden: hidden) } }.value
            guard let self, !Task.isCancelled, self.generation == token else { return }
            switch result {
            case .success(let newEntries):
                if let target = historyTarget { self.historyIndex = target }
                else if addHistory && self.currentURL != url {
                    self.history = Array(self.history.prefix(self.historyIndex + 1))
                    self.history.append(url); self.historyIndex = self.history.count - 1
                }
                self.currentURL = url; self.entries = newEntries
                self.folderSizes = [:]; self.unavailableFolderSizes = []
                self.updateStorage(for: url)
                self.pathField.stringValue = url.path
                self.titleField.stringValue = url.path == "/" ? "Macintosh HD" : url.lastPathComponent
                self.subtitle.stringValue = url.deletingLastPathComponent().path
                self.view.window?.representedURL = url
                self.view.window?.title = url.path == "/" ? "Macintosh HD" : url.lastPathComponent
                self.onLocationChange?()
                self.filterField.stringValue = savedFilter; self.table.deselectAll(nil); self.applyFilter()
                if preserveViewState {
                    self.table.selectRowIndexes(IndexSet(self.visibleEntries.indices.filter { savedSelection.contains(self.visibleEntries[$0].url.path) }), byExtendingSelection: false)
                    if let savedScroll, let scroll = self.table.enclosingScrollView {
                        scroll.contentView.scroll(to: savedScroll); scroll.reflectScrolledClipView(scroll.contentView)
                    }
                }
                let selectionPaths = Set((selectingURLs + (selectionURL.map { [$0] } ?? [])).map { $0.standardizedFileURL.path })
                let selectionRows = IndexSet(self.visibleEntries.indices.filter { selectionPaths.contains(self.visibleEntries[$0].url.standardizedFileURL.path) })
                if let row = selectionRows.first {
                    self.table.selectRowIndexes(selectionRows, byExtendingSelection: false)
                    self.table.scrollRowToVisible(row)
                    self.view.window?.makeFirstResponder(self.table)
                }
                self.calculateFolderSizes(token: token)
            case .failure(let error):
                self.pathField.stringValue = self.currentURL?.path ?? url.path
                if self.currentURL == nil {
                    self.message.stringValue = "This folder is unavailable.\nUse Choose Folder to open another location."
                    self.status.stringValue = error.localizedDescription
                } else {
                    self.message.isHidden = true
                    let alert = NSAlert(); alert.messageText = "Can’t open \(url.lastPathComponent)"
                    alert.informativeText = error.localizedDescription
                    if let window = self.view.window { alert.beginSheetModal(for: window, completionHandler: nil) }
                    self.calculateFolderSizes(token: token)
                }
            }
            self.backButton.isEnabled = self.historyIndex > 0
            self.forwardButton.isEnabled = self.historyIndex < self.history.count - 1
        }
    }

    private func applyFilter() {
        let selected = Set(table.selectedRowIndexes.compactMap { visibleEntries.indices.contains($0) ? visibleEntries[$0].url : nil })
        let query = filterField.stringValue
        visibleEntries = DirectoryReader.sorted(entries.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }, by: sort, ascending: ascending,
            folderSizes: folderSizes.filter { $0.value.isComplete }.mapValues(\.bytes))
        table.reloadData()
        table.selectRowIndexes(IndexSet(visibleEntries.indices.filter { selected.contains(visibleEntries[$0].url) }), byExtendingSelection: false)
        message.stringValue = query.isEmpty ? "This folder is empty" : "No matching files"
        message.isHidden = !visibleEntries.isEmpty
        updateInspector()
    }

    private func calculateFolderSizes(token: UUID) {
        let folders = entries.filter { $0.isDirectory && !$0.isSymbolicLink && folderSizes[$0.url] == nil && !unavailableFolderSizes.contains($0.url) }.map(\.url)
        folderSizeTask = Task.detached(priority: .utility) { [weak self] in
            await withTaskGroup(of: (URL, FolderSize?).self) { group in
                var pending = folders.makeIterator()
                for _ in 0..<3 {
                    guard !Task.isCancelled, let folder = pending.next() else { break }
                    group.addTask { (folder, try? FolderSize.measure(folder)) }
                }
                for await (folder, result) in group {
                    guard !Task.isCancelled else { group.cancelAll(); return }
                    await self?.receiveFolderSize(result, for: folder, token: token)
                    if let next = pending.next() {
                        group.addTask { (next, try? FolderSize.measure(next)) }
                    }
                }
            }
        }
    }

    private func receiveFolderSize(_ result: FolderSize?, for url: URL, token: UUID) {
        guard generation == token else { return }
        if let result { folderSizes[url] = result }
        else { unavailableFolderSizes.insert(url) }
        if sort == .size {
            applyFilter()
        } else {
            if let row = visibleEntries.firstIndex(where: { $0.url == url }),
               let column = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == "size" }) {
                table.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: column))
            }
            if selectedURLs.contains(url) { updateInspector() }
        }
    }

    private func sizeText(for entry: FileEntry) -> String {
        guard entry.isDirectory && !entry.isSymbolicLink else {
            return ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file)
        }
        if let size = folderSizes[entry.url] {
            return (size.isComplete ? "" : "≥ ") + ByteCountFormatter.string(fromByteCount: size.bytes, countStyle: .file)
        }
        return unavailableFolderSizes.contains(entry.url) ? "Unavailable" : "Calculating…"
    }

    func revealExternally(_ urls: [URL], in folder: URL) {
        _ = view
        if urls.contains(where: { $0.lastPathComponent.hasPrefix(".") }) { showHidden = true }
        navigate(folder, selectingURLs: urls)
    }

    private func updateStorage(for url: URL) {
        let token = generation
        storageName.stringValue = "Storage"; storageDetails.stringValue = "Loading storage…"
        storageBar.isHidden = true
        Task { [weak self] in
            let capacity = await Task.detached(priority: .utility) { () -> (String, Int64, Int64)? in
                guard let values = try? url.resolvingSymlinksInPath().resourceValues(forKeys:
                    [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey]),
                    let total = values.volumeTotalCapacity, total > 0,
                    let free = values.volumeAvailableCapacity else { return nil }
                return (values.volumeName ?? "Storage", Int64(total), Int64(max(0, min(free, total))))
            }.value
            guard let self, self.generation == token, self.currentURL == url else { return }
            guard let (name, total, free) = capacity else {
                self.storageDetails.stringValue = "Storage unavailable"
                return
            }
            let used = total - free
            let format = ByteCountFormatter(); format.countStyle = .decimal
            self.storageName.stringValue = name
            self.storageDetails.stringValue = "\(format.string(fromByteCount: used)) of \(format.string(fromByteCount: total)) used"
            self.storageDetails.toolTip = self.storageDetails.stringValue + " · \(format.string(fromByteCount: free)) free"
            self.storageBar.doubleValue = Double(used) / Double(total) * 100
            self.storageBar.setAccessibilityValue(self.storageDetails.stringValue)
            self.storageBar.isHidden = false
        }
    }

    func controlTextDidChange(_ obj: Notification) { if obj.object as? NSSearchField === filterField { applyFilter() } }
    @objc func goBack() { if historyIndex > 0 { navigate(history[historyIndex - 1], historyTarget: historyIndex - 1) } }
    @objc func goForward() { if historyIndex + 1 < history.count { navigate(history[historyIndex + 1], historyTarget: historyIndex + 1) } }
    @objc func goUp() { if let url = currentURL, url.path != "/" { navigate(url.deletingLastPathComponent()) } }
    @objc func refresh() { if let url = currentURL { navigate(url, addHistory: false) } }
    @objc func toggleHidden() { showHidden.toggle(); refresh() }
    @objc func focusPath() { view.window?.makeFirstResponder(pathField); pathField.selectText(nil) }
    @objc func focusFilter() { view.window?.makeFirstResponder(filterField) }
    @objc func submitPath() { navigate(DirectoryReader.resolve(pathField.stringValue)) }
    @objc func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.prompt = "Open Folder"
        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] result in
            if result == .OK, let url = panel.url { self?.navigate(url) }
        }
    }
    @objc func openSelected() {
        if view.window?.firstResponder === tree,
           let node = tree.item(atRow: tree.selectedRow) as? FolderNode, let url = node.url { navigate(url); return }
        guard !selectedURLs.isEmpty else { return }
        if selectedURLs.count == 1, let entry = visibleEntries.first(where: { $0.url == selectedURLs[0] }), entry.canBrowse {
            navigate(entry.url)
        } else { selectedURLs.forEach { NSWorkspace.shared.open($0) } }
    }

    private var selectedURLs: [URL] {
        table.selectedRowIndexes.compactMap { visibleEntries.indices.contains($0) ? visibleEntries[$0].url : nil }
    }

    @objc func toggleQuickLook() {
        if let panel = controlledPreviewPanel, panel.isVisible {
            panel.orderOut(nil)
            view.window?.makeFirstResponder(table)
            return
        }
        guard !selectedURLs.isEmpty, view.window?.attachedSheet == nil else { return }
        previewURLs = selectedURLs
        view.window?.makeFirstResponder(table)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.makeKeyAndOrderFront(nil)
        if controlledPreviewPanel === panel {
            panel.reloadData(); panel.currentPreviewItemIndex = 0
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        view.window != nil && !previewURLs.isEmpty
    }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        controlledPreviewPanel = panel
        panel.dataSource = self; panel.delegate = self
        panel.reloadData()
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil; panel.delegate = nil
        controlledPreviewPanel = nil
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard previewURLs.indices.contains(index) else { return nil }
        return previewURLs[index] as NSURL
    }
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty else { return false }
        if event.keyCode == 49 || event.keyCode == 53 {
            if !event.isARepeat { panel.orderOut(nil); view.window?.makeFirstResponder(table) }
            return true
        }
        if event.keyCode == 125 || event.keyCode == 126 { table.keyDown(with: event); return true }
        return false
    }
    private func updateQuickLookSelection() {
        guard let panel = controlledPreviewPanel, panel.isVisible else { return }
        let urls = selectedURLs
        guard !urls.isEmpty else { panel.orderOut(nil); return }
        guard urls != previewURLs else { return }
        previewURLs = urls; panel.reloadData(); panel.currentPreviewItemIndex = 0
    }
    private var clipboardURLs: [URL] {
        (NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    private func menuItem(_ menu: NSMenu, _ title: String, _ action: Selector, object: Any? = nil) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: "")
        item.target = self; item.representedObject = object
    }
    private func folderMenu() -> NSMenu {
        let menu = NSMenu()
        menuItem(menu, "New Folder…", #selector(newFolder))
        menuItem(menu, "Paste", #selector(paste(_:)))
        menuItem(menu, "Move Items Here", #selector(moveHere(_:)))
        menu.addItem(.separator())
        menuItem(menu, "Refresh", #selector(refresh))
        menuItem(menu, "Show / Hide Hidden Files", #selector(toggleHidden))
        return menu
    }
    private func fileMenu() -> NSMenu {
        guard !selectedURLs.isEmpty else { return folderMenu() }
        let menu = NSMenu()
        menuItem(menu, "Open", #selector(openSelected))
        menuItem(menu, "Quick Look", #selector(toggleQuickLook))
        menuItem(menu, "Share…", #selector(shareSelected(_:)))
        let chatsItem = NSMenuItem(title: "Saved Chats", action: nil, keyEquivalent: "")
        chatsItem.submenu = makeSavedChatsMenu(); menu.addItem(chatsItem)
        menuItem(menu, "Open WhatsApp", #selector(openWhatsApp(_:)))
        menuItem(menu, "Open Discord", #selector(openDiscord(_:)))
        menuItem(menu, "Rename…", #selector(renameSelected))
        menuItem(menu, "Copy", #selector(copy(_:)))
        menuItem(menu, "Duplicate", #selector(duplicateSelected(_:)))
        menuItem(menu, "Copy Path", #selector(copyPath(_:)), object: selectedURLs)
        menuItem(menu, "Reveal in Finder", #selector(revealInFinder(_:)), object: selectedURLs)
        menu.addItem(.separator())
        menuItem(menu, "Move to Trash", #selector(trashSelected))
        menu.addItem(.separator())
        menuItem(menu, "New Folder…", #selector(newFolder))
        menuItem(menu, "Paste", #selector(paste(_:)))
        menuItem(menu, "Move Items Here", #selector(moveHere(_:)))
        return menu
    }
    private func sidebarMenu(row: Int) -> NSMenu {
        guard let node = tree.item(atRow: row) as? FolderNode, let url = node.url else { return folderMenu() }
        let menu = NSMenu()
        menuItem(menu, "Open Folder", #selector(openSidebarFolder(_:)), object: url)
        menuItem(menu, "Copy Path", #selector(copyPath(_:)), object: [url])
        menuItem(menu, "Reveal in Finder", #selector(revealInFinder(_:)), object: [url])
        return menu
    }
    @objc private func openSidebarFolder(_ sender: NSMenuItem) { if let url = sender.representedObject as? URL { navigate(url) } }
    @objc private func copyPath(_ sender: NSMenuItem) {
        guard let urls = sender.representedObject as? [URL] else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
    }
    @objc private func revealInFinder(_ sender: NSMenuItem) {
        if let urls = sender.representedObject as? [URL] { NSWorkspace.shared.activateFileViewerSelecting(urls) }
    }
    private var savedChats: [SavedChat] {
        guard let data = UserDefaults.standard.data(forKey: "sharing.savedChats"),
              let chats = try? JSONDecoder().decode([SavedChat].self, from: data) else { return [] }
        return chats
    }
    private func storeChats(_ chats: [SavedChat]) throws {
        UserDefaults.standard.set(try JSONEncoder().encode(chats), forKey: "sharing.savedChats")
    }
    private func makeSavedChatsMenu(popup: Bool = false) -> NSMenu {
        let menu = NSMenu(title: popup ? "Saved Chats Popup" : "Saved Chats")
        menu.delegate = self; menuNeedsUpdate(menu)
        return menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Saved Chats" || menu.title == "Saved Chats Popup" else { return }
        menu.removeAllItems()
        if menu.title == "Saved Chats Popup" { menu.addItem(withTitle: "Saved Chats", action: nil, keyEquivalent: "") }
        let chats = savedChats
        for chat in chats { menuItem(menu, "\(chat.name) · \(chat.service.rawValue)", #selector(openSavedChat(_:)), object: chat.id.uuidString) }
        if chats.isEmpty {
            let empty = menu.addItem(withTitle: "No saved chats yet", action: nil, keyEquivalent: ""); empty.isEnabled = false
        }
        menu.addItem(.separator())
        menuItem(menu, "Add Chat…", #selector(addSavedChat(_:)))
        if !chats.isEmpty {
            let remove = NSMenuItem(title: "Remove Chat", action: nil, keyEquivalent: ""), submenu = NSMenu()
            for chat in chats { menuItem(submenu, "\(chat.name) · \(chat.service.rawValue)", #selector(removeSavedChat(_:)), object: chat.id.uuidString) }
            remove.submenu = submenu; menu.addItem(remove)
        }
        menu.addItem(.separator())
        menuItem(menu, "Open WhatsApp", #selector(openWhatsApp(_:)))
        menuItem(menu, "Open Discord", #selector(openDiscord(_:)))
    }
    @objc private func addSavedChat(_ sender: Any?) {
        guard let window = view.window, window.attachedSheet == nil else { return }
        let alert = NSAlert(); alert.messageText = "Add Saved Chat"
        let instructions = "WhatsApp: enter a phone number with country code. Discord: paste a channel link or Copy Message Link from a conversation."
        alert.informativeText = instructions
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Cancel")
        let form = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 118))
        let name = NSTextField(frame: NSRect(x: 0, y: 88, width: 380, height: 24))
        name.placeholderString = "Chat name"; name.setAccessibilityLabel("Chat name")
        let service = NSPopUpButton(frame: NSRect(x: 0, y: 46, width: 180, height: 30))
        service.addItems(withTitles: ["WhatsApp", "Discord"]); service.setAccessibilityLabel("Chat app")
        let destination = NSTextField(frame: NSRect(x: 0, y: 8, width: 380, height: 24))
        destination.placeholderString = "Phone number or Discord conversation link"
        destination.setAccessibilityLabel("Phone number or Discord conversation link")
        [name, service, destination].forEach { form.addSubview($0) }
        alert.accessoryView = form; alert.window.initialFirstResponder = name
        Task {
            while await alert.beginSheetModal(for: window) == .alertFirstButtonReturn {
                do {
                    let chat = try SavedChat(name: name.stringValue, service: service.indexOfSelectedItem == 0 ? .whatsapp : .discord, destination: destination.stringValue)
                    try self.storeChats(self.savedChats + [chat])
                    self.status.stringValue = "Saved \(chat.name). Open it from Saved Chats."
                    break
                } catch { alert.informativeText = error.localizedDescription + "\n\n" + instructions }
            }
        }
    }
    @objc private func removeSavedChat(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        do { try storeChats(savedChats.filter { $0.id.uuidString != id }) }
        catch { status.stringValue = "Couldn’t remove chat: \(error.localizedDescription)" }
    }
    @objc private func openSavedChat(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let chat = savedChats.first(where: { $0.id.uuidString == id }) else { return }
        do {
            let link = try chat.link()
            guard NSWorkspace.shared.open(link) else { throw CocoaError(.fileReadUnknown) }
            status.stringValue = "Opened \(chat.name). Drag files into the conversation when ready."
        } catch {
            guard let window = view.window, window.attachedSheet == nil else { return }
            let alert = NSAlert(); alert.messageText = "Couldn’t open saved chat"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
    @objc func openWhatsApp(_ sender: Any?) { openChatApp("WhatsApp", identifier: "net.whatsapp.WhatsApp") }
    @objc func openDiscord(_ sender: Any?) { openChatApp("Discord", identifier: "com.hnc.Discord") }
    private func openChatApp(_ name: String, identifier: String) {
        guard let window = view.window, window.attachedSheet == nil else { return }
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            let alert = NSAlert(); alert.messageText = "\(name) isn’t installed"
            alert.informativeText = "Install the macOS app to use this shortcut."
            alert.beginSheetModal(for: window, completionHandler: nil)
            return
        }
        Task {
            do {
                let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = true
                _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
                self.status.stringValue = "Choose a chat in \(name), then drag your files into it."
            } catch {
                let alert = NSAlert(); alert.messageText = "Couldn’t open \(name)"
                alert.informativeText = error.localizedDescription
                if window.attachedSheet == nil { alert.beginSheetModal(for: window, completionHandler: nil) }
            }
        }
    }
    @objc func shareSelected(_ sender: Any?) {
        let urls = selectedURLs
        guard !urls.isEmpty, !operationInProgress, view.window?.attachedSheet == nil else { return }
        let picker = NSSharingServicePicker(items: urls)
        sharingPicker = picker
        if let button = sender as? NSButton {
            picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        } else {
            let rowRect = table.rect(ofRow: table.selectedRow).intersection(table.visibleRect)
            let anchor = rowRect.isEmpty ? NSRect(x: table.visibleRect.minX + 16, y: table.visibleRect.minY + 16, width: 1, height: 1) : rowRect
            picker.show(relativeTo: anchor, of: table, preferredEdge: .maxY)
        }
    }
    @objc func copy(_ sender: Any?) {
        let urls = copyURLs
        guard !urls.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(urls.map { $0 as NSURL })
    }
    private var copyURLs: [URL] {
        if view.window?.firstResponder === tree {
            return (tree.item(atRow: tree.selectedRow) as? FolderNode)?.url.map { [$0] } ?? []
        }
        return selectedURLs
    }
    @objc func paste(_ sender: Any?) {
        guard let destination = currentURL, !operationInProgress else { return }
        let sources = clipboardURLs
        guard !sources.isEmpty else { return }
        performOperation("Copy", sources: sources) { try FileActions.copy($0, into: destination) }
    }

    @objc func duplicateSelected(_ sender: Any?) {
        guard !operationInProgress, view.window?.attachedSheet == nil,
              view.window?.firstResponder === table, !selectedURLs.isEmpty else { return }
        performOperation("Duplicate", sources: selectedURLs, revealResult: true) {
            try FileActions.copy($0, into: $0.deletingLastPathComponent())
        }
    }

    @objc func moveHere(_ sender: Any?) {
        guard let destination = currentURL else { return }
        moveItems(clipboardURLs, into: destination, clipboardVersion: NSPasteboard.general.changeCount)
    }

    private func moveItems(_ sources: [URL], into destination: URL, clipboardVersion: Int? = nil) {
        guard !sources.isEmpty, !operationInProgress, let window = view.window, window.attachedSheet == nil else { return }
        operationInProgress = true
        Task {
            let conflicts = await Task.detached { FileActions.moveConflicts(sources, into: destination) }.value
            var policy = FileActions.MoveConflict.fail
            if !conflicts.isEmpty {
                let alert = NSAlert(); alert.messageText = "\(conflicts.count) items already exist in \(destination.lastPathComponent)"
                alert.informativeText = "Keep Both gives incoming items new names. Skip leaves conflicting items in their original folders.\n\n" + conflicts.prefix(8).joined(separator: "\n")
                alert.addButton(withTitle: "Keep Both"); alert.addButton(withTitle: "Skip"); alert.addButton(withTitle: "Cancel")
                let response = await alert.beginSheetModal(for: window)
                if response == .alertFirstButtonReturn { policy = .keepBoth }
                else if response == .alertSecondButtonReturn { policy = .skip }
                else { self.operationInProgress = false; return }
            }
            self.operationInProgress = false
            let selectedPolicy = policy
            self.performOperation("Move", sources: sources, revealResult: true, undoKind: .move, completion: { [weak self] moved in
                guard !moved.isEmpty else { return }
                self?.onMovedFiles?(moved.map { $0.deletingLastPathComponent() } + [destination])
                if let clipboardVersion, NSPasteboard.general.changeCount == clipboardVersion {
                    let paths = Set(moved.map { $0.path })
                    let remaining = sources.filter { !paths.contains($0.path) }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects(remaining.map { $0 as NSURL })
                }
            }) { try FileActions.move($0, into: destination, conflict: selectedPolicy) }
        }
    }

    func refreshAfterMove(in folders: [URL]) {
        guard let currentURL, !operationInProgress,
              folders.contains(where: { $0.resolvingSymlinksInPath().path == currentURL.resolvingSymlinksInPath().path }) else { return }
        navigate(currentURL, addHistory: false, preserveViewState: true)
    }

    private func draggedURLs(_ info: NSDraggingInfo) -> [URL] {
        (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    private func dropOperation(_ info: NSDraggingInfo) -> NSDragOperation {
        guard !operationInProgress, view.window?.attachedSheet == nil, !draggedURLs(info).isEmpty else { return [] }
        let modifiers = NSEvent.modifierFlags
        let wantsMove = !modifiers.contains(.option) && (info.draggingSource is FileTable || modifiers.contains(.command))
        if wantsMove && info.draggingSourceOperationMask.contains(.move) { return .move }
        return info.draggingSourceOperationMask.contains(.copy) ? .copy : []
    }
    private func acceptFiles(_ info: NSDraggingInfo, into destination: URL) -> Bool {
        let operation = dropOperation(info), urls = draggedURLs(info)
        if operation == .move { moveItems(urls, into: destination); return true }
        if operation == .copy {
            performOperation("Copy", sources: urls) { try FileActions.copy($0, into: destination) }
            return true
        }
        return false
    }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard !operationInProgress, visibleEntries.indices.contains(row) else { return nil }
        return visibleEntries[row].url as NSURL
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard currentURL != nil else { return [] }
        if operation != .on || !visibleEntries.indices.contains(row) || !visibleEntries[row].canBrowse {
            tableView.setDropRow(-1, dropOperation: .on)
        }
        return dropOperation(info)
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation operation: NSTableView.DropOperation) -> Bool {
        let destination = operation == .on && visibleEntries.indices.contains(row) && visibleEntries[row].canBrowse ? visibleEntries[row].url : currentURL
        guard let destination else { return false }
        return acceptFiles(info, into: destination)
    }
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard (item as? FolderNode)?.url != nil else { return [] }
        outlineView.setDropItem(item, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return dropOperation(info)
    }
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let destination = (item as? FolderNode)?.url else { return false }
        return acceptFiles(info, into: destination)
    }
    private func requestName(title: String, initial: String, accept: String, completion: @escaping (String) -> Void) {
        guard let window = view.window, window.attachedSheet == nil, !operationInProgress else { return }
        let alert = NSAlert(); alert.messageText = title
        alert.addButton(withTitle: accept); alert.addButton(withTitle: "Cancel")
        let input = NSTextField(string: initial); input.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
        alert.accessoryView = input; alert.window.initialFirstResponder = input
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { completion(input.stringValue) }
        }
        input.selectText(nil)
    }
    @objc func newFolder() {
        guard let parent = currentURL else { return }
        var name = "untitled folder", suffix = 2
        let names = Set(entries.map(\.name))
        while names.contains(name) { name = "untitled folder \(suffix)"; suffix += 1 }
        requestName(title: "New Folder", initial: name, accept: "Create") { [weak self] name in
            self?.performOperation("Create folder", sources: [parent], revealResult: true, undoKind: .newFolder) { try FileActions.createFolder(in: $0, name: name) }
        }
    }
    @objc func renameSelected() {
        guard selectedURLs.count == 1, view.window?.firstResponder === table else { return }
        let source = selectedURLs[0]
        requestName(title: "Rename", initial: source.lastPathComponent, accept: "Rename") { [weak self] name in
            self?.performOperation("Rename", sources: [source], undoKind: .rename) { try FileActions.rename($0, to: name) }
        }
    }
    @objc func trashSelected() {
        guard view.window?.firstResponder === table, !selectedURLs.isEmpty else { return }
        performOperation("Move to Trash", sources: selectedURLs, playTrashSound: true, undoKind: .trash) { try FileUndo.trash($0) }
    }
    private func performOperation(_ title: String, sources: [URL], revealResult: Bool = false, playTrashSound: Bool = false, undoKind: FileUndo.Kind? = nil, completion: (([URL]) -> Void)? = nil, action: @escaping @Sendable (URL) throws -> URL) {
        guard !operationInProgress else { return }
        operationInProgress = true; status.stringValue = "\(title)…"
        let originalFolder = currentURL
        Task {
            let (failures, resultURL, undoRecords, warnings, movedSources) = await Task.detached(priority: .userInitiated) {
                var resultURL: URL?
                var undoRecords: [FileUndo.Record] = []
                var warnings: [String] = []
                var movedSources: [URL] = []
                let failures = sources.compactMap { url -> String? in
                    do {
                        let preparation = try undoKind.map { try FileUndo.Preparation(kind: $0, source: url) }
                        let result = try action(url)
                        if undoKind == .move && result.resolvingSymlinksInPath().path != url.resolvingSymlinksInPath().path { movedSources.append(url) }
                        if revealResult { resultURL = result }
                        if let preparation {
                            do { if let record = try preparation.record(result: result) { undoRecords.append(record) } }
                            catch { warnings.append("\(url.lastPathComponent): completed, but Undo is unavailable. \(error.localizedDescription)") }
                        }
                        return nil
                    }
                    catch FileUndo.UndoError.missingTrashLocation {
                        warnings.append("\(url.lastPathComponent): \(FileUndo.UndoError.missingTrashLocation.localizedDescription)")
                        return nil
                    }
                    catch { return "\(url.lastPathComponent): \(error.localizedDescription)" }
                }
                return (failures, resultURL, undoRecords, warnings, movedSources)
            }.value
            self.operationInProgress = false
            if !undoRecords.isEmpty { self.fileUndoHistory.append((title, undoRecords)) }
            if playTrashSound && failures.isEmpty { self.trashSound?.play() }
            if self.currentURL == originalFolder, let originalFolder {
                self.navigate(originalFolder, addHistory: false, selecting: resultURL)
            }
            completion?(movedSources)
            if !failures.isEmpty || !warnings.isEmpty, let window = self.view.window {
                let alert = NSAlert()
                alert.messageText = failures.isEmpty ? "\(title) completed with limited Undo" : "\(title): \(failures.count) of \(sources.count) items failed"
                alert.informativeText = (failures + warnings).joined(separator: "\n\n") + (["Copy", "Duplicate"].contains(title) ? "\n\nAn interrupted copy may leave an incomplete destination. Source files are unchanged." : "")
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    @objc func undo(_ sender: Any?) {
        guard !operationInProgress, view.window?.attachedSheet == nil, let batch = fileUndoHistory.last else { return }
        operationInProgress = true; status.stringValue = "Undo \(batch.title)…"
        let folder = currentURL
        Task {
            let (remaining, failures, restored) = await Task.detached(priority: .userInitiated) {
                var remaining: [FileUndo.Record] = [], failures: [String] = []
                var restored: URL?
                for record in batch.records.reversed() {
                    do { if let url = try record.undo() { restored = url } }
                    catch { remaining.append(record); failures.append("\(record.item.lastPathComponent): \(error.localizedDescription)") }
                }
                return (Array(remaining.reversed()), failures, restored)
            }.value
            self.fileUndoHistory.removeLast()
            if !remaining.isEmpty { self.fileUndoHistory.append((batch.title, remaining)) }
            self.operationInProgress = false
            if self.currentURL == folder, let folder { self.navigate(folder, addHistory: false, selecting: restored) }
            if batch.title == "Move" {
                self.onMovedFiles?(batch.records.flatMap { $0.affectedFolders })
            }
            if !failures.isEmpty, let window = self.view.window {
                let alert = NSAlert(); alert.messageText = "Undo \(batch.title): \(failures.count) of \(batch.records.count) items could not be undone"
                alert.informativeText = failures.joined(separator: "\n\n") + "\n\nThese items remain in Undo history so you can retry after resolving the issue."
                alert.beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action
        let available = !operationInProgress && view.window?.attachedSheet == nil
        if action == #selector(shareSelected(_:)) { return available && !selectedURLs.isEmpty }
        if action == #selector(undo(_:)) {
            menuItem.title = fileUndoHistory.last.map { "Undo \($0.title)" } ?? "Undo"
            return available && !fileUndoHistory.isEmpty
        }
        if action == #selector(newFolder) { return available && currentURL != nil }
        if action == #selector(paste(_:)) { return available && currentURL != nil && !clipboardURLs.isEmpty }
        if action == #selector(moveHere(_:)) { return available && currentURL != nil && !clipboardURLs.isEmpty }
        if action == #selector(renameSelected) { return available && view.window?.firstResponder === table && selectedURLs.count == 1 }
        if action == #selector(trashSelected) { return available && view.window?.firstResponder === table && !selectedURLs.isEmpty }
        if action == #selector(duplicateSelected(_:)) { return available && view.window?.firstResponder === table && !selectedURLs.isEmpty }
        if action == #selector(copy(_:)) { return !copyURLs.isEmpty }
        if action == #selector(toggleQuickLook) { return view.window?.attachedSheet == nil && !selectedURLs.isEmpty }
        if action == #selector(openSelected) {
            if view.window?.firstResponder === tree { return (tree.item(atRow: tree.selectedRow) as? FolderNode)?.url != nil }
            return !selectedURLs.isEmpty
        }
        if action == #selector(goBack) { return historyIndex > 0 }
        if action == #selector(goForward) { return historyIndex + 1 < history.count }
        if action == #selector(goUp) { return currentURL != nil && currentURL?.path != "/" }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { visibleEntries.count }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { SelectionRow() }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = visibleEntries[row], key = tableColumn?.identifier.rawValue ?? "name"
        let identifier = NSUserInterfaceItemIdentifier(key)
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        if cell.textField == nil {
            cell.identifier = identifier
            let text = label("", size: 13, secondary: key != "name"); text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text); cell.textField = text
            var leading = cell.leadingAnchor
            if key == "name" {
                let icon = NSImageView(); icon.translatesAutoresizingMaskIntoConstraints = false; cell.addSubview(icon); cell.imageView = icon
                NSLayoutConstraint.activate([icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4), icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    icon.widthAnchor.constraint(equalToConstant: 22), icon.heightAnchor.constraint(equalToConstant: 22)])
                leading = icon.trailingAnchor
            }
            NSLayoutConstraint.activate([text.leadingAnchor.constraint(equalTo: leading, constant: 12),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8), text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)])
        }
        cell.textField?.stringValue = key == "name" ? entry.name : key == "modified" ? formatDate(entry.modified) : sizeText(for: entry)
        if key == "name" { cell.imageView?.image = NSWorkspace.shared.icon(forFile: entry.url.path) }
        cell.toolTip = entry.url.path
        if key == "size", entry.isDirectory && !entry.isSymbolicLink {
            cell.toolTip = "\(sizeText(for: entry)). Total file sizes, including hidden files and packages. Symbolic links are excluded. ≥ means some contents could not be read. Refresh to recalculate."
        }
        return cell
    }
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first, let key = descriptor.key, let value = FileSort(rawValue: key) else { return }
        sort = value; ascending = descriptor.ascending; applyFilter()
    }
    func tableViewSelectionDidChange(_ notification: Notification) { updateInspector() }
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
    private func updateInspector() {
        updateQuickLookSelection()
        let count = table.selectedRowIndexes.count
        shareButton.isEnabled = count > 0 && !operationInProgress
        status.stringValue = "\(visibleEntries.count) items\(count > 0 ? "  ·  \(count) selected" : "")\(showHidden ? "  ·  Hidden files shown" : "")"
        guard count == 1, visibleEntries.indices.contains(table.selectedRow) else {
            inspectorName.stringValue = count > 1 ? "\(count) items selected" : "Select a file"
            inspectorType.stringValue = ""; inspectorDetails.stringValue = ""; previewIcon.image = nil; openButton.isEnabled = false; return
        }
        let item = visibleEntries[table.selectedRow]
        inspectorName.stringValue = item.name
        inspectorType.stringValue = item.canBrowse ? "Folder · \(sizeText(for: item))" : "\(item.url.pathExtension.uppercased()) file · \(sizeText(for: item))"
        inspectorDetails.stringValue = "Modified\n\(formatDate(item.modified))\n\nCreated\n\(formatDate(item.created))\n\nLocation\n\(item.url.deletingLastPathComponent().path)"
        previewIcon.image = NSWorkspace.shared.icon(forFile: item.url.path)
        openButton.title = item.canBrowse ? "Open Folder" : "Open in Default App"; openButton.isEnabled = true
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int { (item as? FolderNode)?.children?.count ?? (item == nil ? roots.count : 0) }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any { (item as? FolderNode)?.children?[index] ?? roots[index] }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FolderNode else { return false }
        return node.children.map { !$0.isEmpty } ?? (node.url != nil)
    }
    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool {
        guard let node = item as? FolderNode, node.children == nil, let url = node.url, !node.loading else { return true }
        node.loading = true
        Task {
            let result = await Task.detached { Result { try DirectoryReader.read(url) } }.value
            node.loading = false
            if case .success(let items) = result {
                node.children = DirectoryReader.sorted(items.filter { $0.canBrowse && !$0.isSymbolicLink }, by: .name, ascending: true)
                    .map { FolderNode($0.name, url: $0.url) }
                self.tree.reloadItem(node, reloadChildren: true); self.tree.expandItem(node)
            } else { self.status.stringValue = "Can’t expand \(node.title). Open the folder to see the access error." }
        }
        return false
    }
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool { (item as? FolderNode)?.url != nil }
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FolderNode else { return nil }
        let cell = NSTableCellView()
        let text = label(node.title, size: node.url == nil ? 10 : 13, bold: node.url == nil, secondary: node.url == nil)
        text.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(text); cell.textField = text
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
    @objc private func selectFolder() {
        if let node = tree.item(atRow: tree.clickedRow) as? FolderNode, let url = node.url { navigate(url) }
    }
}

@MainActor
private final class MainViewportController: NSViewController {
    enum ViewMode {
        case spatial
        case classic
    }

    let spatialCanvas = SpatialCanvasViewController()
    let explorer: ExplorerController
    private(set) var mode: ViewMode = .spatial

    var onLocationChange: (() -> Void)? {
        didSet { explorer.onLocationChange = onLocationChange }
    }
    var onMovedFiles: (([URL]) -> Void)? {
        didSet { explorer.onMovedFiles = onMovedFiles }
    }
    var sessionURL: URL { explorer.sessionURL }
    var hasPendingFileOperation: Bool { explorer.hasPendingFileOperation }

    init(initialURL: URL) {
        self.explorer = ExplorerController(initialURL: initialURL)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 960))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: 0x080A0F).cgColor

        addChild(spatialCanvas)
        addChild(explorer)

        spatialCanvas.view.frame = view.bounds
        spatialCanvas.view.autoresizingMask = [.width, .height]
        view.addSubview(spatialCanvas.view)

        explorer.view.frame = view.bounds
        explorer.view.autoresizingMask = [.width, .height]

        spatialCanvas.onSwitchToClassicView = { [weak self] in
            self?.toggleMode()
        }
    }

    func toggleMode() {
        setMode(mode == .spatial ? .classic : .spatial)
    }

    func setMode(_ newMode: ViewMode) {
        guard newMode != mode else { return }
        mode = newMode
        if mode == .classic {
            spatialCanvas.view.removeFromSuperview()
            view.addSubview(explorer.view)
        } else {
            explorer.view.removeFromSuperview()
            view.addSubview(spatialCanvas.view)
        }
    }

    func refreshAfterMove(in folders: [URL]) {
        explorer.refreshAfterMove(in: folders)
    }

    func revealExternally(_ urls: [URL], in folder: URL) {
        explorer.revealExternally(urls, in: folder)
    }
}

private extension NSWindow {
    var explorerController: ExplorerController? {
        if let mv = contentViewController as? MainViewportController {
            return mv.explorer
        }
        return contentViewController as? ExplorerController
    }
    var viewportController: MainViewportController? {
        contentViewController as? MainViewportController
    }
}

@MainActor
private final class BrowserWindow: NSWindow {
    override func newWindowForTab(_ sender: Any?) {
        (NSApp.delegate as? AppDelegate)?.newTab(sender)
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [BrowserWindow] = []
    private var restoringSession = false
    private var terminating = false
    private var readyForExternalOpen = false
    private var pendingExternalOpens: [(urls: [URL], reveal: Bool)] = []
    private var changingDefaultViewer = false
    private var activeWindow: BrowserWindow? { (NSApp.mainWindow as? BrowserWindow) ?? windows.first }
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleRevealEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kAEMiscStandards), andEventID: AEEventID(kAEMakeObjectsVisible))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            NSApp.applicationIconImage = NSImage(contentsOf: iconURL)
        }
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let menu = NSMenu(), appMenu = NSMenu(), fileMenu = NSMenu(), viewMenu = NSMenu(), goMenu = NSMenu()
        for (title, submenu) in [("BetterFinder", appMenu), ("File", fileMenu), ("View", viewMenu), ("Go", goMenu)] {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); item.submenu = submenu; menu.addItem(item)
        }
        let folderAccess = appMenu.addItem(withTitle: "Full Disk Access…", action: #selector(configureFolderAccess(_:)), keyEquivalent: "")
        folderAccess.target = self
        appMenu.addItem(.separator())
        let useDefault = appMenu.addItem(withTitle: "Use BetterFinder as Default File Viewer…", action: #selector(useAsDefaultViewer(_:)), keyEquivalent: "")
        useDefault.target = self
        let restoreDefault = appMenu.addItem(withTitle: "Restore Previous File Viewer…", action: #selector(restoreDefaultViewer(_:)), keyEquivalent: "")
        restoreDefault.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit BetterFinder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, modifiers: NSEvent.ModifierFlags = .command) {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key); item.keyEquivalentModifierMask = modifiers
        }
        let newTabItem = fileMenu.addItem(withTitle: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        newTabItem.target = self
        add(fileMenu, "New Folder…", #selector(ExplorerController.newFolder), "n", modifiers: [.command, .shift])
        add(fileMenu, "Open", #selector(ExplorerController.openSelected), "o")
        add(fileMenu, "Quick Look", #selector(ExplorerController.toggleQuickLook), "y")
        add(fileMenu, "Share…", #selector(ExplorerController.shareSelected(_:)), "")
        add(fileMenu, "Open WhatsApp", #selector(ExplorerController.openWhatsApp(_:)), "")
        add(fileMenu, "Open Discord", #selector(ExplorerController.openDiscord(_:)), "")
        add(fileMenu, "Choose Folder…", #selector(ExplorerController.chooseFolder), "")
        add(fileMenu, "Rename…", #selector(ExplorerController.renameSelected), "")
        add(fileMenu, "Duplicate", #selector(ExplorerController.duplicateSelected(_:)), "d")
        add(fileMenu, "Move to Trash", #selector(ExplorerController.trashSelected), String(UnicodeScalar(NSBackspaceCharacter)!))
        fileMenu.addItem(withTitle: "Close Tab", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let spatialItem = viewMenu.addItem(withTitle: "Spatial Neural Canvas", action: #selector(switchToSpatialCanvas), keyEquivalent: "1")
        spatialItem.target = self
        let classicItem = viewMenu.addItem(withTitle: "Classic Details View", action: #selector(switchToClassicView), keyEquivalent: "2")
        classicItem.target = self
        viewMenu.addItem(.separator())
        add(viewMenu, "Refresh", #selector(ExplorerController.refresh), "r")
        add(viewMenu, "Show / Hide Hidden Files", #selector(ExplorerController.toggleHidden), ".", modifiers: [.command, .shift])
        add(viewMenu, "Filter This Folder", #selector(ExplorerController.focusFilter), "f")
        add(goMenu, "Back", #selector(ExplorerController.goBack), "[")
        add(goMenu, "Forward", #selector(ExplorerController.goForward), "]")
        add(goMenu, "Edit Path", #selector(ExplorerController.focusPath), "l")
        add(goMenu, "Go to Folder…", #selector(ExplorerController.focusPath), "g", modifiers: [.command, .shift])
        add(goMenu, "Enclosing Folder", #selector(ExplorerController.goUp), String(UnicodeScalar(NSUpArrowFunctionKey)!))
        add(goMenu, "Open Selection", #selector(ExplorerController.openSelected), String(UnicodeScalar(NSDownArrowFunctionKey)!))
        add(goMenu, "Next Tab", #selector(NSWindow.selectNextTab(_:)), "\t", modifiers: [.control])
        add(goMenu, "Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "\t", modifiers: [.control, .shift])
        // Standard edit commands are needed for the path and filter text fields.
        let editMenu = NSMenu(title: "Edit"), editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = editMenu; menu.insertItem(editItem, at: 2)
        editMenu.addItem(withTitle: "Undo", action: NSSelectorFromString("undo:"), keyEquivalent: "z")
        editMenu.addItem(.separator())
        add(editMenu, "Move Items Here", #selector(ExplorerController.moveHere(_:)), "v", modifiers: [.command, .option])
        for (title, action, key) in [("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: NSSelectorFromString(action), keyEquivalent: key)
        }
        NSApp.mainMenu = menu
        restoreTabs()
        readyForExternalOpen = true
        let queued = pendingExternalOpens; pendingExternalOpens.removeAll()
        for request in queued { openExternal(request.urls, reveal: request.reveal) }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func switchToSpatialCanvas() {
        activeWindow?.viewportController?.setMode(.spatial)
    }
    @objc func switchToClassicView() {
        activeWindow?.viewportController?.setMode(.classic)
    }

    func application(_ application: NSApplication, open urls: [URL]) { openExternal(urls, reveal: false) }
    @objc private func handleRevealEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let direct = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else { return }
        func urls(_ descriptor: NSAppleEventDescriptor) -> [URL] {
            if descriptor.descriptorType == typeAEList {
                guard descriptor.numberOfItems > 0 else { return [] }
                return (1...descriptor.numberOfItems).flatMap { descriptor.atIndex($0).map(urls) ?? [] }
            }
            guard let file = descriptor.coerce(toDescriptorType: DescType(typeFileURL)),
                  let string = String(data: file.data, encoding: .utf8),
                  let url = URL(string: string.trimmingCharacters(in: .controlCharacters)), url.isFileURL else { return [] }
            return [url]
        }
        let files = urls(direct)
        if files.isEmpty { reply.setParam(NSAppleEventDescriptor(int32: -1700), forKeyword: AEKeyword(keyErrorNumber)) }
        else { openExternal(files, reveal: true) }
    }
    private func openExternal(_ urls: [URL], reveal: Bool) {
        guard readyForExternalOpen else { pendingExternalOpens.append((urls, reveal)); return }
        var groups: [(folder: URL, selection: [URL])] = []
        for url in urls where url.isFileURL {
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            let openFolder = !reveal && values?.isDirectory == true && values?.isPackage != true
            let folder = openFolder ? url : url.deletingLastPathComponent()
            if let index = groups.firstIndex(where: { $0.folder.standardizedFileURL.path == folder.standardizedFileURL.path }) {
                if !openFolder { groups[index].selection.append(url) }
            } else { groups.append((folder, openFolder ? [] : [url])) }
        }
        for group in groups {
            let existing = windows.first { $0.explorerController?.sessionURL.standardizedFileURL.path == group.folder.standardizedFileURL.path }
            let window = existing ?? makeWindow(at: group.folder, beside: activeWindow)
            window.explorerController?.revealExternally(group.selection, in: group.folder)
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func configureFolderAccess(_ sender: Any?) {
        guard let window = activeWindow, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Allow access across folders"
        alert.informativeText = "Enable BetterFinder in System Settings → Privacy & Security → Full Disk Access. This covers protected folders such as Desktop, Documents, and Downloads.\n\nIf BetterFinder isn’t listed, drag BetterFinder.app from the file viewer into the Full Disk Access list, or use the + button to add it. We’ll show you the app when you open settings.\n\nQuit and reopen BetterFinder after enabling access. macOS requires you to grant this permission yourself."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
            if !NSWorkspace.shared.open(settingsURL) {
                let failure = NSAlert()
                failure.messageText = "Open Full Disk Access in System Settings"
                failure.informativeText = "Open System Settings manually, then choose Privacy & Security → Full Disk Access and enable BetterFinder."
                failure.beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    @objc private func useAsDefaultViewer(_ sender: Any?) {
        guard let window = activeWindow, !changingDefaultViewer else { return }
        changingDefaultViewer = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let alert = NSAlert()
            do {
                try await DefaultFileViewer.enable()
                alert.messageText = "BetterFinder is now your default file viewer"
                alert.informativeText = "External folders and Reveal in Finder actions will now open in BetterFinder.\n\nYou may need to restart other open applications for this change to take effect everywhere."
            } catch {
                alert.messageText = "Couldn’t change the default file viewer"
                alert.informativeText = error.localizedDescription
            }
            self.changingDefaultViewer = false
            if window.attachedSheet == nil { alert.beginSheetModal(for: window, completionHandler: nil) }
        }
    }

    @objc private func restoreDefaultViewer(_ sender: Any?) {
        guard let window = activeWindow, !changingDefaultViewer else { return }
        changingDefaultViewer = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let alert = NSAlert()
            do {
                try await DefaultFileViewer.restore()
                alert.messageText = "Restored previous file viewer"
                alert.informativeText = "External folders and Reveal in Finder actions will now open with your previous file viewer (such as Finder).\n\nYou may need to restart other open applications for this change to take effect everywhere."
            } catch {
                alert.messageText = "Couldn’t change the default file viewer"
                alert.informativeText = error.localizedDescription
            }
            self.changingDefaultViewer = false
            if window.attachedSheet == nil { alert.beginSheetModal(for: window, completionHandler: nil) }
        }
    }

    private func makeWindow(at url: URL, beside existing: BrowserWindow? = nil) -> BrowserWindow {
        let viewport = MainViewportController(initialURL: url)
        viewport.onLocationChange = { [weak self] in self?.saveSession() }
        viewport.onMovedFiles = { [weak self, weak viewport] folders in
            guard let self else { return }
            for window in self.windows {
                if let other = window.explorerController, other !== viewport?.explorer { other.refreshAfterMove(in: folders) }
            }
        }
        let window = BrowserWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = url.path == "/" ? "Macintosh HD" : url.lastPathComponent
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = NSColor(hex: 0x080A0F)
        window.minSize = NSSize(width: 960, height: 640)
        window.isReleasedWhenClosed = false; window.delegate = self
        window.tabbingIdentifier = "BetterFinder.Browser"
        window.tabbingMode = .preferred
        window.contentViewController = viewport
        windows.append(window)
        if let existing { existing.addTabbedWindow(window, ordered: .above) }
        else { window.center() }
        window.makeKeyAndOrderFront(nil)
        return window
    }

    @objc func newTab(_ sender: Any?) {
        let existing = activeWindow
        let url = existing?.explorerController?.sessionURL ?? FileManager.default.homeDirectoryForCurrentUser
        _ = makeWindow(at: url, beside: existing)
        saveSession()
    }

    private func restoreTabs() {
        restoringSession = true
        let saved = UserDefaults.standard.stringArray(forKey: "session.tabPaths") ?? []
        let paths = saved.filter { $0.hasPrefix("/") }
        let urls = paths.isEmpty ? [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("MyProjects/BetterFinder")] : paths.map { URL(fileURLWithPath: $0) }
        var previous: BrowserWindow?
        for url in urls { previous = makeWindow(at: url, beside: previous) }
        let index = max(0, min(UserDefaults.standard.integer(forKey: "session.selectedTab"), windows.count - 1))
        windows[index].tabGroup?.selectedWindow = windows[index]
        windows[index].makeKeyAndOrderFront(nil)
        restoringSession = false
        saveSession()
    }

    private func saveSession() {
        guard !restoringSession, !terminating, !windows.isEmpty else { return }
        var ordered: [BrowserWindow] = []
        for window in windows {
            for member in window.tabGroup?.windows ?? [window] {
                if let browser = member as? BrowserWindow, windows.contains(where: { $0 === browser }),
                   !ordered.contains(where: { $0 === browser }) { ordered.append(browser) }
            }
        }
        let paths = ordered.compactMap { $0.explorerController?.sessionURL.path }
        UserDefaults.standard.set(paths, forKey: "session.tabPaths")
        UserDefaults.standard.set(ordered.firstIndex(where: { $0 === activeWindow }) ?? 0, forKey: "session.selectedTab")
    }

    func windowDidBecomeMain(_ notification: Notification) { saveSession() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender.explorerController?.hasPendingFileOperation != true else {
            NSSound.beep(); return false
        }
        return true
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? BrowserWindow else { return }
        // Preserve the final tab for the next launch; closing other tabs removes them from the saved session.
        if windows.count == 1 { saveSession() }
        windows.removeAll { $0 === window }
        if !windows.isEmpty { DispatchQueue.main.async { [weak self] in self?.saveSession() } }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if windows.contains(where: { $0.explorerController?.hasPendingFileOperation == true }) {
            NSSound.beep(); return .terminateCancel
        }
        saveSession(); terminating = true
        return .terminateNow
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    withExtendedLifetime(delegate) { application.run() }
}

import AppKit
import QuartzCore
import Quartz
import DirectoryCore

// MARK: - Spatial Neural Canvas View Controller (Master 2.5D Scene)
public final class SpatialCanvasViewController: NSViewController, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private let canvasView = NSView()
    private var filamentsView = SynapticFilamentsView()
    private var clusterViews: [GravityWellView] = []
    private var cardViews: [String: GlassCardContainer] = [:]

    private var clusters: [SpatialCluster] = []
    private var nodes: [SpatialCardNode] = []
    private var filaments: [SynapticFilament] = []

    private let dynamicIsland = DynamicIslandHUD()
    private let chronoRibbon = ChronoRibbonView()
    private let chronoDial = ChronoDialView()
    private let inspectorToggle = NSButton()

    private var canvasOrigin = CGPoint(x: 0, y: 0)
    private var canvasScale: CGFloat = 1.0
    private var lastDragPoint: CGPoint?

    // Filesystem State
    public private(set) var currentURL: URL?
    private var history: [URL] = []
    private var historyIndex: Int = -1
    public var onLocationChange: ((URL) -> Void)?
    public var onSwitchToClassicView: (() -> Void)?
    private var selectedNode: SpatialCardNode?

    public override var acceptsFirstResponder: Bool { true }

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 960))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: 0x080A0F).cgColor // Obsidian space background

        setupCanvas()
        setupOverlays()
    }

    public override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
        updateFullDiskAccessStatus()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func windowDidBecomeKey() {
        updateFullDiskAccessStatus()
    }

    public func updateFullDiskAccessStatus() {
        dynamicIsland.setFullDiskAccessState(granted: FullDiskAccessHelper.isGranted)
    }

    private func setupCanvas() {
        canvasView.frame = NSRect(x: 0, y: 0, width: 2800, height: 1800)
        canvasView.wantsLayer = true
        view.addSubview(canvasView)

        filamentsView.frame = canvasView.bounds
        filamentsView.autoresizingMask = [.width, .height]
        canvasView.addSubview(filamentsView)
    }

    // MARK: - Live Filesystem Loading
    public func loadDirectory(_ url: URL, recordHistory: Bool = true) {
        let standardized = url.standardizedFileURL
        currentURL = standardized

        if recordHistory {
            if historyIndex >= 0 && historyIndex < history.count - 1 {
                history.removeSubrange((historyIndex + 1)...)
            }
            history.append(standardized)
            historyIndex = history.count - 1
        }

        // Read real filesystem entries
        let entries: [FileEntry]
        do {
            entries = try DirectoryReader.read(standardized, showHidden: false)
        } catch {
            NSLog("BetterFinder SpatialCanvas: Failed to read directory \(standardized.path): \(error)")
            entries = []
        }

        let p = CanvasPreset.makeClusters(from: entries, parentURL: standardized)
        applyScene(clusters: p.clusters, nodes: p.nodes, filaments: p.filaments)

        // Update Dynamic Island & Navigation States
        dynamicIsland.searchField.stringValue = ""
        filterNodes("")
        let folderName = standardized.path == "/" ? "Macintosh HD" : standardized.lastPathComponent
        dynamicIsland.setFolderTitle(folderName, fullPath: standardized.path)
        dynamicIsland.setNavigationEnabled(
            canGoBack: historyIndex > 0,
            canGoForward: historyIndex < history.count - 1,
            canGoUp: standardized.path != "/"
        )

        chronoRibbon.highlightShortcut(for: standardized)
        onLocationChange?(standardized)

        // Center view on primary cluster
        if let firstCluster = p.clusters.first {
            focusOnCluster(firstCluster)
        }
    }

    public enum ScenePreset {
        case overview
        case focused
    }
    public private(set) var currentPreset: ScenePreset = .overview

    public func setPreset(_ preset: ScenePreset) {
        currentPreset = preset
        let p = preset == .overview ? CanvasPreset.makeDefaultClusters() : CanvasPreset.makeFocusedPreset()
        applyScene(clusters: p.clusters, nodes: p.nodes, filaments: p.filaments)

        dynamicIsland.setFolderTitle(preset == .overview ? "Active Launch: Project Cyberne" : "Cyberne Neural Focus", fullPath: "Cyberne 2026 Concept Demo")
        dynamicIsland.setNavigationEnabled(canGoBack: historyIndex > 0, canGoForward: historyIndex < history.count - 1, canGoUp: false)
        chronoRibbon.highlightShortcut(for: nil)

        if preset == .focused {
            dynamicIsland.searchField.placeholderString = "Natural language search..."
            chronoDial.isHidden = false
            chronoRibbon.isHidden = true
        } else {
            dynamicIsland.searchField.placeholderString = "Filter files or semantic search…"
            chronoDial.isHidden = true
            chronoRibbon.isHidden = false
        }
    }

    private func applyScene(clusters: [SpatialCluster], nodes: [SpatialCardNode], filaments: [SynapticFilament]) {
        clusterViews.forEach { $0.removeFromSuperview() }
        clusterViews.removeAll()
        cardViews.values.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()
        selectedNode = nil

        self.clusters = clusters
        self.nodes = nodes
        self.filaments = filaments

        // Add Gravity Wells (Clusters)
        for cluster in clusters {
            let gw = GravityWellView(cluster: cluster)
            clusterViews.append(gw)
            canvasView.addSubview(gw)
        }

        // Add Cards
        var nodeCenters: [String: CGPoint] = [:]
        for node in nodes {
            let card = GlassCardContainer(node: node)
            cardViews[node.id] = card
            canvasView.addSubview(card)

            let center = CGPoint(x: node.position.x + node.size.width / 2, y: node.position.y + node.size.height / 2)
            nodeCenters[node.id] = center

            card.onDrag = { [weak self] newOrigin in
                guard let self else { return }
                let newCenter = CGPoint(x: newOrigin.x + node.size.width / 2, y: newOrigin.y + node.size.height / 2)
                self.filamentsView.updateNodePosition(id: node.id, center: newCenter)
            }

            card.onOpenFolder = { [weak self] folderURL in
                self?.loadDirectory(folderURL)
            }

            card.onOpenFile = { fileURL in
                NSWorkspace.shared.open(fileURL)
            }

            card.onSelect = { [weak self] selected in
                self?.selectCard(selected)
            }

            card.onQuickLook = { [weak self] fileURL in
                self?.triggerQuickLook(for: fileURL)
            }
        }

        // Configure Filaments
        filamentsView.configure(filaments: filaments, nodeCenters: nodeCenters)
    }

    private func setupOverlays() {
        // Dynamic Island HUD
        dynamicIsland.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dynamicIsland)

        // Top-Right Inspector Toggle Button
        inspectorToggle.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "Toggle View Mode")
        inspectorToggle.bezelStyle = .regularSquare
        inspectorToggle.isBordered = false
        inspectorToggle.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        inspectorToggle.toolTip = "Toggle Spatial / Classic Mode"
        inspectorToggle.target = self
        inspectorToggle.action = #selector(inspectorToggleTapped)
        inspectorToggle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inspectorToggle)

        // Bottom Chrono-Ribbon Dock
        chronoRibbon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chronoRibbon)

        // Bottom-Right Chrono-Dial
        chronoDial.translatesAutoresizingMaskIntoConstraints = false
        chronoDial.isHidden = true
        view.addSubview(chronoDial)

        NSLayoutConstraint.activate([
            // Dynamic Island
            dynamicIsland.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            dynamicIsland.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dynamicIsland.widthAnchor.constraint(equalToConstant: 780),
            dynamicIsland.heightAnchor.constraint(equalToConstant: 44),

            // Inspector Toggle
            inspectorToggle.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            inspectorToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            inspectorToggle.widthAnchor.constraint(equalToConstant: 24),
            inspectorToggle.heightAnchor.constraint(equalToConstant: 24),

            // Chrono-Ribbon
            chronoRibbon.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 22),
            chronoRibbon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chronoRibbon.widthAnchor.constraint(equalToConstant: 800),
            chronoRibbon.heightAnchor.constraint(equalToConstant: 58),

            // Chrono-Dial
            chronoDial.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            chronoDial.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chronoDial.widthAnchor.constraint(equalToConstant: 220),
            chronoDial.heightAnchor.constraint(equalToConstant: 220)
        ])

        // Handlers
        dynamicIsland.onQueryChange = { [weak self] query in
            self?.filterNodes(query)
        }

        dynamicIsland.onFilterClick = { [weak self] in
            guard let self else { return }
            self.setPreset(self.currentPreset == .overview ? .focused : .overview)
        }

        dynamicIsland.onToggleViewMode = { [weak self] in
            self?.onSwitchToClassicView?()
        }

        dynamicIsland.onGoBack = { [weak self] in
            self?.goBack()
        }

        dynamicIsland.onGoForward = { [weak self] in
            self?.goForward()
        }

        dynamicIsland.onGoUp = { [weak self] in
            self?.goUp()
        }

        dynamicIsland.onChooseFolder = { [weak self] in
            self?.chooseFolder()
        }

        dynamicIsland.onFullDiskAccess = { [weak self] in
            guard let self else { return }
            FullDiskAccessHelper.openSettings(for: self.view.window)
        }

        chronoRibbon.onSelectURL = { [weak self] url in
            self?.loadDirectory(url)
        }

        chronoRibbon.onSelectDemo = { [weak self] in
            self?.setPreset(.overview)
        }

        chronoRibbon.onSelectCluster = { [weak self] index in
            self?.focusOnClusterIndex(index)
        }
    }

    // MARK: - Navigation Helpers
    public func goBack() {
        guard historyIndex > 0 else { return }
        historyIndex -= 1
        loadDirectory(history[historyIndex], recordHistory: false)
    }

    public func goForward() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        loadDirectory(history[historyIndex], recordHistory: false)
    }

    public func goUp() {
        guard let cur = currentURL, cur.path != "/" else { return }
        loadDirectory(cur.deletingLastPathComponent())
    }

    public func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open in Spatial Canvas"
        panel.directoryURL = currentURL

        if let window = view.window {
            panel.beginSheetModal(for: window) { [weak self] response in
                if response == .OK, let url = panel.url {
                    self?.loadDirectory(url)
                }
            }
        } else if panel.runModal() == .OK, let url = panel.url {
            loadDirectory(url)
        }
    }

    @objc private func inspectorToggleTapped() {
        onSwitchToClassicView?()
    }

    private func selectCard(_ node: SpatialCardNode) {
        selectedNode = node
        for (id, card) in cardViews {
            card.setSelected(id == node.id)
        }
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.reloadData()
        }
    }

    private func triggerQuickLook(for url: URL) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
            panel.reloadData()
        }
    }

    private func filterNodes(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for (_, card) in cardViews {
            if q.isEmpty {
                card.animator().alphaValue = 1.0
            } else {
                let match = card.node.title.lowercased().contains(q) || card.node.subtitle.lowercased().contains(q)
                card.animator().alphaValue = match ? 1.0 : 0.15
            }
        }
    }

    private func focusOnClusterIndex(_ index: Int) {
        guard index < clusters.count else { return }
        focusOnCluster(clusters[index])
    }

    private func focusOnCluster(_ cluster: SpatialCluster) {
        let target = cluster.center
        let viewCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let targetOrigin = CGPoint(x: viewCenter.x - target.x, y: viewCenter.y - target.y)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            canvasView.animator().frame.origin = targetOrigin
        }
    }

    // MARK: - Key Events (Space for Quick Look, Back, Up, Enter to Open)
    public override func keyDown(with event: NSEvent) {
        // Spacebar toggles Quick Look
        if event.keyCode == 49 && !event.isARepeat {
            if let selected = selectedNode, let url = selected.url {
                triggerQuickLook(for: url)
                return
            }
        }
        // ⌘[ for Back
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "[" {
            goBack()
            return
        }
        // ⌘] for Forward
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "]" {
            goForward()
            return
        }
        // ⌘↑ for Parent Folder
        if event.modifierFlags.contains(.command) && event.keyCode == 126 {
            goUp()
            return
        }
        // Return or ⌘↓ to Open Selected Folder/File
        if (event.keyCode == 36 || (event.modifierFlags.contains(.command) && event.keyCode == 125)),
           let selected = selectedNode, let url = selected.url {
            if selected.fileEntry?.canBrowse == true {
                loadDirectory(url)
            } else {
                NSWorkspace.shared.open(url)
            }
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Quick Look Panel DataSource & Delegate
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return selectedNode?.url != nil ? 1 : 0
    }

    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard let url = selectedNode?.url else { return nil }
        return url as NSURL
    }

    // Pan Canvas Background
    public override func mouseDown(with event: NSEvent) {
        lastDragPoint = event.locationInWindow
        super.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let last = lastDragPoint else { return }
        let current = event.locationInWindow
        let deltaX = current.x - last.x
        let deltaY = current.y - last.y

        canvasView.frame.origin.x += deltaX
        canvasView.frame.origin.y += deltaY
        lastDragPoint = current
    }

    public override func scrollWheel(with event: NSEvent) {
        canvasView.frame.origin.x += event.scrollingDeltaX
        canvasView.frame.origin.y -= event.scrollingDeltaY
    }

    public override func magnify(with event: NSEvent) {
        let newScale = max(0.45, min(2.2, canvasScale + event.magnification))
        canvasScale = newScale
        canvasView.layer?.setAffineTransform(CGAffineTransform(scaleX: canvasScale, y: canvasScale))
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255,
                  alpha: 1.0)
    }
}


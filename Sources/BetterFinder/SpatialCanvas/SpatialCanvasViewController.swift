import AppKit
import QuartzCore

// MARK: - Spatial Neural Canvas View Controller (Master 2.5D Scene)
public final class SpatialCanvasViewController: NSViewController {
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

    public var onSwitchToClassicView: (() -> Void)?

    public override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1440, height: 960))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(hex: 0x080A0F).cgColor // Obsidian space background

        setupCanvas()
        setupPresets()
        setupOverlays()
    }

    private func setupCanvas() {
        canvasView.frame = NSRect(x: 0, y: 0, width: 2400, height: 1600)
        canvasView.wantsLayer = true
        view.addSubview(canvasView)

        // Filaments under cards
        filamentsView.frame = canvasView.bounds
        filamentsView.autoresizingMask = [.width, .height]
        canvasView.addSubview(filamentsView)
    }

    public enum ScenePreset {
        case overview
        case focused
    }
    public private(set) var currentPreset: ScenePreset = .overview

    private func setupPresets() {
        setPreset(.overview)
    }

    public func setPreset(_ preset: ScenePreset) {
        currentPreset = preset
        clusterViews.forEach { $0.removeFromSuperview() }
        clusterViews.removeAll()
        cardViews.values.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()

        let p = preset == .overview ? CanvasPreset.makeDefaultClusters() : CanvasPreset.makeFocusedPreset()
        self.clusters = p.clusters
        self.nodes = p.nodes
        self.filaments = p.filaments

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
        }

        // Configure Filaments
        filamentsView.configure(filaments: filaments, nodeCenters: nodeCenters)

        if preset == .focused {
            dynamicIsland.searchField.placeholderString = "Natural language search..."
            chronoDial.isHidden = false
            chronoRibbon.isHidden = true
            canvasView.frame.origin = CGPoint(x: 0, y: 0)
        } else {
            dynamicIsland.searchField.placeholderString = "Natural language semantic query lens for search"
            chronoDial.isHidden = true
            chronoRibbon.isHidden = false
            canvasView.frame.origin = CGPoint(x: 0, y: 0)
        }
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
            dynamicIsland.widthAnchor.constraint(equalToConstant: 620),
            dynamicIsland.heightAnchor.constraint(equalToConstant: 44),

            // Inspector Toggle
            inspectorToggle.topAnchor.constraint(equalTo: view.topAnchor, constant: 22),
            inspectorToggle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            inspectorToggle.widthAnchor.constraint(equalToConstant: 24),
            inspectorToggle.heightAnchor.constraint(equalToConstant: 24),

            // Chrono-Ribbon
            chronoRibbon.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -18),
            chronoRibbon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            chronoRibbon.widthAnchor.constraint(equalToConstant: 720),
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

        chronoRibbon.onSelectCluster = { [weak self] index in
            self?.focusOnClusterIndex(index)
        }
    }

    @objc private func inspectorToggleTapped() {
        setPreset(currentPreset == .overview ? .focused : .overview)
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
        let target = clusters[index].center
        let viewCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let targetOrigin = CGPoint(x: viewCenter.x - target.x, y: viewCenter.y - target.y)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.55
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            canvasView.animator().frame.origin = targetOrigin
        }
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

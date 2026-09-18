import AppKit
import SceneKit
import QuartzCore

// MARK: - 3D Turntable Micro-Surface (SceneKit)
public final class Turntable3DView: NSView {
    private let scnView = SCNView()
    private var platterNode: SCNNode?
    private var rootTurntableNode: SCNNode?
    private var lastDragLocation: CGPoint?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupScene()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupScene() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        scnView.frame = bounds
        scnView.autoresizingMask = [.width, .height]
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        addSubview(scnView)

        let scene = SCNScene()
        scnView.scene = scene

        let turntableRoot = SCNNode()
        self.rootTurntableNode = turntableRoot
        scene.rootNode.addChildNode(turntableRoot)

        // Base Plinth (Dark Metallic Chassis)
        let plinthGeo = SCNBox(width: 3.2, height: 0.35, length: 2.6, chamferRadius: 0.08)
        let plinthMat = SCNMaterial()
        plinthMat.diffuse.contents = NSColor(hex: 0x1A202C)
        plinthMat.roughness.contents = 0.35
        plinthMat.metalness.contents = 0.8
        plinthGeo.materials = [plinthMat]
        let plinthNode = SCNNode(geometry: plinthGeo)
        plinthNode.position = SCNVector3(0, -0.2, 0)
        turntableRoot.addChildNode(plinthNode)

        // Rotating Platter & Vinyl
        let rotatingGroup = SCNNode()
        self.platterNode = rotatingGroup
        turntableRoot.addChildNode(rotatingGroup)

        // Metal Platter Rim
        let platterGeo = SCNCylinder(radius: 1.05, height: 0.12)
        let platterMat = SCNMaterial()
        platterMat.diffuse.contents = NSColor(hex: 0x4A5568)
        platterMat.metalness.contents = 0.95
        platterMat.roughness.contents = 0.2
        platterGeo.materials = [platterMat]
        let platterRimNode = SCNNode(geometry: platterGeo)
        platterRimNode.position = SCNVector3(-0.35, 0.02, 0)
        rotatingGroup.addChildNode(platterRimNode)

        // Vinyl Record
        let vinylGeo = SCNCylinder(radius: 0.98, height: 0.03)
        let vinylMat = SCNMaterial()
        vinylMat.diffuse.contents = NSColor(hex: 0x0D1117)
        vinylMat.roughness.contents = 0.15
        vinylMat.metalness.contents = 0.3
        vinylGeo.materials = [vinylMat]
        let vinylNode = SCNNode(geometry: vinylGeo)
        vinylNode.position = SCNVector3(-0.35, 0.08, 0)
        rotatingGroup.addChildNode(vinylNode)

        // Vinyl Label (Cyan center ring)
        let labelGeo = SCNCylinder(radius: 0.32, height: 0.032)
        let labelMat = SCNMaterial()
        labelMat.diffuse.contents = NSColor(red: 0.0, green: 0.8, blue: 0.95, alpha: 1.0)
        labelGeo.materials = [labelMat]
        let labelNode = SCNNode(geometry: labelGeo)
        labelNode.position = SCNVector3(-0.35, 0.082, 0)
        rotatingGroup.addChildNode(labelNode)

        // Center Spindle
        let spindleGeo = SCNCylinder(radius: 0.04, height: 0.25)
        let spindleMat = SCNMaterial()
        spindleMat.diffuse.contents = NSColor.white
        spindleMat.metalness.contents = 1.0
        spindleGeo.materials = [spindleMat]
        let spindleNode = SCNNode(geometry: spindleGeo)
        spindleNode.position = SCNVector3(-0.35, 0.15, 0)
        turntableRoot.addChildNode(spindleNode)

        // Tonearm Base & Arm
        let armBaseGeo = SCNCylinder(radius: 0.2, height: 0.3)
        let armBaseMat = SCNMaterial()
        armBaseMat.diffuse.contents = NSColor(hex: 0x2D3748)
        armBaseMat.metalness.contents = 0.9
        armBaseGeo.materials = [armBaseMat]
        let armBaseNode = SCNNode(geometry: armBaseGeo)
        armBaseNode.position = SCNVector3(1.1, 0.1, -0.7)
        turntableRoot.addChildNode(armBaseNode)

        let armRodGeo = SCNCylinder(radius: 0.025, height: 1.4)
        let armRodMat = SCNMaterial()
        armRodMat.diffuse.contents = NSColor.lightGray
        armRodMat.metalness.contents = 0.9
        armRodGeo.materials = [armRodMat]
        let armRodNode = SCNNode(geometry: armRodGeo)
        armRodNode.position = SCNVector3(0.7, 0.22, -0.1)
        armRodNode.eulerAngles = SCNVector3(Float.pi / 2, 0.25, -0.45)
        turntableRoot.addChildNode(armRodNode)

        // Slow smooth rotation animation
        let rotateAction = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6.0))
        rotatingGroup.runAction(rotateAction)

        // Isometric Lighting
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 36
        cameraNode.position = SCNVector3(0, 3.8, 4.8)
        cameraNode.eulerAngles = SCNVector3(-0.68, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = NSColor(white: 0.35, alpha: 1.0)
        scene.rootNode.addChildNode(ambientLight)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = NSColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1.0)
        keyLight.light?.castsShadow = true
        keyLight.position = SCNVector3(3, 5, 4)
        keyLight.eulerAngles = SCNVector3(-0.7, 0.6, 0)
        scene.rootNode.addChildNode(keyLight)

        let cyanRim = SCNNode()
        cyanRim.light = SCNLight()
        cyanRim.light?.type = .omni
        cyanRim.light?.color = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8)
        cyanRim.position = SCNVector3(-3, 2, -2)
        scene.rootNode.addChildNode(cyanRim)
    }

    // Interactive mouse drag to rotate the model
    public override func mouseDown(with event: NSEvent) {
        lastDragLocation = convert(event.locationInWindow, from: nil)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let last = lastDragLocation, let root = rootTurntableNode else { return }
        let current = convert(event.locationInWindow, from: nil)
        let deltaX = CGFloat(current.x - last.x) * 0.015
        let deltaY = CGFloat(current.y - last.y) * 0.015
        root.eulerAngles.y += deltaX
        root.eulerAngles.x = max(-0.9, min(0.3, root.eulerAngles.x - deltaY))
        lastDragLocation = current
    }
}

// MARK: - Metallic Orb 3D Micro-Surface
public final class MetallicOrb3DView: NSView {
    private let scnView = SCNView()
    private var orbNode: SCNNode?

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupScene()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupScene() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.masksToBounds = true

        scnView.frame = bounds
        scnView.autoresizingMask = [.width, .height]
        scnView.backgroundColor = .clear
        addSubview(scnView)

        let scene = SCNScene()
        scnView.scene = scene

        let sphereGeo = SCNSphere(radius: 1.1)
        sphereGeo.segmentCount = 64
        let sphereMat = SCNMaterial()
        sphereMat.diffuse.contents = NSColor(hex: 0x111625)
        sphereMat.metalness.contents = 0.95
        sphereMat.roughness.contents = 0.12
        sphereGeo.materials = [sphereMat]

        let orb = SCNNode(geometry: sphereGeo)
        self.orbNode = orb
        scene.rootNode.addChildNode(orb)

        // Equator glowing groove
        let ringGeo = SCNTorus(ringRadius: 1.12, pipeRadius: 0.04)
        let ringMat = SCNMaterial()
        ringMat.diffuse.contents = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ringMat.emission.contents = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8)
        ringGeo.materials = [ringMat]
        let ringNode = SCNNode(geometry: ringGeo)
        ringNode.eulerAngles = SCNVector3(Float.pi / 4, Float.pi / 6, 0)
        orb.addChildNode(ringNode)

        orb.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0.2, y: 1.0, z: 0.3, duration: 8.0)))

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0, 3.8)
        scene.rootNode.addChildNode(camera)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = NSColor.white
        keyLight.position = SCNVector3(2, 3, 4)
        scene.rootNode.addChildNode(keyLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .omni
        rimLight.light?.color = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9)
        rimLight.position = SCNVector3(-3, -2, 2)
        scene.rootNode.addChildNode(rimLight)
    }
}

// MARK: - Audio Spectrogram Waveform View
public final class AudioSpectrogramView: NSView {
    private let style: MicroSurfaceKind.AudioStyle
    private var displayLinkTimer: Timer?
    private var phase: CGFloat = 0

    public init(style: MicroSurfaceKind.AudioStyle) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        startAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit { displayLinkTimer?.invalidate() }

    private func startAnimation() {
        displayLinkTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.phase += 0.08
            self.needsDisplay = true
        }
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let width = bounds.width
        let height = bounds.height
        let centerY = height * 0.5

        let barCount = 28
        let barWidth: CGFloat = max(2.0, (width - CGFloat(barCount - 1) * 2.0) / CGFloat(barCount))
        let spacing: CGFloat = 2.0

        for i in 0..<barCount {
            let norm = CGFloat(i) / CGFloat(barCount)
            let waveFactor = sin(norm * CGFloat.pi * 3.0 + phase) * cos(norm * CGFloat.pi + phase * 0.5)
            let baseAmplitude = sin(norm * CGFloat.pi) * 0.85
            let amplitude = max(0.12, abs(waveFactor * baseAmplitude))
            let barHeight = height * 0.75 * amplitude

            let x = CGFloat(i) * (barWidth + spacing)
            let rect = CGRect(x: x, y: centerY - barHeight * 0.5, width: barWidth, height: barHeight)

            // Gradient colors based on style
            let barColor: CGColor
            if style == .cyanMagenta {
                let ratio = norm
                barColor = NSColor(
                    red: (1.0 - ratio) * 0.0 + ratio * 1.0,
                    green: (1.0 - ratio) * 0.94 + ratio * 0.0,
                    blue: (1.0 - ratio) * 1.0 + ratio * 0.65,
                    alpha: 0.9
                ).cgColor
            } else {
                let ratio = norm
                barColor = NSColor(
                    red: (1.0 - ratio) * 1.0 + ratio * 0.47,
                    green: (1.0 - ratio) * 0.0 + ratio * 0.16,
                    blue: (1.0 - ratio) * 0.5 + ratio * 0.95,
                    alpha: 0.9
                ).cgColor
            }

            context.setFillColor(barColor)
            let path = CGPath(roundedRect: rect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
            context.addPath(path)
            context.fillPath()
        }
    }
}

// MARK: - Code Prism Micro-Surface
public final class CodePrismView: NSView {
    public init(snippet: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: 0x0D1117).withAlphaComponent(0.85).cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainer?.lineFragmentPadding = 4
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        let formatted = formatSyntax(snippet)
        textView.textStorage?.setAttributedString(formatted)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func formatSyntax(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
            .foregroundColor: NSColor(hex: 0xE2E8F0)
        ])

        let keywords = ["function", "const", "return", "type", "values", "color", "weight", "prism", "vector", "glyphs", "object"]
        for kw in keywords {
            var searchRange = NSRange(location: 0, length: (text as NSString).length)
            while searchRange.location < (text as NSString).length {
                let range = (text as NSString).range(of: kw, options: [], range: searchRange)
                if range.location != NSNotFound {
                    let color = kw == "function" || kw == "const" || kw == "return"
                        ? NSColor(hex: 0xFF7B72) // red/pink
                        : (kw == "prism" || kw == "vector" ? NSColor(hex: 0x79C0FF) : NSColor(hex: 0x7EE787))
                    result.addAttribute(.foregroundColor, value: color, range: range)
                    searchRange.location = range.location + range.length
                    searchRange.length = (text as NSString).length - searchRange.location
                } else { break }
            }
        }
        return result
    }
}

// MARK: - Vector Glyph Canvas Micro-Surface
public final class VectorGlyphView: NSView {
    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupGlyphs()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupGlyphs() {
        let symbols = ["textformat", "circle", "checkmark", "square", "wrench.and.screwdriver", "cube"]
        let grid = NSGridView(views: [
            [makeIcon(symbols[0]), makeIcon(symbols[1]), makeIcon(symbols[2])],
            [makeIcon(symbols[3]), makeIcon(symbols[4]), makeIcon(symbols[5])]
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)

        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func makeIcon(_ name: String) -> NSImageView {
        let iv = NSImageView()
        iv.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        iv.contentTintColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9)
        iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iv.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return iv
    }
}

// MARK: - Visual Node Graph Micro-Surface
public final class VisualNodeGraphView: NSView {
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let nodePositions: [(CGPoint, NSColor)] = [
            (CGPoint(x: 20, y: 55), NSColor(hex: 0x58A6FF)),
            (CGPoint(x: 45, y: 55), NSColor(hex: 0x7EE787)),
            (CGPoint(x: 70, y: 70), NSColor(hex: 0x58A6FF)),
            (CGPoint(x: 95, y: 70), NSColor(hex: 0xBC8CFF)),
            (CGPoint(x: 70, y: 40), NSColor(hex: 0x58A6FF)),
            (CGPoint(x: 95, y: 40), NSColor(hex: 0x7EE787)),
            (CGPoint(x: 70, y: 18), NSColor(hex: 0xBC8CFF))
        ]

        // Draw connections
        ctx.setLineWidth(1.2)
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.35).cgColor)
        let edges = [(0, 1), (1, 2), (2, 3), (1, 4), (4, 5), (1, 6)]
        for (a, b) in edges {
            ctx.move(to: nodePositions[a].0)
            ctx.addLine(to: nodePositions[b].0)
        }
        ctx.strokePath()

        // Draw nodes
        for (pt, col) in nodePositions {
            let rect = CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10)
            ctx.setFillColor(col.cgColor)
            let path = CGPath(roundedRect: rect, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }
}

// MARK: - Generic Glass File Node View
public final class GenericFileCardView: NSView {
    public init(title: String, subtitle: String, iconName: String, isFolder: Bool) {
        super.init(frame: .zero)
        wantsLayer = true

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: title)
        icon.contentTintColor = isFolder ? NSColor(hex: 0x38BDF8) : NSColor.white.withAlphaComponent(0.85)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(icon)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            icon.widthAnchor.constraint(equalToConstant: isFolder ? 36 : 30),
            icon.heightAnchor.constraint(equalToConstant: isFolder ? 32 : 36),

            titleLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Master Glass Card Container (Iridescent Rim & Frosted Fill)
public final class GlassCardContainer: NSView {
    public let node: SpatialCardNode
    private var borderGradientLayer = CAGradientLayer()
    private var shapeMask = CAShapeLayer()
    private var contentContainer = NSView()
    public var onDrag: ((CGPoint) -> Void)?
    private var dragStartOrigin: CGPoint?

    public init(node: SpatialCardNode) {
        self.node = node
        super.init(frame: NSRect(origin: node.position, size: node.size))
        setupGlassSurface()
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func updateLayer() {
        super.updateLayer()
        borderGradientLayer.frame = bounds
        shapeMask.path = CGPath(roundedRect: bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
    }

    public override func layout() {
        super.layout()
        borderGradientLayer.frame = bounds
        shapeMask.path = CGPath(roundedRect: bounds, cornerWidth: 14, cornerHeight: 14, transform: nil)
    }

    private func setupGlassSurface() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = false

        // Dark Frosted Glass Fill
        layer?.backgroundColor = NSColor(hex: 0x0A0F1D).withAlphaComponent(0.65).cgColor

        // Ambient Occlusion Drop Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowOffset = CGSize(width: 0, height: -6)
        layer?.shadowRadius = 16

        // Iridescent Specular Border Glow
        let borderLayer = CAShapeLayer()
        borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 14, cornerHeight: 14, transform: nil)
        borderLayer.strokeColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 0.75
        layer?.addSublayer(borderLayer)

        // Add Specific Micro-Surface Content
        contentContainer.frame = bounds
        contentContainer.autoresizingMask = [.width, .height]
        addSubview(contentContainer)

        switch node.kind {
        case .turntable3D:
            let turntable = Turntable3DView(frame: NSRect(x: 4, y: 28, width: bounds.width - 8, height: bounds.height - 34))
            turntable.autoresizingMask = [.width, .height]
            contentContainer.addSubview(turntable)
            addBottomLabel(node.title)

        case .metallicOrb3D:
            let orb = MetallicOrb3DView(frame: NSRect(x: 4, y: 28, width: bounds.width - 8, height: bounds.height - 34))
            orb.autoresizingMask = [.width, .height]
            contentContainer.addSubview(orb)
            addBottomLabel(node.title)

        case .audioSpectrogram(_, _, let style):
            let audio = AudioSpectrogramView(style: style)
            audio.frame = NSRect(x: 8, y: 26, width: bounds.width - 16, height: bounds.height - 34)
            audio.autoresizingMask = [.width, .height]
            contentContainer.addSubview(audio)
            addBottomLabel(node.title)

        case .codePrism(_, _, let snippet):
            let code = CodePrismView(snippet: snippet)
            code.frame = NSRect(x: 6, y: 24, width: bounds.width - 12, height: bounds.height - 30)
            code.autoresizingMask = [.width, .height]
            contentContainer.addSubview(code)
            addBottomLabel(node.title)

        case .vectorGlyphs:
            let glyphs = VectorGlyphView(frame: NSRect(x: 6, y: 24, width: bounds.width - 12, height: bounds.height - 30))
            glyphs.autoresizingMask = [.width, .height]
            contentContainer.addSubview(glyphs)
            addBottomLabel(node.title)

        case .visualNodeGraph:
            let graph = VisualNodeGraphView(frame: NSRect(x: 6, y: 24, width: bounds.width - 12, height: bounds.height - 30))
            graph.autoresizingMask = [.width, .height]
            contentContainer.addSubview(graph)
            addBottomLabel(node.title)

        case .videoAsset:
            let v = NSImageView(frame: NSRect(x: 6, y: 24, width: bounds.width - 12, height: bounds.height - 30))
            v.image = NSImage(systemSymbolName: "play.rectangle.fill", accessibilityDescription: nil)
            v.contentTintColor = NSColor.white.withAlphaComponent(0.8)
            contentContainer.addSubview(v)
            addBottomLabel(node.title)

        case .genericFile(let t, let sub, let icon, let isFolder):
            let fileView = GenericFileCardView(title: t, subtitle: sub, iconName: icon, isFolder: isFolder)
            fileView.frame = bounds
            fileView.autoresizingMask = [.width, .height]
            contentContainer.addSubview(fileView)
        }

        // Add Socket Port Dot on left/right for synaptic filaments
        let socket = NSView(frame: NSRect(x: bounds.width - 4, y: bounds.height / 2 - 4, width: 8, height: 8))
        socket.wantsLayer = true
        socket.layer?.cornerRadius = 4
        socket.layer?.backgroundColor = node.socketColor.cgColor
        socket.layer?.shadowColor = node.socketColor.cgColor
        socket.layer?.shadowOpacity = 0.9
        socket.layer?.shadowRadius = 4
        addSubview(socket)
    }

    private func addBottomLabel(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = NSColor(white: 0.92, alpha: 1.0)
        label.lineBreakMode = .byTruncatingMiddle
        label.alignment = .center
        label.frame = NSRect(x: 6, y: 4, width: bounds.width - 12, height: 18)
        label.autoresizingMask = [.width, .maxYMargin]
        addSubview(label)
    }

    // Interactive Dragging on Canvas
    public override func mouseDown(with event: NSEvent) {
        dragStartOrigin = frame.origin
        super.mouseDown(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        let newOrigin = CGPoint(x: frame.origin.x + event.deltaX, y: frame.origin.y - event.deltaY)
        frame.origin = newOrigin
        onDrag?(newOrigin)
    }
}

// Color helper
private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255,
                  alpha: 1.0)
    }
}

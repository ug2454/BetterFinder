import AppKit
import QuartzCore

public struct RibbonShortcutItem {
    public let title: String
    public let symbol: String
    public let url: URL?
    public let isDemo: Bool
}

// MARK: - Chrono-Ribbon Floating Dock (Real Places & Concept Presets)
public final class ChronoRibbonView: NSView {
    public var onSelectURL: ((URL) -> Void)?
    public var onSelectDemo: (() -> Void)?
    public var onSelectCluster: ((Int) -> Void)?

    private var selectedIndex: Int = 1
    private var itemButtons: [NSButton] = []
    private var shortcuts: [RibbonShortcutItem] = []
    private let borderLayer = CAShapeLayer()

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupShortcuts()
        setupRibbon()
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func layout() {
        super.layout()
        borderLayer.frame = bounds
        borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 24, cornerHeight: 24, transform: nil)
    }

    private func setupShortcuts() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsURL = FileManager.default.fileExists(atPath: home.appendingPathComponent("MyProjects").path)
            ? home.appendingPathComponent("MyProjects")
            : home.appendingPathComponent("Projects")

        shortcuts = [
            RibbonShortcutItem(title: "Home", symbol: "house.fill", url: home, isDemo: false),
            RibbonShortcutItem(title: "Projects", symbol: "hammer.fill", url: projectsURL, isDemo: false),
            RibbonShortcutItem(title: "Downloads", symbol: "arrow.down.circle.fill", url: home.appendingPathComponent("Downloads"), isDemo: false),
            RibbonShortcutItem(title: "Documents", symbol: "doc.text.fill", url: home.appendingPathComponent("Documents"), isDemo: false),
            RibbonShortcutItem(title: "Desktop", symbol: "display", url: home.appendingPathComponent("Desktop"), isDemo: false),
            RibbonShortcutItem(title: "Macintosh HD", symbol: "internaldrive.fill", url: URL(fileURLWithPath: "/"), isDemo: false),
            RibbonShortcutItem(title: "Cyberne ✦", symbol: "sparkles", url: nil, isDemo: true)
        ]
    }

    private func setupRibbon() {
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor(hex: 0x0A0F1D).withAlphaComponent(0.85).cgColor

        // Ambient Occlusion Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.5
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 14

        // Hairline Specular Border
        borderLayer.strokeColor = NSColor(white: 1.0, alpha: 0.2).cgColor
        borderLayer.fillColor = nil
        borderLayer.lineWidth = 0.75
        layer?.addSublayer(borderLayer)

        // Stack of shortcut buttons
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        for (i, item) in shortcuts.enumerated() {
            let tile = makeShortcutTile(index: i, item: item, isSelected: i == selectedIndex)
            itemButtons.append(tile)
            stack.addArrangedSubview(tile)
        }
    }

    private func makeShortcutTile(index: Int, item: RibbonShortcutItem, isSelected: Bool) -> NSButton {
        let btn = NSButton(title: "", target: nil, action: nil)
        btn.imagePosition = .noImage
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 10
        btn.layer?.masksToBounds = true
        btn.tag = index
        btn.target = self
        btn.action = #selector(tileClicked(_:))
        btn.toolTip = item.isDemo ? "Cyberne 2026 Concept Demo" : (item.url?.path ?? item.title)

        updateTileVisuals(btn, isSelected: isSelected)

        // Inner tile layout: Icon + Label
        let contentStack = NSStackView()
        contentStack.orientation = .horizontal
        contentStack.spacing = 6
        contentStack.alignment = .centerY
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(contentStack)

        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: item.title)
        icon.contentTintColor = item.isDemo
            ? NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 0.95)
            : (isSelected ? NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.95) : NSColor.white.withAlphaComponent(0.8))
        icon.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(icon)

        let label = NSTextField(labelWithString: item.title)
        label.font = .systemFont(ofSize: 10, weight: isSelected ? .semibold : .regular)
        label.textColor = isSelected ? .white : NSColor(white: 0.8, alpha: 1.0)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14)
        ])

        return btn
    }

    private func updateTileVisuals(_ btn: NSButton, isSelected: Bool) {
        if isSelected {
            btn.layer?.backgroundColor = NSColor(hex: 0x1E293B).withAlphaComponent(0.95).cgColor
            btn.layer?.borderWidth = 1.5
            btn.layer?.borderColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9).cgColor
            btn.layer?.shadowColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8).cgColor
            btn.layer?.shadowRadius = 8
            btn.layer?.shadowOpacity = 0.8
        } else {
            btn.layer?.backgroundColor = NSColor(hex: 0x0E1424).withAlphaComponent(0.7).cgColor
            btn.layer?.borderWidth = 0.5
            btn.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
            btn.layer?.shadowOpacity = 0
        }
    }

    public func highlightShortcut(for url: URL?) {
        guard let url else {
            // Check if demo
            for (idx, btn) in itemButtons.enumerated() {
                let selected = shortcuts[idx].isDemo
                updateTileVisuals(btn, isSelected: selected)
            }
            return
        }
        for (idx, btn) in itemButtons.enumerated() {
            let matches = shortcuts[idx].url?.standardizedFileURL.path == url.standardizedFileURL.path
            updateTileVisuals(btn, isSelected: matches)
        }
    }

    @objc private func tileClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < shortcuts.count else { return }
        selectedIndex = index

        for (idx, btn) in itemButtons.enumerated() {
            updateTileVisuals(btn, isSelected: idx == index)
        }

        let item = shortcuts[index]
        if item.isDemo {
            onSelectDemo?()
        } else if let url = item.url {
            onSelectURL?(url)
        }
        onSelectCluster?(index)
    }
}

// Mini preview graphic drawing glowing rings & miniature card rects
private final class MiniClusterPreview: NSView {
    let index: Int
    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // Mini aura ring
        ctx.setStrokeColor(NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokeEllipse(in: bounds.insetBy(dx: 8, dy: 6))

        // Secondary ring
        ctx.setStrokeColor(NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 0.5).cgColor)
        ctx.setLineWidth(0.8)
        ctx.strokeEllipse(in: bounds.insetBy(dx: 12, dy: 8))

        // Mini cards inside
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.75).cgColor)
        ctx.fill(CGRect(x: center.x - 12, y: center.y - 7, width: 9, height: 14))
        ctx.fill(CGRect(x: center.x + 3, y: center.y - 7, width: 9, height: 14))
    }
}

// MARK: - Chrono-Dial Rotary Scrub Widget (Image 2 Bottom-Right)
public final class ChronoDialView: NSView {
    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let radius: CGFloat = bounds.width * 0.95
        let center = CGPoint(x: bounds.maxX, y: bounds.minY)

        // Draw radial tick marks
        let tickCount = 36
        for i in 0..<tickCount {
            let angle = CGFloat.pi * 0.5 + (CGFloat(i) / CGFloat(tickCount)) * (CGFloat.pi * 0.5)
            let isMajor = i % 5 == 0
            let rInner = radius - (isMajor ? 24 : 14)
            let rOuter = radius - 4

            let p1 = CGPoint(x: center.x - cos(angle) * rInner, y: center.y + sin(angle) * rInner)
            let p2 = CGPoint(x: center.x - cos(angle) * rOuter, y: center.y + sin(angle) * rOuter)

            ctx.setStrokeColor(NSColor(white: 1.0, alpha: isMajor ? 0.65 : 0.3).cgColor)
            ctx.setLineWidth(isMajor ? 1.5 : 0.8)
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.strokePath()
        }

        // Frosted curved arc rim
        ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.4).cgColor)
        ctx.setLineWidth(2.0)
        let arcPath = CGMutablePath()
        arcPath.addArc(center: center, radius: radius, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 1.5, clockwise: false)
        ctx.addPath(arcPath)
        ctx.strokePath()
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

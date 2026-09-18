import AppKit
import QuartzCore

// MARK: - Chrono-Ribbon Floating Dock (Bottom Snapshot Carousel)
public final class ChronoRibbonView: NSView {
    public var onSelectCluster: ((Int) -> Void)?
    private var selectedIndex: Int = 3
    private var itemViews: [NSView] = []

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupRibbon()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupRibbon() {
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor(hex: 0x0A0F1D).withAlphaComponent(0.80).cgColor

        // Ambient Occlusion Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.5
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 14

        // Hairline Specular Border
        let border = CAShapeLayer()
        border.path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 24, cornerHeight: 24, transform: nil)
        border.strokeColor = NSColor(white: 1.0, alpha: 0.2).cgColor
        border.fillColor = nil
        border.lineWidth = 0.75
        layer?.addSublayer(border)

        // Stack of miniature cluster snapshot tiles
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])

        // 8 thumbnail tiles matching Image 1
        for i in 0..<8 {
            let tile = makeSnapshotTile(index: i, isSelected: i == selectedIndex)
            itemViews.append(tile)
            stack.addArrangedSubview(tile)
        }
    }

    private func makeSnapshotTile(index: Int, isSelected: Bool) -> NSView {
        let btn = NSButton(frame: .zero)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 10
        btn.layer?.masksToBounds = true
        btn.tag = index
        btn.target = self
        btn.action = #selector(tileClicked(_:))

        if isSelected {
            btn.layer?.backgroundColor = NSColor(hex: 0x1E293B).withAlphaComponent(0.9).cgColor
            btn.layer?.borderWidth = 1.5
            btn.layer?.borderColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9).cgColor
            btn.layer?.shadowColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8).cgColor
            btn.layer?.shadowRadius = 8
            btn.layer?.shadowOpacity = 0.8
        } else {
            btn.layer?.backgroundColor = NSColor(hex: 0x0E1424).withAlphaComponent(0.65).cgColor
            btn.layer?.borderWidth = 0.5
            btn.layer?.borderColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        }

        // Mini preview graphic inside tile
        let miniCanvas = MiniClusterPreview(index: index)
        miniCanvas.frame = NSRect(x: 4, y: 4, width: 44, height: 32)
        miniCanvas.autoresizingMask = [.width, .height]
        btn.addSubview(miniCanvas)

        return btn
    }

    @objc private func tileClicked(_ sender: NSButton) {
        selectedIndex = sender.tag
        onSelectCluster?(sender.tag)
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
        ctx.setStrokeColor(NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.6).cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: bounds.insetBy(dx: 6, dy: 6))

        // Mini cards
        let cardColor = NSColor(white: 1.0, alpha: 0.6).cgColor
        ctx.setFillColor(cardColor)
        ctx.fill(CGRect(x: center.x - 10, y: center.y - 6, width: 8, height: 12))
        ctx.fill(CGRect(x: center.x + 2, y: center.y - 6, width: 8, height: 12))
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

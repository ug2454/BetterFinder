import AppKit
import QuartzCore

// MARK: - Floating Dynamic Island Search & Lens HUD
public final class DynamicIslandHUD: NSView {
    public let searchField = NSTextField()
    public var onQueryChange: ((String) -> Void)?
    public var onFilterClick: (() -> Void)?
    public var onAddNode: (() -> Void)?
    public var onToggleViewMode: (() -> Void)?

    private let gradientBorderLayer = CAGradientLayer()
    private let shapeBorder = CAShapeLayer()

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setupHUD()
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func layout() {
        super.layout()
        gradientBorderLayer.frame = bounds
        shapeBorder.path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerWidth: bounds.height / 2, cornerHeight: bounds.height / 2, transform: nil)
    }

    private func setupHUD() {
        wantsLayer = true
        layer?.cornerRadius = 22
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor(hex: 0x080D1A).withAlphaComponent(0.82).cgColor

        // Ambient Drop Shadow
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.55
        layer?.shadowOffset = CGSize(width: 0, height: -4)
        layer?.shadowRadius = 18

        // Iridescent Specular Gradient Border (Cyan to Magenta to Violet)
        gradientBorderLayer.colors = [
            NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.85).cgColor,
            NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 0.85).cgColor,
            NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 0.85).cgColor
        ]
        gradientBorderLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientBorderLayer.endPoint = CGPoint(x: 1, y: 0.5)

        shapeBorder.fillColor = nil
        shapeBorder.strokeColor = NSColor.white.cgColor
        shapeBorder.lineWidth = 1.0
        gradientBorderLayer.mask = shapeBorder
        layer?.addSublayer(gradientBorderLayer)

        // Magnifying glass icon
        let searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchIcon)

        // Query field
        searchField.placeholderString = "Natural language semantic query lens for search"
        searchField.font = .systemFont(ofSize: 13, weight: .regular)
        searchField.textColor = .white
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.target = self
        searchField.action = #selector(queryChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        // Lens / Filter Button (Pill button with lines)
        let lensButton = makePillIconButton(symbol: "line.3.horizontal.decrease", help: "Filter Modalities", action: #selector(filterTapped))

        // Sliders Button
        let slidersButton = makeIconButton(symbol: "slider.horizontal.3", help: "Adjust Spatial Parameters", action: #selector(slidersTapped))

        // Add (+) Button
        let addButton = makeIconButton(symbol: "plus", help: "Add Spatial Node / Cluster", action: #selector(addTapped))

        let controlsStack = NSStackView(views: [lensButton, slidersButton, addButton])
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlsStack)

        NSLayoutConstraint.activate([
            searchIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            searchIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: controlsStack.leadingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            controlsStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func makeIconButton(symbol: String, help: String, action: Selector) -> NSButton {
        let btn = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: self, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        btn.toolTip = help
        btn.widthAnchor.constraint(equalToConstant: 24).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return btn
    }

    private func makePillIconButton(symbol: String, help: String, action: Selector) -> NSButton {
        let btn = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: self, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 12
        btn.layer?.backgroundColor = NSColor(hex: 0x1E293B).withAlphaComponent(0.85).cgColor
        btn.contentTintColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9)
        btn.toolTip = help
        btn.widthAnchor.constraint(equalToConstant: 32).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return btn
    }

    @objc private func queryChanged() {
        onQueryChange?(searchField.stringValue)
    }

    @objc private func filterTapped() {
        onFilterClick?()
    }

    @objc private func slidersTapped() {
        onToggleViewMode?()
    }

    @objc private func addTapped() {
        onAddNode?()
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

import AppKit
import QuartzCore

// MARK: - Floating Dynamic Island Search, Navigation & Lens HUD
public final class DynamicIslandHUD: NSView {
    public let searchField = NSTextField()
    private let folderButton = NSButton()
    private var backButton: NSButton!
    private var forwardButton: NSButton!
    private var upButton: NSButton!
    private var fdaButton: NSButton!

    public var onQueryChange: ((String) -> Void)?
    public var onFilterClick: (() -> Void)?
    public var onAddNode: (() -> Void)?
    public var onToggleViewMode: (() -> Void)?
    public var onGoBack: (() -> Void)?
    public var onGoForward: (() -> Void)?
    public var onGoUp: (() -> Void)?
    public var onChooseFolder: (() -> Void)?
    public var onFullDiskAccess: (() -> Void)?

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
        layer?.backgroundColor = NSColor(hex: 0x080D1A).withAlphaComponent(0.85).cgColor

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

        // Left Navigation Stack: Back, Forward, Up, Current Folder Pill
        backButton = makeIconButton(symbol: "chevron.left", help: "Back (⌘[)", action: #selector(backTapped))
        forwardButton = makeIconButton(symbol: "chevron.right", help: "Forward (⌘])", action: #selector(forwardTapped))
        upButton = makeIconButton(symbol: "arrow.up", help: "Parent Folder (⌘↑)", action: #selector(upTapped))

        folderButton.title = " Folder"
        folderButton.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "Choose Folder")
        folderButton.imagePosition = .imageLeft
        folderButton.bezelStyle = .regularSquare
        folderButton.isBordered = false
        folderButton.wantsLayer = true
        folderButton.layer?.cornerRadius = 11
        folderButton.layer?.backgroundColor = NSColor(hex: 0x1E293B).withAlphaComponent(0.8).cgColor
        folderButton.contentTintColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.95)
        folderButton.font = .systemFont(ofSize: 11, weight: .semibold)
        folderButton.toolTip = "Choose Folder…"
        folderButton.target = self
        folderButton.action = #selector(chooseFolderTapped)
        folderButton.translatesAutoresizingMaskIntoConstraints = false
        folderButton.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let navStack = NSStackView(views: [backButton, forwardButton, upButton, folderButton])
        navStack.orientation = .horizontal
        navStack.spacing = 6
        navStack.alignment = .centerY
        navStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(navStack)

        // Center Search Field
        let searchIcon = NSImageView()
        searchIcon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        searchIcon.contentTintColor = NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9)
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchIcon)

        searchField.placeholderString = "Filter files or semantic search…"
        searchField.font = .systemFont(ofSize: 12, weight: .regular)
        searchField.textColor = .white
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.target = self
        searchField.action = #selector(queryChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchField)

        // Right Controls: Full Disk Access Shield, Lens Filter, Folder Picker, View Mode Switcher
        fdaButton = makeIconButton(symbol: "lock.shield", help: "Full Disk Access Settings", action: #selector(fdaTapped))
        fdaButton.contentTintColor = NSColor(red: 1.0, green: 0.72, blue: 0.1, alpha: 0.95)

        let lensButton = makePillIconButton(symbol: "line.3.horizontal.decrease", help: "Filter Modalities", action: #selector(filterTapped))
        let folderPickerBtn = makeIconButton(symbol: "folder.badge.gearshape", help: "Choose Folder…", action: #selector(chooseFolderTapped))
        let classicViewButton = makeIconButton(symbol: "slider.horizontal.3", help: "Toggle Classic Details View (⌘2)", action: #selector(toggleViewTapped))

        let controlsStack = NSStackView(views: [fdaButton, lensButton, folderPickerBtn, classicViewButton])
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 8
        controlsStack.alignment = .centerY
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlsStack)

        NSLayoutConstraint.activate([
            navStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            navStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            searchIcon.leadingAnchor.constraint(equalTo: navStack.trailingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 14),
            searchIcon.heightAnchor.constraint(equalToConstant: 14),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: controlsStack.leadingAnchor, constant: -12),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: 22),

            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            controlsStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    public func setFolderTitle(_ name: String, fullPath: String) {
        folderButton.title = " \(name)"
        folderButton.toolTip = fullPath
    }

    public func setNavigationEnabled(canGoBack: Bool, canGoForward: Bool, canGoUp: Bool) {
        backButton.isEnabled = canGoBack
        backButton.alphaValue = canGoBack ? 1.0 : 0.35
        forwardButton.isEnabled = canGoForward
        forwardButton.alphaValue = canGoForward ? 1.0 : 0.35
        upButton.isEnabled = canGoUp
        upButton.alphaValue = canGoUp ? 1.0 : 0.35
    }

    private func makeIconButton(symbol: String, help: String, action: Selector) -> NSButton {
        let btn = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: self, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.contentTintColor = NSColor(white: 0.85, alpha: 1.0)
        btn.toolTip = help
        btn.widthAnchor.constraint(equalToConstant: 22).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }

    private func makePillIconButton(symbol: String, help: String, action: Selector) -> NSButton {
        let btn = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: help)!, target: self, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 11
        btn.layer?.backgroundColor = NSColor(hex: 0x1E293B).withAlphaComponent(0.85).cgColor
        btn.contentTintColor = NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.9)
        btn.toolTip = help
        btn.widthAnchor.constraint(equalToConstant: 30).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }

    public func setFullDiskAccessState(granted: Bool) {
        if granted {
            fdaButton.image = NSImage(systemSymbolName: "checkmark.shield.fill", accessibilityDescription: "Full Disk Access: Granted")
            fdaButton.contentTintColor = NSColor(red: 0.15, green: 0.95, blue: 0.55, alpha: 0.95)
            fdaButton.toolTip = "Full Disk Access: Granted & Active"
        } else {
            fdaButton.image = NSImage(systemSymbolName: "exclamationmark.shield.fill", accessibilityDescription: "Full Disk Access: Action Needed")
            fdaButton.contentTintColor = NSColor(red: 1.0, green: 0.72, blue: 0.1, alpha: 0.95)
            fdaButton.toolTip = "Full Disk Access: Click to enable access across folders"
        }
    }

    @objc private func backTapped() { onGoBack?() }
    @objc private func forwardTapped() { onGoForward?() }
    @objc private func upTapped() { onGoUp?() }
    @objc private func chooseFolderTapped() { onChooseFolder?() }
    @objc private func queryChanged() { onQueryChange?(searchField.stringValue) }
    @objc private func filterTapped() { onFilterClick?() }
    @objc private func toggleViewTapped() { onToggleViewMode?() }
    @objc private func addTapped() { onAddNode?() }
    @objc private func fdaTapped() { onFullDiskAccess?() }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                  green: CGFloat((hex >> 8) & 255) / 255,
                  blue: CGFloat(hex & 255) / 255,
                  alpha: 1.0)
    }
}

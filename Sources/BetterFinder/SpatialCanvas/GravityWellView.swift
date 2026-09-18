import AppKit
import QuartzCore

// MARK: - Organic Bioluminescent Gravity Well (Cluster Aura & Header)
public final class GravityWellView: NSView {
    public let cluster: SpatialCluster
    private var auraLayers: [CAShapeLayer] = []
    private var titleLabel: NSTextField!

    public init(cluster: SpatialCluster) {
        self.cluster = cluster
        super.init(frame: cluster.bounds)
        wantsLayer = true
        setupAura()
        setupHeader()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupAura() {
        // Multi-ring organic luminous nebulas
        let ringConfigs: [(scale: CGFloat, color: NSColor, width: CGFloat, rotation: CGFloat)] = [
            (1.0, cluster.auraPrimaryColor, 1.5, 0.0),
            (0.92, cluster.auraSecondaryColor, 1.2, 0.12),
            (1.08, cluster.auraPrimaryColor.withAlphaComponent(0.4), 1.0, -0.15),
            (0.85, cluster.auraSecondaryColor.withAlphaComponent(0.35), 0.75, 0.25)
        ]

        for config in ringConfigs {
            let shape = CAShapeLayer()
            shape.frame = bounds
            shape.fillColor = nil
            shape.strokeColor = config.color.cgColor
            shape.lineWidth = config.width
            shape.shadowColor = config.color.cgColor
            shape.shadowOpacity = 0.85
            shape.shadowRadius = 8.0
            shape.shadowOffset = .zero

            let ringBounds = bounds.insetBy(dx: 12 * (1.0 - config.scale), dy: 12 * (1.0 - config.scale))
            let path = CGMutablePath()
            path.addEllipse(in: ringBounds)
            shape.path = path

            // Subtle organic breathing animation
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.98
            pulse.toValue = 1.02
            pulse.duration = Double.random(in: 4.0...6.5)
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            shape.add(pulse, forKey: "pulse")

            layer?.addSublayer(shape)
            auraLayers.append(shape)
        }
    }

    private func setupHeader() {
        titleLabel = NSTextField(labelWithString: cluster.title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = NSColor(white: 0.96, alpha: 1.0)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4)
        ])
    }

    public func updateBounds(_ newBounds: CGRect) {
        frame = newBounds
        for (i, shape) in auraLayers.enumerated() {
            shape.frame = bounds
            let scale: CGFloat = 1.0 - CGFloat(i) * 0.06
            let ringBounds = bounds.insetBy(dx: 12 * (1.0 - scale), dy: 12 * (1.0 - scale))
            let path = CGMutablePath()
            path.addEllipse(in: ringBounds)
            shape.path = path
        }
    }
}

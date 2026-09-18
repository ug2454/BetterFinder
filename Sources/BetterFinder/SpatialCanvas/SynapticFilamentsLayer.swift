import AppKit
import QuartzCore

// MARK: - Synaptic Dependency Filaments (Optical Bezier Threads & Pulses)
public final class SynapticFilamentsView: NSView {
    private var filaments: [SynapticFilament] = []
    private var nodeCenters: [String: CGPoint] = [:]
    private var filamentLayers: [String: (glow: CAShapeLayer, line: CAShapeLayer, pulse: CALayer)] = [:]

    public override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    public func configure(filaments: [SynapticFilament], nodeCenters: [String: CGPoint]) {
        self.filaments = filaments
        self.nodeCenters = nodeCenters
        rebuildFilaments()
    }

    public func updateNodePosition(id: String, center: CGPoint) {
        nodeCenters[id] = center
        updateFilamentPaths()
    }

    private func rebuildFilaments() {
        filamentLayers.values.forEach {
            $0.glow.removeFromSuperlayer()
            $0.line.removeFromSuperlayer()
            $0.pulse.removeFromSuperlayer()
        }
        filamentLayers.removeAll()

        for fil in filaments {
            guard let fromPt = nodeCenters[fil.fromNodeId],
                  let toPt = nodeCenters[fil.toNodeId] else { continue }

            let path = makeBezierPath(from: fromPt, to: toPt)

            // Outer Gaussian Glow Layer
            let glow = CAShapeLayer()
            glow.path = path
            glow.fillColor = nil
            glow.strokeColor = fil.color.withAlphaComponent(0.4).cgColor
            glow.lineWidth = 4.5
            glow.shadowColor = fil.color.cgColor
            glow.shadowOpacity = 0.9
            glow.shadowRadius = 8.0
            layer?.addSublayer(glow)

            // Inner Core Optical Fiber Layer
            let line = CAShapeLayer()
            line.path = path
            line.fillColor = nil
            line.strokeColor = fil.color.withAlphaComponent(0.85).cgColor
            line.lineWidth = 1.6
            layer?.addSublayer(line)

            // Moving Data Pulse Particle
            let pulse = CALayer()
            pulse.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
            pulse.cornerRadius = 3
            pulse.backgroundColor = NSColor.white.cgColor
            pulse.shadowColor = fil.color.cgColor
            pulse.shadowOpacity = 1.0
            pulse.shadowRadius = 5
            layer?.addSublayer(pulse)

            let anim = CAKeyframeAnimation(keyPath: "position")
            anim.path = path
            anim.duration = Double.random(in: 2.8...4.2)
            anim.repeatCount = .infinity
            anim.calculationMode = .paced
            pulse.add(anim, forKey: "travel")

            filamentLayers[fil.id] = (glow, line, pulse)
        }
    }

    private func updateFilamentPaths() {
        for fil in filaments {
            guard let fromPt = nodeCenters[fil.fromNodeId],
                  let toPt = nodeCenters[fil.toNodeId],
                  let layers = filamentLayers[fil.id] else { continue }

            let path = makeBezierPath(from: fromPt, to: toPt)
            layers.glow.path = path
            layers.line.path = path
            if let anim = layers.pulse.animation(forKey: "travel") as? CAKeyframeAnimation {
                anim.path = path
                layers.pulse.removeAnimation(forKey: "travel")
                layers.pulse.add(anim, forKey: "travel")
            }
        }
    }

    private func makeBezierPath(from: CGPoint, to: CGPoint) -> CGPath {
        let path = CGMutablePath()
        path.move(to: from)

        let dx = to.x - from.x
        let dy = to.y - from.y
        let cp1 = CGPoint(x: from.x + dx * 0.5, y: from.y + dy * 0.1)
        let cp2 = CGPoint(x: from.x + dx * 0.5, y: to.y - dy * 0.1)

        path.addCurve(to: to, control1: cp1, control2: cp2)
        return path
    }
}

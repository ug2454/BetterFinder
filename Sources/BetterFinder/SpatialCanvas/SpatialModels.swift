import AppKit
import Foundation

public enum MicroSurfaceKind: Equatable {
    case turntable3D(title: String, subtitle: String)
    case metallicOrb3D(title: String, subtitle: String)
    case audioSpectrogram(title: String, subtitle: String, style: AudioStyle)
    case codePrism(title: String, subtitle: String, snippet: String)
    case visualNodeGraph(title: String, subtitle: String)
    case vectorGlyphs(title: String, subtitle: String)
    case videoAsset(title: String, subtitle: String)
    case genericFile(title: String, subtitle: String, iconName: String, isFolder: Bool)

    public enum AudioStyle {
        case cyanMagenta
        case pinkViolet
    }
}

public struct SpatialCardNode: Identifiable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var kind: MicroSurfaceKind
    public var position: CGPoint
    public var size: CGSize
    public var clusterId: String
    public var socketColor: NSColor

    public init(id: String, title: String, subtitle: String = "", kind: MicroSurfaceKind, position: CGPoint, size: CGSize, clusterId: String, socketColor: NSColor = .systemCyan) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.position = position
        self.size = size
        self.clusterId = clusterId
        self.socketColor = socketColor
    }
}

public struct SpatialCluster: Identifiable {
    public let id: String
    public var title: String
    public var subtitle: String
    public var center: CGPoint
    public var bounds: CGRect
    public var nodeIds: [String]
    public var auraPrimaryColor: NSColor
    public var auraSecondaryColor: NSColor

    public init(id: String, title: String, subtitle: String = "", center: CGPoint, bounds: CGRect, nodeIds: [String], auraPrimaryColor: NSColor, auraSecondaryColor: NSColor) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.center = center
        self.bounds = bounds
        self.nodeIds = nodeIds
        self.auraPrimaryColor = auraPrimaryColor
        self.auraSecondaryColor = auraSecondaryColor
    }
}

public struct SynapticFilament: Identifiable {
    public let id: String
    public var fromNodeId: String
    public var toNodeId: String
    public var color: NSColor
    public var controlPointOffset: CGPoint

    public init(id: String, fromNodeId: String, toNodeId: String, color: NSColor = .systemCyan, controlPointOffset: CGPoint = .zero) {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.color = color
        self.controlPointOffset = controlPointOffset
    }
}

public struct CanvasPreset {
    public static func makeDefaultClusters() -> (clusters: [SpatialCluster], nodes: [SpatialCardNode], filaments: [SynapticFilament]) {
        var nodes: [SpatialCardNode] = []
        var clusters: [SpatialCluster] = []
        var filaments: [SynapticFilament] = []

        // MARK: - Cluster 1: Active Launch: Project Cyberne (Top-Left)
        let c1Center = CGPoint(x: 320, y: 340)
        let c1 = SpatialCluster(
            id: "cluster-cyberne",
            title: "Active Launch: Project Cyberne",
            subtitle: "4 files · Synced",
            center: c1Center,
            bounds: CGRect(x: 120, y: 140, width: 390, height: 380),
            nodeIds: ["c1-turntable", "c1-cad-doc", "c1-assets", "c1-files", "c1-duration"],
            auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.7), // Cyan
            auraSecondaryColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 0.5) // Violet
        )
        clusters.append(c1)

        nodes.append(SpatialCardNode(
            id: "c1-turntable",
            title: "3D CAD turntable model rotating slowly",
            subtitle: "12.88 nits",
            kind: .turntable3D(title: "3D CAD turntable model rotating slowly", subtitle: "12.88 nits"),
            position: CGPoint(x: 160, y: 350),
            size: CGSize(width: 170, height: 160),
            clusterId: c1.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c1-cad-doc",
            title: "3D CAD turntable",
            subtitle: ".step · 24 MB",
            kind: .genericFile(title: "3D CAD turntable", subtitle: ".step", iconName: "cube.transparent", isFolder: false),
            position: CGPoint(x: 345, y: 350),
            size: CGSize(width: 100, height: 130),
            clusterId: c1.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c1-assets",
            title: "Assets",
            subtitle: "18 items",
            kind: .genericFile(title: "Assets", subtitle: "18 items", iconName: "doc.fill", isFolder: false),
            position: CGPoint(x: 210, y: 220),
            size: CGSize(width: 75, height: 95),
            clusterId: c1.id
        ))

        nodes.append(SpatialCardNode(
            id: "c1-files",
            title: "Files/iacs",
            subtitle: "Directory",
            kind: .genericFile(title: "Files/iacs", subtitle: "Folder", iconName: "folder.fill", isFolder: true),
            position: CGPoint(x: 295, y: 220),
            size: CGSize(width: 80, height: 95),
            clusterId: c1.id
        ))

        nodes.append(SpatialCardNode(
            id: "c1-duration",
            title: "Code duration",
            subtitle: "3.4s telemetry",
            kind: .genericFile(title: "Code duration", subtitle: "Telemetry", iconName: "doc.text.fill", isFolder: false),
            position: CGPoint(x: 330, y: 80),
            size: CGSize(width: 110, height: 115),
            clusterId: c1.id,
            socketColor: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 1.0)
        ))

        // MARK: - Cluster 2: Design System Lenses (Center)
        let c2Center = CGPoint(x: 720, y: 360)
        let c2 = SpatialCluster(
            id: "cluster-lenses",
            title: "Design System Lenses",
            subtitle: "Core visual & audio modalities",
            center: c2Center,
            bounds: CGRect(x: 570, y: 200, width: 310, height: 320),
            nodeIds: ["c2-audio1", "c2-audio2", "c2-vector", "c2-code"],
            auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.65),
            auraSecondaryColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 0.5) // Pink/Magenta
        )
        clusters.append(c2)

        nodes.append(SpatialCardNode(
            id: "c2-audio1",
            title: "Audio spectrogram",
            subtitle: "Spatial ambience",
            kind: .audioSpectrogram(title: "Audio spectrogram", subtitle: "78.9k ms", style: .cyanMagenta),
            position: CGPoint(x: 605, y: 390),
            size: CGSize(width: 110, height: 115),
            clusterId: c2.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c2-audio2",
            title: "Audio spectrogram",
            subtitle: "Stem analyzer",
            kind: .audioSpectrogram(title: "Audio spectrogram", subtitle: "Master mix", style: .pinkViolet),
            position: CGPoint(x: 725, y: 390),
            size: CGSize(width: 110, height: 115),
            clusterId: c2.id,
            socketColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c2-vector",
            title: "Vector glyph canvas",
            subtitle: "SVG tokens",
            kind: .vectorGlyphs(title: "Vector glyph canvas", subtitle: "Tokens"),
            position: CGPoint(x: 605, y: 265),
            size: CGSize(width: 110, height: 115),
            clusterId: c2.id
        ))

        nodes.append(SpatialCardNode(
            id: "c2-code",
            title: "Code prism",
            subtitle: "Syntax runtime",
            kind: .codePrism(title: "Code prism", subtitle: "SwiftUI/Metal", snippet: """
                <prism>
                  <vector glyphs>
                  return object
                </prism>
                """),
            position: CGPoint(x: 725, y: 265),
            size: CGSize(width: 110, height: 115),
            clusterId: c2.id,
            socketColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 1.0)
        ))

        // MARK: - Cluster 3: Neural Datasets (Top Right)
        let c3Center = CGPoint(x: 1060, y: 520)
        let c3 = SpatialCluster(
            id: "cluster-neural-top",
            title: "Neural Datasets",
            subtitle: "Embeddings & weights",
            center: c3Center,
            bounds: CGRect(x: 930, y: 430, width: 260, height: 210),
            nodeIds: ["c3-train", "c3-read"],
            auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.6),
            auraSecondaryColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 0.4)
        )
        clusters.append(c3)

        nodes.append(SpatialCardNode(
            id: "c3-train",
            title: "Train/init.net",
            subtitle: "Weights checkpoint",
            kind: .genericFile(title: "Train/init.net", subtitle: "2.4 GB", iconName: "photo.artframe", isFolder: false),
            position: CGPoint(x: 970, y: 460),
            size: CGSize(width: 85, height: 125),
            clusterId: c3.id
        ))

        nodes.append(SpatialCardNode(
            id: "c3-read",
            title: "Read/init.hot",
            subtitle: "Tensor stream",
            kind: .genericFile(title: "Read/init.hot", subtitle: "Tensor", iconName: "atom", isFolder: false),
            position: CGPoint(x: 1070, y: 460),
            size: CGSize(width: 85, height: 125),
            clusterId: c3.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        // MARK: - Cluster 4: Neural Datasets (Bottom Right)
        let c4Center = CGPoint(x: 1080, y: 220)
        let c4 = SpatialCluster(
            id: "cluster-neural-bottom",
            title: "Neural Datasets",
            subtitle: "Code prisms & syntax",
            center: c4Center,
            bounds: CGRect(x: 950, y: 110, width: 280, height: 230),
            nodeIds: ["c4-syntax", "c4-code"],
            auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.6),
            auraSecondaryColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 0.5)
        )
        clusters.append(c4)

        nodes.append(SpatialCardNode(
            id: "c4-syntax",
            title: "Syntax Datasets",
            subtitle: "JSON AST",
            kind: .codePrism(title: "Syntax Datasets", subtitle: "AST tokens", snippet: """
                function Function(
                  const data = {
                    embeddings: 30
                  }
                );
                """),
            position: CGPoint(x: 970, y: 130),
            size: CGSize(width: 100, height: 125),
            clusterId: c4.id
        ))

        nodes.append(SpatialCardNode(
            id: "c4-code",
            title: "Code prism",
            subtitle: "Color config",
            kind: .codePrism(title: "Code prism", subtitle: "Config", snippet: """
                price: {
                  values: 3;
                  color: 'neon';
                  weight: 700;
                }
                """),
            position: CGPoint(x: 1085, y: 130),
            size: CGSize(width: 100, height: 125),
            clusterId: c4.id,
            socketColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 1.0)
        ))

        // MARK: - Synaptic Filaments (Connections from Image 1 & Image 2)
        filaments.append(SynapticFilament(
            id: "f-c1-to-c2",
            fromNodeId: "c1-turntable",
            toNodeId: "c2-audio1",
            color: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.85)
        ))
        filaments.append(SynapticFilament(
            id: "f-c1-duration-to-c2",
            fromNodeId: "c1-duration",
            toNodeId: "c2-vector",
            color: NSColor(red: 0.0, green: 0.8, blue: 0.95, alpha: 0.75)
        ))
        filaments.append(SynapticFilament(
            id: "f-c2-to-c3",
            fromNodeId: "c2-audio2",
            toNodeId: "c3-train",
            color: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.8)
        ))
        filaments.append(SynapticFilament(
            id: "f-c2-to-c4",
            fromNodeId: "c2-code",
            toNodeId: "c4-syntax",
            color: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8)
        ))
        filaments.append(SynapticFilament(
            id: "f-c1-to-c1-duration",
            fromNodeId: "c1-assets",
            toNodeId: "c1-duration",
            color: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.6)
        ))

        return (clusters, nodes, filaments)
    }

    public static func makeFocusedPreset() -> (clusters: [SpatialCluster], nodes: [SpatialCardNode], filaments: [SynapticFilament]) {
        var nodes: [SpatialCardNode] = []
        var clusters: [SpatialCluster] = []
        var filaments: [SynapticFilament] = []

        let cFocused = SpatialCluster(
            id: "cluster-focused",
            title: "",
            subtitle: "",
            center: CGPoint(x: 600, y: 400),
            bounds: CGRect(x: 200, y: 150, width: 850, height: 600),
            nodeIds: ["f-3d", "f-audio", "f-node", "f-video"],
            auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.5),
            auraSecondaryColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 0.4)
        )
        clusters.append(cFocused)

        nodes.append(SpatialCardNode(
            id: "f-3d",
            title: "Interactive 3D render",
            subtitle: "12.88 nits",
            kind: .metallicOrb3D(title: "Interactive 3D render", subtitle: "12.88 nits"),
            position: CGPoint(x: 270, y: 480),
            size: CGSize(width: 280, height: 195),
            clusterId: cFocused.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "f-audio",
            title: "Audio asset",
            subtitle: "78.9K mis",
            kind: .audioSpectrogram(title: "Audio asset", subtitle: "78.9K mis", style: .pinkViolet),
            position: CGPoint(x: 690, y: 480),
            size: CGSize(width: 280, height: 195),
            clusterId: cFocused.id,
            socketColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "f-node",
            title: "Visual Node Graph",
            subtitle: "19.86 nits",
            kind: .visualNodeGraph(title: "Visual Node Graph", subtitle: "19.86 nits"),
            position: CGPoint(x: 340, y: 220),
            size: CGSize(width: 260, height: 185),
            clusterId: cFocused.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "f-video",
            title: "High-resolution Video",
            subtitle: "10.4K Inits",
            kind: .videoAsset(title: "High-resolution Video", subtitle: "10.4K Inits"),
            position: CGPoint(x: 690, y: 220),
            size: CGSize(width: 280, height: 185),
            clusterId: cFocused.id,
            socketColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 1.0)
        ))

        filaments.append(SynapticFilament(
            id: "f-3d-to-audio",
            fromNodeId: "f-3d",
            toNodeId: "f-audio",
            color: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.85)
        ))
        filaments.append(SynapticFilament(
            id: "f-3d-to-node",
            fromNodeId: "f-3d",
            toNodeId: "f-node",
            color: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.8)
        ))
        filaments.append(SynapticFilament(
            id: "f-node-to-audio",
            fromNodeId: "f-node",
            toNodeId: "f-audio",
            color: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.8)
        ))
        filaments.append(SynapticFilament(
            id: "f-node-to-video",
            fromNodeId: "f-node",
            toNodeId: "f-video",
            color: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.85)
        ))

        return (clusters, nodes, filaments)
    }
}

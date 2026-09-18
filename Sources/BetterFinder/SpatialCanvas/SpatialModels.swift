import AppKit
import Foundation
import DirectoryCore

public enum MicroSurfaceKind: Equatable {
    case turntable3D(title: String, subtitle: String)
    case metallicOrb3D(title: String, subtitle: String)
    case audioSpectrogram(title: String, subtitle: String, style: AudioStyle)
    case codePrism(title: String, subtitle: String, snippet: String)
    case visualNodeGraph(title: String, subtitle: String)
    case vectorGlyphs(title: String, subtitle: String)
    case videoAsset(title: String, subtitle: String)
    case genericFile(title: String, subtitle: String, iconName: String, isFolder: Bool)

    // Real filesystem micro-surface modalities
    case realFolder(title: String, subtitle: String, folderURL: URL, itemCount: Int?)
    case realCode(title: String, subtitle: String, fileURL: URL, snippet: String, language: String)
    case realImage(title: String, subtitle: String, imageURL: URL)
    case realAudio(title: String, subtitle: String, fileURL: URL, style: AudioStyle)
    case real3D(title: String, subtitle: String, fileURL: URL)
    case realFile(title: String, subtitle: String, fileURL: URL, icon: NSImage, sizeStr: String)

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
    public var url: URL?
    public var fileEntry: FileEntry?
    public var isSelected: Bool

    public init(
        id: String,
        title: String,
        subtitle: String = "",
        kind: MicroSurfaceKind,
        position: CGPoint,
        size: CGSize,
        clusterId: String,
        socketColor: NSColor = .systemCyan,
        url: URL? = nil,
        fileEntry: FileEntry? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.position = position
        self.size = size
        self.clusterId = clusterId
        self.socketColor = socketColor
        self.url = url
        self.fileEntry = fileEntry
        self.isSelected = isSelected
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
            size: CGSize(width: 115, height: 130),
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
        let c2Center = CGPoint(x: 725, y: 360)
        let c2 = SpatialCluster(
            id: "cluster-lenses",
            title: "Design System Lenses",
            subtitle: "Core visual & audio modalities",
            center: c2Center,
            bounds: CGRect(x: 565, y: 200, width: 325, height: 320),
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
            position: CGPoint(x: 595, y: 390),
            size: CGSize(width: 125, height: 115),
            clusterId: c2.id,
            socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c2-audio2",
            title: "Audio spectrogram",
            subtitle: "Stem analyzer",
            kind: .audioSpectrogram(title: "Audio spectrogram", subtitle: "Master mix", style: .pinkViolet),
            position: CGPoint(x: 735, y: 390),
            size: CGSize(width: 125, height: 115),
            clusterId: c2.id,
            socketColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 1.0)
        ))

        nodes.append(SpatialCardNode(
            id: "c2-vector",
            title: "Vector glyph canvas",
            subtitle: "SVG tokens",
            kind: .vectorGlyphs(title: "Vector glyph canvas", subtitle: "Tokens"),
            position: CGPoint(x: 595, y: 265),
            size: CGSize(width: 125, height: 115),
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
            position: CGPoint(x: 735, y: 265),
            size: CGSize(width: 125, height: 115),
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

    // MARK: - Dynamic Real Filesystem Cluster Generator
    public static func makeClusters(from entries: [FileEntry], parentURL: URL) -> (clusters: [SpatialCluster], nodes: [SpatialCardNode], filaments: [SynapticFilament]) {
        var clusters: [SpatialCluster] = []
        var nodes: [SpatialCardNode] = []
        var filaments: [SynapticFilament] = []

        if entries.isEmpty {
            let isAccessIssue = !FullDiskAccessHelper.isGranted
            let emptyCluster = SpatialCluster(
                id: "cluster-empty",
                title: parentURL.lastPathComponent,
                subtitle: isAccessIssue ? "Full Disk Access Recommended" : "Empty directory",
                center: CGPoint(x: 600, y: 400),
                bounds: CGRect(x: 350, y: 220, width: 500, height: 360),
                nodeIds: ["node-empty"],
                auraPrimaryColor: isAccessIssue ? NSColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.7) : NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.6),
                auraSecondaryColor: isAccessIssue ? NSColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.5) : NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.4)
            )
            let emptyNode = SpatialCardNode(
                id: "node-empty",
                title: isAccessIssue ? "Full Disk Access Required" : "Folder is Empty",
                subtitle: isAccessIssue ? "Click shield icon in top HUD to grant access" : parentURL.path,
                kind: .genericFile(
                    title: isAccessIssue ? "Full Disk Access Required" : "Folder is Empty",
                    subtitle: isAccessIssue ? "Click shield icon in top HUD to grant access" : parentURL.path,
                    iconName: isAccessIssue ? "lock.shield.fill" : "folder.badge.questionmark",
                    isFolder: true
                ),
                position: CGPoint(x: 480, y: 340),
                size: CGSize(width: 240, height: 130),
                clusterId: emptyCluster.id,
                url: parentURL
            )
            return ([emptyCluster], [emptyNode], [])
        }

        // Categorize entries
        let codeExtensions: Set<String> = [
            "swift", "py", "js", "ts", "jsx", "tsx", "json", "yml", "yaml", "toml",
            "sh", "bash", "zsh", "c", "cpp", "h", "hpp", "rs", "go", "html", "css",
            "scss", "sql", "rb", "php", "java", "kt", "xml", "plist", "lock", "env", "proto"
        ]
        let mediaExtensions: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "svg", "icns", "heic", "tiff", "bmp",
            "mp3", "wav", "m4a", "flac", "aac", "ogg", "aif", "aiff",
            "usdz", "obj", "dae", "stl", "gltf", "glb", "step",
            "mov", "mp4", "m4v"
        ]

        var folderEntries: [FileEntry] = []
        var codeEntries: [FileEntry] = []
        var mediaEntries: [FileEntry] = []
        var docEntries: [FileEntry] = []

        for entry in entries {
            if entry.canBrowse {
                folderEntries.append(entry)
            } else {
                let ext = entry.url.pathExtension.lowercased()
                if codeExtensions.contains(ext) {
                    codeEntries.append(entry)
                } else if mediaExtensions.contains(ext) {
                    mediaEntries.append(entry)
                } else {
                    docEntries.append(entry)
                }
            }
        }

        struct CategoryDef {
            let id: String
            let title: String
            let subtitle: String
            let entries: [FileEntry]
            let auraPrimaryColor: NSColor
            let auraSecondaryColor: NSColor
            let socketColor: NSColor
        }

        var activeCategories: [CategoryDef] = []
        if !folderEntries.isEmpty {
            activeCategories.append(CategoryDef(
                id: "cluster-folders",
                title: "Directories & Workspaces",
                subtitle: "\(folderEntries.count) subfolders",
                entries: folderEntries,
                auraPrimaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.75),
                auraSecondaryColor: NSColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 0.5),
                socketColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 1.0)
            ))
        }
        if !codeEntries.isEmpty {
            activeCategories.append(CategoryDef(
                id: "cluster-code",
                title: "Code & Architecture",
                subtitle: "\(codeEntries.count) source files",
                entries: codeEntries,
                auraPrimaryColor: NSColor(red: 0.47, green: 0.16, blue: 0.79, alpha: 0.75),
                auraSecondaryColor: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.55),
                socketColor: NSColor(red: 0.74, green: 0.0, blue: 1.0, alpha: 1.0)
            ))
        }
        if !mediaEntries.isEmpty {
            activeCategories.append(CategoryDef(
                id: "cluster-media",
                title: "Media & Assets",
                subtitle: "\(mediaEntries.count) visual & audio assets",
                entries: mediaEntries,
                auraPrimaryColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 0.75),
                auraSecondaryColor: NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.5),
                socketColor: NSColor(red: 1.0, green: 0.0, blue: 0.48, alpha: 1.0)
            ))
        }
        if !docEntries.isEmpty {
            activeCategories.append(CategoryDef(
                id: "cluster-docs",
                title: "Documents & Data",
                subtitle: "\(docEntries.count) items",
                entries: docEntries,
                auraPrimaryColor: NSColor(red: 0.0, green: 0.44, blue: 0.95, alpha: 0.7),
                auraSecondaryColor: NSColor(red: 0.5, green: 0.0, blue: 0.9, alpha: 0.45),
                socketColor: NSColor(red: 0.0, green: 0.44, blue: 0.95, alpha: 1.0)
            ))
        }

        // Compute Cluster Base Centers in 2.5D space
        let clusterOrigins: [CGPoint]
        switch activeCategories.count {
        case 1:
            clusterOrigins = [CGPoint(x: 650, y: 460)]
        case 2:
            clusterOrigins = [CGPoint(x: 420, y: 460), CGPoint(x: 1080, y: 460)]
        case 3:
            clusterOrigins = [CGPoint(x: 360, y: 560), CGPoint(x: 1040, y: 560), CGPoint(x: 700, y: 220)]
        default:
            clusterOrigins = [
                CGPoint(x: 360, y: 640),
                CGPoint(x: 1080, y: 640),
                CGPoint(x: 360, y: 220),
                CGPoint(x: 1080, y: 220)
            ]
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        for (catIndex, cat) in activeCategories.enumerated() {
            let baseCenter = catIndex < clusterOrigins.count ? clusterOrigins[catIndex] : CGPoint(x: 700 + CGFloat(catIndex * 400), y: 400)
            var catNodeIds: [String] = []
            var catNodePositions: [CGPoint] = []
            var catNodeSizes: [CGSize] = []

            // Limit displayed cards per cluster to 12 for clean aesthetics and performance
            let maxItems = min(12, cat.entries.count)
            let itemsToDisplay = Array(cat.entries.prefix(maxItems))

            // Layout in columns
            let columns = min(3, max(2, Int(ceil(sqrt(Double(maxItems))))))
            let cardW: CGFloat = cat.id == "cluster-code" ? 175 : (cat.id == "cluster-media" ? 160 : 135)
            let cardH: CGFloat = cat.id == "cluster-code" ? 135 : (cat.id == "cluster-media" ? 130 : 105)
            let spacingX: CGFloat = 20
            let spacingY: CGFloat = 20

            let totalW = CGFloat(columns) * cardW + CGFloat(columns - 1) * spacingX
            let rows = Int(ceil(Double(itemsToDisplay.count) / Double(columns)))
            let totalH = CGFloat(rows) * cardH + CGFloat(rows - 1) * spacingY

            let startX = baseCenter.x - totalW / 2
            let startY = baseCenter.y + totalH / 2 - cardH

            for (idx, entry) in itemsToDisplay.enumerated() {
                let col = idx % columns
                let row = idx / columns
                let posX = startX + CGFloat(col) * (cardW + spacingX)
                let posY = startY - CGFloat(row) * (cardH + spacingY)
                let pos = CGPoint(x: posX, y: posY)
                let size = CGSize(width: cardW, height: cardH)

                let nodeId = "\(cat.id)-\(idx)"
                catNodeIds.append(nodeId)
                catNodePositions.append(pos)
                catNodeSizes.append(size)

                let ext = entry.url.pathExtension.lowercased()
                let kind: MicroSurfaceKind

                if entry.canBrowse {
                    kind = .realFolder(title: entry.name, subtitle: "Folder", folderURL: entry.url, itemCount: nil)
                } else if codeExtensions.contains(ext) {
                    let snippet = readCodeSnippet(from: entry.url, maxLines: 7)
                    kind = .realCode(title: entry.name, subtitle: ext.uppercased(), fileURL: entry.url, snippet: snippet, language: ext)
                } else if ["png", "jpg", "jpeg", "gif", "webp", "svg", "icns", "heic", "tiff"].contains(ext) {
                    kind = .realImage(title: entry.name, subtitle: formatter.string(fromByteCount: entry.size), imageURL: entry.url)
                } else if ["mp3", "wav", "m4a", "flac", "aac", "ogg", "aif", "aiff"].contains(ext) {
                    kind = .realAudio(title: entry.name, subtitle: formatter.string(fromByteCount: entry.size), fileURL: entry.url, style: idx % 2 == 0 ? .cyanMagenta : .pinkViolet)
                } else if ["usdz", "obj", "dae", "stl", "gltf", "glb", "step"].contains(ext) {
                    kind = .real3D(title: entry.name, subtitle: ext.uppercased(), fileURL: entry.url)
                } else {
                    let icon = NSWorkspace.shared.icon(forFile: entry.url.path)
                    let sizeStr = formatter.string(fromByteCount: entry.size)
                    kind = .realFile(title: entry.name, subtitle: sizeStr, fileURL: entry.url, icon: icon, sizeStr: sizeStr)
                }

                let cardNode = SpatialCardNode(
                    id: nodeId,
                    title: entry.name,
                    subtitle: entry.canBrowse ? "Folder" : formatter.string(fromByteCount: entry.size),
                    kind: kind,
                    position: pos,
                    size: size,
                    clusterId: cat.id,
                    socketColor: cat.socketColor,
                    url: entry.url,
                    fileEntry: entry,
                    isSelected: false
                )
                nodes.append(cardNode)
            }

            // Compute cluster bounds
            let minX = (catNodePositions.map { $0.x }.min() ?? baseCenter.x) - 45
            let maxX = (catNodePositions.enumerated().map { $0.element.x + catNodeSizes[$0.offset].width }.max() ?? (baseCenter.x + 100)) + 45
            let minY = (catNodePositions.map { $0.y }.min() ?? baseCenter.y) - 45
            let maxY = (catNodePositions.enumerated().map { $0.element.y + catNodeSizes[$0.offset].height }.max() ?? (baseCenter.y + 100)) + 55

            let clusterBounds = CGRect(x: minX, y: minY, width: max(260, maxX - minX), height: max(200, maxY - minY))
            let clusterCenter = CGPoint(x: clusterBounds.midX, y: clusterBounds.midY)

            let cluster = SpatialCluster(
                id: cat.id,
                title: cat.title,
                subtitle: cat.subtitle,
                center: clusterCenter,
                bounds: clusterBounds,
                nodeIds: catNodeIds,
                auraPrimaryColor: cat.auraPrimaryColor,
                auraSecondaryColor: cat.auraSecondaryColor
            )
            clusters.append(cluster)
        }

        // Generate dynamic synaptic filaments between primary nodes across clusters
        if clusters.count >= 2 {
            for i in 0..<(clusters.count - 1) {
                if let fromId = clusters[i].nodeIds.first, let toId = clusters[i + 1].nodeIds.first {
                    filaments.append(SynapticFilament(
                        id: "fil-\(i)-\(i+1)",
                        fromNodeId: fromId,
                        toNodeId: toId,
                        color: NSColor(red: 0.0, green: 0.94, blue: 1.0, alpha: 0.75),
                        controlPointOffset: CGPoint(x: 0, y: -30)
                    ))
                }
            }
        }

        // Add intra-cluster filaments if multiple items exist
        for cluster in clusters {
            if cluster.nodeIds.count >= 3 {
                filaments.append(SynapticFilament(
                    id: "intra-\(cluster.id)",
                    fromNodeId: cluster.nodeIds[0],
                    toNodeId: cluster.nodeIds[1],
                    color: cluster.auraPrimaryColor.withAlphaComponent(0.65),
                    controlPointOffset: CGPoint(x: 15, y: 15)
                ))
            }
        }

        return (clusters, nodes, filaments)
    }

    private static func readCodeSnippet(from url: URL, maxLines: Int = 8) -> String {
        guard let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return "// Empty file" }
        let chunk = data.prefix(1500)
        guard let str = String(data: chunk, encoding: .utf8) ?? String(data: chunk, encoding: .ascii) else {
            return "// Binary file"
        }
        let lines = str.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.isEmpty { return "// Empty file" }
        return lines.prefix(maxLines).joined(separator: "\n")
    }
}

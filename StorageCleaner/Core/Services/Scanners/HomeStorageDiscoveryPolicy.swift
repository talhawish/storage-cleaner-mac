import Foundation

struct HomeStorageDiscoveryPolicy: Sendable {
    let root: URL
    let excludedFolderRoots: [URL]
    let excludedModelRoots: [URL]
    let minimumFolderBytes: Int64
    let minimumModelBytes: Int64
    let maximumFolderCandidates: Int
    let maximumModelCandidates: Int

    /// Shared routing rule: Large Files must only defer a file to AI Models
    /// when it lies inside the model scanner's traversal coverage.
    func includesModelLocation(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/"),
              !excludedModelRoots.contains(where: {
                  let excluded = $0.standardizedFileURL.path
                  return path == excluded || path.hasPrefix(excluded + "/")
              }) else { return false }
        let relative = path.dropFirst(rootPath.count + 1).split(separator: "/").dropLast()
        return !relative.contains { component in
            let name = String(component)
            return Self.generatedDirectoryNames.contains(name)
                || Self.packageExtensions.contains(URL(fileURLWithPath: name).pathExtension.lowercased())
        }
    }

    static let generatedDirectoryNames: Set<String> = [
        ".build", ".git", ".gradle", ".swiftpm", ".venv", "build", "node_modules",
        "Pods", "vendor", "venv"
    ]

    private static let packageExtensions: Set<String> = ["app", "bundle", "framework", "mlpackage", "mlmodelc"]

    static var live: HomeStorageDiscoveryPolicy {
        HomeStorageDiscoveryPolicy(
            root: UserHomeDirectory.url,
            excludedFolderRoots: DependencyPaths.StorageInventory.excludedFolderRoots,
            excludedModelRoots: DependencyPaths.StorageInventory.excludedModelRoots,
            minimumFolderBytes: HomeStorageDiscoveryThresholds.minimumFolderBytes,
            minimumModelBytes: LargeFileThreshold.collectionFloor.bytes,
            maximumFolderCandidates: HomeStorageDiscoveryThresholds.maximumFolderCandidates,
            maximumModelCandidates: HomeStorageDiscoveryThresholds.maximumModelCandidates
        )
    }
}

enum HomeStorageDiscoveryThresholds {
    static let minimumFolderBytes: Int64 = 1_073_741_824
    static let minimumAmbiguousBinaryModelBytes: Int64 = 1_073_741_824
    static let maximumFolderCandidates = 500
    static let maximumModelCandidates = 2_000
}

enum LocalAIModelFormat: String, CaseIterable, Sendable {
    case gguf
    case ggml
    case safetensors
    case onnx
    case tflite
    case pytorchScript = "pt"
    case pth
    case checkpoint = "ckpt"
    case protocolBuffer = "pb"
    case mlmodel
    case mlpackage
    case mlmodelc
    case bin

    private static let ambiguousFormatPathTokens: Set<String> = [
        "model", "models", "weight", "weights", "checkpoint", "checkpoints"
    ]

    var isBundle: Bool {
        self == .mlpackage || self == .mlmodelc
    }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }

    func minimumBytes(defaultMinimum: Int64) -> Int64 {
        guard self == .bin else { return defaultMinimum }
        return max(defaultMinimum, HomeStorageDiscoveryThresholds.minimumAmbiguousBinaryModelBytes)
    }

    func isLikelyModel(at url: URL, bytes: Int64, defaultMinimum: Int64) -> Bool {
        guard bytes >= minimumBytes(defaultMinimum: defaultMinimum) else { return false }
        guard self == .bin || self == .protocolBuffer else { return true }
        return Self.hasModelPathContext(url)
    }

    private static func hasModelPathContext(_ url: URL) -> Bool {
        url.pathComponents.contains { component in
            let tokens = component.lowercased().split { !$0.isLetter && !$0.isNumber }
            return !ambiguousFormatPathTokens.isDisjoint(with: tokens.map(String.init))
        }
    }
}

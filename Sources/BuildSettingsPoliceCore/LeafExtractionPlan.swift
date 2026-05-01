public struct LeafExtractionPlan: Sendable, Equatable {
    public let targetName: String
    public let configurationName: String
    public let xcconfigFilename: String
    public let outputDirectory: String
    public let xcconfigContents: String
    public let extractedSettingKeys: [String]

    public init(
        targetName: String,
        configurationName: String,
        xcconfigFilename: String,
        outputDirectory: String,
        xcconfigContents: String,
        extractedSettingKeys: [String]
    ) {
        self.targetName = targetName
        self.configurationName = configurationName
        self.xcconfigFilename = xcconfigFilename
        self.outputDirectory = outputDirectory
        self.xcconfigContents = xcconfigContents
        self.extractedSettingKeys = extractedSettingKeys
    }

    public var xcconfigRelativePath: String {
        outputDirectory.isEmpty ? xcconfigFilename : "\(outputDirectory)/\(xcconfigFilename)"
    }
}

public enum LeafExtractionError: Error, Equatable, CustomStringConvertible {
    case targetNotFound(name: String)
    case configurationNotFound(target: String, configuration: String)
    case configurationAlreadyHasBaseConfiguration(target: String, configuration: String, existing: String)
    case nothingToExtract(target: String, configuration: String)

    public var description: String {
        switch self {
        case .targetNotFound(let name):
            "Target '\(name)' not found in project."
        case .configurationNotFound(let target, let configuration):
            "Configuration '\(configuration)' not found on target '\(target)'."
        case .configurationAlreadyHasBaseConfiguration(let target, let configuration, let existing):
            "Target '\(target)' configuration '\(configuration)' already has an xcconfig attached: \(existing). Resolve this manually before extracting."
        case .nothingToExtract(let target, let configuration):
            "Target '\(target)' configuration '\(configuration)' has no inline build settings to extract."
        }
    }
}

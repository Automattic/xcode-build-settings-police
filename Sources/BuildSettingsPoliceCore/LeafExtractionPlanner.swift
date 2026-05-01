import XCConfigKit
import XcodeProj

public struct LeafExtractionPlanner: Sendable {
    public init() {}

    public func plan(
        projectPath: String,
        targetName: String,
        configurationName: String,
        outputDirectory: String
    ) throws -> LeafExtractionPlan {
        let xcodeProj = try XcodeProj(pathString: projectPath)
        return try plan(
            xcodeProj: xcodeProj,
            targetName: targetName,
            configurationName: configurationName,
            outputDirectory: outputDirectory
        )
    }

    public func plan(
        xcodeProj: XcodeProj,
        targetName: String,
        configurationName: String,
        outputDirectory: String
    ) throws -> LeafExtractionPlan {
        guard let target = xcodeProj.pbxproj.rootObject?.targets.first(where: { $0.name == targetName }) else {
            throw LeafExtractionError.targetNotFound(name: targetName)
        }

        guard let configuration = target.buildConfigurationList?
            .buildConfigurations
            .first(where: { $0.name == configurationName })
        else {
            throw LeafExtractionError.configurationNotFound(
                target: targetName,
                configuration: configurationName
            )
        }

        if let existing = configuration.baseConfiguration?.path {
            throw LeafExtractionError.configurationAlreadyHasBaseConfiguration(
                target: targetName,
                configuration: configurationName,
                existing: existing
            )
        }

        if configuration.buildSettings.isEmpty {
            throw LeafExtractionError.nothingToExtract(
                target: targetName,
                configuration: configurationName
            )
        }

        let xcconfigFile = XCConfigFile(
            settings: configuration.buildSettings.mapValues(toXCConfigValue)
        )
        let contents = XCConfigSerializer().serialize(xcconfigFile)

        let stem = TargetFilenameNormalizer().normalizedFilenameStem(for: targetName)
        let filename = "\(stem)-\(configurationName).xcconfig"

        return LeafExtractionPlan(
            targetName: targetName,
            configurationName: configurationName,
            xcconfigFilename: filename,
            outputDirectory: outputDirectory,
            xcconfigContents: contents,
            extractedSettingKeys: configuration.buildSettings.keys.sorted()
        )
    }

    private func toXCConfigValue(_ setting: BuildSetting) -> XCConfigFile.Value {
        switch setting {
        case .string(let value):
            .string(value)
        case .array(let values):
            .array(values)
        }
    }
}

import Foundation
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
        let projectParentURL = URL(fileURLWithPath: projectPath).deletingLastPathComponent()

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

        let outputDirectoryURL = resolveOutputDirectory(
            outputDirectory: outputDirectory,
            relativeTo: projectParentURL
        )
        let xcconfigAbsoluteURL = outputDirectoryURL
            .appendingPathComponent(filename)
            .standardizedFileURL
        let xcconfigPathInProject = relativePath(
            from: projectParentURL.standardizedFileURL,
            to: xcconfigAbsoluteURL
        )

        return LeafExtractionPlan(
            targetName: targetName,
            configurationName: configurationName,
            xcconfigFilename: filename,
            xcconfigContents: contents,
            extractedSettingKeys: configuration.buildSettings.keys.sorted(),
            xcconfigAbsoluteURL: xcconfigAbsoluteURL,
            xcconfigPathInProject: xcconfigPathInProject
        )
    }

    private func resolveOutputDirectory(outputDirectory: String, relativeTo projectParent: URL) -> URL {
        if outputDirectory.hasPrefix("/") {
            return URL(fileURLWithPath: outputDirectory, isDirectory: true)
        }
        if outputDirectory.isEmpty {
            return projectParent
        }
        return projectParent.appendingPathComponent(outputDirectory, isDirectory: true)
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

func relativePath(from base: URL, to target: URL) -> String {
    let baseComponents = base.standardizedFileURL.pathComponents
    let targetComponents = target.standardizedFileURL.pathComponents

    var commonPrefix = 0
    while commonPrefix < baseComponents.count
        && commonPrefix < targetComponents.count
        && baseComponents[commonPrefix] == targetComponents[commonPrefix]
    {
        commonPrefix += 1
    }

    let upLevels = baseComponents.count - commonPrefix
    let downComponents = Array(targetComponents.suffix(from: commonPrefix))
    let parts = Array(repeating: "..", count: upLevels) + downComponents
    return parts.joined(separator: "/")
}

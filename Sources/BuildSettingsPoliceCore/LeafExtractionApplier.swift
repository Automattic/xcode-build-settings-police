import Foundation
import PathKit
import XcodeProj

public struct LeafExtractionApplier: Sendable {
    public init() {}

    public func apply(
        plan: LeafExtractionPlan,
        projectPath: String,
        outputBaseURL: URL
    ) throws {
        let fileManager = FileManager.default
        let outputDirectoryURL = plan.outputDirectory.isEmpty
            ? outputBaseURL
            : outputBaseURL.appendingPathComponent(plan.outputDirectory, isDirectory: true)
        try fileManager.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )

        let xcconfigURL = outputDirectoryURL.appendingPathComponent(plan.xcconfigFilename)
        try plan.xcconfigContents.write(to: xcconfigURL, atomically: true, encoding: .utf8)

        let xcodeProj = try XcodeProj(pathString: projectPath)
        guard let project = xcodeProj.pbxproj.rootObject else {
            throw LeafExtractionError.targetNotFound(name: plan.targetName)
        }
        guard let target = project.targets.first(where: { $0.name == plan.targetName }) else {
            throw LeafExtractionError.targetNotFound(name: plan.targetName)
        }
        guard let configuration = target.buildConfigurationList?
            .buildConfigurations
            .first(where: { $0.name == plan.configurationName })
        else {
            throw LeafExtractionError.configurationNotFound(
                target: plan.targetName,
                configuration: plan.configurationName
            )
        }

        let fileReference = try registerFileReference(
            for: plan.xcconfigRelativePath,
            in: project.mainGroup,
            pbxproj: xcodeProj.pbxproj
        )
        configuration.baseConfiguration = fileReference
        configuration.buildSettings = [:]

        try xcodeProj.writePBXProj(
            path: Path(projectPath),
            outputSettings: PBXOutputSettings()
        )
    }

    private func registerFileReference(
        for relativePath: String,
        in mainGroup: PBXGroup,
        pbxproj: PBXProj
    ) throws -> PBXFileReference {
        if let existing = mainGroup.children.compactMap({ $0 as? PBXFileReference })
            .first(where: { $0.path == relativePath })
        {
            return existing
        }

        let reference = PBXFileReference(
            sourceTree: .group,
            lastKnownFileType: "text.xcconfig",
            path: relativePath
        )
        pbxproj.add(object: reference)
        mainGroup.children.append(reference)
        return reference
    }
}

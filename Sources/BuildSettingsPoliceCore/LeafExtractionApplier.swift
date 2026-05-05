import Foundation
import PathKit
import XcodeProj

public struct LeafExtractionApplier: Sendable {
    public init() {}

    public func apply(plan: LeafExtractionPlan, projectPath: String) throws {
        let outputDirectoryURL = plan.xcconfigAbsoluteURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )
        try plan.xcconfigContents.write(
            to: plan.xcconfigAbsoluteURL,
            atomically: true,
            encoding: .utf8
        )

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

        let projectParent = URL(fileURLWithPath: projectPath).deletingLastPathComponent().path
        let syncRoots = collectSynchronizedRootGroups(under: project.mainGroup)

        if let match = try findContainingSyncRoot(
            for: plan.xcconfigAbsoluteURL,
            syncRoots: syncRoots,
            sourceRoot: projectParent
        ) {
            configuration.baseConfigurationAnchor = match.group
            configuration.baseConfigurationReferenceRelativePath = match.relativePath
        } else {
            let fileReference = try registerFileReference(
                for: plan.xcconfigPathInProject,
                in: project.mainGroup,
                pbxproj: xcodeProj.pbxproj
            )
            configuration.baseConfiguration = fileReference
        }
        configuration.buildSettings = [:]

        try xcodeProj.writePBXProj(
            path: Path(projectPath),
            outputSettings: PBXOutputSettings()
        )
    }

    private func collectSynchronizedRootGroups(under group: PBXGroup) -> [PBXFileSystemSynchronizedRootGroup] {
        var collected: [PBXFileSystemSynchronizedRootGroup] = []
        for child in group.children {
            if let syncRoot = child as? PBXFileSystemSynchronizedRootGroup {
                collected.append(syncRoot)
            } else if let subgroup = child as? PBXGroup {
                collected.append(contentsOf: collectSynchronizedRootGroups(under: subgroup))
            }
        }
        return collected
    }

    private func findContainingSyncRoot(
        for outputURL: URL,
        syncRoots: [PBXFileSystemSynchronizedRootGroup],
        sourceRoot: String
    ) throws -> (group: PBXFileSystemSynchronizedRootGroup, relativePath: String)? {
        let outputPath = outputURL.standardizedFileURL.path
        var matches: [(group: PBXFileSystemSynchronizedRootGroup, relativePath: String)] = []

        for group in syncRoots {
            guard let groupAbsolute = try group.fullPath(sourceRoot: sourceRoot) else { continue }
            let groupURL = URL(fileURLWithPath: groupAbsolute).standardizedFileURL
            let prefix = groupURL.path + "/"
            guard outputPath.hasPrefix(prefix) else { continue }
            let relative = String(outputPath.dropFirst(prefix.count))
            matches.append((group: group, relativePath: relative))
        }

        return matches.min(by: { $0.relativePath.count < $1.relativePath.count })
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

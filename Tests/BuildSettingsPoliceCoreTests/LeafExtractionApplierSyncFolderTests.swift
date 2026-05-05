import Foundation
import PathKit
import Testing
import XcodeProj

@testable import BuildSettingsPoliceCore

struct LeafExtractionApplierSyncFolderTests {
    @Test func extractsIntoSynchronizedRootGroup_setsAnchorAndRelativePath() throws {
        let fixture = try SyncFolderFixtureProject.make(syncRootName: "config", syncRootPath: "config")
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "config/targets"
        )
        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcodeProj = try XcodeProj(pathString: fixture.projectPath)
        let target = try #require(xcodeProj.pbxproj.rootObject?.targets.first(where: { $0.name == "App" }))
        let configuration = try #require(target.buildConfigurationList?.buildConfigurations.first(where: { $0.name == "Debug" }))

        #expect(configuration.baseConfiguration == nil)
        #expect(configuration.baseConfigurationAnchor != nil)
        #expect(configuration.baseConfigurationAnchor?.name == "config")
        #expect(configuration.baseConfigurationReferenceRelativePath == "targets/App-Debug.xcconfig")
        #expect(configuration.buildSettings.isEmpty)
    }

    @Test func extractsIntoSynchronizedRootGroup_doesNotCreatePBXFileReference() throws {
        let fixture = try SyncFolderFixtureProject.make(syncRootName: "config", syncRootPath: "config")
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "config/targets"
        )
        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcodeProj = try XcodeProj(pathString: fixture.projectPath)
        let mainGroupChildren = xcodeProj.pbxproj.rootObject?.mainGroup.children ?? []
        let xcconfigReferences = mainGroupChildren
            .compactMap { $0 as? PBXFileReference }
            .filter { ($0.path ?? "").hasSuffix(".xcconfig") }

        #expect(xcconfigReferences.isEmpty)
    }

    @Test func extractsOutsideSynchronizedRootGroup_fallsBackToFileReference() throws {
        let fixture = try SyncFolderFixtureProject.make(syncRootName: "config", syncRootPath: "config")
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Outside/Targets"
        )
        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcodeProj = try XcodeProj(pathString: fixture.projectPath)
        let target = try #require(xcodeProj.pbxproj.rootObject?.targets.first(where: { $0.name == "App" }))
        let configuration = try #require(target.buildConfigurationList?.buildConfigurations.first(where: { $0.name == "Debug" }))

        #expect(configuration.baseConfiguration != nil)
        #expect(configuration.baseConfigurationAnchor == nil)
        #expect(configuration.baseConfigurationReferenceRelativePath == nil)
    }
}

private struct SyncFolderFixtureProject {
    let directoryURL: URL
    let projectPath: String

    static func make(syncRootName: String, syncRootPath: String) throws -> SyncFolderFixtureProject {
        let tempDir = try FileManager.default.makeTemporaryDirectory()
        let projectURL = tempDir.appendingPathComponent("App.xcodeproj")
        let syncRootDiskURL = tempDir.appendingPathComponent(syncRootPath, isDirectory: true)
        try FileManager.default.createDirectory(at: syncRootDiskURL, withIntermediateDirectories: true)

        let syncRoot = PBXFileSystemSynchronizedRootGroup(
            sourceTree: .group,
            path: syncRootPath,
            name: syncRootName
        )
        let mainGroup = PBXGroup(children: [syncRoot], sourceTree: .group)

        let projectDebug = XCBuildConfiguration(name: "Debug", buildSettings: [:])
        let projectRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let projectConfigList = XCConfigurationList(
            buildConfigurations: [projectDebug, projectRelease],
            defaultConfigurationName: "Release"
        )

        let targetDebug = XCBuildConfiguration(
            name: "Debug",
            buildSettings: [
                "PRODUCT_NAME": "App",
                "OTHER_SWIFT_FLAGS": .array(["-D", "DEBUG_FLAG"]),
            ]
        )
        let targetRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let targetConfigList = XCConfigurationList(
            buildConfigurations: [targetDebug, targetRelease],
            defaultConfigurationName: "Release"
        )

        let target = PBXNativeTarget(name: "App", buildConfigurationList: targetConfigList)

        let project = PBXProject(
            name: "App",
            buildConfigurationList: projectConfigList,
            compatibilityVersion: nil,
            preferredProjectObjectVersion: nil,
            minimizedProjectReferenceProxies: nil,
            mainGroup: mainGroup,
            targets: [target]
        )

        let objects: [PBXObject] = [
            syncRoot, mainGroup,
            projectDebug, projectRelease, projectConfigList,
            targetDebug, targetRelease, targetConfigList,
            target, project,
        ]

        let pbxproj = PBXProj(rootObject: project, objects: objects)
        let xcodeProj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj)
        try xcodeProj.write(path: Path(projectURL.path))

        return SyncFolderFixtureProject(directoryURL: tempDir, projectPath: projectURL.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

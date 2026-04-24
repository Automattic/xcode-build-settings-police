import Foundation
import PathKit
import Testing
import XcodeProj

@testable import BuildSettingsPoliceCore

struct XcodeProjectLoaderTests {
    @Test func readsProjectNameAndConfigurationNames() throws {
        let fixture = try FixtureProject.make()
        defer { fixture.cleanup() }

        let loaded = try XcodeProjectLoader().load(projectPath: fixture.projectPath)

        #expect(loaded.name == "App")
        #expect(loaded.projectConfigurations.map(\.name) == ["Debug", "Release"])
        #expect(loaded.targets.map(\.name) == ["App"])
        #expect(loaded.targets.first?.configurations.map(\.name) == ["Debug", "Release"])
    }

    @Test func readsInlineSettingsAtProjectAndTargetLevel() throws {
        let fixture = try FixtureProject.make()
        defer { fixture.cleanup() }

        let loaded = try XcodeProjectLoader().load(projectPath: fixture.projectPath)

        let projectDebug = try #require(loaded.projectConfigurations.first { $0.name == "Debug" })
        #expect(projectDebug.inlineSettings["PROJECT_KEY"] == .string("project-value"))

        let target = try #require(loaded.targets.first)
        let targetDebug = try #require(target.configurations.first { $0.name == "Debug" })
        #expect(targetDebug.inlineSettings["TARGET_KEY"] == .string("target-value"))
        #expect(targetDebug.inlineSettings["FLAGS"] == .array(["-Xfrontend", "-debug-time-function-bodies"]))
    }

    @Test func readsBaseConfigurationPathWithoutResolving() throws {
        let fixture = try FixtureProject.make()
        defer { fixture.cleanup() }

        let loaded = try XcodeProjectLoader().load(projectPath: fixture.projectPath)

        let target = try #require(loaded.targets.first)
        let targetDebug = try #require(target.configurations.first { $0.name == "Debug" })
        #expect(targetDebug.baseConfigurationPath == "Configs/Target-Debug.xcconfig")

        let targetRelease = try #require(target.configurations.first { $0.name == "Release" })
        #expect(targetRelease.baseConfigurationPath == nil)
    }

}

private struct FixtureProject {
    let directoryURL: URL
    let projectPath: String

    static func make() throws -> FixtureProject {
        let tempDir = try FileManager.default.makeTemporaryDirectory()
        let projectURL = tempDir.appendingPathComponent("App.xcodeproj")

        let xcconfigFile = PBXFileReference(
            sourceTree: .group,
            path: "Configs/Target-Debug.xcconfig"
        )
        let mainGroup = PBXGroup(children: [xcconfigFile], sourceTree: .group)

        let projectDebug = XCBuildConfiguration(
            name: "Debug",
            buildSettings: ["PROJECT_KEY": "project-value"]
        )
        let projectRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let projectConfigList = XCConfigurationList(
            buildConfigurations: [projectDebug, projectRelease],
            defaultConfigurationName: "Release"
        )

        let targetDebug = XCBuildConfiguration(
            name: "Debug",
            baseConfiguration: xcconfigFile,
            buildSettings: [
                "TARGET_KEY": "target-value",
                "FLAGS": .array(["-Xfrontend", "-debug-time-function-bodies"]),
            ]
        )
        let targetRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let targetConfigList = XCConfigurationList(
            buildConfigurations: [targetDebug, targetRelease],
            defaultConfigurationName: "Release"
        )

        let target = PBXNativeTarget(
            name: "App",
            buildConfigurationList: targetConfigList
        )

        let project = PBXProject(
            name: "App",
            buildConfigurationList: projectConfigList,
            compatibilityVersion: nil,
            preferredProjectObjectVersion: nil,
            minimizedProjectReferenceProxies: nil,
            mainGroup: mainGroup,
            targets: [target]
        )

        let pbxproj = PBXProj(
            rootObject: project,
            objects: [
                mainGroup,
                xcconfigFile,
                projectDebug, projectRelease, projectConfigList,
                targetDebug, targetRelease, targetConfigList,
                target,
                project,
            ]
        )

        let xcodeProj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj)
        try xcodeProj.write(path: Path(projectURL.path))

        return FixtureProject(directoryURL: tempDir, projectPath: projectURL.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private extension FileManager {
    func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("build-settings-police-tests-\(UUID().uuidString)", isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

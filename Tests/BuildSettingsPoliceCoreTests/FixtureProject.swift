import Foundation
import PathKit
import XcodeProj

struct FixtureProject {
    let directoryURL: URL
    let projectPath: String

    static func make(
        name: String = "App",
        projectDebugInlineSettings: BuildSettings = ["PROJECT_KEY": "project-value"],
        targetDebugInlineSettings: BuildSettings = [
            "TARGET_KEY": "target-value",
            "FLAGS": .array(["-Xfrontend", "-debug-time-function-bodies"]),
        ],
        targetDebugBaseConfigPath: String? = "Configs/Target-Debug.xcconfig"
    ) throws -> FixtureProject {
        let tempDir = try FileManager.default.makeTemporaryDirectory()
        let projectURL = tempDir.appendingPathComponent("\(name).xcodeproj")

        let xcconfigFile = targetDebugBaseConfigPath.map {
            PBXFileReference(sourceTree: .group, path: $0)
        }
        let mainGroup = PBXGroup(
            children: xcconfigFile.map { [$0] } ?? [],
            sourceTree: .group
        )

        let projectDebug = XCBuildConfiguration(name: "Debug", buildSettings: projectDebugInlineSettings)
        let projectRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let projectConfigList = XCConfigurationList(
            buildConfigurations: [projectDebug, projectRelease],
            defaultConfigurationName: "Release"
        )

        let targetDebug = XCBuildConfiguration(
            name: "Debug",
            baseConfiguration: xcconfigFile,
            buildSettings: targetDebugInlineSettings
        )
        let targetRelease = XCBuildConfiguration(name: "Release", buildSettings: [:])
        let targetConfigList = XCConfigurationList(
            buildConfigurations: [targetDebug, targetRelease],
            defaultConfigurationName: "Release"
        )

        let target = PBXNativeTarget(name: name, buildConfigurationList: targetConfigList)

        let project = PBXProject(
            name: name,
            buildConfigurationList: projectConfigList,
            compatibilityVersion: nil,
            preferredProjectObjectVersion: nil,
            minimizedProjectReferenceProxies: nil,
            mainGroup: mainGroup,
            targets: [target]
        )

        var objects: [PBXObject] = [
            mainGroup,
            projectDebug, projectRelease, projectConfigList,
            targetDebug, targetRelease, targetConfigList,
            target, project,
        ]
        if let xcconfigFile {
            objects.append(xcconfigFile)
        }

        let pbxproj = PBXProj(rootObject: project, objects: objects)
        let xcodeProj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj)
        try xcodeProj.write(path: Path(projectURL.path))

        return FixtureProject(directoryURL: tempDir, projectPath: projectURL.path)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

extension FileManager {
    func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("build-settings-police-tests-\(UUID().uuidString)", isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

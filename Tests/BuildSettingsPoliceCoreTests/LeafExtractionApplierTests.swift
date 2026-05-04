import Foundation
import PathKit
import Testing
import XcodeProj

@testable import BuildSettingsPoliceCore

struct LeafExtractionApplierTests {
    @Test func writesXcconfigFileToOutputDirectory() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcconfigURL = fixture.directoryURL
            .appendingPathComponent("Config")
            .appendingPathComponent("App-Debug.xcconfig")
        let contents = try String(contentsOf: xcconfigURL, encoding: .utf8)
        #expect(contents.contains("PRODUCT_NAME = App\n"))
    }

    @Test func clearsInlineSettingsAndAttachesBaseConfiguration() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: [
                "PRODUCT_NAME": "App",
                "OTHER_LDFLAGS": .array(["-ObjC"]),
            ],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let target = try #require(
            reloaded.pbxproj.rootObject?.targets.first(where: { $0.name == "App" })
        )
        let configuration = try #require(
            target.buildConfigurationList?.buildConfigurations.first(where: { $0.name == "Debug" })
        )

        #expect(configuration.buildSettings.isEmpty)
        #expect(configuration.baseConfiguration?.path == "Config/App-Debug.xcconfig")
    }

    @Test func leavesOtherConfigurationsUntouched() throws {
        let fixture = try FixtureProject.make(
            projectDebugInlineSettings: ["PROJECT_KEY": "kept"],
            targetDebugInlineSettings: ["TARGET_KEY": "extracted"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let project = try #require(reloaded.pbxproj.rootObject)

        let projectDebug = try #require(
            project.buildConfigurationList?.buildConfigurations.first(where: { $0.name == "Debug" })
        )
        #expect(projectDebug.buildSettings["PROJECT_KEY"]?.stringValue == "kept")

        let targetRelease = try #require(
            project.targets.first?.buildConfigurationList?.buildConfigurations
                .first(where: { $0.name == "Release" })
        )
        #expect(targetRelease.baseConfiguration == nil)
    }

    @Test func registersXcconfigFileReferenceInMainGroup() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let mainGroup = try #require(reloaded.pbxproj.rootObject?.mainGroup)

        let allFileRefPaths = collectFileReferencePaths(from: mainGroup)
        #expect(allFileRefPaths.contains("Config/App-Debug.xcconfig"))
    }

    @Test func writesNothingWhenPlanIsApplied_butDirectoryAlreadyExists() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let configDir = fixture.directoryURL.appendingPathComponent("Config")
        try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcconfigURL = configDir.appendingPathComponent("App-Debug.xcconfig")
        #expect(FileManager.default.fileExists(atPath: xcconfigURL.path))
    }

    @Test func writesToAbsoluteOutputDirectory() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let absoluteOutput = fixture.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("absolute-output-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: absoluteOutput) }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: absoluteOutput.path
        )

        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let xcconfigURL = absoluteOutput.appendingPathComponent("App-Debug.xcconfig")
        #expect(FileManager.default.fileExists(atPath: xcconfigURL.path))

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let configuration = try #require(
            reloaded.pbxproj.rootObject?.targets.first?.buildConfigurationList?
                .buildConfigurations.first(where: { $0.name == "Debug" })
        )
        #expect(configuration.baseConfiguration?.path?.hasPrefix("../") == true)
    }
}

private func collectFileReferencePaths(from group: PBXGroup) -> [String] {
    var paths: [String] = []
    for child in group.children {
        if let reference = child as? PBXFileReference, let path = reference.path {
            paths.append(path)
        }
        if let subgroup = child as? PBXGroup {
            paths.append(contentsOf: collectFileReferencePaths(from: subgroup))
        }
    }
    return paths
}

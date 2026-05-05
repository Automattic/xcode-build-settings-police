import Foundation
import Testing
import XcodeProj

@testable import BuildSettingsPoliceCore

struct LeafExtractionPlannerTests {
    @Test func plansFilenameAndContentsFromInlineSettings() throws {
        let fixture = try FixtureProject.make(
            projectDebugInlineSettings: [:],
            targetDebugInlineSettings: [
                "PRODUCT_NAME": "App",
                "OTHER_LDFLAGS": .array(["$(inherited)", "-ObjC"]),
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

        #expect(plan.targetName == "App")
        #expect(plan.configurationName == "Debug")
        #expect(plan.xcconfigFilename == "App-Debug.xcconfig")
        #expect(plan.xcconfigPathInProject == "Config/App-Debug.xcconfig")
        #expect(plan.extractedSettingKeys == ["OTHER_LDFLAGS", "PRODUCT_NAME"])
        #expect(plan.xcconfigContents.contains("OTHER_LDFLAGS = $(inherited) -ObjC\n"))
        #expect(plan.xcconfigContents.contains("PRODUCT_NAME = App\n"))
    }

    @Test func errorsWhenTargetNameUnknown() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        #expect(throws: LeafExtractionError.targetNotFound(name: "Missing")) {
            _ = try LeafExtractionPlanner().plan(
                projectPath: fixture.projectPath,
                targetName: "Missing",
                configurationName: "Debug",
                outputDirectory: "Config"
            )
        }
    }

    @Test func errorsWhenConfigurationNameUnknown() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        #expect(
            throws: LeafExtractionError.configurationNotFound(
                target: "App",
                configuration: "Beta"
            )
        ) {
            _ = try LeafExtractionPlanner().plan(
                projectPath: fixture.projectPath,
                targetName: "App",
                configurationName: "Beta",
                outputDirectory: "Config"
            )
        }
    }

    @Test func errorsWhenConfigurationAlreadyHasBaseConfiguration() throws {
        let fixture = try FixtureProject.make(
            targetDebugBaseConfigPath: "Config/Existing.xcconfig"
        )
        defer { fixture.cleanup() }

        #expect(
            throws: LeafExtractionError.configurationAlreadyHasBaseConfiguration(
                target: "App",
                configuration: "Debug",
                existing: "Config/Existing.xcconfig"
            )
        ) {
            _ = try LeafExtractionPlanner().plan(
                projectPath: fixture.projectPath,
                targetName: "App",
                configurationName: "Debug",
                outputDirectory: "Config"
            )
        }
    }

    @Test func errorsWhenNothingToExtract() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: [:],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        #expect(
            throws: LeafExtractionError.nothingToExtract(
                target: "App",
                configuration: "Debug"
            )
        ) {
            _ = try LeafExtractionPlanner().plan(
                projectPath: fixture.projectPath,
                targetName: "App",
                configurationName: "Debug",
                outputDirectory: "Config"
            )
        }
    }

    @Test func emptyOutputDirectoryWritesAlongsideTheProject() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: ""
        )

        #expect(plan.xcconfigPathInProject == "App-Debug.xcconfig")
        let expectedURL = fixture.directoryURL.appendingPathComponent("App-Debug.xcconfig").standardizedFileURL
        #expect(plan.xcconfigAbsoluteURL == expectedURL)
    }

    @Test func relativeOutputDirectoryAnchorsAtProjectParent() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        #expect(plan.xcconfigPathInProject == "Config/App-Debug.xcconfig")
        let expectedURL = fixture.directoryURL
            .appendingPathComponent("Config")
            .appendingPathComponent("App-Debug.xcconfig")
            .standardizedFileURL
        #expect(plan.xcconfigAbsoluteURL == expectedURL)
    }

    @Test func relativeOutputDirectoryWithDotDotEscapesProjectParent() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "../sibling-config"
        )

        #expect(plan.xcconfigPathInProject == "../sibling-config/App-Debug.xcconfig")
        let expectedURL = fixture.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("sibling-config")
            .appendingPathComponent("App-Debug.xcconfig")
            .standardizedFileURL
        #expect(plan.xcconfigAbsoluteURL == expectedURL)
    }

    @Test func absoluteOutputDirectoryInsideProjectParent() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let absolute = fixture.directoryURL.appendingPathComponent("Config").path

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: absolute
        )

        #expect(plan.xcconfigPathInProject == "Config/App-Debug.xcconfig")
        let expectedURL = URL(fileURLWithPath: absolute)
            .appendingPathComponent("App-Debug.xcconfig")
            .standardizedFileURL
        #expect(plan.xcconfigAbsoluteURL == expectedURL)
    }

    @Test func absoluteOutputDirectoryOutsideProjectParent() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let outside = fixture.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("external-config-\(UUID().uuidString)")

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: outside.path
        )

        #expect(plan.xcconfigPathInProject.hasPrefix("../"))
        #expect(plan.xcconfigPathInProject.hasSuffix("/App-Debug.xcconfig"))
        #expect(plan.xcconfigAbsoluteURL == outside.appendingPathComponent("App-Debug.xcconfig").standardizedFileURL)
    }
}

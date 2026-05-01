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
        #expect(plan.outputDirectory == "Config")
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

    @Test func emptyOutputDirectoryProducesBareFilename() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: ""
        )

        #expect(plan.xcconfigRelativePath == "App-Debug.xcconfig")
    }

    @Test func relativePathJoinsOutputDirectoryAndFilename() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )

        #expect(plan.xcconfigRelativePath == "Config/App-Debug.xcconfig")
    }
}

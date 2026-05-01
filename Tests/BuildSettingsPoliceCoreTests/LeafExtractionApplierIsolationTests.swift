import Foundation
import Testing

@testable import BuildSettingsPoliceCore

struct LeafExtractionApplierIsolationTests {
    @Test func leavesXcsharedDataUntouched() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let sharedDataDir = URL(fileURLWithPath: fixture.projectPath)
            .appendingPathComponent("xcshareddata")
        try FileManager.default.createDirectory(
            at: sharedDataDir,
            withIntermediateDirectories: true
        )
        let sentinelURL = sharedDataDir.appendingPathComponent("sentinel.txt")
        let sentinelContent = "do-not-touch-\(UUID().uuidString)"
        try sentinelContent.write(to: sentinelURL, atomically: true, encoding: .utf8)

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )
        try LeafExtractionApplier().apply(
            plan: plan,
            projectPath: fixture.projectPath,
            outputBaseURL: fixture.directoryURL
        )

        #expect(FileManager.default.fileExists(atPath: sentinelURL.path))
        let reloadedContent = try String(contentsOf: sentinelURL, encoding: .utf8)
        #expect(reloadedContent == sentinelContent)
    }

    @Test func leavesXcuserDataUntouched() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let userDataDir = URL(fileURLWithPath: fixture.projectPath)
            .appendingPathComponent("xcuserdata")
        try FileManager.default.createDirectory(
            at: userDataDir,
            withIntermediateDirectories: true
        )
        let sentinelURL = userDataDir.appendingPathComponent("sentinel.txt")
        let sentinelContent = "user-data-\(UUID().uuidString)"
        try sentinelContent.write(to: sentinelURL, atomically: true, encoding: .utf8)

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )
        try LeafExtractionApplier().apply(
            plan: plan,
            projectPath: fixture.projectPath,
            outputBaseURL: fixture.directoryURL
        )

        #expect(FileManager.default.fileExists(atPath: sentinelURL.path))
        let reloadedContent = try String(contentsOf: sentinelURL, encoding: .utf8)
        #expect(reloadedContent == sentinelContent)
    }

    @Test func leavesWorkspaceDataUntouched() async throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let workspaceFile = URL(fileURLWithPath: fixture.projectPath)
            .appendingPathComponent("project.xcworkspace")
            .appendingPathComponent("contents.xcworkspacedata")
        let originalContent = try String(contentsOf: workspaceFile, encoding: .utf8)
        let originalAttributes = try FileManager.default.attributesOfItem(atPath: workspaceFile.path)
        let originalDate = originalAttributes[.modificationDate] as? Date

        try await Task.sleep(nanoseconds: 1_500_000_000)

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )
        try LeafExtractionApplier().apply(
            plan: plan,
            projectPath: fixture.projectPath,
            outputBaseURL: fixture.directoryURL
        )

        let reloadedContent = try String(contentsOf: workspaceFile, encoding: .utf8)
        #expect(reloadedContent == originalContent)

        let reloadedAttributes = try FileManager.default.attributesOfItem(atPath: workspaceFile.path)
        let reloadedDate = reloadedAttributes[.modificationDate] as? Date
        #expect(reloadedDate == originalDate, "applier rewrote project.xcworkspace/contents.xcworkspacedata")
    }
}

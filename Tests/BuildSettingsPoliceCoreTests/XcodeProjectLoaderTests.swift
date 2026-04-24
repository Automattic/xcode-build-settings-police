import Testing

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

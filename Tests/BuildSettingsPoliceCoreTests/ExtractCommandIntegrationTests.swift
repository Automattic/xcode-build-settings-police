import Foundation
import Testing
import XcodeProj

struct ExtractCommandIntegrationTests {
    @Test func dryRunPrintsPlanAndDoesNotMutateProject() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let result = try runExtract(
            projectPath: fixture.projectPath,
            arguments: ["--target", "App", "--configuration", "Debug", "--output", "Config", "--dry-run"]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Config/App-Debug.xcconfig"))
        #expect(result.stdout.contains("PRODUCT_NAME"))

        let xcconfigURL = fixture.directoryURL
            .appendingPathComponent("Config")
            .appendingPathComponent("App-Debug.xcconfig")
        #expect(!FileManager.default.fileExists(atPath: xcconfigURL.path))

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let configuration = try #require(
            reloaded.pbxproj.rootObject?.targets.first?.buildConfigurationList?
                .buildConfigurations.first(where: { $0.name == "Debug" })
        )
        #expect(configuration.buildSettings["PRODUCT_NAME"]?.stringValue == "App")
        #expect(configuration.baseConfiguration == nil)
    }

    @Test func realRunWritesFileAndMutatesProject() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: ["PRODUCT_NAME": "App"],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let result = try runExtract(
            projectPath: fixture.projectPath,
            arguments: ["--target", "App", "--configuration", "Debug", "--output", "Config"]
        )

        #expect(result.exitCode == 0)

        let xcconfigURL = fixture.directoryURL
            .appendingPathComponent("Config")
            .appendingPathComponent("App-Debug.xcconfig")
        #expect(FileManager.default.fileExists(atPath: xcconfigURL.path))

        let reloaded = try XcodeProj(pathString: fixture.projectPath)
        let configuration = try #require(
            reloaded.pbxproj.rootObject?.targets.first?.buildConfigurationList?
                .buildConfigurations.first(where: { $0.name == "Debug" })
        )
        #expect(configuration.buildSettings.isEmpty)
        #expect(configuration.baseConfiguration?.path == "Config/App-Debug.xcconfig")
    }

    @Test func unknownTargetExitsNonZero() throws {
        let fixture = try FixtureProject.make(targetDebugBaseConfigPath: nil)
        defer { fixture.cleanup() }

        let result = try runExtract(
            projectPath: fixture.projectPath,
            arguments: ["--target", "DoesNotExist", "--configuration", "Debug", "--output", "Config"]
        )

        #expect(result.exitCode != 0)
        let combined = result.stdout + result.stderr
        #expect(combined.contains("DoesNotExist"))
    }

    @Test func configurationWithExistingXcconfigExitsNonZero() throws {
        let fixture = try FixtureProject.make(
            targetDebugBaseConfigPath: "Config/Existing.xcconfig"
        )
        defer { fixture.cleanup() }

        let result = try runExtract(
            projectPath: fixture.projectPath,
            arguments: ["--target", "App", "--configuration", "Debug", "--output", "Config"]
        )

        #expect(result.exitCode != 0)
        let combined = result.stdout + result.stderr
        #expect(combined.contains("Existing.xcconfig"))
    }

    @Test func emptyConfigurationExitsNonZero() throws {
        let fixture = try FixtureProject.make(
            targetDebugInlineSettings: [:],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let result = try runExtract(
            projectPath: fixture.projectPath,
            arguments: ["--target", "App", "--configuration", "Debug", "--output", "Config"]
        )

        #expect(result.exitCode != 0)
        let combined = result.stdout + result.stderr
        #expect(combined.lowercased().contains("no inline build settings"))
    }
}

private struct ExtractRunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func runExtract(projectPath: String, arguments: [String]) throws -> ExtractRunResult {
    let binary = try locateExtractBinary()
    let process = Process()
    process.executableURL = binary
    process.arguments = ["extract", projectPath] + arguments

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()

    return ExtractRunResult(
        exitCode: process.terminationStatus,
        stdout: String(decoding: stdoutData, as: UTF8.self),
        stderr: String(decoding: stderrData, as: UTF8.self)
    )
}

private func locateExtractBinary() throws -> URL {
    let testFile = URL(fileURLWithPath: #filePath, isDirectory: false)
    let packageRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let candidate = packageRoot
        .appendingPathComponent(".build/debug/build-settings-police")
    guard FileManager.default.fileExists(atPath: candidate.path) else {
        throw ExtractIntegrationTestError.binaryNotFound(path: candidate.path)
    }
    return candidate
}

private enum ExtractIntegrationTestError: Error, CustomStringConvertible {
    case binaryNotFound(path: String)

    var description: String {
        switch self {
        case .binaryNotFound(let path):
            "CLI binary not found at \(path). Run `swift build` before `swift test`."
        }
    }
}

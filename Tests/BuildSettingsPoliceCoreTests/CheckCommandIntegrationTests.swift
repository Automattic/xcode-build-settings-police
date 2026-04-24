import Foundation
import Testing

struct CheckCommandIntegrationTests {
    @Test func exitsZeroAndReportsCleanForProjectWithNoInlineSettings() throws {
        let fixture = try FixtureProject.make(
            projectDebugInlineSettings: [:],
            targetDebugInlineSettings: [:]
        )
        defer { fixture.cleanup() }

        let result = try runCheck(projectPath: fixture.projectPath)

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("No inline build settings found."))
    }

    @Test func exitsNonZeroAndListsViolationsInPlainFormat() throws {
        let fixture = try FixtureProject.make()
        defer { fixture.cleanup() }

        let result = try runCheck(projectPath: fixture.projectPath)

        #expect(result.exitCode != 0)
        #expect(result.stdout.contains("Found"))
        #expect(result.stdout.contains("project [Debug]"))
        #expect(result.stdout.contains("target App [Debug]"))
    }

    @Test func emitsJSONWhenFormatFlagIsJSON() throws {
        let fixture = try FixtureProject.make()
        defer { fixture.cleanup() }

        let result = try runCheck(projectPath: fixture.projectPath, arguments: ["--format", "json"])

        #expect(result.exitCode != 0)

        let payload = try JSONDecoder().decode(DecodedPayload.self, from: Data(result.stdout.utf8))
        #expect(payload.violations.contains { $0.scope == "project" && $0.configuration == "Debug" })
        #expect(payload.violations.contains { $0.scope == "target" && $0.target == "App" })
    }

    @Test func exitsNonZeroWhenProjectPathDoesNotExist() throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).xcodeproj")

        let result = try runCheck(projectPath: missing.path)

        #expect(result.exitCode != 0)
    }
}

private struct RunResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

private func runCheck(projectPath: String, arguments: [String] = []) throws -> RunResult {
    let binary = try locateBinary()
    let process = Process()
    process.executableURL = binary
    process.arguments = ["check", projectPath] + arguments

    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = errPipe.fileHandleForReading.readDataToEndOfFile()

    return RunResult(
        exitCode: process.terminationStatus,
        stdout: String(decoding: stdoutData, as: UTF8.self),
        stderr: String(decoding: stderrData, as: UTF8.self)
    )
}

private func locateBinary() throws -> URL {
    let testFile = URL(fileURLWithPath: #filePath, isDirectory: false)
    let packageRoot = testFile
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let candidate = packageRoot
        .appendingPathComponent(".build/debug/build-settings-police")
    guard FileManager.default.fileExists(atPath: candidate.path) else {
        throw IntegrationTestError.binaryNotFound(path: candidate.path)
    }
    return candidate
}

private enum IntegrationTestError: Error, CustomStringConvertible {
    case binaryNotFound(path: String)

    var description: String {
        switch self {
        case .binaryNotFound(let path):
            "CLI binary not found at \(path). Run `swift build` before `swift test`."
        }
    }
}

private struct DecodedPayload: Decodable {
    let violations: [DecodedViolation]
}

private struct DecodedViolation: Decodable {
    let scope: String
    let target: String?
    let configuration: String
    let settings: [String]
}

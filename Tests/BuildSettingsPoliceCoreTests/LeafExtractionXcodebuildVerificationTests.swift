import Foundation
import Testing

@testable import BuildSettingsPoliceCore

struct LeafExtractionXcodebuildVerificationTests {
    @Test func extractedSettingsMatchInlineSettingsViaXcodebuild() throws {
        let fixture = try FixtureProject.make(
            projectDebugInlineSettings: [:],
            targetDebugInlineSettings: [
                "PRODUCT_NAME": "App",
                "OTHER_SWIFT_FLAGS": .array(["-D", "DEBUG_FLAG"]),
                "GCC_PREPROCESSOR_DEFINITIONS": .array(["$(inherited)", "DEBUG=1"]),
            ],
            targetDebugBaseConfigPath: nil
        )
        defer { fixture.cleanup() }

        let before = try captureBuildSettings(
            projectPath: fixture.projectPath,
            target: "App",
            configuration: "Debug"
        )

        let plan = try LeafExtractionPlanner().plan(
            projectPath: fixture.projectPath,
            targetName: "App",
            configurationName: "Debug",
            outputDirectory: "Config"
        )
        try LeafExtractionApplier().apply(plan: plan, projectPath: fixture.projectPath)

        let after = try captureBuildSettings(
            projectPath: fixture.projectPath,
            target: "App",
            configuration: "Debug"
        )

        let semanticBefore = filterSemanticSettings(before)
        let semanticAfter = filterSemanticSettings(after)
        #expect(semanticBefore == semanticAfter, "build settings differ after extraction")
    }
}

private func captureBuildSettings(projectPath: String, target: String, configuration: String) throws -> [String: String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    process.arguments = [
        "-project", projectPath,
        "-target", target,
        "-configuration", configuration,
        "-showBuildSettings",
    ]
    let outPipe = Pipe()
    let errPipe = Pipe()
    process.standardOutput = outPipe
    process.standardError = errPipe

    try process.run()
    process.waitUntilExit()

    let stdout = String(decoding: outPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let stderr = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    if process.terminationStatus != 0 {
        throw XcodebuildError.failed(status: process.terminationStatus, stderr: stderr, stdout: stdout)
    }

    return parseBuildSettings(stdout)
}

private func parseBuildSettings(_ output: String) -> [String: String] {
    var settings: [String: String] = [:]
    for line in output.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let equalsIndex = trimmed.firstIndex(of: "=") else { continue }
        let key = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
        if key.isEmpty || key.contains(" ") { continue }
        settings[String(key)] = String(value)
    }
    return settings
}

private let environmentDependentKeys: Set<String> = [
    "BUILD_DIR", "BUILD_ROOT", "CACHE_ROOT", "CCHROOT",
    "CONFIGURATION_BUILD_DIR", "CONFIGURATION_TEMP_DIR", "DERIVED_DATA_DIR",
    "DERIVED_FILE_DIR", "DERIVED_FILES_DIR", "DERIVED_SOURCES_DIR",
    "OBJECT_FILE_DIR", "OBJECT_FILE_DIR_normal", "OBJROOT", "PROJECT_DIR",
    "PROJECT_FILE_PATH", "PROJECT_TEMP_DIR", "PROJECT_TEMP_ROOT",
    "SHARED_DERIVED_FILE_DIR", "SHARED_PRECOMPS_DIR", "SOURCE_ROOT", "SRCROOT",
    "SYMROOT", "TARGET_BUILD_DIR", "TARGET_TEMP_DIR", "TEMP_DIR", "TEMP_FILE_DIR",
    "TEMP_FILES_DIR", "TEMP_ROOT",
    "DEVELOPER_DIR", "DEVELOPER_FRAMEWORKS_DIR", "DEVELOPER_LIBRARY_DIR",
    "DEVELOPER_TOOLS_DIR", "DEVELOPER_USR_DIR", "DEVELOPER_BIN_DIR",
    "USER_LIBRARY_DIR", "HOME", "LOGNAME", "USER",
]

private func filterSemanticSettings(_ settings: [String: String]) -> [String: String] {
    settings.filter { key, _ in !environmentDependentKeys.contains(key) }
}

private enum XcodebuildError: Error, CustomStringConvertible {
    case failed(status: Int32, stderr: String, stdout: String)

    var description: String {
        switch self {
        case .failed(let status, let stderr, let stdout):
            "xcodebuild exited \(status). stderr:\n\(stderr)\nstdout:\n\(stdout)"
        }
    }
}

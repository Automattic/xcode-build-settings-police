import ArgumentParser
import BuildSettingsPoliceCore

struct CheckCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Fail if inline build settings are present in an Xcode project."
    )

    @Argument(help: "Path to the .xcodeproj to inspect.")
    var projectPath: String

    @Option(help: "Output format: plain or json.")
    var format: CheckReportFormat = .plain

    func run() throws {
        let project = try XcodeProjectLoader().load(projectPath: projectPath)
        let report = InlineSettingsChecker().check(project)
        let output = try CheckReportFormatter().format(report, as: format)
        print(output)
        if report.hasViolations {
            throw ExitCode.failure
        }
    }
}

extension CheckReportFormat: ExpressibleByArgument {}

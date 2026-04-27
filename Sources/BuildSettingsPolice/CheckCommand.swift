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

    @Flag(help: "Check every scope. Default when no other scope flag is given.")
    var all: Bool = false

    @Flag(inversion: .prefixedNo, help: "Include or exclude project-level configurations.")
    var project: Bool?

    @Option(name: .customLong("target"), parsing: .singleValue, help: "Restrict the check to the named target. Repeatable.")
    var targets: [String] = []

    @Option(name: .customLong("no-target"), parsing: .singleValue, help: "Exclude the named target from the check. Repeatable.")
    var excludedTargets: [String] = []

    func validate() throws {
        let hasInclude = project == true || !targets.isEmpty
        let hasExclude = project == false || !excludedTargets.isEmpty
        if all && (hasInclude || hasExclude) {
            throw ValidationError("--all is mutually exclusive with --project/--no-project and --target/--no-target.")
        }
        if hasInclude && hasExclude {
            throw ValidationError("Include flags (--project, --target) cannot be combined with exclude flags (--no-project, --no-target).")
        }
    }

    func run() throws {
        let loadedProject = try XcodeProjectLoader().load(projectPath: projectPath)
        let selection = buildSelection()
        try selection.validate(against: loadedProject)
        let report = InlineSettingsChecker().check(loadedProject).filtered(by: selection)
        let output = try CheckReportFormatter().format(report, as: format)
        print(output)
        if report.hasViolations {
            throw ExitCode.failure
        }
    }

    private func buildSelection() -> ScopeSelection {
        if project == true || !targets.isEmpty {
            return .include(project: project == true, targets: Set(targets))
        }
        if project == false || !excludedTargets.isEmpty {
            return .exclude(project: project == false, targets: Set(excludedTargets))
        }
        return .all
    }
}

extension CheckReportFormat: ExpressibleByArgument {}

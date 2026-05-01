import ArgumentParser
import BuildSettingsPoliceCore
import Foundation

struct ExtractCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract inline build settings from a single (target, configuration) into an xcconfig file."
    )

    @Argument(help: "Path to the .xcodeproj to inspect.")
    var projectPath: String

    @Option(help: "Target whose configuration should be extracted.")
    var target: String

    @Option(help: "Configuration on the named target to extract.")
    var configuration: String

    @Option(help: "Output directory for the generated .xcconfig, relative to the project's parent directory.")
    var output: String

    @Flag(help: "Print the plan without writing anything.")
    var dryRun: Bool = false

    func run() throws {
        let plan = try LeafExtractionPlanner().plan(
            projectPath: projectPath,
            targetName: target,
            configurationName: configuration,
            outputDirectory: output
        )

        if dryRun {
            printPlan(plan)
            return
        }

        let projectURL = URL(fileURLWithPath: projectPath)
        let outputBaseURL = projectURL.deletingLastPathComponent()
        try LeafExtractionApplier().apply(
            plan: plan,
            projectPath: projectPath,
            outputBaseURL: outputBaseURL
        )
        print("Wrote \(plan.xcconfigRelativePath) and attached it to \(plan.targetName) [\(plan.configurationName)].")
    }

    private func printPlan(_ plan: LeafExtractionPlan) {
        print("Dry run — no files written, no project mutations.")
        print("Target:        \(plan.targetName)")
        print("Configuration: \(plan.configurationName)")
        print("Will write:    \(plan.xcconfigRelativePath)")
        print("Settings to extract (\(plan.extractedSettingKeys.count)):")
        for key in plan.extractedSettingKeys {
            print("  - \(key)")
        }
        print("")
        print("xcconfig contents:")
        print("---")
        print(plan.xcconfigContents, terminator: "")
        print("---")
    }
}

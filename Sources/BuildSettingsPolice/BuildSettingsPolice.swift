import ArgumentParser

@main
struct BuildSettingsPolice: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build-settings-police",
        abstract: "Extract and police Xcode build settings.",
        subcommands: [CheckCommand.self, ExtractCommand.self]
    )
}

import ArgumentParser

@main
struct BuildSettingsPolice: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extract and police Xcode build settings."
    )

    func run() throws {}
}

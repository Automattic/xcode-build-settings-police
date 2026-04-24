import XcodeProj

public struct LoadedProject: Sendable, Equatable {
    public let name: String
    public let projectConfigurations: [BuildConfigurationSnapshot]
    public let targets: [LoadedTarget]

    public init(
        name: String,
        projectConfigurations: [BuildConfigurationSnapshot],
        targets: [LoadedTarget]
    ) {
        self.name = name
        self.projectConfigurations = projectConfigurations
        self.targets = targets
    }
}

public struct LoadedTarget: Sendable, Equatable {
    public let name: String
    public let configurations: [BuildConfigurationSnapshot]

    public init(name: String, configurations: [BuildConfigurationSnapshot]) {
        self.name = name
        self.configurations = configurations
    }
}

public struct BuildConfigurationSnapshot: Sendable, Equatable {
    public let name: String
    public let inlineSettings: BuildSettings
    public let baseConfigurationPath: String?

    public init(
        name: String,
        inlineSettings: BuildSettings,
        baseConfigurationPath: String?
    ) {
        self.name = name
        self.inlineSettings = inlineSettings
        self.baseConfigurationPath = baseConfigurationPath
    }
}

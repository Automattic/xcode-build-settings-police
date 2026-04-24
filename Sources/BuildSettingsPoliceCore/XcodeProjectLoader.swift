import XcodeProj

public struct XcodeProjectLoader: Sendable {
    public init() {}

    public func load(projectPath: String) throws -> LoadedProject {
        let xcodeProj = try XcodeProj(pathString: projectPath)
        guard let rootProject = xcodeProj.pbxproj.rootObject else {
            throw XcodeProjectLoaderError.missingRootProject
        }
        return LoadedProject(
            name: rootProject.name,
            projectConfigurations: snapshot(rootProject.buildConfigurationList?.buildConfigurations ?? []),
            targets: rootProject.targets.map { target in
                LoadedTarget(
                    name: target.name,
                    configurations: snapshot(target.buildConfigurationList?.buildConfigurations ?? [])
                )
            }
        )
    }

    private func snapshot(_ configurations: [XCBuildConfiguration]) -> [BuildConfigurationSnapshot] {
        configurations.map { configuration in
            BuildConfigurationSnapshot(
                name: configuration.name,
                inlineSettings: configuration.buildSettings,
                baseConfigurationPath: configuration.baseConfiguration?.path
            )
        }
    }
}

public enum XcodeProjectLoaderError: Error, Equatable {
    case missingRootProject
}

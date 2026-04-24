public struct InlineSettingsChecker: Sendable {
    public init() {}

    public func check(_ project: LoadedProject) -> CheckReport {
        var violations: [InlineSettingViolation] = []

        for configuration in project.projectConfigurations where !configuration.inlineSettings.isEmpty {
            violations.append(
                InlineSettingViolation(
                    scope: .project,
                    configurationName: configuration.name,
                    settingKeys: configuration.inlineSettings.keys.sorted()
                )
            )
        }

        for target in project.targets {
            for configuration in target.configurations where !configuration.inlineSettings.isEmpty {
                violations.append(
                    InlineSettingViolation(
                        scope: .target(name: target.name),
                        configurationName: configuration.name,
                        settingKeys: configuration.inlineSettings.keys.sorted()
                    )
                )
            }
        }

        return CheckReport(violations: violations)
    }
}

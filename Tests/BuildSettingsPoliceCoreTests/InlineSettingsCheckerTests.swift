import Testing

@testable import BuildSettingsPoliceCore

struct InlineSettingsCheckerTests {
    @Test func reportsNoViolationsWhenAllConfigurationsAreEmpty() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [
                BuildConfigurationSnapshot(name: "Debug", inlineSettings: [:], baseConfigurationPath: nil),
                BuildConfigurationSnapshot(name: "Release", inlineSettings: [:], baseConfigurationPath: nil),
            ],
            targets: [
                LoadedTarget(
                    name: "App",
                    configurations: [
                        BuildConfigurationSnapshot(name: "Debug", inlineSettings: [:], baseConfigurationPath: nil),
                    ]
                ),
            ]
        )

        let report = InlineSettingsChecker().check(project)

        #expect(!report.hasViolations)
        #expect(report.violations.isEmpty)
    }

    @Test func reportsProjectLevelInlineSettings() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [
                BuildConfigurationSnapshot(
                    name: "Debug",
                    inlineSettings: ["SWIFT_VERSION": "5.10", "SDKROOT": "iphoneos"],
                    baseConfigurationPath: nil
                ),
            ],
            targets: []
        )

        let report = InlineSettingsChecker().check(project)

        #expect(report.violations == [
            InlineSettingViolation(
                scope: .project,
                configurationName: "Debug",
                settingKeys: ["SDKROOT", "SWIFT_VERSION"]
            ),
        ])
    }

    @Test func reportsTargetLevelInlineSettings() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [],
            targets: [
                LoadedTarget(
                    name: "App",
                    configurations: [
                        BuildConfigurationSnapshot(
                            name: "Release",
                            inlineSettings: ["PRODUCT_NAME": "App"],
                            baseConfigurationPath: nil
                        ),
                    ]
                ),
            ]
        )

        let report = InlineSettingsChecker().check(project)

        #expect(report.violations == [
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
        ])
    }

    @Test func reportsProjectAndTargetViolationsTogether() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [
                BuildConfigurationSnapshot(
                    name: "Debug",
                    inlineSettings: ["SWIFT_VERSION": "5.10"],
                    baseConfigurationPath: nil
                ),
            ],
            targets: [
                LoadedTarget(
                    name: "App",
                    configurations: [
                        BuildConfigurationSnapshot(
                            name: "Debug",
                            inlineSettings: ["PRODUCT_NAME": "App"],
                            baseConfigurationPath: nil
                        ),
                    ]
                ),
            ]
        )

        let report = InlineSettingsChecker().check(project)

        #expect(report.hasViolations)
        #expect(report.violations.count == 2)
        #expect(report.violations[0].scope == .project)
        #expect(report.violations[1].scope == .target(name: "App"))
    }

    @Test func sortsSettingKeysAlphabetically() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [
                BuildConfigurationSnapshot(
                    name: "Debug",
                    inlineSettings: ["ZETA": "z", "ALPHA": "a", "MIDDLE": "m"],
                    baseConfigurationPath: nil
                ),
            ],
            targets: []
        )

        let report = InlineSettingsChecker().check(project)

        #expect(report.violations.first?.settingKeys == ["ALPHA", "MIDDLE", "ZETA"])
    }

    @Test func ignoresBaseConfigurationPathWhenDeciding() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [
                BuildConfigurationSnapshot(
                    name: "Debug",
                    inlineSettings: [:],
                    baseConfigurationPath: "Configs/Project.xcconfig"
                ),
            ],
            targets: []
        )

        let report = InlineSettingsChecker().check(project)

        #expect(!report.hasViolations)
    }
}

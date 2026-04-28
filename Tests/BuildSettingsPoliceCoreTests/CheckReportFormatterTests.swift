import Foundation
import Testing

@testable import BuildSettingsPoliceCore

struct CheckReportFormatterTests {
    private let subject = CheckReportFormatter()

    @Test func plainFormatReportsCleanProject() throws {
        let output = try subject.format(CheckReport(violations: []), as: .plain)
        #expect(output == "No inline build settings found.")
    }

    @Test func plainFormatProjectOnlyHeaderShowsSettingCounts() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .project,
                configurationName: "Debug",
                settingKeys: ["SDKROOT", "SWIFT_VERSION"]
            ),
            InlineSettingViolation(
                scope: .project,
                configurationName: "Release",
                settingKeys: ["SDKROOT"]
            ),
        ])

        let output = try subject.format(report, as: .plain)

        #expect(output == """
        Found inline build settings at the project level:
          project [Debug]: 2 settings
          project [Release]: 1 setting
        """)
    }

    @Test func plainFormatSingleTargetHeaderUsesSingularNoun() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
        ])

        let output = try subject.format(report, as: .plain)

        #expect(output == """
        Found inline build settings in 1 target:
          target App [Release]: 1 setting
        """)
    }

    @Test func plainFormatMultipleTargetsHeaderCountsDistinctNames() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Debug",
                settingKeys: ["PRODUCT_NAME"]
            ),
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
            InlineSettingViolation(
                scope: .target(name: "Tests"),
                configurationName: "Debug",
                settingKeys: ["TEST_HOST"]
            ),
        ])

        let output = try subject.format(report, as: .plain)

        let firstLine = output.split(separator: "\n").first
        #expect(firstLine == "Found inline build settings in 2 targets:")
    }

    @Test func plainFormatMixedScopeHeaderMentionsBoth() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .project,
                configurationName: "Debug",
                settingKeys: ["SDKROOT"]
            ),
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
        ])

        let output = try subject.format(report, as: .plain)

        #expect(output == """
        Found inline build settings at the project level and in 1 target:
          project [Debug]: 1 setting
          target App [Release]: 1 setting
        """)
    }

    @Test func plainVerboseFormatListsSettingKeys() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .project,
                configurationName: "Debug",
                settingKeys: ["SDKROOT", "SWIFT_VERSION"]
            ),
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
        ])

        let output = try subject.format(report, as: .plain, verbose: true)

        #expect(output == """
        Found inline build settings at the project level and in 1 target:
          project [Debug]: SDKROOT, SWIFT_VERSION
          target App [Release]: PRODUCT_NAME
        """)
    }

    @Test func jsonFormatReturnsEmptyViolationsArrayForCleanProject() throws {
        let output = try subject.format(CheckReport(violations: []), as: .json)
        let decoded = try JSONDecoder().decode(DecodedPayload.self, from: Data(output.utf8))
        #expect(decoded.violations.isEmpty)
    }

    @Test func jsonFormatEncodesProjectAndTargetViolations() throws {
        let report = CheckReport(violations: [
            InlineSettingViolation(
                scope: .project,
                configurationName: "Debug",
                settingKeys: ["SDKROOT"]
            ),
            InlineSettingViolation(
                scope: .target(name: "App"),
                configurationName: "Release",
                settingKeys: ["PRODUCT_NAME"]
            ),
        ])

        let output = try subject.format(report, as: .json)
        let decoded = try JSONDecoder().decode(DecodedPayload.self, from: Data(output.utf8))

        #expect(decoded.violations == [
            DecodedViolation(scope: "project", target: nil, configuration: "Debug", settings: ["SDKROOT"]),
            DecodedViolation(scope: "target", target: "App", configuration: "Release", settings: ["PRODUCT_NAME"]),
        ])
    }
}

private struct DecodedPayload: Decodable {
    let violations: [DecodedViolation]
}

private struct DecodedViolation: Decodable, Equatable {
    let scope: String
    let target: String?
    let configuration: String
    let settings: [String]
}

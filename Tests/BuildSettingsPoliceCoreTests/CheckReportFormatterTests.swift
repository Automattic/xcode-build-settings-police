import Foundation
import Testing

@testable import BuildSettingsPoliceCore

struct CheckReportFormatterTests {
    private let subject = CheckReportFormatter()

    @Test func plainFormatReportsCleanProject() throws {
        let output = try subject.format(CheckReport(violations: []), as: .plain)
        #expect(output == "No inline build settings found.")
    }

    @Test func plainFormatListsViolations() throws {
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

        let output = try subject.format(report, as: .plain)

        #expect(output == """
        Found 2 inline build setting violation(s):
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

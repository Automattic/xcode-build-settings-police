import Foundation

public enum CheckReportFormat: String, Sendable, Equatable, CaseIterable {
    case plain
    case json
}

public struct CheckReportFormatter: Sendable {
    public init() {}

    public func format(_ report: CheckReport, as format: CheckReportFormat) throws -> String {
        switch format {
        case .plain:
            renderPlain(report)
        case .json:
            try renderJSON(report)
        }
    }

    private func renderPlain(_ report: CheckReport) -> String {
        guard report.hasViolations else {
            return "No inline build settings found."
        }
        let header = "Found \(report.violations.count) inline build setting violation(s):"
        let lines = report.violations.map(describe)
        return ([header] + lines.map { "  \($0)" }).joined(separator: "\n")
    }

    private func describe(_ violation: InlineSettingViolation) -> String {
        let scope = switch violation.scope {
        case .project: "project"
        case .target(let name): "target \(name)"
        }
        return "\(scope) [\(violation.configurationName)]: \(violation.settingKeys.joined(separator: ", "))"
    }

    private func renderJSON(_ report: CheckReport) throws -> String {
        let payload = JSONPayload(violations: report.violations.map(JSONViolation.init))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct JSONPayload: Encodable {
    let violations: [JSONViolation]
}

private struct JSONViolation: Encodable {
    let scope: String
    let target: String?
    let configuration: String
    let settings: [String]

    init(_ violation: InlineSettingViolation) {
        switch violation.scope {
        case .project:
            scope = "project"
            target = nil
        case .target(let name):
            scope = "target"
            target = name
        }
        configuration = violation.configurationName
        settings = violation.settingKeys
    }
}

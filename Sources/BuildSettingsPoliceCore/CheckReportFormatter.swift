import Foundation

public enum CheckReportFormat: String, Sendable, Equatable, CaseIterable {
    case plain
    case json
}

public struct CheckReportFormatter: Sendable {
    public init() {}

    public func format(_ report: CheckReport, as format: CheckReportFormat, verbose: Bool = false) throws -> String {
        switch format {
        case .plain:
            renderPlain(report, verbose: verbose)
        case .json:
            try renderJSON(report)
        }
    }

    private func renderPlain(_ report: CheckReport, verbose: Bool) -> String {
        guard report.hasViolations else {
            return "No inline build settings found."
        }
        let lines = report.violations.map { describe($0, verbose: verbose) }
        return ([headerLine(for: report)] + lines.map { "  \($0)" }).joined(separator: "\n")
    }

    private func headerLine(for report: CheckReport) -> String {
        let hasProject = report.violations.contains { violation in
            if case .project = violation.scope { return true }
            return false
        }
        let targetNames = Set(report.violations.compactMap { violation -> String? in
            if case .target(let name) = violation.scope { return name }
            return nil
        })

        switch (hasProject, targetNames.count) {
        case (true, 0):
            return "Found inline build settings at the project level:"
        case (false, let count):
            return "Found inline build settings in \(pluralize(count, "target")):"
        case (true, let count):
            return "Found inline build settings at the project level and in \(pluralize(count, "target")):"
        }
    }

    private func describe(_ violation: InlineSettingViolation, verbose: Bool) -> String {
        let scope = switch violation.scope {
        case .project: "project"
        case .target(let name): "target \(name)"
        }
        let prefix = "\(scope) [\(violation.configurationName)]"
        if verbose {
            return "\(prefix): \(violation.settingKeys.joined(separator: ", "))"
        }
        return "\(prefix): \(pluralize(violation.settingKeys.count, "setting"))"
    }

    private func pluralize(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
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

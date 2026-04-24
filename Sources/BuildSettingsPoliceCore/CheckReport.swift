public struct CheckReport: Sendable, Equatable {
    public let violations: [InlineSettingViolation]

    public init(violations: [InlineSettingViolation]) {
        self.violations = violations
    }

    public var hasViolations: Bool { !violations.isEmpty }
}

public struct InlineSettingViolation: Sendable, Equatable {
    public let scope: Scope
    public let configurationName: String
    public let settingKeys: [String]

    public init(scope: Scope, configurationName: String, settingKeys: [String]) {
        self.scope = scope
        self.configurationName = configurationName
        self.settingKeys = settingKeys
    }

    public enum Scope: Sendable, Equatable {
        case project
        case target(name: String)
    }
}

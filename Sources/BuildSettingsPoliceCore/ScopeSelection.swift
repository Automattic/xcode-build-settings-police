public struct ScopeSelection: Sendable, Equatable {
    public enum Mode: Sendable, Equatable {
        case all
        case include
        case exclude
    }

    public let mode: Mode
    public let project: Bool
    public let targets: Set<String>

    private init(mode: Mode, project: Bool, targets: Set<String>) {
        self.mode = mode
        self.project = project
        self.targets = targets
    }

    public static let all = ScopeSelection(mode: .all, project: false, targets: [])

    public static func include(project: Bool, targets: Set<String>) -> ScopeSelection {
        ScopeSelection(mode: .include, project: project, targets: targets)
    }

    public static func exclude(project: Bool, targets: Set<String>) -> ScopeSelection {
        ScopeSelection(mode: .exclude, project: project, targets: targets)
    }

    public func includes(_ scope: InlineSettingViolation.Scope) -> Bool {
        switch mode {
        case .all:
            return true
        case .include:
            switch scope {
            case .project:
                return project
            case .target(let name):
                return targets.contains(name)
            }
        case .exclude:
            switch scope {
            case .project:
                return !project
            case .target(let name):
                return !targets.contains(name)
            }
        }
    }

    public func validate(against project: LoadedProject) throws {
        let known = Set(project.targets.map(\.name))
        let unknown = targets.subtracting(known).sorted()
        if !unknown.isEmpty {
            throw UnknownTargetNamesError(names: unknown)
        }
    }
}

public struct UnknownTargetNamesError: Error, Equatable, CustomStringConvertible {
    public let names: [String]

    public init(names: [String]) {
        self.names = names
    }

    public var description: String {
        "Unknown target name(s): \(names.joined(separator: ", "))."
    }
}

public extension CheckReport {
    func filtered(by selection: ScopeSelection) -> CheckReport {
        CheckReport(violations: violations.filter { selection.includes($0.scope) })
    }
}

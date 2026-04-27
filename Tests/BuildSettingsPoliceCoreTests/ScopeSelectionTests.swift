import Testing
@testable import BuildSettingsPoliceCore

struct ScopeSelectionTests {
    @Test func allIncludesEveryScope() {
        let selection = ScopeSelection.all
        #expect(selection.includes(.project))
        #expect(selection.includes(.target(name: "App")))
        #expect(selection.includes(.target(name: "Tests")))
    }

    @Test func includeProjectOnlyAcceptsProjectScope() {
        let selection = ScopeSelection.include(project: true, targets: [])
        #expect(selection.includes(.project))
        #expect(!selection.includes(.target(name: "App")))
    }

    @Test func includeTargetsOnlyAcceptsListedTargets() {
        let selection = ScopeSelection.include(project: false, targets: ["App", "Widget"])
        #expect(!selection.includes(.project))
        #expect(selection.includes(.target(name: "App")))
        #expect(selection.includes(.target(name: "Widget")))
        #expect(!selection.includes(.target(name: "Tests")))
    }

    @Test func excludeProjectKeepsTargets() {
        let selection = ScopeSelection.exclude(project: true, targets: [])
        #expect(!selection.includes(.project))
        #expect(selection.includes(.target(name: "App")))
        #expect(selection.includes(.target(name: "Tests")))
    }

    @Test func excludeTargetsRejectsListedTargetsButKeepsProject() {
        let selection = ScopeSelection.exclude(project: false, targets: ["Tests"])
        #expect(selection.includes(.project))
        #expect(selection.includes(.target(name: "App")))
        #expect(!selection.includes(.target(name: "Tests")))
    }

    @Test func validatePassesWhenAllNamesAreKnown() throws {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [],
            targets: [
                LoadedTarget(name: "App", configurations: []),
                LoadedTarget(name: "Tests", configurations: []),
            ]
        )
        let selection = ScopeSelection.include(project: false, targets: ["App", "Tests"])
        try selection.validate(against: project)
    }

    @Test func validateThrowsForUnknownNamesSorted() {
        let project = LoadedProject(
            name: "App",
            projectConfigurations: [],
            targets: [LoadedTarget(name: "App", configurations: [])]
        )
        let selection = ScopeSelection.exclude(project: false, targets: ["Zeta", "Alpha"])

        #expect(throws: UnknownTargetNamesError(names: ["Alpha", "Zeta"])) {
            try selection.validate(against: project)
        }
    }

    @Test func filteredReportDropsViolationsOutsideSelection() {
        let report = CheckReport(violations: [
            InlineSettingViolation(scope: .project, configurationName: "Debug", settingKeys: ["A"]),
            InlineSettingViolation(scope: .target(name: "App"), configurationName: "Debug", settingKeys: ["B"]),
            InlineSettingViolation(scope: .target(name: "Tests"), configurationName: "Debug", settingKeys: ["C"]),
        ])

        let filtered = report.filtered(by: .exclude(project: false, targets: ["Tests"]))

        #expect(filtered.violations.count == 2)
        #expect(filtered.violations.map(\.scope).contains(.project))
        #expect(filtered.violations.map(\.scope).contains(.target(name: "App")))
        #expect(!filtered.violations.map(\.scope).contains(.target(name: "Tests")))
    }
}

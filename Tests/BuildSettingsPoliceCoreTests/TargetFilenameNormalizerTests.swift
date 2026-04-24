import Testing

@testable import BuildSettingsPoliceCore

struct TargetFilenameNormalizerTests {
    private let subject = TargetFilenameNormalizer()

    @Test func preservesSafeTargetNames() {
        #expect(subject.normalizedFilenameStem(for: "AppTests") == "AppTests")
        #expect(subject.normalizedFilenameStem(for: "App-Tests") == "App-Tests")
        #expect(subject.normalizedFilenameStem(for: "App.Tests") == "App.Tests")
        #expect(subject.normalizedFilenameStem(for: "App_Tests") == "App_Tests")
    }

    @Test func replacesNonStandardCharactersWithUnderscores() {
        #expect(subject.normalizedFilenameStem(for: "App Tests") == "App_Tests")
        #expect(subject.normalizedFilenameStem(for: "App/Tests") == "App_Tests")
        #expect(subject.normalizedFilenameStem(for: "App:Tests") == "App_Tests")
    }

    @Test func collapsesRepeatedReplacementCharacters() {
        #expect(subject.normalizedFilenameStem(for: "App   Tests") == "App_Tests")
        #expect(subject.normalizedFilenameStem(for: "App///Tests") == "App_Tests")
    }

    @Test func dropsLeadingAndTrailingReplacementCharacters() {
        #expect(subject.normalizedFilenameStem(for: " App Tests ") == "App_Tests")
    }

    @Test func returnsFallbackForEmptyStem() {
        #expect(subject.normalizedFilenameStem(for: "") == "Target")
        #expect(subject.normalizedFilenameStem(for: "   ") == "Target")
    }
}

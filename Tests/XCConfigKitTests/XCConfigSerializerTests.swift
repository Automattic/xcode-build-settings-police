import Testing

@testable import XCConfigKit

struct XCConfigSerializerTests {
    @Test func rendersSingleStringSetting() {
        let file = XCConfigFile(settings: ["SWIFT_VERSION": .string("5.10")])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "SWIFT_VERSION = 5.10\n")
    }

    @Test func rendersArrayValueAsSpaceSeparatedPreservingOrder() {
        let file = XCConfigFile(settings: [
            "OTHER_LDFLAGS": .array(["$(inherited)", "-ObjC", "-framework", "CoreData"]),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "OTHER_LDFLAGS = $(inherited) -ObjC -framework CoreData\n")
    }

    @Test func quotesValueContainingDoubleSlashSoItIsNotReadAsComment() {
        let file = XCConfigFile(settings: [
            "USER_HEADER_SEARCH_PATHS": .string("https://example.com/path"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "USER_HEADER_SEARCH_PATHS = \"https://example.com/path\"\n")
    }

    @Test func quotesValueWithTrailingWhitespaceSoItIsPreserved() {
        let file = XCConfigFile(settings: [
            "KEY": .string("value\u{20}"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "KEY = \"value \"\n")
    }

    @Test func quotesValueWithLeadingWhitespaceSoItIsPreserved() {
        let file = XCConfigFile(settings: [
            "KEY": .string("\u{20}value"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "KEY = \" value\"\n")
    }

    @Test func quotesValueContainingSemicolon() {
        let file = XCConfigFile(settings: [
            "KEY": .string("a;b"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "KEY = \"a;b\"\n")
    }

    @Test func rendersEmptyStringValueWithoutTrailingSpace() {
        let file = XCConfigFile(settings: [
            "KEY": .string(""),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "KEY =\n")
    }

    @Test func doesNotQuoteOrdinaryValueWithInternalWhitespace() {
        let file = XCConfigFile(settings: [
            "OTHER_LDFLAGS": .string("$(inherited) -ObjC"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "OTHER_LDFLAGS = $(inherited) -ObjC\n")
    }

    @Test func rendersIncludesInGivenOrderWhenNoSettings() {
        let file = XCConfigFile(includes: ["Parent.xcconfig", "Grandparent.xcconfig"])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == """
        #include "Parent.xcconfig"
        #include "Grandparent.xcconfig"

        """)
    }

    @Test func separatesIncludesAndSettingsWithBlankLine() {
        let file = XCConfigFile(
            includes: ["Parent.xcconfig"],
            settings: ["KEY": .string("value")]
        )

        let output = XCConfigSerializer().serialize(file)

        #expect(output == """
        #include "Parent.xcconfig"

        KEY = value

        """)
    }

    @Test func rendersEmptyFileAsEmptyString() {
        let file = XCConfigFile()

        let output = XCConfigSerializer().serialize(file)

        #expect(output == "")
    }

    @Test func preservesConditionalKeysAndSortsThemAfterTheirBaseKey() {
        let file = XCConfigFile(settings: [
            "KEY[sdk=iphoneos*]": .string("ios"),
            "KEY": .string("base"),
            "ALPHA": .string("a"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == """
        ALPHA = a
        KEY = base
        KEY[sdk=iphoneos*] = ios

        """)
    }

    @Test func sortsSettingsLexicographicallyByKey() {
        let file = XCConfigFile(settings: [
            "ZETA": .string("z"),
            "ALPHA": .string("a"),
            "MIDDLE": .string("m"),
        ])

        let output = XCConfigSerializer().serialize(file)

        #expect(output == """
        ALPHA = a
        MIDDLE = m
        ZETA = z

        """)
    }
}

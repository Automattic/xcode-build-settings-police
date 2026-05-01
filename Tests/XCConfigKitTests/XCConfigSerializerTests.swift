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

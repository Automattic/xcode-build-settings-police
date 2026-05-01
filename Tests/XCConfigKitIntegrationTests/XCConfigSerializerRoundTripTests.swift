import Foundation
import PathKit
import Testing
import XcodeProj

@testable import XCConfigKit

struct XCConfigSerializerRoundTripTests {
    @Test func roundTripsEscapedValuesThroughXcodeProjParser() throws {
        let file = XCConfigFile(settings: [
            "ARRAY_VALUE": .array(["$(inherited)", "\"VALUE\""]),
            "BACKSLASH": .string("\\"),
            "ESCAPED_BACKSLASHES": .string("a\\na"),
            "QUOTED": .string("\"a\""),
        ])

        let temporaryDirectory = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let path = temporaryDirectory.appendingPathComponent("RoundTrip.xcconfig")
        try XCConfigSerializer().serialize(file).write(to: path, atomically: true, encoding: .utf8)

        let parsed = try XCConfig(path: Path(path.path))

        #expect(parsed.buildSettings["QUOTED"]?.stringValue == "\"\\\"a\\\"\"")
        #expect(parsed.buildSettings["BACKSLASH"]?.stringValue == "\"\\\\\"")
        #expect(parsed.buildSettings["ESCAPED_BACKSLASHES"]?.stringValue == "\"a\\\\na\"")
        #expect(parsed.buildSettings["ARRAY_VALUE"]?.stringValue == "$(inherited) \"\\\"VALUE\\\"\"")
    }

    @Test func preservesIncludePathsWhenParsedByXcodeProj() throws {
        let file = XCConfigFile(includes: ["Parent.xcconfig"])

        let temporaryDirectory = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let parentPath = temporaryDirectory.appendingPathComponent("Parent.xcconfig")
        try "\n".write(to: parentPath, atomically: true, encoding: .utf8)

        let path = temporaryDirectory.appendingPathComponent("Child.xcconfig")
        try XCConfigSerializer().serialize(file).write(to: path, atomically: true, encoding: .utf8)

        let parsed = try XCConfig(path: Path(path.path))

        #expect(parsed.includes.count == 1)
        #expect(parsed.includes.first?.include.string == "Parent.xcconfig")
    }

    @Test func preservesSemicolonValuesWhenParsedByXcodeProj() throws {
        let file = XCConfigFile(settings: [
            "SEMICOLON": .string("a;b"),
        ])

        let parsed = try parse(file)

        #expect(parsed.buildSettings["SEMICOLON"]?.stringValue == "\"a;b\"")
    }

    @Test func preservesLeadingAndTrailingWhitespaceWhenParsedByXcodeProj() throws {
        let file = XCConfigFile(settings: [
            "LEADING": .string(" value"),
            "TRAILING": .string("value "),
        ])

        let parsed = try parse(file)

        #expect(parsed.buildSettings["LEADING"]?.stringValue == "\" value\"")
        #expect(parsed.buildSettings["TRAILING"]?.stringValue == "\"value \"")
    }

    @Test func preservesConditionalKeysWhenParsedByXcodeProj() throws {
        let file = XCConfigFile(settings: [
            "KEY[sdk=iphoneos*]": .string("\"ios\""),
        ])

        let parsed = try parse(file)

        #expect(parsed.buildSettings["KEY[sdk=iphoneos*]"]?.stringValue == "\"\\\"ios\\\"\"")
    }
}

private extension FileManager {
    func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("xcconfigkit-integration-tests-\(UUID().uuidString)", isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private func parse(_ file: XCConfigFile) throws -> XCConfig {
    let temporaryDirectory = try FileManager.default.makeTemporaryDirectory()
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let path = temporaryDirectory.appendingPathComponent("RoundTrip.xcconfig")
    try XCConfigSerializer().serialize(file).write(to: path, atomically: true, encoding: .utf8)

    return try XCConfig(path: Path(path.path))
}

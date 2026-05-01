public struct XCConfigSerializer {
    public init() {}

    public func serialize(_ file: XCConfigFile) -> String {
        var lines: [String] = []
        for key in file.settings.keys.sorted() {
            let value = file.settings[key]!
            lines.append("\(key) = \(render(value))")
        }
        return lines.map { $0 + "\n" }.joined()
    }

    private func render(_ value: XCConfigFile.Value) -> String {
        switch value {
        case .string(let raw):
            return raw
        case .array(let elements):
            return elements.joined(separator: " ")
        }
    }
}

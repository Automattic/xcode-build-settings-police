public struct XCConfigSerializer {
    public init() {}

    public func serialize(_ file: XCConfigFile) -> String {
        var blocks: [String] = []
        if !file.includes.isEmpty {
            blocks.append(file.includes.map { "#include \"\($0)\"\n" }.joined())
        }
        if !file.settings.isEmpty {
            var lines: [String] = []
            for key in file.settings.keys.sorted() {
                let value = file.settings[key]!
                let rendered = render(value)
                lines.append(rendered.isEmpty ? "\(key) =" : "\(key) = \(rendered)")
            }
            blocks.append(lines.map { $0 + "\n" }.joined())
        }
        return blocks.joined(separator: "\n")
    }

    private func render(_ value: XCConfigFile.Value) -> String {
        switch value {
        case .string(let raw):
            return quoted(raw)
        case .array(let elements):
            return elements.map(quoted).joined(separator: " ")
        }
    }

    private func quoted(_ raw: String) -> String {
        needsQuoting(raw) ? "\"\(raw)\"" : raw
    }

    private func needsQuoting(_ raw: String) -> Bool {
        if raw.contains("//") || raw.contains(";") {
            return true
        }
        if let first = raw.first, first.isWhitespace {
            return true
        }
        if let last = raw.last, last.isWhitespace {
            return true
        }
        return false
    }
}

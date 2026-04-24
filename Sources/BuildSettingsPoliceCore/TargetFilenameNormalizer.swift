public struct TargetFilenameNormalizer: Sendable {
    public init() {}

    public func normalizedFilenameStem(for targetName: String) -> String {
        let scalars = targetName.unicodeScalars.map { scalar in
            if isAllowed(scalar) {
                return String(scalar)
            } else {
                return "_"
            }
        }

        let collapsed = scalars
            .joined()
            .split(separator: "_", omittingEmptySubsequences: true)
            .joined(separator: "_")

        return collapsed.isEmpty ? "Target" : collapsed
    }

    private func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 48 ... 57, 65 ... 90, 97 ... 122:
            return true
        case 45, 46, 95:
            return true
        default:
            return false
        }
    }
}

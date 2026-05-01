public struct XCConfigFile: Equatable {
    public var includes: [String]
    public var settings: [String: Value]

    public init(includes: [String] = [], settings: [String: Value] = [:]) {
        self.includes = includes
        self.settings = settings
    }

    public enum Value: Equatable {
        case string(String)
        case array([String])
    }
}

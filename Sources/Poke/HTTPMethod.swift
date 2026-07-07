public enum HTTPMethod: String, Sendable {
    case get, post, put, delete, patch, head
}

extension HTTPMethod: CustomStringConvertible {
    public var description: String {
        rawValue.uppercased()
    }
}

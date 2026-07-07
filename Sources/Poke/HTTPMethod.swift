public enum HTTPMethod: String, RawRepresentable, Sendable {
    case get, post, put, delete, patch, head

    public var description: String {
        rawValue.uppercased()
    }
}

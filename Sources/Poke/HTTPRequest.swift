import struct Foundation.Data
import struct Foundation.URL

public typealias HTTPRequestEncodable = Encodable & Sendable

public struct HTTPRequest: Sendable {
    public var url: URL
    public var method: HTTPMethod
    public var headers: [String: String]
    public var body: Data?

    public init(
        url: URL,
        method: HTTPMethod,
        headers: [String: String],
        body: Data?,
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

extension HTTPRequest: CustomStringConvertible {
    /// Headers whose values `description` masks. Lowercased: header names are case-insensitive.
    private static let credentialHeaderNames: Set<String> = [
        "authorization",
        "proxy-authorization",
        "cookie",
        "x-api-key",
    ]

    private static func isCredential(headerName: String) -> Bool {
        credentialHeaderNames.contains(headerName.lowercased())
    }

    public var description: String {
        let headers: String = headers
            .map { (name: String, value: String) in
                let value = Self.isCredential(headerName: name) ? "********" : value
                return "        \(name): \(value)"
            }
            .joined(separator: "\n")

        let body: String? = body.map {
            String(data: $0, encoding: .utf8) ?? $0.description
        }

        return """
        HTTPRequest(
            method: \(method.rawValue.uppercased())
            URL: \(url)
            headers:
        \(headers)
            body: \(body, default: "-")
        )
        """
    }
}

import struct Foundation.Data
import struct Foundation.URL

public typealias HTTPResponseDecodable = Decodable & Sendable

public struct HTTPResponse: Sendable {
    public var url: URL
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(
        url: URL,
        statusCode: Int,
        headers: [String: String],
        body: Data,
    ) {
        self.url = url
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

extension HTTPResponse: CustomStringConvertible {
    public var description: String {
        let headers: String = headers
            .map { (name: String, value: String) in
                "        \(name): \(value)"
            }
            .joined(separator: "\n")

        let body = String(data: body, encoding: .utf8) ?? body.description

        return """
        HTTPResponse:
            URL: \(url)
            status code: \(statusCode)
            headers:
        \(headers)
            body: \(body, default: "-")
        """
    }
}

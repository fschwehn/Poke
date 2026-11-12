import Foundation

public enum HTTPError: Error {
    case networkingFailed(request: HTTPRequest, error: Error)
    case noHttpUrlResponse(
        request: HTTPRequest,
        urlResponse: URLResponse,
        data: Data,
    )
    case encodingFailed(body: any HTTPRequestEncodable, error: Error)
    case decodingFailed(
        request: HTTPRequest,
        response: HTTPResponse,
        error: Error,
    )
    case statusCodeValidationFailed(
        request: HTTPRequest,
        response: HTTPResponse,
    )
}

extension HTTPError: LocalizedError {
    public var errorDescription: String? {
        "HTTP Error"
    }

    public var failureReason: String? {
        switch self {
        case .networkingFailed:
            "Networking failure."
        case .noHttpUrlResponse:
            "Received a non-HTTP response."
        case .encodingFailed:
            "Failed to encode request body."
        case .decodingFailed:
            "Failed to decode response body."
        case let .statusCodeValidationFailed(_, response):
            if let excerpt = Self.excerpt(of: response.body) {
                "The request returned with an unexpected status code: \(response.statusCode). The server said: \(excerpt)"
            } else {
                "The request returned with an unexpected status code: \(response.statusCode)."
            }
        }
    }

    /// The longest body excerpt `failureReason` shows, in characters.
    static let maxExcerptLength = 300

    /// A body as one line of text, cut to `maxExcerptLength`; `nil` for an empty or non-UTF-8 body.
    static func excerpt(of body: Data) -> String? {
        guard let text = String(data: body, encoding: .utf8) else { return nil }

        let line = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard !line.isEmpty else { return nil }

        return line.count > maxExcerptLength ? line.prefix(maxExcerptLength) + "…" : line
    }
}

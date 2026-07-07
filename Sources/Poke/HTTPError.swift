import Foundation

public enum HTTPError: Error {
    case networkgingFailed(request: HTTPRequest, error: Error)
    case noHttpUrlResponse(
        request: HTTPRequest,
        urlReponse: URLResponse,
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
        case .networkgingFailed:
            "Networking failure."
        case .noHttpUrlResponse:
            "Networkging failure."
        case .encodingFailed:
            "Failed to encode request body."
        case .decodingFailed:
            "Failed to decode response body."
        case let .statusCodeValidationFailed(_, response):
            "The request returned with an unexpected status code: \(response.statusCode)."
        }
    }
}

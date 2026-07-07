import Combine
import Foundation
import OSLog

public struct HTTPClient<RequestEncoder: TopLevelEncoder & Sendable, ResponseDecoder: TopLevelDecoder & Sendable> where
    RequestEncoder.Output == Data,
    ResponseDecoder.Input == Data
{
    let baseUrl: URL
    let headers: [String: String]
    let requestEncoder: RequestEncoder
    let responseDecoder: ResponseDecoder
    let urlSession: URLSession

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "-", category: "HTTPClient")

    public init(
        baseUrl: URL,
        headers: [String: String] = [:],
        requestEncoder: RequestEncoder,
        responseDecoder: ResponseDecoder,
        urlSession: URLSession = .shared,
    ) {
        self.baseUrl = baseUrl
        self.headers = headers
        self.requestEncoder = requestEncoder
        self.responseDecoder = responseDecoder
        self.urlSession = urlSession
    }

    public func send<Response: HTTPResponseDecodable>(
        method: HTTPMethod = .get,
        path: String,
        query: [URLQueryItem]? = nil,
        body: (any HTTPRequestEncodable)? = nil,
        as _: Response.Type = Response.self,
    ) async throws(HTTPError) -> Response {
        var url = baseUrl.appendingPathComponent(path)

        if let query {
            url.append(queryItems: query)
        }

        var requestBody: Data? = nil

        if let body {
            do {
                requestBody = try requestEncoder.encode(body)
            } catch {
                throw HTTPError.encodingFailed(body: body, error: error)
            }
        }

        let httpRequest = HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: requestBody,
        )

        let httpResponse: HTTPResponse = try await send(request: httpRequest)

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            logger.warning("Inacceptable status code: \(httpResponse.statusCode)")
            throw .statusCodeValidationFailed(request: httpRequest, response: httpResponse)
        }

        do {
            return try responseDecoder.decode(Response.self, from: httpResponse.body)
        } catch {
            throw .decodingFailed(request: httpRequest, response: httpResponse, error: error)
        }
    }

    public func send(request: HTTPRequest) async throws(HTTPError) -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue.uppercased()

        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        urlRequest.httpBody = request.body

        logger.debug("Sending \(request)")

        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await urlSession.data(for: urlRequest)
        } catch {
            throw .networkgingFailed(request: request, error: error)
        }

        guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
            logger.error("Received non-HTTP URL response: \(urlResponse)")
            throw .noHttpUrlResponse(request: request, urlReponse: urlResponse, data: data)
        }

        let response = HTTPResponse(
            url: request.url,
            statusCode: httpUrlResponse.statusCode,
            headers: httpUrlResponse.allHeaderFields as? [String: String] ?? [:],
            body: data,
        )

        logger.debug("Received \(response)")

        return response
    }
}

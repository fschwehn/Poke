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

    private let logger = Logger(subsystem: "Poke", category: "HTTPClient")

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
        contentType: String = "application/json",
        as _: Response.Type = Response.self,
    ) async throws(HTTPError) -> Response {
        let (httpRequest, httpResponse) = try await sendValidatingStatus(
            method: method,
            path: path,
            query: query,
            body: body,
            contentType: contentType,
        )

        do {
            return try responseDecoder.decode(Response.self, from: httpResponse.body)
        } catch {
            throw .decodingFailed(request: httpRequest, response: httpResponse, error: error)
        }
    }

    /// Sends a request and validates the status code, ignoring the response body.
    ///
    /// Use this for endpoints that legitimately return no body (HTTP `204 No Content`, or a
    /// `200`/`201` with an empty body — common for `POST`/`PUT`/`DELETE`), where there is no
    /// `Response` to decode. A non-2xx status still throws `.statusCodeValidationFailed`.
    public func send(
        method: HTTPMethod = .get,
        path: String,
        query: [URLQueryItem]? = nil,
        body: (any HTTPRequestEncodable)? = nil,
        contentType: String = "application/json",
    ) async throws(HTTPError) {
        _ = try await sendValidatingStatus(
            method: method,
            path: path,
            query: query,
            body: body,
            contentType: contentType,
        )
    }

    /// Builds and sends a request, validating that the response has a 2xx status code.
    ///
    /// Returns both the request and response so callers can attach them to a later
    /// `.decodingFailed` error.
    private func sendValidatingStatus(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem]?,
        body: (any HTTPRequestEncodable)?,
        contentType: String,
    ) async throws(HTTPError) -> (HTTPRequest, HTTPResponse) {
        var url = baseUrl.appendingPathComponent(path)

        if let query {
            url.append(queryItems: query)
        }

        var requestHeaders = headers
        var requestBody: Data? = nil

        if let body {
            do {
                requestBody = try requestEncoder.encode(body)
            } catch {
                throw HTTPError.encodingFailed(body: body, error: error)
            }

            // Set the encoder's content type for the encoded body, unless the
            // caller already supplied one via the client-wide headers.
            let hasContentType = requestHeaders.keys
                .contains { $0.caseInsensitiveCompare("Content-Type") == .orderedSame }
            if !hasContentType {
                requestHeaders["Content-Type"] = contentType
            }
        }

        let httpRequest = HTTPRequest(
            url: url,
            method: method,
            headers: requestHeaders,
            body: requestBody,
        )

        let httpResponse: HTTPResponse = try await send(request: httpRequest)

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            logger.warning("Inacceptable status code: \(httpResponse.statusCode)")
            throw .statusCodeValidationFailed(request: httpRequest, response: httpResponse)
        }

        return (httpRequest, httpResponse)
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
            throw .networkingFailed(request: request, error: error)
        }

        guard let httpUrlResponse = urlResponse as? HTTPURLResponse else {
            logger.error("Received non-HTTP URL response: \(urlResponse)")
            throw .noHttpUrlResponse(request: request, urlResponse: urlResponse, data: data)
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

import Foundation
@testable import Poke
import Testing

@Suite(.serialized)
struct HTTPClientTests {
    struct Widget: Codable, Equatable {
        let id: Int
        let name: String
    }

    struct Ack: Codable {
        let ok: Bool
    }

    /// Records the request seen by the mock so tests can assert on it after the call returns.
    final class Recorder {
        var request: URLRequest?
    }

    let baseUrl = URL(string: "https://example.com")!

    func makeClient() -> HTTPClient<JSONEncoder, JSONDecoder> {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)

        return HTTPClient(
            baseUrl: baseUrl,
            headers: ["Accept": "application/json"],
            requestEncoder: JSONEncoder(),
            responseDecoder: JSONDecoder(),
            urlSession: session,
        )
    }

    func makeResponse(url: URL, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"],
        )!
    }

    @Test
    func `GET decodes a typed response`() async throws {
        let widget = Widget(id: 42, name: "sprocket")
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return try (makeResponse(url: request.url!, statusCode: 200), JSONEncoder().encode(widget))
        }

        let result: Widget = try await makeClient().send(path: "widgets/42")

        #expect(result == widget)
        #expect(recorder.request?.httpMethod == "GET")
        #expect(recorder.request?.url?.path == "/widgets/42")
        #expect(recorder.request?.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test
    func `POST sends the encoded body`() async throws {
        let widget = Widget(id: 7, name: "gear")
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return (makeResponse(url: request.url!, statusCode: 201), Data(#"{"ok":true}"#.utf8))
        }

        let ack: Ack = try await makeClient().send(method: .post, path: "widgets", body: widget)

        #expect(ack.ok)
        #expect(recorder.request?.httpMethod == "POST")

        let sentBody = try #require(recorder.request?.bodyData)
        let decoded = try JSONDecoder().decode(Widget.self, from: sentBody)
        #expect(decoded == widget)
    }

    @Test
    func `a request with a body sets Content-Type`() async throws {
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return (makeResponse(url: request.url!, statusCode: 200), Data(#"{"ok":true}"#.utf8))
        }

        let _: Ack = try await makeClient().send(method: .post, path: "widgets", body: Widget(id: 1, name: "cog"))

        #expect(recorder.request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test
    func `a bodiless request does not set Content-Type`() async throws {
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return try (makeResponse(url: request.url!, statusCode: 200), JSONEncoder().encode(Widget(id: 1, name: "cog")))
        }

        let _: Widget = try await makeClient().send(path: "widgets/1")

        #expect(recorder.request?.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test
    func `query items are appended to the URL`() async throws {
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return (makeResponse(url: request.url!, statusCode: 200), Data("[]".utf8))
        }

        let _: [Widget] = try await makeClient().send(path: "widgets", query: [
            .init(name: "q", value: "gear"),
            .init(name: "limit", value: "10"),
        ])

        let url = try #require(recorder.request?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try #require(components.queryItems)

        #expect(items.contains(URLQueryItem(name: "q", value: "gear")))
        #expect(items.contains(URLQueryItem(name: "limit", value: "10")))
    }

    @Test
    func `non-2xx status throws statusCodeValidationFailed`() async throws {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(url: request.url!, statusCode: 404), Data("not found".utf8))
        }

        let client = makeClient()

        do {
            let _: Widget = try await client.send(path: "widgets/1")
            Issue.record("expected an error to be thrown")
        } catch {
            guard case let .statusCodeValidationFailed(_, response) = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
            #expect(response.statusCode == 404)
        }
    }

    @Test
    func `malformed body throws decodingFailed`() async throws {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(url: request.url!, statusCode: 200), Data("not json".utf8))
        }

        let client = makeClient()

        do {
            let _: Widget = try await client.send(path: "widgets/1")
            Issue.record("expected an error to be thrown")
        } catch {
            guard case .decodingFailed = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
        }
    }

    @Test
    func `the bodiless overload ignores a 204 No Content response`() async throws {
        let recorder = Recorder()

        MockURLProtocol.requestHandler = { request in
            recorder.request = request
            return (makeResponse(url: request.url!, statusCode: 204), Data())
        }

        try await makeClient().send(method: .delete, path: "widgets/1")

        #expect(recorder.request?.httpMethod == "DELETE")
        #expect(recorder.request?.url?.path == "/widgets/1")
    }

    @Test
    func `the bodiless overload ignores an empty body`() async throws {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(url: request.url!, statusCode: 200), Data())
        }

        try await makeClient().send(method: .post, path: "widgets", body: Widget(id: 1, name: "cog"))
    }

    @Test
    func `the bodiless overload still validates the status code`() async throws {
        MockURLProtocol.requestHandler = { request in
            (makeResponse(url: request.url!, statusCode: 500), Data())
        }

        let client = makeClient()

        do {
            try await client.send(method: .delete, path: "widgets/1")
            Issue.record("expected an error to be thrown")
        } catch {
            guard case let .statusCodeValidationFailed(_, response) = error else {
                Issue.record("unexpected error: \(error)")
                return
            }
            #expect(response.statusCode == 500)
        }
    }
}

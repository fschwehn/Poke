import Foundation
@testable import Poke
import Testing

struct HTTPErrorTests {
    func statusError(_ statusCode: Int, body: Data) -> HTTPError {
        let url = URL(string: "https://example.com/widgets/1")!

        return .statusCodeValidationFailed(
            request: HTTPRequest(url: url, method: .get, headers: [:], body: nil),
            response: HTTPResponse(url: url, statusCode: statusCode, headers: [:], body: body),
        )
    }

    @Test
    func `failureReason includes the server's message`() {
        let body = Data(#"{"errorMessages":["Issue does not exist"],"errors":{}}"#.utf8)

        #expect(statusError(404, body: body).failureReason == """
        The request returned with an unexpected status code: 404. \
        The server said: {"errorMessages":["Issue does not exist"],"errors":{}}
        """)
    }

    @Test
    func `failureReason puts a multi-line body on one line`() {
        let body = Data("{\n  \"message\": \"Bad\n   request\"\n}\n".utf8)

        #expect(statusError(400, body: body).failureReason?.hasSuffix(#"The server said: { "message": "Bad request" }"#) == true)
    }

    @Test
    func `failureReason cuts a long body`() throws {
        let body = Data(String(repeating: "x", count: 1000).utf8)
        let reason = try #require(statusError(502, body: body).failureReason)

        #expect(reason.hasSuffix(String(repeating: "x", count: HTTPError.maxExcerptLength) + "…"))
        #expect(!reason.contains(String(repeating: "x", count: HTTPError.maxExcerptLength + 1)))
    }

    @Test(arguments: [Data(), Data(" \n ".utf8), Data([0xFF, 0xFE, 0xFD])])
    func `failureReason without a readable body is the status code only`(body: Data) {
        #expect(statusError(500, body: body).failureReason == "The request returned with an unexpected status code: 500.")
    }
}

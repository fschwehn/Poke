import Foundation
@testable import Poke
import Testing

struct HTTPRequestTests {
    func makeRequest(headers: [String: String]) -> HTTPRequest {
        HTTPRequest(
            url: URL(string: "https://example.com")!,
            method: .get,
            headers: headers,
            body: nil,
        )
    }

    @Test(arguments: ["Authorization", "authorization", "AUTHORIZATION", "Proxy-Authorization", "Cookie", "X-API-Key", "x-api-key"])
    func `description masks credential headers in any spelling`(name: String) {
        let description = makeRequest(headers: [name: "secret-value"]).description

        #expect(!description.contains("secret-value"))
        #expect(description.contains("\(name): ********"))
    }

    @Test
    func `description shows other headers`() {
        let description = makeRequest(headers: ["Accept": "application/json"]).description

        #expect(description.contains("Accept: application/json"))
    }
}

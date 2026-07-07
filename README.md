# Poke

A tiny, modern, typed HTTP client for Swift — a thin wrapper over `URLSession`.

- Generic over any `Codable` encoder/decoder (e.g. `JSONEncoder`/`JSONDecoder`).
- Typed throws: every call fails with a single `HTTPError`.
- `async`/`await` and `Sendable`-clean.
- Injectable `URLSession` for testing; defaults to `.shared`.

Apple platforms only (uses `Combine`, `Foundation`, `OSLog`).

## Installation

Add Poke to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fschwehn/Poke.git", from: "0.1.0"),
]
```

and list it as a target dependency:

```swift
.target(name: "YourTarget", dependencies: ["Poke"])
```

## Usage

```swift
import Poke

let client = HTTPClient(
    baseUrl: URL(string: "https://api.example.com/v1")!,
    headers: ["Accept": "application/json"],
    requestEncoder: JSONEncoder(),
    responseDecoder: JSONDecoder()
)

struct User: Decodable, Sendable {
    let id: Int
    let name: String
}

// GET with the response type inferred from the binding.
let user: User = try await client.send(path: "users/42")

// GET with query items.
let results: [User] = try await client.send(
    path: "users",
    query: [URLQueryItem(name: "q", value: "ada")]
)

// POST with an Encodable body.
struct NewUser: Encodable, Sendable { let name: String }
let created: User = try await client.send(
    method: .post,
    path: "users",
    body: NewUser(name: "Ada")
)
```

When a `body` is sent, `Content-Type` defaults to `application/json`. Override it per call with
the `contentType:` parameter, or set your own `Content-Type` in the client-wide `headers` and it
will be left untouched.

Non-2xx responses, transport failures, and encoding/decoding problems are all surfaced as
`HTTPError`.

## License

Poke is available under the MIT license. See [LICENSE](LICENSE) for details.

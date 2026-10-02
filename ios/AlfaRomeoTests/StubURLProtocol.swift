import Foundation

/// Offline HTTP for parser tests: answers every request from a per-host table, never touches the network.
final class StubURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var table: [String: (status: Int, body: Data)] = [:]

    static func stub(host: String, status: Int = 200, json: String) {
        lock.lock(); defer { lock.unlock() }
        table[host] = (status, Data(json.utf8))
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        table.removeAll()
    }

    private static func response(for host: String) -> (status: Int, body: Data)? {
        lock.lock(); defer { lock.unlock() }
        return table[host]
    }

    /// A session whose every request is served by this protocol (unknown host → 404).
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else { return }
        let (status, body) = Self.response(for: url.host ?? "") ?? (404, Data())
        let http = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

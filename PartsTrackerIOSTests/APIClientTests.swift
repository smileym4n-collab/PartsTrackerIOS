import XCTest
@testable import PartsTrackerIOS

final class APIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testUnauthorizedResponseThrowsLoginState() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.url?.path, "/api/v1/parts")
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let body = #"{"error":{"code":"unauthorized","message":"Authentication is required."}}"#.data(using: .utf8)!
            return (response, body)
        }

        do {
            _ = try await client.parts(perPage: 1)
            XCTFail("Expected unauthorized error")
        } catch APIClientError.unauthorized {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPartsRequestUsesSupportedQueryParameters() async throws {
        let client = makeClient { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(request.url?.path, "/api/v1/parts")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "search" })?.value, "OPA")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "type" })?.value, "Opamp")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "page" })?.value, "2")
            XCTAssertEqual(components?.queryItems?.first(where: { $0.name == "per_page" })?.value, "25")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            let body = #"{"items":[],"pagination":{"page":2,"per_page":25,"total":0,"pages":1}}"#.data(using: .utf8)!
            return (response, body)
        }

        let result = try await client.parts(search: "OPA", type: "Opamp", page: 2, perPage: 25)

        XCTAssertEqual(result.pagination.page, 2)
        XCTAssertEqual(result.items.count, 0)
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        MockURLProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return APIClient(baseURL: URL(string: "https://inventory.example")!, session: session)
    }
}

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}


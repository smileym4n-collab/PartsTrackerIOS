import Foundation

final class APIClient {
    var baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL.normalizedServerBaseURL
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func health() async throws -> HealthResponse {
        try await get("api/v1/health")
    }

    func parts(search: String = "", type: String = "", page: Int = 1, perPage: Int = 50) async throws -> PaginatedResponse<Part> {
        try await get("api/v1/parts", queryItems: listQuery(search: search, page: page, perPage: perPage) + optionalQuery(name: "type", value: type))
    }

    func part(id: Int) async throws -> Part {
        try await get("api/v1/parts/\(id)")
    }

    func projects(search: String = "", status: String = "", tag: String = "", tab: ProjectTab = .active, page: Int = 1, perPage: Int = 50) async throws -> PaginatedResponse<Project> {
        var query = listQuery(search: search, page: page, perPage: perPage)
        query.append(URLQueryItem(name: "tab", value: tab.rawValue))
        query += optionalQuery(name: "status", value: status)
        query += optionalQuery(name: "tag", value: tag)
        return try await get("api/v1/projects", queryItems: query)
    }

    func project(id: Int) async throws -> Project {
        try await get("api/v1/projects/\(id)")
    }

    func buildability(projectID: Int) async throws -> Buildability {
        try await get("api/v1/projects/\(projectID)/buildability")
    }

    func lowStock(search: String = "", type: String = "", page: Int = 1, perPage: Int = 50) async throws -> PaginatedResponse<Part> {
        try await get("api/v1/low-stock", queryItems: listQuery(search: search, page: page, perPage: perPage) + optionalQuery(name: "type", value: type))
    }

    func login(username: String, password: String) async throws {
        var request = URLRequest(url: makeURL("login", queryItems: [URLQueryItem(name: "next", value: "/api/v1/health")]))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody([
            "username": username,
            "password": password,
            "next": "/api/v1/health"
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<400).contains(http.statusCode) else {
            throw APIClientError.httpStatus(http.statusCode)
        }
    }

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        var request = URLRequest(url: makeURL(path, queryItems: queryItems))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIClientError.decoding(error)
            }
        case 401:
            throw APIClientError.unauthorized
        case 403:
            throw APIClientError.forbidden
        case 404:
            throw APIClientError.notFound
        default:
            if let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw APIClientError.api(apiError.error)
            }
            throw APIClientError.httpStatus(http.statusCode)
        }
    }

    private func makeURL(_ path: String, queryItems: [URLQueryItem] = []) -> URL {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var url = baseURL.appendingPathComponent(cleanPath)
        guard !queryItems.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = queryItems
        url = components.url ?? url
        return url
    }

    private func listQuery(search: String, page: Int, perPage: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "page", value: String(max(page, 1))),
            URLQueryItem(name: "per_page", value: String(max(perPage, 1)))
        ]
        items += optionalQuery(name: "search", value: search)
        return items
    }

    private func optionalQuery(name: String, value: String) -> [URLQueryItem] {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? [] : [URLQueryItem(name: name, value: trimmed)]
    }

    private func formBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(key.urlFormEncoded)=\(value.urlFormEncoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }
}

enum APIClientError: LocalizedError, Equatable {
    case invalidBaseURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case httpStatus(Int)
    case api(APIError)
    case decoding(Error)

    static func == (lhs: APIClientError, rhs: APIClientError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidBaseURL, .invalidBaseURL),
            (.invalidResponse, .invalidResponse),
            (.unauthorized, .unauthorized),
            (.forbidden, .forbidden),
            (.notFound, .notFound):
            return true
        case let (.httpStatus(left), .httpStatus(right)):
            return left == right
        case let (.api(left), .api(right)):
            return left == right
        case (.decoding, .decoding):
            return true
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "Enter a valid server address."
        case .invalidResponse:
            return "The server returned an unreadable response."
        case .unauthorized:
            return "Please log in to the inventory server."
        case .forbidden:
            return "Your account does not have permission to view this data."
        case .notFound:
            return "The requested item was not found."
        case let .httpStatus(status):
            return "The server returned HTTP \(status)."
        case let .api(error):
            return error.message
        case .decoding:
            return "The server response did not match the expected API format."
        }
    }
}

private extension URL {
    var normalizedServerBaseURL: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        let trimmedPath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        components?.path = trimmedPath
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? self
    }
}

private extension String {
    var urlFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFormAllowed) ?? self
    }
}

private extension CharacterSet {
    static let urlFormAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return allowed
    }()
}

import Foundation

struct PaginatedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let pagination: Pagination
}

struct Pagination: Decodable, Equatable {
    let page: Int
    let perPage: Int
    let total: Int
    let pages: Int

    var hasNextPage: Bool { page < pages }
    var hasPreviousPage: Bool { page > 1 }
}

struct APIErrorEnvelope: Decodable {
    let error: APIError
}

struct APIError: Decodable, Equatable, Error {
    let code: String
    let message: String
}


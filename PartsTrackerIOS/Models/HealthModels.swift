import Foundation

struct HealthResponse: Decodable, Equatable {
    let status: String
    let api: HealthComponent
    let app: HealthComponent
}

struct HealthComponent: Decodable, Equatable {
    let version: String?
    let status: String
}


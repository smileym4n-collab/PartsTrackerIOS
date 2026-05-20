import Foundation

struct Part: Decodable, Identifiable, Equatable {
    let id: Int
    let partNumber: String
    let name: String
    let manufacturer: String
    let category: String
    let partType: String
    let description: String
    let stock: StockSummary
    let lowStock: Bool
    let reorderStatus: String
    let supplierPartNumbers: SupplierPartNumbers
    let storageLocation: String?
    let datasheetLink: String?
    let tags: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?

    var displayTitle: String {
        partNumber.isEmpty ? name : partNumber
    }
}

struct StockSummary: Decodable, Equatable {
    let physicalQuantity: Int?
    let reservedQuantity: Int
    let availableQuantity: Int?
    let quantityUnknown: Bool
    let lowStockThreshold: Int
    let status: String
    let statusLabel: String
    let lowStock: Bool
    let outOfStock: Bool
}

struct SupplierPartNumbers: Decodable, Equatable {
    let mouser: String
    let digikey: String
    let farnell: String
    let cpc: String?

    var populated: [(String, String)] {
        [
            ("Mouser", mouser),
            ("Digi-Key", digikey),
            ("Farnell", farnell),
            ("CPC", cpc ?? "")
        ].filter { !$0.1.isEmpty }
    }
}


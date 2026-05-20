import Foundation

enum ProjectTab: String, CaseIterable, Identifiable {
    case active
    case archive

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct Project: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let title: String
    let sku: String
    let productCode: String
    let status: String
    let projectStatus: String
    let visibility: String
    let boardRevision: String
    let barePcbStock: BarePCBStock
    let description: String?
    let projectTags: String?
    let pcbName: String?
    let shopProductEnabled: Bool?
    let shopProductType: String?
    let createdAt: String?
    let updatedAt: String?
    let bom: BOMSummary?
    let buildability: Buildability?
}

struct BarePCBStock: Decodable, Equatable {
    let physicalQuantity: Int
    let reservedQuantity: Int
    let availableQuantity: Int
    let limitsBuildability: Bool?
}

struct BOMSummary: Decodable, Equatable {
    let uniquePartsCount: Int
    let totalQuantity: Int
    let stockWarningCount: Int
    let lowStockCount: Int
    let outOfStockCount: Int
    let stockTrackingEnabled: Bool
    let items: [BOMItem]
}

struct BOMItem: Decodable, Identifiable, Equatable {
    let partId: Int?
    let partNumber: String
    let manufacturer: String
    let partType: String
    let description: String
    let quantityRequiredPerUnit: Int
    let physicalQuantity: Int?
    let reservedQuantity: Int
    let availableQuantity: Int?
    let stockStatus: String
    let stockStatusLabel: String
    let supplierPartNumbers: BOMSupplierPartNumbers

    var id: String {
        "\(partId ?? -1)-\(partNumber)-\(quantityRequiredPerUnit)"
    }
}

struct BOMSupplierPartNumbers: Decodable, Equatable {
    let mouser: String
    let digikey: String
    let farnell: String
}

struct Buildability: Decodable, Equatable {
    let project: BuildabilityProject
    let buildableQuantity: Int
    let availabilityState: String
    let availabilityLabel: String
    let componentLimitedQuantity: Int
    let barePcb: BarePCBStock
    let limitingParts: [BuildabilityPart]
    let missingParts: [BuildabilityPart]
    let shortParts: [BuildabilityPart]
}

struct BuildabilityProject: Decodable, Equatable {
    let id: Int
    let name: String
}

struct BuildabilityPart: Decodable, Identifiable, Equatable {
    let partId: Int?
    let partNumber: String
    let manufacturer: String
    let partType: String
    let quantityRequiredPerUnit: Int
    let quantityAvailable: Int
    let buildableUnits: Int

    var id: String {
        "\(partId ?? -1)-\(partNumber)-\(buildableUnits)"
    }
}


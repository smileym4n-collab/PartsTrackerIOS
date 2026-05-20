import XCTest
@testable import PartsTrackerIOS

final class APIDecodingTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    func testPartDecodesFromAPIShape() throws {
        let data = """
        {
          "id": 42,
          "part_number": "OPA1656",
          "name": "OPA1656",
          "manufacturer": "Texas Instruments",
          "category": "Opamp",
          "part_type": "Opamp",
          "description": "Dual low-noise op amp",
          "stock": {
            "physical_quantity": 10,
            "reserved_quantity": 2,
            "available_quantity": 8,
            "quantity_unknown": false,
            "low_stock_threshold": 5,
            "status": "enough",
            "status_label": "Enough Stock",
            "low_stock": false,
            "out_of_stock": false
          },
          "low_stock": false,
          "reorder_status": "ok",
          "supplier_part_numbers": {
            "mouser": "MOU-1",
            "digikey": "DK-1",
            "farnell": "",
            "cpc": ""
          }
        }
        """.data(using: .utf8)!

        let part = try decoder.decode(Part.self, from: data)

        XCTAssertEqual(part.id, 42)
        XCTAssertEqual(part.partNumber, "OPA1656")
        XCTAssertEqual(part.stock.availableQuantity, 8)
        XCTAssertEqual(part.supplierPartNumbers.populated.count, 2)
    }

    func testProjectDetailDecodesBOMAndBuildability() throws {
        let data = """
        {
          "id": 7,
          "name": "ES9023 DAC",
          "title": "ES9023 DAC",
          "sku": "DAC-001",
          "product_code": "DAC-001",
          "status": "active",
          "project_status": "active",
          "visibility": "public",
          "board_revision": "A",
          "bare_pcb_stock": {
            "physical_quantity": 6,
            "reserved_quantity": 1,
            "available_quantity": 5
          },
          "description": "DAC board",
          "project_tags": "audio",
          "pcb_name": "dac-main",
          "shop_product_enabled": true,
          "shop_product_type": "assembled_board",
          "bom": {
            "unique_parts_count": 1,
            "total_quantity": 2,
            "stock_warning_count": 0,
            "low_stock_count": 0,
            "out_of_stock_count": 0,
            "stock_tracking_enabled": true,
            "items": [
              {
                "part_id": 42,
                "part_number": "OPA1656",
                "manufacturer": "TI",
                "part_type": "Opamp",
                "description": "Dual op amp",
                "quantity_required_per_unit": 2,
                "physical_quantity": 10,
                "reserved_quantity": 0,
                "available_quantity": 10,
                "stock_status": "enough",
                "stock_status_label": "Enough Stock",
                "supplier_part_numbers": {
                  "mouser": "",
                  "digikey": "",
                  "farnell": ""
                }
              }
            ]
          },
          "buildability": {
            "project": { "id": 7, "name": "ES9023 DAC" },
            "buildable_quantity": 4,
            "availability_state": "available",
            "availability_label": "Built to order - available",
            "component_limited_quantity": 4,
            "bare_pcb": {
              "physical_quantity": 6,
              "reserved_quantity": 1,
              "available_quantity": 5,
              "limits_buildability": false
            },
            "limiting_parts": [],
            "missing_parts": [],
            "short_parts": []
          }
        }
        """.data(using: .utf8)!

        let project = try decoder.decode(Project.self, from: data)

        XCTAssertEqual(project.name, "ES9023 DAC")
        XCTAssertEqual(project.bom?.uniquePartsCount, 1)
        XCTAssertEqual(project.buildability?.buildableQuantity, 4)
    }
}


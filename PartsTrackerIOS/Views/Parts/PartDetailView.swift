import SwiftUI

struct PartDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    let partID: Int

    @State private var part: Part?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && part == nil {
                LoadingOverlay(title: "Loading part")
            } else if let errorMessage, part == nil {
                ErrorStateView(title: "Could not load part", message: errorMessage) {
                    Task { await load() }
                }
            } else if let part {
                Form {
                    Section {
                        SummaryBanner(
                            title: part.displayTitle,
                            subtitle: partSummary(part),
                            systemImage: "memorychip",
                            tint: stockTint(part.stock)
                        )
                        MetricStrip(metrics: [
                            Metric(title: "Available", value: part.stock.availableQuantity.inventoryDisplay, systemImage: "checkmark.circle", tint: stockTint(part.stock)),
                            Metric(title: "Physical", value: part.stock.physicalQuantity.inventoryDisplay, systemImage: "shippingbox", tint: .blue),
                            Metric(title: "Reserved", value: String(part.stock.reservedQuantity), systemImage: "lock", tint: .gray),
                            Metric(title: "Threshold", value: String(part.stock.lowStockThreshold), systemImage: "gauge.with.dots.needle.bottom.50percent", tint: .orange)
                        ])
                    }

                    Section("Identity") {
                        DetailRow("Part Number", part.partNumber)
                        DetailRow("Name", part.name)
                        DetailRow("Manufacturer", part.manufacturer)
                        DetailRow("Type", part.partType)
                        DetailRow("Location", part.storageLocation)
                    }

                    if !part.description.isEmpty {
                        Section("Description") {
                            Text(part.description)
                        }
                    }

                    Section("Stock") {
                        StockStatusLabel(stock: part.stock)
                        DetailRow("Physical", part.stock.physicalQuantity.inventoryDisplay)
                        DetailRow("Reserved", String(part.stock.reservedQuantity))
                        DetailRow("Available", part.stock.availableQuantity.inventoryDisplay)
                        DetailRow("Threshold", String(part.stock.lowStockThreshold))
                        DetailRow("Status", part.stock.statusLabel)
                    }

                    if !part.supplierPartNumbers.populated.isEmpty {
                        Section("Supplier Part Numbers") {
                            ForEach(part.supplierPartNumbers.populated, id: \.0) { supplier, number in
                                DetailRow(supplier, number)
                            }
                        }
                    }

                    Section("Metadata") {
                        DetailRow("Tags", part.tags)
                        if let datasheet = part.datasheetLink?.nilIfBlank, let url = URL(string: datasheet) {
                            Link(destination: url) {
                                Label("Open Datasheet", systemImage: "doc.text.magnifyingglass")
                            }
                        } else {
                            DetailRow("Datasheet", part.datasheetLink)
                        }
                        DetailRow("Created", part.createdAt)
                        DetailRow("Updated", part.updatedAt)
                    }

                    if let notes = part.notes?.nilIfBlank {
                        Section("Notes") {
                            Text(notes)
                        }
                    }
                }
                .refreshable {
                    await load()
                }
            } else {
                ContentUnavailableView("Part Not Found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(part?.displayTitle ?? "Part")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if part == nil {
                await load()
            }
        }
    }

    private func load() async {
        guard let apiClient = sessionManager.apiClient else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            part = try await apiClient.part(id: partID)
        } catch APIClientError.unauthorized {
            await sessionManager.refreshState()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func partSummary(_ part: Part) -> String {
        let values = [part.manufacturer, part.partType, part.storageLocation ?? ""].filter { !$0.isEmpty }
        if values.isEmpty {
            return part.description.nilIfBlank ?? "No manufacturer, type, or location set."
        }
        return values.joined(separator: " / ")
    }

    private func stockTint(_ stock: StockSummary) -> Color {
        if stock.outOfStock {
            return .red
        }
        if stock.lowStock {
            return .orange
        }
        if stock.quantityUnknown {
            return .gray
        }
        return .green
    }
}

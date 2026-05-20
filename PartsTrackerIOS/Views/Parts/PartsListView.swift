import SwiftUI

struct PartsListView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var parts: [Part] = []
    @State private var pagination: Pagination?
    @State private var searchText = ""
    @State private var typeFilter = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterSheetPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && parts.isEmpty {
                    LoadingOverlay(title: "Loading parts")
                } else if let errorMessage, parts.isEmpty {
                    ErrorStateView(title: "Could not load parts", message: errorMessage) {
                        Task { await load(page: pagination?.page ?? 1) }
                    }
                } else if parts.isEmpty {
                    ContentUnavailableView("No Parts", systemImage: "shippingbox", description: Text("Try a different search or filter."))
                } else {
                    List {
                        Section {
                            SummaryBanner(
                                title: "Inventory",
                                subtitle: "Browse read-only part records from the connected server.",
                                systemImage: "shippingbox",
                                tint: .blue
                            )
                            ListSummaryRow(pagination: pagination, filters: activeFilters)
                        }

                        Section {
                            ForEach(parts) { part in
                                NavigationLink(value: part.id) {
                                    PartRow(part: part)
                                }
                            }
                        }

                        Section {
                            PageControls(
                                pagination: pagination,
                                isLoading: isLoading,
                                previous: { Task { await load(page: max((pagination?.page ?? 1) - 1, 1)) } },
                                next: { Task { await load(page: (pagination?.page ?? 1) + 1) } }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await load(page: pagination?.page ?? 1)
                    }
                }
            }
            .navigationTitle("Parts")
            .navigationDestination(for: Int.self) { partID in
                PartDetailView(partID: partID)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Part number, maker, description")
            .onSubmit(of: .search) {
                Task { await load(page: 1) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        filterSheetPresented = true
                    } label: {
                        Label("Filter", systemImage: typeFilter.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $filterSheetPresented) {
                NavigationStack {
                    Form {
                        Section("Part Type") {
                            TextField("Exact type, such as Resistor", text: $typeFilter)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    .navigationTitle("Filters")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Clear") {
                                typeFilter = ""
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Apply") {
                                filterSheetPresented = false
                                Task { await load(page: 1) }
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task {
                if parts.isEmpty {
                    await load(page: 1)
                }
            }
        }
    }

    private var activeFilters: [String] {
        var filters: [String] = []
        if let search = searchText.nilIfBlank {
            filters.append("Search: \(search)")
        }
        if let type = typeFilter.nilIfBlank {
            filters.append("Type: \(type)")
        }
        return filters
    }

    private func load(page: Int) async {
        guard let apiClient = sessionManager.apiClient else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.parts(search: searchText, type: typeFilter, page: page, perPage: 50)
            parts = response.items
            pagination = response.pagination
        } catch APIClientError.unauthorized {
            await sessionManager.refreshState()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct PartRow: View {
    let part: Part

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(part.displayTitle)
                        .font(.headline)
                        .monospacedDigit()
                    if !part.description.isEmpty {
                        Text(part.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                StockStatusLabel(stock: part.stock)
            }

            if !part.manufacturer.isEmpty || !part.partType.isEmpty {
                StatusPill(
                    text: [part.manufacturer, part.partType].filter { !$0.isEmpty }.joined(separator: " / "),
                    systemImage: "tag",
                    tint: .indigo
                )
            }

            HStack(spacing: 12) {
                Label("Available \(part.stock.availableQuantity.inventoryDisplay)", systemImage: "checkmark.circle")
                Label("Physical \(part.stock.physicalQuantity.inventoryDisplay)", systemImage: "shippingbox")
                if part.stock.reservedQuantity > 0 {
                    Label("Reserved \(part.stock.reservedQuantity)", systemImage: "lock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

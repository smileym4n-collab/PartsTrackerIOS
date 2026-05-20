import SwiftUI

struct ProjectDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    let projectID: Int

    @State private var project: Project?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && project == nil {
                LoadingOverlay(title: "Loading project")
            } else if let errorMessage, project == nil {
                ErrorStateView(title: "Could not load project", message: errorMessage) {
                    Task { await load() }
                }
            } else if let project {
                Form {
                    Section {
                        SummaryBanner(
                            title: project.name.isEmpty ? project.title : project.name,
                            subtitle: projectSummary(project),
                            systemImage: "folder",
                            tint: buildabilityTint(project.buildability)
                        )
                        MetricStrip(metrics: projectMetrics(project))
                    }

                    Section("Summary") {
                        DetailRow("Name", project.name)
                        DetailRow("SKU", project.sku)
                        DetailRow("Status", project.status)
                        DetailRow("Visibility", project.visibility)
                        DetailRow("Board Revision", project.boardRevision)
                        DetailRow("PCB Name", project.pcbName)
                        DetailRow("Tags", project.projectTags)
                    }

                    if let description = project.description?.nilIfBlank {
                        Section("Description") {
                            Text(description)
                        }
                    }

                    Section("Bare PCB Stock") {
                        DetailRow("Physical", String(project.barePcbStock.physicalQuantity))
                        DetailRow("Reserved", String(project.barePcbStock.reservedQuantity))
                        DetailRow("Available", String(project.barePcbStock.availableQuantity))
                    }

                    if let buildability = project.buildability {
                        Section("Buildability") {
                            StatusPill(text: buildability.availabilityLabel.isEmpty ? buildability.availabilityState : buildability.availabilityLabel, systemImage: "hammer", tint: buildabilityTint(buildability))
                            CountBadge(title: "Buildable", value: String(buildability.buildableQuantity), systemImage: "hammer")
                            DetailRow("Availability", buildability.availabilityLabel)
                            DetailRow("Component Limit", String(buildability.componentLimitedQuantity))
                            DetailRow("Bare PCB Limit", buildability.barePcb.limitsBuildability == true ? "Yes" : "No")
                        }

                        if !buildability.shortParts.isEmpty {
                            Section("Short Parts") {
                                ForEach(buildability.shortParts) { part in
                                    BuildabilityPartRow(part: part)
                                }
                            }
                        }
                    }

                    if let bom = project.bom {
                        Section("BOM Summary") {
                            DetailRow("Unique Parts", String(bom.uniquePartsCount))
                            DetailRow("Total Quantity", String(bom.totalQuantity))
                            DetailRow("Warnings", String(bom.stockWarningCount))
                            DetailRow("Low Stock", String(bom.lowStockCount))
                            DetailRow("Out of Stock", String(bom.outOfStockCount))
                        }

                        if !bom.items.isEmpty {
                            Section("BOM Items") {
                                ForEach(bom.items) { item in
                                    BOMItemRow(item: item)
                                }
                            }
                        }
                    }

                    Section("Metadata") {
                        DetailRow("Shop Enabled", project.shopProductEnabled == true ? "Yes" : "No")
                        DetailRow("Shop Type", project.shopProductType)
                        DetailRow("Created", project.createdAt)
                        DetailRow("Updated", project.updatedAt)
                    }
                }
                .refreshable {
                    await load()
                }
            } else {
                ContentUnavailableView("Project Not Found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(project?.name ?? "Project")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if project == nil {
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
            project = try await apiClient.project(id: projectID)
        } catch APIClientError.unauthorized {
            await sessionManager.refreshState()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }

    private func projectSummary(_ project: Project) -> String {
        let values = [project.sku, project.status, project.boardRevision, project.visibility].filter { !$0.isEmpty }
        if values.isEmpty {
            return project.description?.nilIfBlank ?? "No SKU, status, revision, or visibility set."
        }
        return values.joined(separator: " / ")
    }

    private func projectMetrics(_ project: Project) -> [Metric] {
        var metrics = [
            Metric(title: "PCB Available", value: String(project.barePcbStock.availableQuantity), systemImage: "cpu", tint: .teal),
            Metric(title: "PCB Reserved", value: String(project.barePcbStock.reservedQuantity), systemImage: "lock", tint: .gray)
        ]

        if let bom = project.bom {
            metrics.append(Metric(title: "BOM Parts", value: String(bom.uniquePartsCount), systemImage: "list.bullet.rectangle", tint: .blue))
            metrics.append(Metric(title: "Stock Warnings", value: String(bom.stockWarningCount), systemImage: "exclamationmark.triangle", tint: bom.stockWarningCount > 0 ? .orange : .green))
        }

        if let buildability = project.buildability {
            metrics.insert(Metric(title: "Buildable", value: String(buildability.buildableQuantity), systemImage: "hammer", tint: buildabilityTint(buildability)), at: 0)
        }

        return metrics
    }

    private func buildabilityTint(_ buildability: Buildability?) -> Color {
        guard let buildability else { return .teal }
        return buildabilityTint(buildability)
    }

    private func buildabilityTint(_ buildability: Buildability) -> Color {
        switch buildability.availabilityState {
        case "available":
            return .green
        case "limited":
            return .orange
        case "unavailable":
            return .red
        default:
            return .teal
        }
    }
}

private struct BOMItemRow: View {
    let item: BOMItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.partNumber.isEmpty ? "Unnamed Part" : item.partNumber)
                    .font(.headline)
                Spacer()
                Text("x\(item.quantityRequiredPerUnit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text([item.manufacturer, item.partType].filter { !$0.isEmpty }.joined(separator: " / "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Label("Avail \(item.availableQuantity.inventoryDisplay)", systemImage: "checkmark.circle")
                Label(item.stockStatusLabel.isEmpty ? item.stockStatus : item.stockStatusLabel, systemImage: "gauge.with.dots.needle.bottom.50percent")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct BuildabilityPartRow: View {
    let part: BuildabilityPart

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(part.partNumber)
                .font(.headline)
            Text([part.manufacturer, part.partType].filter { !$0.isEmpty }.joined(separator: " / "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Needs \(part.quantityRequiredPerUnit) each, \(part.quantityAvailable) available, supports \(part.buildableUnits) builds")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

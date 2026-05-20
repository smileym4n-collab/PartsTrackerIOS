import SwiftUI

struct ProjectsListView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    @State private var projects: [Project] = []
    @State private var pagination: Pagination?
    @State private var searchText = ""
    @State private var statusFilter = ""
    @State private var tagFilter = ""
    @State private var selectedTab: ProjectTab = .active
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var filterSheetPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && projects.isEmpty {
                    LoadingOverlay(title: "Loading projects")
                } else if let errorMessage, projects.isEmpty {
                    ErrorStateView(title: "Could not load projects", message: errorMessage) {
                        Task { await load(page: pagination?.page ?? 1) }
                    }
                } else if projects.isEmpty {
                    ContentUnavailableView("No Projects", systemImage: "folder", description: Text("Try changing the search, filters, or active/archive tab."))
                } else {
                    List {
                        Section {
                            SummaryBanner(
                                title: selectedTab == .active ? "Active Projects" : "Archived Projects",
                                subtitle: "Review project stock posture, BOM, and buildability without making changes.",
                                systemImage: "folder",
                                tint: .teal
                            )
                            ListSummaryRow(pagination: pagination, filters: activeFilters)
                        }

                        Section {
                            ForEach(projects) { project in
                                NavigationLink(value: project.id) {
                                    ProjectRow(project: project)
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
            .navigationTitle("Projects")
            .navigationDestination(for: Int.self) { projectID in
                ProjectDetailView(projectID: projectID)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Project name, SKU, tag")
            .onSubmit(of: .search) {
                Task { await load(page: 1) }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Project Tab", selection: $selectedTab) {
                        ForEach(ProjectTab.allCases) { tab in
                            Text(tab.label).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .onChange(of: selectedTab) {
                        Task { await load(page: 1) }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        filterSheetPresented = true
                    } label: {
                        Label("Filter", systemImage: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $filterSheetPresented) {
                NavigationStack {
                    Form {
                        Section("Supported Filters") {
                            TextField("Exact status", text: $statusFilter)
                                .textInputAutocapitalization(.never)
                            TextField("Tag", text: $tagFilter)
                                .textInputAutocapitalization(.words)
                        }
                    }
                    .navigationTitle("Filters")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Clear") {
                                statusFilter = ""
                                tagFilter = ""
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
                if projects.isEmpty {
                    await load(page: 1)
                }
            }
        }
    }

    private var filtersActive: Bool {
        !statusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !tagFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeFilters: [String] {
        var filters = ["Tab: \(selectedTab.label)"]
        if let search = searchText.nilIfBlank {
            filters.append("Search: \(search)")
        }
        if let status = statusFilter.nilIfBlank {
            filters.append("Status: \(status)")
        }
        if let tag = tagFilter.nilIfBlank {
            filters.append("Tag: \(tag)")
        }
        return filters
    }

    private func load(page: Int) async {
        guard let apiClient = sessionManager.apiClient else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.projects(search: searchText, status: statusFilter, tag: tagFilter, tab: selectedTab, page: page, perPage: 50)
            projects = response.items
            pagination = response.pagination
        } catch APIClientError.unauthorized {
            await sessionManager.refreshState()
        } catch {
            errorMessage = error.userFacingMessage
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name.isEmpty ? project.title : project.name)
                        .font(.headline)
                    Text(projectMeta)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if !project.status.isEmpty {
                    StatusPill(text: project.status, systemImage: "circle.fill", tint: .blue)
                }
            }

            HStack(spacing: 12) {
                Label("PCB \(project.barePcbStock.availableQuantity) available", systemImage: "cpu")
                Label("\(project.barePcbStock.physicalQuantity) physical", systemImage: "shippingbox")
                if project.barePcbStock.reservedQuantity > 0 {
                    Label("\(project.barePcbStock.reservedQuantity) reserved", systemImage: "lock")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var projectMeta: String {
        let values = [project.sku, project.boardRevision, project.visibility].filter { !$0.isEmpty }
        return values.isEmpty ? "No SKU, revision, or visibility set" : values.joined(separator: " / ")
    }
}

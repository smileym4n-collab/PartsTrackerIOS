import SwiftUI

struct LoadingOverlay: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.circle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
        }
    }
}

struct PageControls: View {
    let pagination: Pagination?
    let isLoading: Bool
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        if let pagination, pagination.pages > 1 {
            HStack {
                Button {
                    previous()
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(!pagination.hasPreviousPage || isLoading)

                Spacer()

                Text("Page \(pagination.page) of \(pagination.pages)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    next()
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .labelStyle(.titleAndIcon)
                .disabled(!pagination.hasNextPage || isLoading)
            }
        }
    }
}

struct SummaryBanner: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 42, height: 42)
                .foregroundStyle(tint)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct MetricStrip: View {
    let metrics: [Metric]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
            ForEach(metrics) { metric in
                MetricTile(title: metric.title, value: metric.value, systemImage: metric.systemImage, tint: metric.tint)
            }
        }
        .padding(.vertical, 4)
    }
}

struct Metric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

struct StatusPill: View {
    let text: String
    let systemImage: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct ListSummaryRow: View {
    let pagination: Pagination?
    let filters: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(totalText, systemImage: "number")
                Spacer()
                if let pagination {
                    Text("Page \(pagination.page) of \(pagination.pages)")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.footnote)

            if !filters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filters, id: \.self) { filter in
                            StatusPill(text: filter, systemImage: "line.3.horizontal.decrease.circle", tint: .blue)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var totalText: String {
        guard let pagination else { return "No results loaded" }
        return "\(pagination.total) result\(pagination.total == 1 ? "" : "s")"
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String?) {
        self.title = title
        self.value = value?.nilIfBlank ?? "Not set"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CountBadge: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
    }
}

struct StockStatusLabel: View {
    let stock: StockSummary

    var body: some View {
        StatusPill(text: label, systemImage: iconName, tint: tint)
    }

    private var label: String {
        stock.statusLabel.isEmpty ? stock.status.capitalized : stock.statusLabel
    }

    private var iconName: String {
        if stock.outOfStock {
            return "xmark.circle"
        }
        if stock.lowStock {
            return "exclamationmark.triangle"
        }
        if stock.quantityUnknown {
            return "questionmark.circle"
        }
        return "checkmark.circle"
    }

    private var tint: Color {
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

extension Optional where Wrapped == Int {
    var inventoryDisplay: String {
        guard let self else { return "Unknown" }
        return String(self)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Error {
    var userFacingMessage: String {
        if let localized = self as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return localizedDescription
    }
}

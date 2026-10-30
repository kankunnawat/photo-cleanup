import SwiftUI

struct ApplyResultCard: View {
    let report: ApplyReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(headline, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .accessibilityIdentifier("apply.result")
            ForEach(details, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    var headline: String {
        switch report.outcome {
        case .completed:
            if let entry = report.logEntry {
                "Deleted \(Formatting.items(entry.deletedCount)), up to \(Formatting.bytes(entry.bytes))"
            } else if report.keptCount > 0 {
                "Added \(Formatting.items(report.keptCount)) to Keep"
            } else {
                "Nothing left to apply"
            }
        case .deleteCancelled:
            "Nothing was deleted"
        case .failed:
            "Apply stopped"
        }
    }

    var details: [String] {
        var lines: [String] = []
        if report.logEntry != nil {
            if report.keptCount > 0 { lines.append("Added \(report.keptCount.formatted()) to the Keep album.") }
            lines.append(SafetyCopy.recentlyDeleted)
        }
        if report.outcome == .deleteCancelled {
            if report.keptCount > 0 { lines.append("Added \(report.keptCount.formatted()) to the Keep album.") }
            lines.append("The items to delete are still queued. Apply again when you are ready.")
        }
        if case .failed(let message) = report.outcome {
            lines.append(message)
            if report.keptCount > 0 { lines.append("Added \(report.keptCount.formatted()) to the Keep album.") }
            lines.append("Nothing was deleted. Your other decisions are still queued.")
        }
        if report.droppedProtected > 0 {
            lines.append("Skipped \(Formatting.items(report.droppedProtected)) that \(isAre(report.droppedProtected)) now protected.")
        }
        if report.droppedMissing > 0 {
            lines.append("Removed \(Formatting.items(report.droppedMissing)) that \(isAre(report.droppedMissing)) no longer in your library.")
        }
        return lines
    }

    private func isAre(_ count: Int) -> String {
        count == 1 ? "is" : "are"
    }

    private var symbol: String {
        switch report.outcome {
        case .completed: "checkmark.circle.fill"
        case .deleteCancelled: "hand.raised.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var tint: Color {
        switch report.outcome {
        case .completed: .keepGreen
        case .deleteCancelled: .secondary
        case .failed: .orange
        }
    }
}

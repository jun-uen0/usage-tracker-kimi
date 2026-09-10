import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var store: UsageStore

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kimi Code Usage")
                .font(.headline)
            if let level = store.membershipLevel {
                Text(level.replacingOccurrences(of: "LEVEL_", with: "").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.entries.isEmpty {
                Text("No usage data yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.entries.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.label)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(entry.remainingPercent.map { "\($0)% left" } ?? "--")
                                .font(.subheadline.monospacedDigit())
                        }
                        HStack {
                            if let used = entry.used, let limit = entry.limit {
                                Text("\(used) / \(limit) used")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let reset = entry.resetTime {
                                Text("resets \(Self.timeFormatter.string(from: reset))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .opacity(store.isStale ? 0.55 : 1)
                }
            }

            Divider()

            if let hint = store.failureHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if store.isStale, let updated = store.lastUpdated {
                Text("Showing last good values from \(Self.timeFormatter.string(from: updated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let updated = store.lastUpdated {
                Text("Updated \(Self.timeFormatter.string(from: updated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Refresh now") {
                    Task { await store.refresh() }
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

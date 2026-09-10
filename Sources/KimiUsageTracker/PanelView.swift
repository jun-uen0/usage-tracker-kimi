import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var store: UsageStore
    @AppStorage("menuBarLabelStyle") private var style = MenuBarLabelStyle.percent.rawValue

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    private static let quotaPageURL = URL(string: "https://www.kimi.ai/settings/subscription?tab=quota")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kimi Code Usage")
                .font(.headline)
            if let level = store.membershipLevel {
                Text(level.replacingOccurrences(of: "LEVEL_", with: "").capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Menu bar style", selection: $style) {
                Text("Percent").tag(MenuBarLabelStyle.percent.rawValue)
                Text("Bar").tag(MenuBarLabelStyle.bar.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

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
                            Text(entry.usedPercent.map { "\($0)% used" } ?? "--")
                                .font(.subheadline.monospacedDigit())
                        }
                        GaugeBar(ratio: entry.usedRatio)
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

            Text("Monthly total usage is only available on the official quota page.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open official quota page") {
                NSWorkspace.shared.open(Self.quotaPageURL)
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

struct GaugeBar: View {
    let ratio: Double?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.15))
                Capsule()
                    .fill(.primary)
                    .frame(width: geo.size.width * min(max(ratio ?? 0, 0), 1))
            }
        }
        .frame(height: 6)
    }
}

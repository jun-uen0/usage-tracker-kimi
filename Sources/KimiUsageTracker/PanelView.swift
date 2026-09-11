import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var store: UsageStore
    @AppStorage("menuBarLabelStyle") private var style = MenuBarLabelStyle.percent.rawValue
    @State private var webTokenInput = ""

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
                            Text(entry.percentText.map { "\($0) used" } ?? "--")
                                .font(.subheadline.monospacedDigit())
                        }
                        GaugeBar(ratio: entry.usedRatio ?? 0,
                                 elapsed: entry.elapsedFraction(at: store.now))
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
                Text("Fill: used. Red marker: even-pace allowance — it moves as time passes. Yellow: using close to or past the pace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            if store.isWebSessionConfigured {
                HStack {
                    Text("Web session (monthly + 7-day): active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove") {
                        store.removeWebRefreshToken()
                    }
                }
            } else {
                Text("To add the monthly total and 7-day window, paste your kimi.ai web refresh token:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                SecureField("refresh_token", text: $webTokenInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") {
                        try? store.saveWebRefreshToken(webTokenInput)
                        webTokenInput = ""
                        Task { await store.refresh() }
                    }
                    .disabled(webTokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Spacer()
                }
                Text("kimi.ai quota page → DevTools → Application → Local Storage → refresh_token → copy value. Stored locally with 0600 permissions; the browser session keeps working.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Open official quota page") {
                NSWorkspace.shared.open(Self.quotaPageURL)
            }

            Divider()

            if let hint = store.webSessionHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
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
    let ratio: Double
    var elapsed: Double? = nil

    // Usage within this margin of the pace pointer counts as "approaching".
    private static let nearMargin = 0.03

    private var nearPace: Bool {
        guard let elapsed else { return false }
        return ratio >= elapsed - Self.nearMargin
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.15))
                Capsule()
                    .fill(nearPace ? Color.yellow : Color.primary)
                    .frame(width: geo.size.width * min(max(ratio, 0), 1))
                if let elapsed {
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: geo.size.width * min(max(elapsed, 0), 1) - 1)
                }
            }
        }
        .frame(height: 6)
    }
}

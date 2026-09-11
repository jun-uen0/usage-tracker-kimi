import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var entries: [LimitEntry] = []
    @Published private(set) var membershipLevel: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isStale = false
    @Published private(set) var failure: UsageFetchError?
    // Wall clock for time-based UI (the pace pointer drifts with time even
    // between quota refreshes).
    @Published private(set) var now = Date()

    private let client = UsageClient()
    private let webClient = WebSessionClient()
    private var timer: Timer?
    private var clock: Timer?

    private var lastGoodURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        return base.appendingPathComponent("usage-tracker-kimi/last-good.json")
    }

    func start() {
        guard timer == nil else { return }
        restoreLastGood()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        clock = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    func refresh() async {
        // The web session (when configured) exposes more accurate ratios plus
        // the 7-day and monthly windows; the CLI API is the fallback.
        if webClient.isConfigured {
            switch await webClient.fetchEntries() {
            case .success(let entries):
                apply(entries: entries, membershipLevel: membershipLevel)
                webSessionError = nil
                return
            case .failure(let error):
                webSessionError = error
            }
        } else {
            webSessionError = nil
        }

        switch await client.fetch() {
        case .success(let snapshot):
            apply(entries: snapshot.limitEntries, membershipLevel: snapshot.membershipLevel)
        case .failure(let error):
            failure = error
            isStale = lastUpdated != nil
        }
    }

    private func apply(entries: [LimitEntry], membershipLevel: String?) {
        self.entries = entries
        if let membershipLevel { self.membershipLevel = membershipLevel }
        lastUpdated = Date()
        isStale = false
        failure = nil
        persist(UsageSnapshot(fetchedAt: Date(), membershipLevel: self.membershipLevel,
                              entries: entries))
    }

    @Published private(set) var webSessionError: WebSessionError?

    var isWebSessionConfigured: Bool { webClient.isConfigured }

    func saveWebRefreshToken(_ token: String) throws {
        try webClient.saveRefreshToken(token)
        webSessionError = nil
    }

    func removeWebRefreshToken() {
        webClient.removeRefreshToken()
        webSessionError = nil
    }

    // The window shown in the menu bar: prefer the 5-hour window; otherwise
    // fall back to the longest window available.
    var primaryEntry: LimitEntry? {
        if let fiveHour = entries.first(where: { $0.isFiveHour }) { return fiveHour }
        return entries.max(by: { $0.windowSeconds < $1.windowSeconds })
    }

    var failureHint: String? {
        switch failure {
        case .none: return nil
        case .tokenExpired:
            return "Sign-in expired. Use the Kimi CLI once to renew it."
        case .noCredentials:
            return "No Kimi Code credentials found. Sign in with the Kimi CLI first."
        case .http(let code):
            return "Quota request failed (HTTP \(code))."
        case .network:
            return "Network error while reading quota."
        case .decoding:
            return "Quota response format not recognized."
        }
    }

    var webSessionHint: String? {
        switch webSessionError {
        case .none, .notConfigured: return nil
        case .refreshRejected:
            return "Web session expired. Re-paste the refresh token from the browser."
        case .http(let code):
            return "Web quota request failed (HTTP \(code))."
        case .network:
            return "Network error while reading web quota."
        case .decoding:
            return "Web quota response format changed."
        }
    }

    private func persist(_ snapshot: UsageSnapshot) {
        let url = lastGoodURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: url, options: .atomic)
        } catch {
            // Persistence is best-effort; stale display still works in memory.
        }
    }

    private func restoreLastGood() {
        guard let data = try? Data(contentsOf: lastGoodURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(UsageSnapshot.self, from: data) else { return }
        entries = snapshot.limitEntries
        membershipLevel = snapshot.membershipLevel
        lastUpdated = snapshot.fetchedAt
        isStale = true
    }
}

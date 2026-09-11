import Foundation

// Decodable mirrors of GET /coding/v1/usages. Unknown fields are ignored on
// purpose; everything we read is optional so a partial schema change degrades
// instead of failing the whole decode.

struct UsageResponse: Decodable {
    let limits: [UsageLimit]?
    let user: UsageUser?
}

struct UsageLimit: Decodable {
    let window: UsageWindow?
    let detail: UsageDetail?
}

struct UsageWindow: Decodable {
    let duration: Int?
    let timeUnit: String?
}

struct UsageDetail: Decodable {
    let limit: String?
    let used: String?
    let remaining: String?
    let resetTime: String?
}

struct UsageUser: Decodable {
    let membership: UsageMembership?
}

struct UsageMembership: Decodable {
    let level: String?
}

// Presentation model derived from UsageLimit.

struct LimitEntry {
    let windowSeconds: Int
    let limit: Int?
    let used: Int?
    let remaining: Int?
    let resetTime: Date?
    // Web-session entries carry a precise ratio instead of request counts.
    let ratio: Double?
    // Overrides the computed label (e.g. "Monthly total").
    let displayLabel: String?

    var isFiveHour: Bool { windowSeconds == 300 * 60 }
    var isMonthly: Bool { windowSeconds >= 28 * 24 * 3600 }
    var isSevenDay: Bool { !isMonthly && windowSeconds >= 7 * 24 * 3600 }

    var label: String {
        if let displayLabel { return displayLabel }
        if isFiveHour { return "5-hour window" }
        if isMonthly { return "Monthly window" }
        if isSevenDay { return "7-day window" }
        let hours = windowSeconds / 3600
        if hours >= 24, hours % 24 == 0 { return "\(hours / 24)-day window" }
        if hours >= 1, windowSeconds % 3600 == 0 { return "\(hours)-hour window" }
        return "\(windowSeconds / 60)-minute window"
    }

    // Short suffix shown next to the menu bar label for non-5-hour windows.
    var shortMarker: String? {
        if isFiveHour { return nil }
        if isMonthly { return "M" }
        if isSevenDay { return "7d" }
        return nil
    }

    var usedPercent: Int? {
        guard let used, let limit, limit > 0 else { return nil }
        return Int((Double(used) / Double(limit) * 100).rounded())
    }

    // Menu bar / panel text: integer for request-count entries, one decimal
    // for ratio-based (web session) entries, matching the official page.
    var percentText: String? {
        if let percent = usedPercent { return "\(percent)%" }
        guard let ratio else { return nil }
        return String(format: "%.1f%%", min(max(ratio, 0), 1) * 100)
    }

    var usedRatio: Double? {
        if let used, let limit, limit > 0 {
            return min(max(Double(used) / Double(limit), 0), 1)
        }
        return ratio.map { min(max($0, 0), 1) }
    }

    // The window starts one full window before its reset time.
    var windowStart: Date? {
        resetTime.map { $0.addingTimeInterval(-TimeInterval(windowSeconds)) }
    }

    // Fraction of the window already elapsed at `now` (0...1). This is the
    // even-pace usage allowance: at 50% of the window you should have used
    // about 50% of the quota. Returns nil when the reset time is unknown.
    func elapsedFraction(at now: Date) -> Double? {
        guard let start = windowStart else { return nil }
        let fraction = now.timeIntervalSince(start) / TimeInterval(windowSeconds)
        return min(max(fraction, 0), 1)
    }

    init?(_ raw: UsageLimit) {
        guard let duration = raw.window?.duration, duration > 0 else { return nil }
        let unit = raw.window?.timeUnit ?? ""
        switch unit {
        case "TIME_UNIT_SECOND": windowSeconds = duration
        case "TIME_UNIT_MINUTE": windowSeconds = duration * 60
        case "TIME_UNIT_HOUR": windowSeconds = duration * 3600
        case "TIME_UNIT_DAY": windowSeconds = duration * 86400
        default: return nil
        }
        limit = raw.detail?.limit.flatMap(Int.init)
        used = raw.detail?.used.flatMap(Int.init)
        remaining = raw.detail?.remaining.flatMap(Int.init)
        resetTime = raw.detail?.resetTime.flatMap(Self.parseResetTime)
        ratio = nil
        displayLabel = nil
    }

    private static func parseResetTime(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

struct UsageSnapshot: Codable {
    let fetchedAt: Date
    let membershipLevel: String?
    let entries: [Entry]

    struct Entry: Codable {
        let windowSeconds: Int
        let limit: Int?
        let used: Int?
        let remaining: Int?
        let resetTime: Date?
        let ratio: Double?
        let displayLabel: String?
    }

    init(response: UsageResponse, fetchedAt: Date) {
        self.fetchedAt = fetchedAt
        membershipLevel = response.user?.membership?.level
        entries = (response.limits ?? []).compactMap { raw in
            guard let e = LimitEntry(raw) else { return nil }
            return Entry(windowSeconds: e.windowSeconds, limit: e.limit,
                         used: e.used, remaining: e.remaining, resetTime: e.resetTime,
                         ratio: e.ratio, displayLabel: e.displayLabel)
        }
    }

    init(fetchedAt: Date, membershipLevel: String?, entries: [LimitEntry]) {
        self.fetchedAt = fetchedAt
        self.membershipLevel = membershipLevel
        self.entries = entries.map {
            Entry(windowSeconds: $0.windowSeconds, limit: $0.limit,
                  used: $0.used, remaining: $0.remaining, resetTime: $0.resetTime,
                  ratio: $0.ratio, displayLabel: $0.displayLabel)
        }
    }

    var limitEntries: [LimitEntry] {
        entries.map { e in
            LimitEntry(windowSeconds: e.windowSeconds, limit: e.limit,
                       used: e.used, remaining: e.remaining, resetTime: e.resetTime,
                       ratio: e.ratio, displayLabel: e.displayLabel)
        }
    }
}

extension LimitEntry {
    init(windowSeconds: Int, limit: Int?, used: Int?, remaining: Int?, resetTime: Date?,
         ratio: Double? = nil, displayLabel: String? = nil) {
        self.windowSeconds = windowSeconds
        self.limit = limit
        self.used = used
        self.remaining = remaining
        self.resetTime = resetTime
        self.ratio = ratio
        self.displayLabel = displayLabel
    }
}

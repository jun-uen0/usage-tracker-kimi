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

    var isFiveHour: Bool { windowSeconds == 300 * 60 }
    var isWeekly: Bool { windowSeconds >= 7 * 24 * 3600 }

    var label: String {
        if isFiveHour { return "5-hour window" }
        if isWeekly { return "Weekly window" }
        let hours = windowSeconds / 3600
        if hours >= 24, hours % 24 == 0 { return "\(hours / 24)-day window" }
        if hours >= 1, windowSeconds % 3600 == 0 { return "\(hours)-hour window" }
        return "\(windowSeconds / 60)-minute window"
    }

    var usedPercent: Int? {
        guard let used, let limit, limit > 0 else { return nil }
        return Int((Double(used) / Double(limit) * 100).rounded())
    }

    var usedRatio: Double? {
        guard let used, let limit, limit > 0 else { return nil }
        return min(max(Double(used) / Double(limit), 0), 1)
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
    }

    init(response: UsageResponse, fetchedAt: Date) {
        self.fetchedAt = fetchedAt
        membershipLevel = response.user?.membership?.level
        entries = (response.limits ?? []).compactMap { raw in
            guard let e = LimitEntry(raw) else { return nil }
            return Entry(windowSeconds: e.windowSeconds, limit: e.limit,
                         used: e.used, remaining: e.remaining, resetTime: e.resetTime)
        }
    }

    var limitEntries: [LimitEntry] {
        entries.map { e in
            LimitEntry(windowSeconds: e.windowSeconds, limit: e.limit,
                       used: e.used, remaining: e.remaining, resetTime: e.resetTime)
        }
    }
}

extension LimitEntry {
    init(windowSeconds: Int, limit: Int?, used: Int?, remaining: Int?, resetTime: Date?) {
        self.windowSeconds = windowSeconds
        self.limit = limit
        self.used = used
        self.remaining = remaining
        self.resetTime = resetTime
    }
}

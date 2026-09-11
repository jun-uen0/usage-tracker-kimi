import Foundation

enum WebSessionError: Error {
    case notConfigured
    case refreshRejected
    case http(Int)
    case network
    case decoding
}

// Fetches the official quota page's own data source. The CLI API only exposes
// the 5-hour window; the monthly total (subscriptionBalance) and the 7-day
// rate limit are only available on the kimi.ai web gateway, which authenticates
// with the browser session's tokens. A refresh token copied once from the
// browser (DevTools > Application > Local Storage > refresh_token) is kept in
// a 0600 file; each exchange mints a 15-minute access token and returns a
// rotated refresh token that is persisted in its place. The server keeps
// rotated refresh tokens valid, so this copy survives in parallel with the
// browser's own session.

final class WebSessionClient {
    private static let refreshURL = URL(string: "https://auth.kimi.ai/api/account.gateway.v1.AuthService/RefreshToken")!
    private static let statsURL = URL(string: "https://www.kimi.ai/apiv2/kimi.gateway.membership.v2.MembershipService/GetSubscriptionStats")!

    private var cachedAccessToken: (token: String, expiresAt: Date)?

    private var baseDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory,
                                 in: .userDomainMask)[0]
            .appendingPathComponent("usage-tracker-kimi")
    }

    private var refreshTokenURL: URL {
        baseDir.appendingPathComponent("web-refresh-token")
    }

    var isConfigured: Bool { readRefreshToken() != nil }

    func saveRefreshToken(_ token: String) throws {
        try FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        try trimmed.write(to: refreshTokenURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                              ofItemAtPath: refreshTokenURL.path)
        cachedAccessToken = nil
    }

    func removeRefreshToken() {
        try? FileManager.default.removeItem(at: refreshTokenURL)
        cachedAccessToken = nil
    }

    func fetchEntries() async -> Result<[LimitEntry], WebSessionError> {
        guard let refreshToken = readRefreshToken() else { return .failure(.notConfigured) }

        let accessToken: String
        if let cached = cachedAccessToken,
           cached.expiresAt > Date().addingTimeInterval(60) {
            accessToken = cached.token
        } else {
            switch await exchange(refreshToken) {
            case .success(let tokens):
                persistRotatedRefreshToken(tokens.refreshToken)
                cachedAccessToken = (tokens.accessToken, Self.expiry(of: tokens.accessToken))
                accessToken = tokens.accessToken
            case .failure(let error):
                return .failure(error)
            }
        }

        var request = URLRequest(url: Self.statsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.network)
        }
        guard let http = response as? HTTPURLResponse else { return .failure(.network) }
        guard http.statusCode == 200 else {
            return .failure(http.statusCode == 401 ? .refreshRejected : .http(http.statusCode))
        }
        do {
            let stats = try JSONDecoder().decode(SubscriptionStats.self, from: data)
            return .success(Self.makeEntries(from: stats))
        } catch {
            return .failure(.decoding)
        }
    }

    private func readRefreshToken() -> String? {
        guard let raw = try? String(contentsOf: refreshTokenURL, encoding: .utf8)
        else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistRotatedRefreshToken(_ token: String) {
        try? token.write(to: refreshTokenURL, atomically: true, encoding: .utf8)
    }

    private func exchange(_ refreshToken: String) async -> Result<(accessToken: String, refreshToken: String), WebSessionError> {
        var request = URLRequest(url: Self.refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["refresh_token": refreshToken])
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.network)
        }
        guard let http = response as? HTTPURLResponse else { return .failure(.network) }
        guard http.statusCode == 200 else {
            return .failure(http.statusCode == 401 ? .refreshRejected : .http(http.statusCode))
        }
        do {
            let decoded = try JSONDecoder().decode(TokenExchangeResponse.self, from: data)
            return .success((decoded.accessToken, decoded.refreshToken))
        } catch {
            return .failure(.decoding)
        }
    }

    // Reads the exp claim without verifying the signature; the token is sent
    // back to its issuer either way.
    private static func expiry(of jwt: String) -> Date {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return Date() }
        var payload = String(parts[1])
        while payload.count % 4 != 0 { payload.append("=") }
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = (obj["exp"] as? NSNumber)?.doubleValue
        else { return Date() }
        return Date(timeIntervalSince1970: exp)
    }
}

private struct TokenExchangeResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

// Mirrors MembershipService/GetSubscriptionStats. Only the fields we use are
// listed; everything else is ignored so schema changes degrade gracefully.
struct SubscriptionStats: Decodable {
    let ratelimitCode5h: RateLimit?
    let ratelimitCode7d: RateLimit?
    let subscriptionBalance: Balance?

    struct RateLimit: Decodable {
        let ratio: Double?
        let enabled: Bool?
        let resetTime: String?
    }

    struct Balance: Decodable {
        let amountUsedRatio: Double?
        let expireTime: String?
    }
}

extension WebSessionClient {
    static func makeEntries(from stats: SubscriptionStats) -> [LimitEntry] {
        var out: [LimitEntry] = []
        if let fiveHour = stats.ratelimitCode5h,
           fiveHour.enabled != false, let ratio = fiveHour.ratio {
            out.append(LimitEntry(windowSeconds: 300 * 60, limit: nil, used: nil,
                                  remaining: nil, resetTime: parseTimestamp(fiveHour.resetTime),
                                  ratio: ratio))
        }
        if let sevenDay = stats.ratelimitCode7d,
           sevenDay.enabled != false, let ratio = sevenDay.ratio {
            out.append(LimitEntry(windowSeconds: 7 * 24 * 3600, limit: nil, used: nil,
                                  remaining: nil, resetTime: parseTimestamp(sevenDay.resetTime),
                                  ratio: ratio))
        }
        if let balance = stats.subscriptionBalance,
           let ratio = balance.amountUsedRatio,
           let expire = parseTimestamp(balance.expireTime) {
            // The balance resets on the billing date; approximate the window
            // as one calendar month for the pace pointer.
            let start = Calendar.current.date(byAdding: .month, value: -1, to: expire) ?? expire
            let windowSeconds = max(Int(expire.timeIntervalSince(start)), 1)
            out.append(LimitEntry(windowSeconds: windowSeconds, limit: nil, used: nil,
                                  remaining: nil, resetTime: expire, ratio: ratio,
                                  displayLabel: "Monthly total"))
        }
        return out
    }

    // Tolerant ISO8601 parser: the gateway emits nanosecond fractions that
    // ISO8601DateFormatter rejects, so clamp them to milliseconds first.
    static func parseTimestamp(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let clamped: String
        if let regex = try? NSRegularExpression(pattern: #"^(.*\.\d{3})\d+(.*)$"#),
           let m = regex.firstMatch(in: s, options: [],
                                    range: NSRange(s.startIndex..., in: s)),
           let head = Range(m.range(at: 1), in: s) {
            let tail = Range(m.range(at: 2), in: s).map { String(s[$0]) } ?? ""
            clamped = String(s[head]) + tail
        } else {
            clamped = s
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = formatter.date(from: clamped) { return d }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: clamped)
    }
}

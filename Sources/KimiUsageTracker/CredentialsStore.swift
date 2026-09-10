import Foundation

struct Credentials {
    let accessToken: String
    let expiresAt: Date
}

enum CredentialsError: Error {
    case notFound
    case expired(Date)
}

// Reads the Kimi Code CLI's own sign-in state. Only the access token and its
// expiry are read; the refresh token is never touched and the file is never
// written. Reloaded on every fetch cycle because the CLI rotates the token.
struct CredentialsStore {
    func load() throws -> Credentials {
        let env = ProcessInfo.processInfo.environment
        let home = env["KIMI_CODE_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".kimi-code").path
        let dir = URL(fileURLWithPath: home).appendingPathComponent("credentials")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)) ?? []

        var best: Credentials?
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = obj["access_token"] as? String,
                  let expiresAt = (obj["expires_at"] as? NSNumber)?.doubleValue
            else { continue }
            let candidate = Credentials(accessToken: token,
                                        expiresAt: Date(timeIntervalSince1970: expiresAt))
            if let current = best {
                if candidate.expiresAt > current.expiresAt { best = candidate }
            } else {
                best = candidate
            }
        }
        guard let credentials = best else { throw CredentialsError.notFound }
        if credentials.expiresAt <= Date() {
            throw CredentialsError.expired(credentials.expiresAt)
        }
        return credentials
    }
}

import Foundation

enum UsageFetchError: Error {
    case noCredentials
    case tokenExpired
    case http(Int)
    case network
    case decoding
}

struct UsageClient {
    private let endpoint = URL(string: "https://api.kimi.ai/coding/v1/usages")!
    private let credentialsStore = CredentialsStore()

    func fetch() async -> Result<UsageSnapshot, UsageFetchError> {
        let credentials: Credentials
        do {
            credentials = try credentialsStore.load()
        } catch CredentialsError.expired {
            return .failure(.tokenExpired)
        } catch {
            return .failure(.noCredentials)
        }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(credentials.accessToken)",
                         forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .failure(.network)
        }
        guard let http = response as? HTTPURLResponse else { return .failure(.network) }
        guard http.statusCode == 200 else { return .failure(.http(http.statusCode)) }
        do {
            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            return .success(UsageSnapshot(response: decoded, fetchedAt: Date()))
        } catch {
            return .failure(.decoding)
        }
    }
}

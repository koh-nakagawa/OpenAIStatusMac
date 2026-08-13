import Foundation

public enum StatusClientError: LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "ステータスサーバーから不正な応答を受信しました。"
        case .httpStatus(let code):
            "ステータスサーバーがエラーを返しました（HTTP \(code)）。"
        }
    }
}

public enum OpenAIStatusClient {
    public static let statusPageURL = URL(string: "https://status.openai.com/")!
    public static let summaryURL = URL(string: "https://status.openai.com/api/v2/summary.json")!
    public static let incidentsURL = URL(string: "https://status.openai.com/api/v2/incidents.json")!

    public static func fetchSnapshot() async throws -> OpenAIStatusSnapshot {
        async let summary: StatusSummaryResponse = fetch(summaryURL)
        async let incidents: IncidentsResponse = fetch(incidentsURL)
        return try await OpenAIStatusSnapshot(summary: summary, incidents: incidents)
    }

    private static func fetch<T: Decodable & Sendable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadRevalidatingCacheData
        request.setValue("OpenAIStatusMac/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StatusClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw StatusClientError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

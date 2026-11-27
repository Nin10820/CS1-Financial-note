import Foundation

/// Today's exchange rates in đồng, from ExchangeRate-API's free daily list (open.er-api.com).
/// This is the one thing the app downloads: a public list of rates, the same for everyone.
/// Nothing about you or your money is sent. The free terms ask us to name the source.
enum LiveRates {
    static let source = "ExchangeRate-API"
    private static let url = URL(string: "https://open.er-api.com/v6/latest/USD")!

    private struct Reply: Decodable {
        let result: String
        let time_last_update_unix: TimeInterval
        let rates: [String: Double]
    }

    /// Đồng for 1 of each code, e.g. ["USD": 25783, "EUR": 28294], and when the list was made.
    static func fetch(codes: [String]) async throws -> (rates: [String: Double], updated: Date) {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        let (data, _) = try await URLSession.shared.data(for: request)
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard reply.result == "success", let vnd = reply.rates["VND"], vnd > 0 else {
            throw URLError(.cannotParseResponse)
        }
        var out: [String: Double] = [:]
        for code in codes {
            if let r = reply.rates[code], r > 0 { out[code] = (vnd / r).rounded() }
        }
        return (out, Date(timeIntervalSince1970: reply.time_last_update_unix))
    }
}

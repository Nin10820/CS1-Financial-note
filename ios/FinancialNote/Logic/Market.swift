import Foundation
import Network
import SwiftData

/// The unit an asset is held in: foreign money, gold by the chỉ / phân / lượng, or a coin.
nonisolated enum HoldingUnit: String, CaseIterable, Identifiable, Sendable {
    case usd, eur, jpy, krw, cny, sgd, thb, aud
    case chi, phan, luong
    case btc, eth, usdt

    var id: Self { self }

    /// What follows the number: "5 chỉ", "1,000 $", "0.05 BTC".
    var label: String {
        switch self {
        case .usd: "$"
        case .eur: "€"
        case .jpy: "¥"
        case .krw: "₩"
        case .cny: "元"
        case .sgd: "S$"
        case .thb: "฿"
        case .aud: "A$"
        case .chi: "chỉ"
        case .phan: "phân"
        case .luong: "lượng"
        case .btc: "BTC"
        case .eth: "ETH"
        case .usdt: "USDT"
        }
    }

    var name: String {
        switch self {
        case .usd: "US dollar"
        case .eur: "Euro"
        case .jpy: "Japanese yen"
        case .krw: "Korean won"
        case .cny: "Chinese yuan"
        case .sgd: "Singapore dollar"
        case .thb: "Thai baht"
        case .aud: "Australian dollar"
        case .chi: "Gold by the chỉ"
        case .phan: "Gold by the phân (1/10 chỉ)"
        case .luong: "Gold by the lượng / cây (10 chỉ)"
        case .btc: "Bitcoin"
        case .eth: "Ethereum"
        case .usdt: "Tether"
        }
    }

    var isGold: Bool { self == .chi || self == .phan || self == .luong }

    /// How many chỉ one of this is (gold only): a phân is a tenth of a chỉ, a lượng ten chỉ.
    var chiEach: Double {
        switch self {
        case .phan: 0.1
        case .luong: 10
        default: 1
        }
    }

    /// Gold held by the chỉ or phân, split the way people say it: 5,5 chỉ → (5, 5) "5 chỉ 5 phân".
    static func chiPhan(_ q: Double, _ unit: HoldingUnit) -> (chi: Int, phan: Double)? {
        guard unit == .chi || unit == .phan else { return nil }
        let phanTotal = ((q * unit.chiEach * 10) * 100).rounded() / 100
        let chi = Int(phanTotal / 10)
        return (chi, ((phanTotal - Double(chi) * 10) * 100).rounded() / 100)
    }

    /// The key in the price list and how many of it one unit is (a phân is a tenth of a chỉ).
    fileprivate var priceKey: (key: String, times: Double) {
        switch self {
        case .chi: ("GOLD_CHI", 1)
        case .phan: ("GOLD_CHI", 0.1)
        case .luong: ("GOLD_CHI", 10)
        case .btc: ("BTC", 1)
        case .eth: ("ETH", 1)
        case .usdt: ("USDT", 1)
        default: (rawValue.uppercased(), 1)
        }
    }

    /// A first guess from the asset's look: gold in chỉ, dollars, bitcoin.
    static func guess(_ icon: AssetIcon) -> HoldingUnit? {
        switch icon {
        case .gold: .chi
        case .usd: .usd
        case .coin: .btc
        default: nil
        }
    }
}

/// Today's prices in đồng, downloaded when the phone is online. Only public price lists come
/// in; nothing about you or your money goes out. Sources, named on screen as their free terms ask:
/// ExchangeRate-API (money), gold-api.com (world gold price), CoinGecko (coins).
enum Market {
    static let sources = "ExchangeRate-API, gold-api.com, CoinGecko"
    /// One chỉ is 3.75 g; a troy ounce is 31.1034768 g.
    private static let chiPerOunce = 3.75 / 31.1034768

    private static let pricesKey = "marketPrices"
    private static let atKey = "marketPricesAt"
    static let premiumKey = "goldPremium"

    /// The last prices, by key ("USD", "GOLD_CHI", "BTC"…), in đồng.
    static var prices: [String: Double] {
        let raw = UserDefaults.standard.string(forKey: pricesKey) ?? ""
        return (try? JSONDecoder().decode([String: Double].self, from: Data(raw.utf8))) ?? [:]
    }

    /// When those prices were downloaded.
    static var updatedAt: Date? {
        let t = UserDefaults.standard.double(forKey: atKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// How much more gold costs in Vietnam than the world price, in percent (SJC is often 15–20%
    /// above). The user sets it; 0 means the world price as it is.
    static var goldPremium: Double {
        get { UserDefaults.standard.double(forKey: premiumKey) }
        set { UserDefaults.standard.set(newValue, forKey: premiumKey) }
    }

    /// Đồng for one of this unit, with the gold premium added.
    static func price(_ unit: HoldingUnit) -> Double? {
        let (key, times) = unit.priceKey
        guard let p = prices[key] else { return nil }
        return p * times * (unit.isGold ? 1 + goldPremium / 100 : 1)
    }

    /// Downloads all three lists. Keeps whatever each one gave, so one source being down doesn't
    /// lose the others. Throws only when nothing came back (offline).
    static func refresh() async throws {
        var out = prices
        async let fx = try? LiveRates.fetch(codes: HoldingUnit.allCases.filter { !$0.isGold && ![.btc, .eth, .usdt].contains($0) }
                                                .map { $0.rawValue.uppercased() } + ["VND"])
        async let gold = try? fetchJSON(GoldReply.self, "https://api.gold-api.com/price/XAU")
        async let coins = try? fetchJSON([String: [String: Double]].self,
                                         "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum,tether&vs_currencies=vnd")
        let (f, g, c) = await (fx, gold, coins)
        var got = false
        if let f {
            for (k, v) in f.rates where k != "VND" { out[k] = v }
            got = true
        }
        if let g, g.price > 0, let usd = out["USD"] {
            out["GOLD_CHI"] = (g.price * chiPerOunce * usd).rounded()
            got = true
        }
        if let c {
            for (id, key) in [("bitcoin", "BTC"), ("ethereum", "ETH"), ("tether", "USDT")] {
                if let v = c[id]?["vnd"], v > 0 { out[key] = v }
            }
            got = true
        }
        guard got, let data = try? JSONEncoder().encode(out) else { throw URLError(.notConnectedToInternet) }
        UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: pricesKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: atKey)
    }

    private nonisolated struct GoldReply: Decodable, Sendable { let price: Double }

    private static func fetchJSON<T: Decodable>(_ type: T.Type, _ url: String) async throws -> T {
        let request = URLRequest(url: URL(string: url)!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Keeps assets held in units (gold, dollars, coins) at today's price: when the app opens or the
/// phone comes back online, and when you tap Sync. Each asset gets at most one "Value changed"
/// line a day from this; a later sync that day adjusts it.
@MainActor
enum MarketSync {
    private static var monitor: NWPathMonitor?
    private static var running = false

    /// Watches the connection (Wi-Fi or mobile data) and syncs when it's there and prices are
    /// older than three hours.
    static func start(_ container: ModelContainer) {
        guard monitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in await run(container.mainContext, force: false) }
        }
        m.start(queue: .global(qos: .utility))
        monitor = m
    }

    /// Fetches prices (unless they're fresh and `force` is off) and updates every asset held in
    /// units. Returns false when it couldn't get prices.
    @discardableResult
    static func run(_ context: ModelContext, force: Bool) async -> Bool {
        guard !running else { return true }
        let stale = Market.updatedAt.map { Date().timeIntervalSince($0) > 3 * 3600 } ?? true
        guard force || stale else { return true }
        running = true
        defer { running = false }
        guard (try? await Market.refresh()) != nil else { return false }
        LocalStore(context: context).revalueHoldings(today: Day.today())
        return true
    }
}

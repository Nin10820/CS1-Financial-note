import Foundation
import FoundationModels
import Vision

/// One asset read from a scan, a photo or a quick note, to check before it's added.
struct AssetDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var kind: AssetKind
    /// Worth in đồng; for an asset held in units, today's price × quantity (nil until prices sync).
    var amount: Int?
    var quantity: Double?
    var unit: HoldingUnit?
}

/// Reads assets out of text: "vàng 5 chỉ", "tiết kiệm TPBank 50tr", "USD 700", a bank app's
/// balance screen, a savings book. Apple Intelligence does it on the phone when this iPhone has
/// it; otherwise (or when it finds nothing) the rule reader goes line by line. Nothing is sent.
enum AssetReader {
    static var usesAI: Bool { ReceiptAI.isAvailable }

    /// A typed note is already one asset per line, so the rule reader goes first (instant and
    /// predictable). A scan or a photo is messy text: Apple Intelligence goes first there.
    static func read(_ lines: [String], today: String, typed: Bool) async -> (drafts: [AssetDraft], byAI: Bool) {
        let ruled = rules(lines, today: today)
        if typed && !ruled.isEmpty { return (ruled, false) }
        let text = lines.joined(separator: "\n")
        if usesAI, let ai = await readWithAI(text), !ai.isEmpty {
            return (ai.map { d in
                var d = d
                if let k = kindHint(d.name) { d.kind = k }
                if let u = d.unit, u.isGold || [.btc, .eth].contains(u) { d.kind = .growing }
                return d
            }, true)
        }
        return (ruled, false)
    }

    /// The group the words point to, when they say: tiết kiệm → Set aside, vàng / quỹ → Growing,
    /// cho mượn → Owed, MoMo / tài khoản / tiền mặt → Available. nil when the name doesn't say.
    static func kindHint(_ name: String) -> AssetKind? {
        let n = AssetImportSheet.key(name)
        func has(_ p: String) -> Bool { n.range(of: p, options: .regularExpression) != nil }
        if has(#"cho .*muon|cho muon|lent|owes|no toi"#) { return .owed }
        if has(#"tiet kiem|saving|deposit|ky han|gui gop"#) { return .aside }
        if has(#"vang|gold|sjc|pnj|doji|quy|fund|co phieu|stock|chung khoan|etf|crypto|bitcoin|btc|eth"#) { return .growing }
        if has(#"momo|zalopay|vnpay|shopeepay|tai khoan|account|tien mat|cash|vi "#) { return .available }
        return nil
    }

    // MARK: - Rules

    /// "5 chỉ", "3,5 phân", "700 usd", "0.01 btc" (number then unit), or "USD 700", "$700" (unit first).
    private static let numberFirst =
        #"(\d+(?:[.,]\d+)*)\s*(chỉ|chi|phân|phan|lượng|luong|cây|cay|usd|đô la|đô|eur|€|btc|eth|usdt|\$)(?![\p{L}])"#
    private static let unitFirst = #"(?<![\p{L}])(usd|eur|btc|eth|usdt|\$|€)\s*(\d+(?:[.,]\d+)*)"#

    static func rules(_ lines: [String], today: String) -> [AssetDraft] {
        lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let lower = trimmed.lowercased(with: Locale(identifier: "vi"))
            let (name, amount, sentenceKind) = AssetSentence.read(trimmed, today: today)
            let kind = kindHint(trimmed) ?? sentenceKind
            if let held = units(in: lower) {
                var rest = held.rest.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if rest.isEmpty {
                    rest = held.unit.isGold ? "Gold" : [.btc, .eth, .usdt].contains(held.unit) ? "Coin" : held.unit.rawValue.uppercased()
                }
                let title = rest.prefix(1).uppercased() + rest.dropFirst()
                let worth = Market.price(held.unit).map { Int(($0 * held.quantity).rounded()) }
                let k: AssetKind = held.unit.isGold || [.btc, .eth].contains(held.unit) ? .growing : kind
                return AssetDraft(name: title, kind: k, amount: worth, quantity: held.quantity, unit: held.unit)
            }
            guard let amount, amount > 0 else { return nil }
            return AssetDraft(name: name.isEmpty ? trimmed : name, kind: kind, amount: amount)
        }
    }

    /// The quantity and unit in a line, and the line without them (the name).
    static func units(in lower: String) -> (quantity: Double, unit: HoldingUnit, rest: String)? {
        for (pattern, numberAt, unitAt) in [(numberFirst, 1, 2), (unitFirst, 2, 1)] {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                  let whole = Range(m.range, in: lower),
                  let n = Range(m.range(at: numberAt), in: lower),
                  let u = Range(m.range(at: unitAt), in: lower),
                  let q = number(String(lower[n])), q > 0 else { continue }
            let unit: HoldingUnit
            switch String(lower[u]) {
            case "chỉ", "chi": unit = .chi
            case "phân", "phan": unit = .phan
            case "lượng", "luong", "cây", "cay": unit = .luong
            case "eur", "€": unit = .eur
            case "btc": unit = .btc
            case "eth": unit = .eth
            case "usdt": unit = .usdt
            default: unit = .usd
            }
            var rest = lower
            rest.removeSubrange(whole)
            return (q, unit, rest)
        }
        return nil
    }

    /// "1,000" and "1.000" are a thousand; "3,5" and "0.01" are decimals.
    static func number(_ s: String) -> Double? {
        if s.range(of: #"^\d{1,3}([.,]\d{3})+$"#, options: .regularExpression) != nil {
            return Double(s.filter(\.isNumber))
        }
        return Double(s.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Apple Intelligence

    private static func readWithAI(_ text: String) async -> [AssetDraft]? {
        let session = LanguageModelSession(instructions: """
            You read text a Vietnamese user wrote, scanned with the camera, or took from a screenshot
            (a bank app, a savings book, a gold receipt, a brokerage or crypto app) and list what they own.
            One item per account or holding. Never invent anything that isn't in the text.
            group: "available" for cash, bank accounts and e-wallets (MoMo, ZaloPay) and foreign cash;
            "growing" for gold, funds, stocks and crypto; "aside" for savings deposits (tiết kiệm, kỳ hạn);
            "owed" for money someone owes them (cho mượn).
            amount: the worth in đồng as a whole number. "50tr" and "50 triệu" mean 50000000, "1tr2" means
            1200000, "25k" means 25000, "50.000.000" means 50000000. In a bank screenshot the balance
            (Số dư, Available balance) is the amount; ignore transactions, fees and dates.
            For gold, foreign money and coins held in units, set quantity and unit and amount 0:
            chỉ = "chi", phân = "phan", lượng or cây = "luong", dollars = "usd", euro = "eur", bitcoin = "btc",
            ethereum = "eth", tether = "usdt". Otherwise quantity 0 and unit "none".
            name: short, the way the user would call it, with Vietnamese accents ("Vàng SJC", "Tiết kiệm TPBank").
            """)
        do {
            let reply = try await session.respond(to: "Text:\n\(text)", generating: ScannedAssets.self)
            let drafts = reply.content.items.compactMap { item -> AssetDraft? in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let unit = HoldingUnit(rawValue: item.unit)
                let quantity = unit != nil && item.quantity > 0 ? item.quantity : nil
                var amount = item.amount > 0 && item.amount < 100_000_000_000 ? item.amount : nil
                if let quantity, let unit, let price = Market.price(unit) { amount = Int((price * quantity).rounded()) }
                guard amount != nil || quantity != nil else { return nil }
                return AssetDraft(name: name, kind: AssetKind(rawValue: item.group) ?? .available,
                                  amount: amount, quantity: quantity, unit: quantity == nil ? nil : unit)
            }
            return drafts
        } catch {
            return nil
        }
    }

    // MARK: - Photos

    /// The words in a photo or screenshot, read on the phone (Vision), one line per row: words
    /// side by side ("Số dư" … "50.000.000 VND") come out on the same line.
    static func lines(inImage data: Data) async -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLanguages = [Locale.Language(identifier: "vi-VN"), Locale.Language(identifier: "en-US")]
        request.usesLanguageCorrection = true
        guard let found = try? await request.perform(on: data) else { return [] }
        let boxes = found.compactMap { o -> (text: String, rect: CGRect)? in
            guard let s = o.topCandidates(1).first?.string else { return nil }
            return (s, o.boundingBox.cgRect)
        }
        // Vision measures from the bottom left; read top to bottom, left to right.
        var rows: [[(text: String, rect: CGRect)]] = []
        for b in boxes.sorted(by: { $0.rect.midY > $1.rect.midY }) {
            if let last = rows.last?.first, abs(last.rect.midY - b.rect.midY) < max(last.rect.height, b.rect.height) * 0.6 {
                rows[rows.count - 1].append(b)
            } else {
                rows.append([b])
            }
        }
        return rows.map { $0.sorted { $0.rect.minX < $1.rect.minX }.map(\.text).joined(separator: " ") }
    }
}

@Generable
nonisolated struct ScannedAssets {
    @Guide(description: "Each account or holding, in the order it appears")
    var items: [ScannedAsset]
}

@Generable
nonisolated struct ScannedAsset {
    @Guide(description: "Short name with Vietnamese accents")
    var name: String
    @Guide(description: "Which group", .anyOf(["available", "growing", "aside", "owed"]))
    var group: String
    @Guide(description: "Worth in đồng, whole number; 0 when held in units")
    var amount: Int
    @Guide(description: "How many units, 0 when the worth is in đồng")
    var quantity: Double
    @Guide(description: "The unit", .anyOf(["none", "chi", "phan", "luong", "usd", "eur", "btc", "eth", "usdt"]))
    var unit: String
}

import Foundation

/// What a belonging is worth today, what a quick sale would fetch, and the words for it.
/// Nothing here looks a price up: the value is yours (estimate), what you paid, or what's left
/// after it loses some each year. No advice to buy or sell.
enum BelongingMath {
    /// Its worth on `today`.
    static func value(_ b: Belonging, today: String) -> Int {
        switch b.mode {
        case .estimate: return b.estimate
        case .paid: return b.paid
        case .depreciate:
            let years = max(0, Double(Day.daysBetween(b.boughtOn, today)) / 365.25)
            let kept = pow(1 - min(b.lossPerYear, 100) / 100, years)
            let floor = Double(b.paid) * b.floorPct / 100
            return Int(max(Double(b.paid) * kept, floor).rounded())
        }
    }

    /// What it would fetch if it had to go fast.
    static func quickSale(_ b: Belonging, today: String) -> Int {
        if b.keeps { return 0 }
        return Int((Double(value(b, today: today)) * b.quickSalePct / 100).rounded())
    }

    /// Everything together. A collection counts through its pieces, so it's never counted twice.
    static func total(_ list: [Belonging], today: String) -> Int {
        list.filter { !$0.isCollection && $0.soldOn == nil }.reduce(0) { $0 + value($1, today: today) }
    }

    static func quickTotal(_ list: [Belonging], today: String) -> Int {
        list.filter { !$0.isCollection && $0.soldOn == nil }.reduce(0) { $0 + quickSale($1, today: today) }
    }

    /// The pieces of a collection, newest first; sold ones last.
    static func pieces(of c: Belonging, in all: [Belonging]) -> [Belonging] {
        all.filter { $0.parentId == c.id }.sorted(by: listOrder)
    }

    /// Newest first, sold ones at the end.
    static func listOrder(_ a: Belonging, _ b: Belonging) -> Bool {
        if (a.soldOn == nil) != (b.soldOn == nil) { return a.soldOn == nil }
        return a.createdAt > b.createdAt
    }

    /// Worth of one thing: a collection is the sum of its pieces.
    static func worth(_ b: Belonging, in all: [Belonging], today: String) -> Int {
        b.isCollection ? total(pieces(of: b, in: all), today: today) : value(b, today: today)
    }

    static func quickWorth(_ b: Belonging, in all: [Belonging], today: String) -> Int {
        b.isCollection ? quickTotal(pieces(of: b, in: all), today: today) : quickSale(b, today: today)
    }

    /// Things on their own and collections (not the pieces inside), for the list.
    static func topLevel(_ all: [Belonging]) -> [Belonging] { all.filter { $0.parentId == nil }.sorted(by: listOrder) }

    /// An estimate not looked at for half a year: a quiet "Check this value?".
    static func needsCheck(_ b: Belonging, today: String) -> Bool {
        b.mode == .estimate && Day.daysBetween(b.estimatedOn, today) >= 182
    }

    /// The grey line under its name: "Estimate · 4 months ago", "Loses 10% a year", "What you paid",
    /// "Collection · 5 pieces".
    static func line(_ b: Belonging, in all: [Belonging] = [], today: String) -> String {
        if let sold = b.soldOn { return "Sold " + ago(sold, today: today) }
        if b.keeps { return "Family's · " + plainLine(b, in: all, today: today) }
        return plainLine(b, in: all, today: today)
    }

    private static func plainLine(_ b: Belonging, in all: [Belonging], today: String) -> String {
        // A piece: its code, year and condition first ("21060 · 2023 · New").
        if b.parentId != nil, !needsCheck(b, today: today) {
            let bits = [b.code, b.year.map(String.init), b.condition?.short].compactMap { $0 }.filter { !$0.isEmpty }
            if !bits.isEmpty { return bits.joined(separator: " · ") }
        }
        if b.isCollection {
            let p = pieces(of: b, in: all).filter { $0.soldOn == nil }
            guard !p.isEmpty else { return "Collection · empty" }
            let count = "\(p.count) \(p.count == 1 ? "piece" : "pieces")"
            let stale = p.filter { needsCheck($0, today: today) }.count
            return stale > 0 ? "\(count) · \(stale) to check" : "Collection · " + count
        }
        switch b.mode {
        case .estimate:
            if needsCheck(b, today: today) { return "Check this value?" }
            return "Estimate · " + ago(b.estimatedOn, today: today)
        case .depreciate: return "−\(Self.pct(b.lossPerYear)) a year, from what you paid"
        case .paid: return "What you paid"
        }
    }

    static func pct(_ v: Double) -> String {
        (v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)) + "%"
    }

    /// "today", "3 days ago", "4 months ago", "2 years ago".
    static func ago(_ iso: String, today: String) -> String {
        let d = Day.daysBetween(iso, today)
        switch d {
        case ..<1: return "today"
        case 1: return "yesterday"
        case ..<31: return "\(d) days ago"
        case ..<365:
            let m = d / 30
            return m == 1 ? "a month ago" : "\(m) months ago"
        default:
            let y = d / 365
            return y == 1 ? "a year ago" : "\(y) years ago"
        }
    }

    /// The tile from the name: "đất", "Lego", "Rolex"…
    static func guessIcon(_ name: String) -> BelongingIcon {
        let n = AssetImportSheet.key(name)
        func has(_ p: String) -> Bool { n.range(of: p, options: .regularExpression) != nil }
        if has(#"dat|land|so do|lo dat|m2"#) { return .land }
        if has(#"nha|can ho|chung cu|house|apartment"#) { return .house }
        if has(#"o to|oto|xe hoi|car|mazda|toyota|vinfast|honda city|kia"#) { return .car }
        if has(#"xe dap|bike|bicycle|giant|trek|martin"#) && !has(#"motorbike"#) { return .bicycle }
        if has(#"xe may|vision|sh |air blade|wave|vespa|motorbike|scooter"#) { return .motorbike }
        if has(#"dong ho|watch|rolex|seiko|omega|casio|citizen"#) { return .watch }
        if has(#"tui|bag|lv|louis|chanel|gucci|hermes|vi da"#) { return .bag }
        if has(#"lego"#) { return .lego }
        if has(#"the bai|pokemon|yugioh|one piece card|tcg|card|the cau thu"#) { return .cards }
        if has(#"sneaker|jordan|yeezy|dunk|air force|giay suu tam"#) { return .sneakers }
        if has(#"figure|mo hinh|gundam|funko|nendoroid|art toy|blind box|labubu"#) { return .figure }
        if has(#"board ?game|catan|ma soi|co ty phu|monopoly|splendor"#) { return .boardGame }
        if has(#"dong xu|tien xu|tien co|tien giay|xu co|numismatic|coin collection"#) { return .coins }
        if has(#"collect|suu tam"#) { return .lego }
        if has(#"may anh|camera|leica|fuji|sony a|canon|nikon"#) { return .camera }
        if has(#"laptop|macbook|may tinh"#) { return .laptop }
        if has(#"ban phim|keyboard|keychron|chuot|mouse|logitech|tai nghe|airpods|headphone|earbuds|loa|speaker|man hinh|monitor|ps5|playstation|nintendo|switch|xbox|tay cam|apple watch|kindle|may doc sach|ipad"#) { return .gadget }
        if has(#"iphone|dien thoai|phone|samsung|ipad|xiaomi|redmi|poco|oppo|vivo|pixel|k30|k40|k50|k60|k70|k80|k90"#) { return .phone }
        if has(#"tranh|art|painting|tuong"#) { return .art }
        if has(#"vot|racket|cau long|tennis|pickleball|gay golf|golf|giay chay"#) { return .sport }
        if has(#"nem|giuong|ghe|ban lam viec|tu quan ao|sofa|mattress|chair|desk|kymdan|van thanh|manson"#) { return .furniture }
        if has(#"may say|may giat|tu lanh|dieu hoa|may lanh|lo vi song|noi chien|may loc|robot hut|hitachi|dryer|fridge"#) { return .appliance }
        return .other
    }

    /// How it's usually valued: phones, laptops, cars and bikes lose value; the rest you estimate.
    static func guessMode(_ icon: BelongingIcon) -> BelongingValue {
        switch icon {
        case .car, .motorbike, .bicycle, .laptop, .phone, .camera, .gadget, .sport, .furniture, .appliance: .depreciate
        default: .estimate
        }
    }

    /// A usual yearly loss for the kind of thing.
    static func usualLoss(_ icon: BelongingIcon) -> Double {
        switch icon {
        case .phone, .laptop, .gadget: 25
        case .camera: 15
        case .car, .motorbike: 10
        default: 10
        }
    }
}

/// What a belonging is, for Overview's three cards: things that hold their value (tài sản),
/// everyday things that wear with use (tiêu sản), and collections.
nonisolated enum BelongingGroup: String, CaseIterable, Hashable, Sendable {
    case lasting, everyday, collection

    var title: String {
        switch self {
        case .lasting: "Holds value"
        case .everyday: "Everyday things"
        case .collection: "Collections"
        }
    }

    /// Under the amount when there's nothing yet.
    var emptyLine: String {
        switch self {
        case .lasting: "Land, a house, a watch, a bag"
        case .everyday: "Phones, laptops, bikes, a car"
        case .collection: "Lego, cards, sneakers…"
        }
    }

    /// What the group's page says at the end.
    var hint: String {
        switch self {
        case .lasting: "Things that keep their worth. Update a value when you see a real price."
        case .everyday: "Things you use. Their worth goes down a little each year, worked out from what you paid."
        case .collection: "Each piece keeps its own value. Tap a collection to see its pieces."
        }
    }
}

extension BelongingMath {
    /// Which card a belonging goes on. A piece goes with its collection.
    static func group(_ b: Belonging) -> BelongingGroup {
        if b.isCollection || b.parentId != nil || [.lego, .cards, .sneakers, .figure, .boardGame, .coins].contains(b.icon) { return .collection }
        switch b.icon {
        case .phone, .laptop, .gadget, .camera, .bicycle, .motorbike, .car, .sport, .furniture, .appliance: return .everyday
        default: return .lasting
        }
    }

    /// The things counted in a group (pieces, not the collection holding them).
    static func counted(_ g: BelongingGroup, in all: [Belonging]) -> [Belonging] {
        all.filter { !$0.isCollection && $0.soldOn == nil && group($0) == g }
    }

    /// What the group's page lists: collections themselves (with lone collectibles) for
    /// Collections, the things themselves otherwise. Newest first.
    static func shown(_ g: BelongingGroup, in all: [Belonging]) -> [Belonging] {
        all.filter { group($0) == g && (g != .collection || $0.parentId == nil) }
            .sorted(by: listOrder)
    }
}

/// Spending or something you own? The line between them is blurry (a 2.5M keyboard is much
/// like a phone), so the app never decides: it suggests keeping a line in Belongings and says why.
enum KeepSuggestion {
    /// Spending lines from this much ask (Finance › ••• › Ask to keep from).
    static let thresholdKey = "keepThreshold"
    static let defaultThreshold = 2_000_000
    /// Gadgets ask from a lower amount: they keep a resale price.
    static let gadgetFloor = 1_000_000

    /// Clothes and everyday shoes: spending, even when they cost a lot (designer pieces aside).
    static func isClothes(_ name: String) -> Bool {
        let n = AssetImportSheet.key(name)
        let clothes = n.range(of: #"\b(ao|quan|vay|dam|giay|dep|non|mu|tat|vo|khan|shirt|pants|jeans|dress|shoes|socks|jacket|hoodie|uniqlo|zara|h&m)\b"#,
                              options: .regularExpression) != nil
        let designer = n.range(of: #"lv|louis|gucci|chanel|hermes|dior|prada|jordan|yeezy|rolex|sneaker suu tam"#,
                               options: .regularExpression) != nil
        return clothes && !designer
    }

    /// Why a spending line could be kept, or nil when it's plainly spending.
    static func reason(title: String, amount: Int, flow: Flow, category: Category, threshold: Int) -> String? {
        guard flow == .out, category != .food, category != .bills, category != .transport, amount > 0 else { return nil }
        if isClothes(title) { return nil }
        let icon = BelongingMath.guessIcon(title)
        let tech: Set<BelongingIcon> = [.phone, .laptop, .gadget, .camera]
        if tech.contains(icon) && amount >= gadgetFloor {
            return "Tech keeps a resale price. Keep it in Everyday things to see what it's worth later."
        }
        if amount >= threshold {
            return "A big buy. If it would still sell for real money, keep it in Belongings too."
        }
        return nil
    }
}

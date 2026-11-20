import SwiftUI

/// How needed a spend is, for the Analytics pie: Essential, Worthwhile or Optional.
/// Guessed on the phone from the line's category (see `SpendKind`) and a few words in its
/// name — a soft read for the user, never a judgement shown in red.
enum SpendNeed: String, CaseIterable, Identifiable {
    case essential = "Essential"
    case worthwhile = "Worthwhile"
    case optional = "Optional"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .essential: Tokens.brand500
        case .worthwhile: Color(hex: 0x2E90FA)
        case .optional: Color(hex: 0x98A2B3)
        }
    }

    static func of(_ e: Entry) -> SpendNeed {
        let kind = SpendKind.of(e)
        let t = SpendKind.fold(e.title)
        func has(_ words: [String]) -> Bool { words.contains { SpendKind.contains(t, $0) } }
        // A few names say more than their category.
        if has(["tra sua", "milk tea", "an vat", "snack", "banh trang", "nhau", "bia", "beer", "ruou"]) { return .optional }
        if has(["ca phe", "cafe", "coffee", "grab", "taxi", "gym", "yoga", "ny", "nguoi yeu", "date"]) { return .worthwhile }
        if e.category == .bills { return kind == .subscriptions ? .optional : .essential }
        return kind.need
    }

    /// What this group is for, under the pie when it's picked.
    var hint: String {
        switch self {
        case .essential: "Home, meals, getting around and health — the things that keep the month running."
        case .worthwhile: "Things that make life better: learning, people, trips, tools. Worth it, and easy to trim a little."
        case .optional: "Treats, hobbies, extra shopping and subscriptions. The easiest place to keep more money."
        }
    }
}

/// What a spend was for: eleven categories, guessed from the line's name (Vietnamese with or
/// without accents, or English) and, failing that, its category. Each keeps a long word list
/// so everyday names land in the right place.
enum SpendKind: String, CaseIterable, Identifiable {
    case food = "Food & Drinks"
    case housing = "Housing & Utilities"
    case transportation = "Transportation"
    case health = "Health & Fitness"
    case education = "Education"
    case technology = "Technology"
    case hobbies = "Hobbies"
    case shopping = "Shopping"
    case travel = "Travel"
    case social = "Social & Gifts"
    case subscriptions = "Subscriptions"
    case other = "Other"

    var id: String { rawValue }

    var icon: Icon {
        switch self {
        case .food: .forkKnife
        case .housing: .house
        case .transportation: .motorcycle
        case .health: .heartbeat
        case .education: .graduationCap
        case .technology: .deviceMobile
        case .hobbies: .gameController
        case .shopping: .shoppingBag
        case .travel: .airplane
        case .social: .gift
        case .subscriptions: .repeatIcon
        case .other: .dotsThreeCircle
        }
    }

    var color: Color {
        switch self {
        case .food: Tokens.categoryFood
        case .housing: Color(hex: 0x7A5AF8)
        case .transportation: Tokens.categoryTransport
        case .health: Color(hex: 0xF04438)
        case .education: Color(hex: 0x0BA5EC)
        case .technology: Color(hex: 0x475467)
        case .hobbies: Color(hex: 0xE0A100)
        case .shopping: Color(hex: 0xEE46BC)
        case .travel: Color(hex: 0x00BA90)
        case .social: Color(hex: 0xFF8000)
        case .subscriptions: Color(hex: 0x6172F3)
        case .other: Tokens.grey400
        }
    }

    /// Where the category sits on the needs pie unless the name says otherwise.
    var need: SpendNeed {
        switch self {
        case .food, .housing, .transportation, .health: .essential
        case .education, .technology, .travel, .social, .other: .worthwhile
        case .hobbies, .shopping, .subscriptions: .optional
        }
    }

    /// Words for each category, without accents (names are folded the same way).
    /// Checked in this order, so the more specific lists come first.
    private static let words: [(SpendKind, [String])] = [
        (.subscriptions, ["netflix", "spotify", "youtube premium", "youtube", "icloud", "google one", "google drive",
                          "apple music", "apple tv", "apple one", "disney", "fpt play", "vieon", "k+", "chatgpt", "claude",
                          "canva", "notion", "adobe", "figma", "office 365", "microsoft 365", "zing mp3", "nhaccuatui",
                          "tiktok", "subscription", "goi thang", "phi thanh vien", "membership", "thue bao", "premium"]),
        (.travel, ["du lich", "travel", "trip", "khach san", "hotel", "homestay", "resort", "airbnb", "booking",
                   "ve may bay", "may bay", "flight", "vietjet", "vietnam airlines", "bamboo", "ve tau", "tau hoa",
                   "xe khach", "ve xe", "limousine", "da lat", "vung tau", "nha trang", "phu quoc", "sapa", "ha long",
                   "hoi an", "da nang", "tour", "visa", "ho chieu", "passport", "vali", "phong khach san", "cam trai", "camping"]),
        (.social, ["qua", "gift", "sinh nhat", "birthday", "mung cuoi", "dam cuoi", "dam hoi", "wedding", "dam tang",
                   "phung vieng", "li xi", "mung tuoi", "tet", "an voi ny", "voi ny", "ny", "nguoi yeu", "hen ho", "date",
                   "di an voi", "an voi ban", "nhau", "bia", "beer", "lau voi", "hop lop", "hop mat", "party", "tiec",
                   "moi ban", "bao ban", "chia tien", "dong gop", "quyen gop", "tu thien", "donate", "hoa tang", "bo hoa",
                   "flowers", "thiep"]),
        (.education, ["hoc phi", "tuition", "khoa hoc", "course", "lop hoc", "hoc them", "hoc tieng", "ielts", "toeic",
                      "english", "tieng anh", "tieng nhat", "tieng han", "sach", "book", "giao trinh", "tai lieu",
                      "van phong pham", "but", "vo viet", "workshop", "seminar", "udemy", "coursera", "duolingo",
                      "chung chi", "thi ", "le phi thi", "gia su", "tutor", "truong", "school", "dai hoc"]),
        (.health, ["thuoc", "medicine", "nha thuoc", "pharmacy", "kham", "doctor", "benh vien", "hospital", "phong kham",
                   "clinic", "nha khoa", "nho rang", "tram rang", "dau rang", "dentist", "xet nghiem", "vitamin", "thuc pham chuc nang", "bao hiem y te",
                   "gym", "yoga", "pilates", "boi", "swim", "chay bo", "running", "the thao", "sport", "fitness", "whey",
                   "protein", "massage", "spa", "vat ly tri lieu", "kinh mat", "kinh can", "cat toc", "haircut", "goi dau"]),
        (.technology, ["dien thoai", "iphone", "samsung", "xiaomi", "oppo", "laptop", "macbook", "may tinh", "pc",
                       "ipad", "tablet", "tai nghe", "airpods", "headphone", "sac", "charger", "cap sac", "cable",
                       "op lung", "op dien thoai", "case", "ban phim", "keyboard", "chuot", "mouse", "man hinh", "monitor",
                       "o cung", "ssd", "usb", "loa", "speaker", "dong ho thong minh", "apple watch", "camera",
                       "sua dien thoai", "thay pin", "phan mem", "software", "app ", "game key", "the nho", "router", "wifi"]),
        (.hobbies, ["game", "steam", "playstation", "nintendo", "nap game", "guitar", "dan", "piano", "ukulele",
                    "ve tranh", "mau ve", "painting", "cau ca", "fishing", "board game", "lego", "mo hinh", "figure",
                    "suu tam", "trong cay", "cay canh", "hat giong", "nhiep anh", "film", "phim", "movie", "cgv", "lotte cinema",
                    "rap", "karaoke", "concert", "nhac hoi", "bida", "bowling", "tennis", "cau long", "badminton",
                    "pickleball", "da banh", "san bong", "len", "thu cong", "craft", "anime", "manga", "truyen"]),
        (.housing, ["tien nha", "thue nha", "rent", "phong tro", "nha tro", "dien", "electric", "evn", "tien nuoc",
                    "nuoc sinh hoat", "water bill", "internet", "wifi nha", "fpt", "viettel", "vnpt", "gas", "binh gas",
                    "phi quan ly", "chung cu", "rac", "ve sinh", "giat ui", "giat say", "laundry", "nuoc giat", "giay ve sinh",
                    "do gia dung", "noi chao", "chen bat", "ga giuong", "chan goi", "sua nha", "tho dien", "tho nuoc",
                    "noi that", "furniture", "ikea", "bong den", "cay lau nha", "chat tay rua", "do dung nha"]),
        (.transportation, ["xang", "do xang", "petrol", "fuel", "grab", "be ", "xanh sm", "gojek", "taxi",
                           "uber", "xe om", "gui xe", "parking", "phi do xe", "ve gui xe", "rua xe", "sua xe", "bao duong",
                           "thay nhot", "lop xe", "vo xe", "bus", "xe buyt", "metro", "tau dien", "phi cau duong", "bot",
                           "etc", "dang kiem", "bao hiem xe", "bang lai", "mu bao hiem"]),
        (.shopping, ["shopee", "lazada", "tiki", "tiktok shop", "sendo", "dat do", "order", "ao", "quan", "jean",
                     "vay", "dam ", "giay", "dep", "sandal", "tui", "balo", "vi ", "wallet", "dong ho", "trang suc",
                     "nhan", "day chuyen", "my pham", "son", "kem chong nang", "skincare", "sua rua mat", "nuoc hoa",
                     "perfume", "uniqlo", "zara", "h&m", "muji", "decathlon", "mall", "trung tam thuong mai", "do choi",
                     "phu kien", "mua sam", "shopping"]),
        (.food, ["com", "pho", "bun", "mi ", "mien", "hu tieu", "banh mi", "banh cuon", "banh xeo", "xoi", "chao", "lau",
                 "nuong", "ga ", "bo ", "heo", "ca ", "tom", "hai san", "an sang", "an trua", "an toi", "breakfast", "lunch",
                 "dinner", "ca phe", "cafe", "coffee", "tra", "tea", "tra sua", "milk tea", "sinh to", "nuoc ep", "juice",
                 "nuoc ngot", "nuoc suoi", "banh", "che", "kem", "an vat", "snack", "trai cay", "hoa qua", "di cho",
                 "sieu thi", "bach hoa xanh", "winmart", "coopmart", "circle k", "gs25", "7-eleven", "thuc pham",
                 "grocer", "gao", "rau", "thit", "trung", "sua", "pizza", "burger", "kfc", "lotteria", "jollibee",
                 "highlands", "phuc long", "starbucks", "the coffee house", "katinat", "gong cha", "shopeefood",
                 "grabfood", "baemin", "do an", "food"]),
    ]

    static func of(_ e: Entry) -> SpendKind {
        let t = fold(e.title)
        for (kind, list) in words where list.contains(where: { contains(t, $0) }) { return kind }
        switch e.category {
        case .food: return .food
        case .transport: return .transportation
        case .shopping: return .shopping
        case .bills: return .housing
        default: return .other
        }
    }

    /// Lower case, no accents, đ → d, anything else between words a space, padded with spaces:
    /// "Cà phê sữa đá!" → " ca phe sua da ".
    static func fold(_ s: String) -> String {
        let plain = s.lowercased(with: Locale(identifier: "vi"))
            .replacingOccurrences(of: "đ", with: "d")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "vi"))
        let spaced = String(plain.map { $0.isLetter || $0.isNumber || "&+-".contains($0) ? $0 : " " })
        return " " + spaced.split(separator: " ").joined(separator: " ") + " "
    }

    /// Whole-word match, so "ca" doesn't catch "cafe" and "ny" doesn't catch "sunny".
    static func contains(_ folded: String, _ word: String) -> Bool {
        folded.contains(" " + word.trimmingCharacters(in: .whitespaces) + " ")
    }
}

/// Where money in came from: salary, a business, rent, freelance work… Guessed on the phone
/// from the line's name, so the income pie works for any way of earning.
enum IncomeKind: String, CaseIterable, Identifiable {
    case salary = "Salary"
    case business = "Business & selling"
    case rental = "Rent"
    case freelance = "Freelance"
    case interest = "Interest & investing"
    case paidBack = "Paid back"
    case other = "Other"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .salary: Tokens.brand500
        case .business: Color(hex: 0xFF8000)
        case .rental: Color(hex: 0x7A5AF8)
        case .freelance: Color(hex: 0x00BA90)
        case .interest: Color(hex: 0xE0A100)
        case .paidBack: Color(hex: 0x2E90FA)
        case .other: Tokens.grey400
        }
    }

    var icon: Icon {
        switch self {
        case .salary: .wallet
        case .business: .shoppingBag
        case .rental: .receipt
        case .freelance: .pencil
        case .interest: .chartLineUp
        case .paidBack: .heart
        case .other: .dotsThreeCircle
        }
    }

    static func of(_ e: Entry) -> IncomeKind {
        let t = e.title.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { t.range(of: p, options: .regularExpression) != nil }
        if has("lương|luong|salary|thưởng|bonus|payroll") { return .salary }
        if has("cho thuê|thuê nhà|tiền nhà|rent|rental") { return .rental }
        if has("freelance|dự án|du an|project|thiết kế|design|job") { return .freelance }
        if has("lãi|lai suat|interest|cổ tức|dividend|chứng khoán|stock|quỹ|fund|crypto") { return .interest }
        if has("trả tiền|trả lại|tra tien|paid back|pay back|hoàn|refund") { return .paidBack }
        if has("bán|ban hang|buôn|kinh doanh|shop|order|doanh thu|sale|sell") { return .business }
        return .other
    }
}

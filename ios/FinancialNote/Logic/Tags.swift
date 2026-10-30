import Foundation

/// Tags from Figma High Fi 2 › Select tag (1052:6578). A line keeps its category (for colours and
/// the reader) and can carry any number of tags on top.
nonisolated enum Tags {
    struct Info: Sendable {
        var name: String
        var symbol: String
        /// Fill when picked (light / dark), and whether its text should be white.
        var fill: UInt32
        var fillDark: UInt32
        var whiteText: Bool
    }

    static let defaults: [Info] = [
        Info(name: "Food", symbol: "fork.knife", fill: 0xF8EADC, fillDark: 0x5A3420, whiteText: false),
        Info(name: "Drinks", symbol: "cup.and.saucer.fill", fill: 0xBDE7FA, fillDark: 0x0B4A68, whiteText: false),
        Info(name: "Transport", symbol: "car.fill", fill: 0xD1E9FF, fillDark: 0x123B6E, whiteText: false),
        Info(name: "Health", symbol: "heart.fill", fill: 0x0E7C66, fillDark: 0x0E7C66, whiteText: true),
        Info(name: "Housing", symbol: "house.fill", fill: 0xE0EAFF, fillDark: 0x1E2250, whiteText: false),
        Info(name: "Education", symbol: "graduationcap.fill", fill: 0xC7D7FE, fillDark: 0x2D3A8C, whiteText: false),
        Info(name: "Snacks", symbol: "birthday.cake.fill", fill: 0xB42318, fillDark: 0xB42318, whiteText: true),
        Info(name: "Public Transit", symbol: "bus.fill", fill: 0xCCFBEF, fillDark: 0x0E3B33, whiteText: false),
        Info(name: "Shopping", symbol: "bag.fill", fill: 0xFCE7F6, fillDark: 0x5C1A4A, whiteText: false),
        Info(name: "Internet & Phone", symbol: "wifi", fill: 0xE2F4D3, fillDark: 0x1C3314, whiteText: false),
        Info(name: "Clothing", symbol: "tshirt.fill", fill: 0xFEF0C7, fillDark: 0x4E3A06, whiteText: false),
        Info(name: "Medical", symbol: "cross.case.fill", fill: 0xFEE4E2, fillDark: 0x55160C, whiteText: false),
    ]

    static func info(_ name: String) -> Info? { defaults.first { $0.name == name } }

    /// A sensible tag for a line, from its category and the words in its name.
    static func suggest(title: String, category: Category) -> String? {
        let t = title.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { t.range(of: p, options: .regularExpression) != nil }
        switch category {
        case .food:
            if has(#"cà phê|ca phe|cafe|coffee|\bcf\b|trà|tra sua|milk tea|tea|bia|beer|nước|drink|juice|sinh tố"#) { return "Drinks" }
            if has(#"snack|bánh|banh|kẹo|chips|cake"#) { return "Snacks" }
            return "Food"
        case .transport:
            if has(#"bus|xe buýt|train|tàu|metro"#) { return "Public Transit" }
            return "Transport"
        case .shopping:
            if has(#"áo|quần|giày|dép|shirt|t-shirt|shoes|clothes|váy"#) { return "Clothing" }
            return "Shopping"
        case .bills:
            if has(#"internet|wifi|phone|điện thoại|sim|4g|mạng"#) { return "Internet & Phone" }
            if has(#"điện|nước|water|electric|rent|tiền nhà|nhà"#) { return "Housing" }
            if has(#"học|course|school|tuition"#) { return "Education" }
            return nil
        case .other:
            if has(#"thuốc|medicine|doctor|bác sĩ|hospital|bệnh viện|khám"#) { return "Medical" }
            if has(#"gym|haircut|cắt tóc|spa"#) { return "Health" }
            return nil
        case .received:
            return nil
        }
    }

    /// "Cash", "Transfer" or "Card" from how the note said it was paid ("· cash", "chuyển khoản"…).
    static func paidFrom(_ said: String?) -> String? {
        guard let s = said?.lowercased(with: Locale(identifier: "vi")) else { return nil }
        if s.contains("cash") || s.contains("tiền mặt") || s.contains("tien mat") { return "Cash" }
        if s.contains("transfer") || s.contains("chuyển khoản") || s.contains("chuyen khoan") || s == "ck" { return "Transfer" }
        if s.contains("card") || s.contains("thẻ") { return "Card" }
        return nil
    }
}

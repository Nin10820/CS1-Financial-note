import Foundation

/// "Say it your way" on New asset: "vàng SJC 15tr", "tiết kiệm TPBank 50 triệu", "cho Minh mượn 2tr".
/// Guesses the group from the words (gold, fund, stock → Growing; savings, deposit → Set aside;
/// lent, owes → Owed; otherwise Available), then the name and amount with the note parser.
enum AssetSentence {
    static func read(_ text: String, today: String) -> (name: String, amount: Int?, kind: AssetKind) {
        let lower = text.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { lower.range(of: p, options: .regularExpression) != nil }
        let kind: AssetKind =
            has(#"cho .* mượn|cho mượn|mượn|muon|lent|owes|owed|nợ tôi|no toi|người ta nợ"#) ? .owed
            : has(#"tiết kiệm|tiet kiem|saving|gửi góp|gui gop|kỳ hạn|ky han|deposit|sổ tiết kiệm"#) ? .aside
            : has(#"vàng|vang|gold|sjc|pnj|quỹ|quy|fund|fmarket|cổ phiếu|co phieu|stock|chứng khoán|etf|crypto|bitcoin|btc"#) ? .growing
            : .available
        guard let line = NoteParser.parse(text, day: today).first else { return (text, nil, kind) }
        return (line.title, line.amount, kind)
    }
}

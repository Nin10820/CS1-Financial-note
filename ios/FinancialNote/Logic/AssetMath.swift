import Foundation

/// Asset groups and shares, ported from `src/lib/assets.ts`.
enum AssetMath {
    struct Group: Equatable {
        var kind: AssetKind
        var sum: Int
        /// Whole percent; the four groups always add up to 100 when there is anything at all.
        var pct: Int
    }

    /// Share of each group, rounded so the four always add up to 100.
    static func shares(_ assets: [Asset]) -> (total: Int, groups: [Group]) {
        let total = assets.reduce(0) { $0 + $1.amount }
        let raw: [(kind: AssetKind, sum: Int, pct: Double)] = AssetKind.allCases.map { k in
            let sum = assets.filter { $0.kind == k }.reduce(0) { $0 + $1.amount }
            return (k, sum, total == 0 ? 0 : Double(sum) / Double(total) * 100)
        }
        var groups = raw.map { Group(kind: $0.kind, sum: $0.sum, pct: Int($0.pct.rounded(.down))) }
        var left = total == 0 ? 0 : 100 - groups.reduce(0) { $0 + $1.pct }
        // Give the leftover points to the groups that lost the most when rounding down.
        let order = raw.indices.sorted { a, b in
            let fa = raw[a].pct - raw[a].pct.rounded(.down)
            let fb = raw[b].pct - raw[b].pct.rounded(.down)
            return fa == fb ? a < b : fa > fb
        }
        for i in order where left > 0 && raw[i].sum > 0 {
            groups[i].pct += 1
            left -= 1
        }
        return (total, groups)
    }

    /// One asset's money: what was put in (in − out), what it is worth, and the difference.
    struct Growth: Equatable {
        var putIn: Int
        var value: Int
        var change: Int { value - putIn }
        /// Whole percent of what was put in; nil when nothing was put in.
        var pct: Int? { putIn > 0 ? Int((Double(change) / Double(putIn) * 100).rounded()) : nil }
    }

    /// nil when the asset has no recorded moves yet (written down before they were kept).
    static func growth(_ asset: Asset, moves: [AssetMove]) -> Growth? {
        let mine = moves.filter { $0.assetId == asset.id }
        guard !mine.isEmpty else { return nil }
        let putIn = mine.filter { $0.kind != .value }.reduce(0) { $0 + $1.amount }
        return Growth(putIn: putIn, value: asset.amount)
    }

    /// The asset's worth after each move, oldest first, for its line.
    static func valueLine(_ asset: Asset, moves: [AssetMove]) -> [(date: String, value: Int)] {
        let mine = moves.filter { $0.assetId == asset.id }.sorted { $0.date < $1.date }
        var running = 0
        var out: [(date: String, value: Int)] = []
        for m in mine {
            running += m.amount
            if let last = out.last, last.date == m.date { out[out.count - 1].value = running } else { out.append((m.date, running)) }
        }
        return out
    }

    static func guessIcon(_ name: String, kind: AssetKind) -> AssetIcon {
        let n = name.lowercased(with: Locale(identifier: "vi"))
        func has(_ p: String) -> Bool { n.range(of: p, options: .regularExpression) != nil }
        if has("gold|vàng|vang|sjc|pnj") { return .gold }
        if has("fund|quỹ|quy|fmarket|stock|cổ phiếu|etf|vn30") { return .fund }
        if has("bank|tiết kiệm|tiet kiem|saving|tp|vcb|techcom|mb|acb") { return .bank }
        if kind == .owed { return .lent }
        return .cash
    }
}

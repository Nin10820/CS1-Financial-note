import Foundation
import UIKit

/// One Lego set from the list that ships with the app (Rebrickable's public set list).
nonisolated struct LegoSet: Identifiable, Hashable, Sendable {
    /// Rebrickable's set number, "21060-1".
    var id: String
    var name: String
    var year: Int
    var theme: String
    var parts: Int

    /// The number printed on the box: "21060" (the "-1" dropped; other versions kept).
    var code: String { id.hasSuffix("-1") ? String(id.dropLast(2)) : id }
}

/// Lego sets to search by code or name, without the internet: about 20,000 sets bundled as
/// Resources/lego-sets.tsv. Only a set's picture is downloaded, once, when it's added
/// (Rebrickable's image server; allowed by Nin on 2026-11-25). Nothing about the user is sent.
enum LegoCatalog {
    nonisolated static let all: [LegoSet] = {
        guard let url = Bundle.main.url(forResource: "lego-sets", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var out: [LegoSet] = []
        out.reserveCapacity(21_000)
        for line in text.split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard f.count == 5 else { continue }
            out.append(LegoSet(id: String(f[0]), name: String(f[1]), year: Int(f[2]) ?? 0, theme: String(f[3]),
                               parts: Int(f[4]) ?? 0))
        }
        return out
    }()

    private nonisolated static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// Sets matching a code ("21060", "2106") or words of a name ("himeji", "red dragon").
    /// The exact code first, then newer sets first.
    nonisolated static func search(_ query: String, limit: Int = 20) -> [LegoSet] {
        let q = fold(query.trimmingCharacters(in: .whitespaces))
        guard q.count >= 2 else { return [] }
        let words = q.split(separator: " ").map(String.init)
        let isCode = q.allSatisfy { $0.isNumber || $0 == "-" }
        let hits = all.filter { s in
            if isCode { return s.id.hasPrefix(q) }
            let name = fold(s.name + " " + s.theme)
            return words.allSatisfy { name.contains($0) }
        }
        return Array(hits.sorted { a, b in
            let ea = a.code == q, eb = b.code == q
            if ea != eb { return ea }
            return (a.year, b.name) > (b.year, a.name)
        }.prefix(limit))
    }

    nonisolated static func find(code: String) -> LegoSet? {
        let c = code.trimmingCharacters(in: .whitespaces)
        return all.first { $0.code == c || $0.id == c }
    }

    nonisolated static func pictureURL(_ set: LegoSet) -> URL? {
        URL(string: "https://cdn.rebrickable.com/media/sets/\(set.id.lowercased()).jpg")
    }

    /// The set's picture, made small (600 px) to keep on the phone. nil when offline.
    static func picture(for set: LegoSet) async -> Data? {
        guard let url = pictureURL(set),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        let side: CGFloat = 600
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.8)
    }
}

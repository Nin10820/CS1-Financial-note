import Foundation

/// Reads a VietQR / EMVCo payment code (the QR shown by Vietnamese bank apps and shops).
/// Only reads it — the app never pays anything. Fields: amount (tag 54), merchant name (59),
/// the transfer note (62 › 08) and the receiving bank and account (38 › 01).
nonisolated struct VietQR: Equatable, Sendable {
    var amount: Int?
    var name: String?
    var note: String?
    var bankBIN: String?
    var account: String?

    /// Short bank names by BIN (the six digits in the code).
    static let banks: [String: String] = [
        "970436": "Vietcombank", "970415": "VietinBank", "970418": "BIDV", "970405": "Agribank",
        "970422": "MB Bank", "970407": "Techcombank", "970416": "ACB", "970432": "VPBank",
        "970423": "TPBank", "970403": "Sacombank", "970437": "HDBank", "970441": "VIB",
        "970443": "SHB", "970431": "Eximbank", "970426": "MSB", "970448": "OCB",
    ]

    var bankName: String? { bankBIN.flatMap { Self.banks[$0] } }

    /// What to call the line: the note if there is one, else who it went to.
    var title: String {
        if let note, !note.isEmpty { return note }
        if let name, !name.isEmpty { return name.capitalized(with: Locale(identifier: "vi")) }
        if let bank = bankName { return "Transfer to \(bank)" }
        return "QR payment"
    }

    /// Splits "IDLLvalue IDLLvalue…" into a dictionary. Returns nil when it isn't TLV.
    static func fields(_ s: String) -> [String: String]? {
        var out: [String: String] = [:]
        var i = s.startIndex
        while i < s.endIndex {
            guard s.distance(from: i, to: s.endIndex) >= 4 else { return nil }
            let idEnd = s.index(i, offsetBy: 2)
            let lenEnd = s.index(idEnd, offsetBy: 2)
            guard let len = Int(s[idEnd..<lenEnd]), s.distance(from: lenEnd, to: s.endIndex) >= len else { return nil }
            let valueEnd = s.index(lenEnd, offsetBy: len)
            out[String(s[i..<idEnd])] = String(s[lenEnd..<valueEnd])
            i = valueEnd
        }
        return out
    }

    /// nil when the text isn't a payment code (a link, a Wi-Fi code…).
    init?(payload: String) {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("000201"), let f = Self.fields(text) else { return nil }
        if let a = f["54"], let v = Double(a) { amount = Int(v.rounded()) }
        name = f["59"]
        if let extra = f["62"], let inner = Self.fields(extra) { note = inner["08"] }
        if let acc = f["38"], let inner = Self.fields(acc), let bene = inner["01"], let b = Self.fields(bene) {
            bankBIN = b["00"]
            account = b["01"]
        }
        guard amount != nil || name != nil || bankBIN != nil else { return nil }
    }
}

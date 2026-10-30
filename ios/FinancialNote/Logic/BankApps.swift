import Foundation

/// Bank apps the user can pay from after scanning a QR. The app never moves money: "Open bank
/// app" hands the transfer to the bank's own app, where the user confirms it.
///
/// The link is VietQR's open deeplink (vietqr.io › Deeplink app ngân hàng):
/// `https://dl.vietqr.io/pay?app=bidv&ba=ACCOUNT@BANK&am=AMOUNT&tn=NOTE&bn=NAME&url=RETURN`.
/// Only some apps take the account and amount filled in (`fills`, ⚡ in the picker); the rest
/// just open. The link goes through vietqr.io, so the account, amount and note leave the phone
/// at that moment — Profile › Your data says so.
nonisolated struct BankApp: Identifiable, Hashable, Sendable {
    /// VietQR app id ("bidv", "mb", "icb"…).
    let id: String
    let name: String
    /// The app opens with the account, amount and note filled in.
    let fills: Bool

    /// From vietqr.io's iOS list (api.vietqr.io/v2/ios-app-deeplinks, autofill = 1 for the first five).
    static let all: [BankApp] = [
        BankApp(id: "bidv", name: "BIDV", fills: true),
        BankApp(id: "mb", name: "MB", fills: true),
        BankApp(id: "icb", name: "VietinBank", fills: true),
        BankApp(id: "acb", name: "ACB", fills: true),
        BankApp(id: "ocb", name: "OCB", fills: true),
        BankApp(id: "vcb", name: "Vietcombank", fills: false),
        BankApp(id: "tcb", name: "TCB", fills: false),
        BankApp(id: "vpb", name: "VPBank", fills: false),
        BankApp(id: "tpb", name: "TPBank", fills: false),
        BankApp(id: "vba", name: "Agribank", fills: false),
        BankApp(id: "hdb", name: "HDBank", fills: false),
        BankApp(id: "vib-2", name: "VIB", fills: false),
        BankApp(id: "shb", name: "SHB", fills: false),
        BankApp(id: "eib", name: "Eximbank", fills: false),
        BankApp(id: "cake", name: "Cake", fills: false),
        BankApp(id: "timo", name: "Timo", fills: false),
    ]

    static func named(_ id: String) -> BankApp? { all.first { $0.id == id } }

    /// VietQR bank codes for the receiving bank, by the BIN in the scanned code.
    static let codes: [String: String] = [
        "970436": "vcb", "970415": "icb", "970418": "bidv", "970405": "vba", "970422": "mb",
        "970407": "tcb", "970416": "acb", "970432": "vpb", "970423": "tpb", "970403": "stb",
        "970437": "hdb", "970441": "vib", "970443": "shb", "970431": "eib", "970426": "msb",
        "970448": "ocb",
    ]

    /// Where the bank app sends the user back to when it supports it.
    static let returnURL = "financialnote://paid"

    /// The link that opens this bank app with the transfer. nil when the code had no account.
    func transferURL(account: String?, bankBIN: String?, amount: Int, note: String, name: String?) -> URL? {
        guard let account, !account.isEmpty, let bin = bankBIN, let code = Self.codes[bin] else { return nil }
        var c = URLComponents()
        c.scheme = "https"
        c.host = "dl.vietqr.io"
        c.path = "/pay"
        var items = [
            URLQueryItem(name: "app", value: id),
            URLQueryItem(name: "ba", value: "\(account)@\(code)"),
            URLQueryItem(name: "am", value: String(amount)),
            URLQueryItem(name: "tn", value: note),
        ]
        if let name, !name.isEmpty { items.append(URLQueryItem(name: "bn", value: name)) }
        items.append(URLQueryItem(name: "url", value: Self.returnURL))
        c.queryItems = items
        return c.url
    }
}

/// A scanned QR waiting to be paid, then waiting to be confirmed once the user comes back.
struct TransferDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String?
    var bankBIN: String?
    var account: String?
    var amount: Int
    var note: String
    var category: Category = .other
    var from: BankApp?

    init(_ qr: VietQR) {
        name = qr.name.map { $0.capitalized(with: Locale(identifier: "vi")) }
        bankBIN = qr.bankBIN
        account = qr.account
        amount = qr.amount ?? 0
        note = qr.note ?? ""
        if let n = qr.note { category = NoteParser.guessCategory(n) }
    }

    var bankName: String? { bankBIN.flatMap { VietQR.banks[$0] } }

    /// "Au Thien Vy", or "Transfer to TPBank" when the code has no name.
    var payee: String { name ?? bankName.map { "Transfer to \($0)" } ?? "QR payment" }

    /// The saved line's name: the note if there is one, else who it went to.
    var title: String { note.isEmpty ? payee : note }
}

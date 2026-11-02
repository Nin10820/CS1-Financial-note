import Foundation

/// Bank apps the user can pay from after scanning a QR. The app never moves money: it opens the
/// bank's own app, where the user makes and confirms the transfer. The banks' links (`mbbank://`…) only open the
/// app; none of them takes an account or amount, and vietqr.io's web link can't either on iOS.
nonisolated struct BankApp: Identifiable, Hashable, Sendable {
    /// VietQR app id ("bidv", "mb", "icb"…).
    let id: String
    let name: String
    /// The bank app's own link ("mbbank://"): opens it straight away, without the details.
    let scheme: String

    /// From vietqr.io's iOS list (api.vietqr.io/v2/ios-app-deeplinks); `scheme` is each app's own link.
    static let all: [BankApp] = [
        BankApp(id: "bidv", name: "BIDV", scheme: "bidv.smartbanking.partner://"),
        BankApp(id: "mb", name: "MB", scheme: "mbbank://"),
        BankApp(id: "icb", name: "VietinBank", scheme: "vietinbankipay://"),
        BankApp(id: "acb", name: "ACB", scheme: "acbone://"),
        BankApp(id: "ocb", name: "OCB", scheme: "newomni-app://"),
        BankApp(id: "vcb", name: "Vietcombank", scheme: "vietcombankmobile://"),
        BankApp(id: "tcb", name: "TCB", scheme: "tcb://"),
        BankApp(id: "vpb", name: "VPBank", scheme: "vpbankneo://"),
        BankApp(id: "tpb", name: "TPBank", scheme: "hydro://"),
        BankApp(id: "vba", name: "Agribank", scheme: "agribankmobile://"),
        BankApp(id: "hdb", name: "HDBank", scheme: "hdbankmobile://"),
        BankApp(id: "vib-2", name: "VIB", scheme: "myvib2://"),
        BankApp(id: "shb", name: "SHB", scheme: "shbmobile://"),
        BankApp(id: "eib", name: "Eximbank", scheme: "eximbankmobile://"),
        BankApp(id: "cake", name: "Cake", scheme: "cake.vn://"),
        BankApp(id: "timo", name: "Timo", scheme: "plus://"),
    ]

    static func named(_ id: String) -> BankApp? { all.first { $0.id == id } }

    var schemeURL: URL? { URL(string: scheme) }

    /// VietQR lists these apps as filling in the account and amount from its link.
    var vietQRFills: Bool { ["bidv", "mb", "icb", "acb", "ocb"].contains(id) }

    /// VietQR's link for this app: `ba` = account@receiving bank code, `tn` with + for spaces,
    /// `url` not encoded (as the open-source projects that use it found works).
    func vietQRLink(account: String, receiverBIN: String, amount: Int, note: String) -> URL? {
        let receiver = Self.code(forBIN: receiverBIN) ?? receiverBIN
        let tn = VietQR.ascii(note).replacingOccurrences(of: " ", with: "+")
        return URL(string: "https://dl.vietqr.io/pay?app=\(id)&ba=\(account)@\(receiver)&am=\(amount)&tn=\(tn)&url=https://www.vietqr.io/deeplink")
    }

    /// VietQR's bank codes (the `code` in api.vietqr.io/v2/banks) by BIN, for the receiving bank.
    static func code(forBIN bin: String) -> String? {
        [
            "970436": "VCB", "970415": "ICB", "970418": "BIDV", "970405": "VBA", "970422": "MB",
            "970407": "TCB", "970416": "ACB", "970432": "VPB", "970423": "TPB", "970403": "STB",
            "970437": "HDB", "970441": "VIB", "970443": "SHB", "970431": "EIB", "970426": "MSB",
            "970448": "OCB",
        ][bin]
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

    /// The scanned code, rebuilt with the amount when the bank app is opened.
    var payload: String

    init(_ qr: VietQR) {
        payload = qr.raw
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

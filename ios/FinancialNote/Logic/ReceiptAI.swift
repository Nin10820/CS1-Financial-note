import Foundation
import FoundationModels

/// Reads text scanned from a receipt or a handwritten note with Apple Intelligence, on the phone.
/// Nothing is sent anywhere and it costs nothing. It needs an iPhone with Apple Intelligence
/// turned on (iPhone 15 Pro and later); everywhere else `isAvailable` is false and the app keeps
/// using NoteParser.
enum ReceiptAI {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// The things bought, as drafts to check before saving. nil when the model isn't there,
    /// fails, or finds nothing, so the caller keeps NoteParser's reading.
    static func read(_ text: String, day: String) async -> [Draft]? {
        guard isAvailable else { return nil }
        let session = LanguageModelSession(instructions: """
            You read text scanned from a Vietnamese receipt or a handwritten spending note.
            List each thing that was bought or paid for, with the amount actually paid for that line in đồng
            (quantity × unit price when both are shown).
            Amounts: "55.000" and "55,000" mean 55000; "25k" means 25000; "1tr2" means 1200000.
            Skip the shop name, address, phone, date, subtotal, total, tax, discount lines, cash given,
            change and thank-you lines.
            If no single items can be read but a total can, return one item named after the shop with the total.
            Keep every word of each item name and its order; drop only quantities and prices.
            Receipts often print Vietnamese without accents: put the accents back on every word
            ("Pho bo tai" becomes "Phở bò tái", "Tra da" becomes "Trà đá", "Quay" becomes "Quẩy").
            """)
        do {
            let reply = try await session.respond(to: "Scanned text:\n\(markQuantities(text))", generating: ScannedReceipt.self)
            let drafts = reply.content.items.compactMap { item -> Draft? in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, item.amount > 0, item.amount < 10_000_000_000 else { return nil }
                return Draft(title: name, amount: item.amount, flow: .out,
                             category: Category(rawValue: item.category) ?? .other, date: day)
            }
            return drafts.isEmpty ? nil : drafts
        } catch {
            return nil
        }
    }
}

extension ReceiptAI {
    /// Receipts print the quantity right before the price ("Cơm sườn 1 85.000"), and the model can
    /// read that as 185.000. Marking it "x1" first keeps the two apart.
    nonisolated static func markQuantities(_ text: String) -> String {
        text.replacingOccurrences(of: #"(?<=\s)(\d{1,2})\s+(?=\d{1,3}(?:[.,]\d{3})+\b)"#,
                                  with: "x$1 ", options: .regularExpression)
    }
}

@Generable
nonisolated struct ScannedReceipt {
    @Guide(description: "Each thing bought, in the order it appears")
    var items: [ScannedItem]
}

@Generable
nonisolated struct ScannedItem {
    @Guide(description: "What was bought, short, in Vietnamese if the receipt is Vietnamese")
    var name: String
    @Guide(description: "Amount paid for this line in đồng, a whole number")
    var amount: Int
    @Guide(description: "The spending category", .anyOf(["Food", "Transport", "Shopping", "Bills", "Other"]))
    var category: String
}

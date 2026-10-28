import Foundation
import SwiftData

// Everything is stored on this phone with SwiftData. No account, no server, no network.
// Shapes follow `src/lib/store.ts`, `bills.ts` and `assets.ts`; ids are strings so the
// sample's "sample-…" ids and exported JSON stay the same as in the web app.

/// One saved line. Lines saved together from one note share a `noteId`.
@Model
final class Entry {
    @Attribute(.unique) var id: String
    /// "YYYY-MM-DD"
    var date: String
    var title: String
    /// Whole đồng.
    var amount: Int
    var flowRaw: String
    var categoryRaw: String
    var noteId: String
    /// The note exactly as the user wrote it.
    var source: String
    var createdAt: Date
    /// Set when the entry was created by checking off a bill.
    var billId: String?
    /// Part of the sample data (removable in one switch).
    var sample: Bool

    var flow: Flow {
        get { Flow(rawValue: flowRaw) ?? .out }
        set { flowRaw = newValue.rawValue }
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString, date: String, title: String, amount: Int, flow: Flow,
        category: Category, noteId: String, source: String, createdAt: Date = .now,
        billId: String? = nil, sample: Bool = false
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.amount = amount
        self.flowRaw = flow.rawValue
        self.categoryRaw = category.rawValue
        self.noteId = noteId
        self.source = source
        self.createdAt = createdAt
        self.billId = billId
        self.sample = sample
    }
}

/// The free-form note for a day: lines as the user wrote them.
@Model
final class DayNote {
    @Attribute(.unique) var date: String
    var lines: [String]
    var updatedAt: Date
    var sample: Bool

    init(date: String, lines: [String], updatedAt: Date = .now, sample: Bool = false) {
        self.date = date
        self.lines = lines
        self.updatedAt = updatedAt
        self.sample = sample
    }
}

/// What was paid for one month of a bill, and which entry recorded it.
nonisolated struct PaidRecord: Codable, Equatable, Sendable {
    var amount: Int
    var at: Date
    var entryId: String?
}

/// A bill the user wants to remember. Recurring and installment bills repeat monthly.
@Model
final class Bill {
    @Attribute(.unique) var id: String
    var kindRaw: String
    var name: String
    var iconRaw: String
    /// Expected amount per payment (an estimate when `varies`).
    var amount: Int
    var varies: Bool
    /// First due date, "YYYY-MM-DD". Repeats on the same day each month.
    var start: String
    var code: String?
    var payWith: String?
    // Installments only.
    var lender: String?
    var principal: Int?
    var payments: Int?
    /// Monthly interest, percent.
    var rate: Double?
    /// One-time conversion fee, percent of the principal.
    var fee: Double?
    /// "YYYY-MM" → PaidRecord, stored as JSON.
    var paidData: Data
    var createdAt: Date
    var sample: Bool

    var kind: BillKind {
        get { BillKind(rawValue: kindRaw) ?? .recurring }
        set { kindRaw = newValue.rawValue }
    }

    var icon: BillIcon {
        get { BillIcon(rawValue: iconRaw) ?? .bell }
        set { iconRaw = newValue.rawValue }
    }

    var paid: [String: PaidRecord] {
        get { (try? JSONDecoder().decode([String: PaidRecord].self, from: paidData)) ?? [:] }
        set { paidData = (try? JSONEncoder().encode(newValue)) ?? Data("{}".utf8) }
    }

    init(
        id: String = UUID().uuidString, kind: BillKind, name: String, icon: BillIcon, amount: Int,
        varies: Bool = false, start: String, code: String? = nil, payWith: String? = nil,
        lender: String? = nil, principal: Int? = nil, payments: Int? = nil, rate: Double? = nil,
        fee: Double? = nil, paid: [String: PaidRecord] = [:], createdAt: Date = .now, sample: Bool = false
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.name = name
        self.iconRaw = icon.rawValue
        self.amount = amount
        self.varies = varies
        self.start = start
        self.code = code
        self.payWith = payWith
        self.lender = lender
        self.principal = principal
        self.payments = payments
        self.rate = rate
        self.fee = fee
        self.paidData = (try? JSONEncoder().encode(paid)) ?? Data("{}".utf8)
        self.createdAt = createdAt
        self.sample = sample
    }
}

/// Something the user owns, written down by hand. Nothing here talks to a bank.
@Model
final class Asset {
    @Attribute(.unique) var id: String
    var name: String
    var kindRaw: String
    var iconRaw: String
    var amount: Int
    /// Last time the user updated the amount, "YYYY-MM-DD".
    /// Not called `updated`: Core Data already uses that name for its own "has changes" flag.
    var updatedOn: String
    var sample: Bool

    var kind: AssetKind {
        get { AssetKind(rawValue: kindRaw) ?? .available }
        set { kindRaw = newValue.rawValue }
    }

    var icon: AssetIcon {
        get { AssetIcon(rawValue: iconRaw) ?? .cash }
        set { iconRaw = newValue.rawValue }
    }

    init(id: String = UUID().uuidString, name: String, kind: AssetKind, icon: AssetIcon, amount: Int, updated: String, sample: Bool = false) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.iconRaw = icon.rawValue
        self.amount = amount
        self.updatedOn = updated
        self.sample = sample
    }
}

/// One change to an asset: money put in (positive) or taken out (negative).
@Model
final class AssetMove {
    @Attribute(.unique) var id: String
    var title: String
    var iconRaw: String
    var amount: Int
    var date: String
    var sample: Bool

    var icon: AssetIcon { AssetIcon(rawValue: iconRaw) ?? .cash }

    init(id: String = UUID().uuidString, title: String, icon: AssetIcon, amount: Int, date: String, sample: Bool = false) {
        self.id = id
        self.title = title
        self.iconRaw = icon.rawValue
        self.amount = amount
        self.date = date
        self.sample = sample
    }
}

/// Money given to family — counted as "Taken care of", never as spending.
@Model
final class CareGift {
    @Attribute(.unique) var id: String
    /// Who it was for: "Parents", "Young brother", "Household"…
    var who: String
    var title: String
    var amount: Int
    var date: String
    var sample: Bool

    init(id: String = UUID().uuidString, who: String, title: String, amount: Int, date: String, sample: Bool = false) {
        self.id = id
        self.who = who
        self.title = title
        self.amount = amount
        self.date = date
        self.sample = sample
    }
}

/// Net worth at the end of a month, for the chart. Only the sample fills it today.
@Model
final class WorthPoint {
    @Attribute(.unique) var month: String
    var value: Int
    var sample: Bool

    init(month: String, value: Int, sample: Bool = false) {
        self.month = month
        self.value = value
        self.sample = sample
    }
}

/// The one profile on this phone: name and display choices (Prefs in the web app).
@Model
final class Profile {
    var name: String
    /// Start with amounts hidden every time the app opens.
    var hideOnOpen: Bool
    /// Apply the same hiding to the Finance tab.
    var hideAssets: Bool
    /// "YYYY-MM-DD" — first time the app was opened on this phone.
    var joined: String
    var birthYear: Int?

    init(name: String = "Nin", hideOnOpen: Bool = false, hideAssets: Bool = false, joined: String = Day.today(), birthYear: Int? = nil) {
        self.name = name
        self.hideOnOpen = hideOnOpen
        self.hideAssets = hideAssets
        self.joined = joined
        self.birthYear = birthYear
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Entry.self, DayNote.self, Bill.self, Asset.self, AssetMove.self, CareGift.self, WorthPoint.self, Profile.self,
    ]
}

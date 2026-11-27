import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Everything on this phone as one JSON file the user keeps (Profile › Download your data).
/// Same shape as the web app's export: dates "YYYY-MM-DD", money in whole đồng.
nonisolated struct ExportFile: Codable, Equatable, Sendable {
    struct EntryRow: Codable, Equatable, Sendable {
        var id, date, title: String
        var amount: Int
        var flow, category, noteId, source: String
        var createdAt: Date
        var billId: String?
        var sample: Bool
        var tags: [String]
        var comment: String
        var paidFrom: String?
    }
    struct NoteRow: Codable, Equatable, Sendable { var date: String; var lines: [String]; var updatedAt: Date }
    struct BillRow: Codable, Equatable, Sendable {
        var id, kind, name, icon: String
        var amount: Int
        var varies: Bool
        var start: String
        var code, payWith, lender: String?
        var principal, payments: Int?
        var rate, fee: Double?
        var paid: [String: PaidRecord]
        var sample: Bool
    }
    struct AssetRow: Codable, Equatable, Sendable {
        var id, name, kind, icon: String
        var amount: Int
        var updated: String
        var sample: Bool
        var note: String? = nil
        /// What's held in its own unit, e.g. 5 "chi" (version 3; older files have neither).
        var quantity: Double? = nil
        var unit: String? = nil
        /// false when the user keeps their own value instead of today's price (newer files only).
        var followsPrice: Bool? = nil
    }
    struct MoveRow: Codable, Equatable, Sendable {
        var id, title, icon: String
        var amount: Int
        var date: String
        var sample: Bool
        /// Which asset, and "in" / "out" / "value" (version 2; older files have neither).
        var assetId: String? = nil
        var kind: String? = nil
    }
    struct LoanRow: Codable, Equatable, Sendable {
        var id, who, title, kind: String
        var amount: Int
        var date: String
        var rate: Double
        var sample: Bool
    }
    struct BelongingRow: Codable, Equatable, Sendable {
        var id, name, icon, mode: String
        var paid: Int
        var boughtOn: String
        var estimate: Int
        var estimatedOn: String
        var lossPerYear, floorPct, quickSalePct: Double
        var source, note: String?
        var createdAt: Date
        var sample: Bool
        /// A collection, and the collection a piece is in (newer files only).
        var isCollection: Bool? = nil
        var parentId: String? = nil
        var entryId: String? = nil
        var code: String? = nil
        var year: Int? = nil
        var condition: String? = nil
        var keeps: Bool? = nil
        var soldOn: String? = nil
        var soldFor: Int? = nil
    }
    struct WorthRow: Codable, Equatable, Sendable { var month: String; var value: Int; var sample: Bool }
    /// Settings kept outside the database (on this phone's UserDefaults).
    struct Settings: Codable, Equatable, Sendable {
        var savingGoal: Int?
        var savingCountsBills: Bool?
        var depositPlans: [String: Int]?
        var padRates: [String: Double]?
    }
    struct CareRow: Codable, Equatable, Sendable { var id, who, title: String; var amount: Int; var date: String; var sample: Bool }
    struct Prefs: Codable, Equatable, Sendable {
        var hideOnOpen, hideAssets: Bool
        var joined: String
        var birthYear: Int?
        var customTags: [String]
        var banks: [String]? = nil
    }

    /// 2 adds family loans, the Total Asset line, asset notes, move kinds and settings.
    var version: Int? = 2
    var exported: Date
    var name: String
    var entries: [EntryRow]
    var notes: [NoteRow]
    var bills: [BillRow]
    var assets: [AssetRow]
    var moves: [MoveRow]
    var care: [CareRow]
    var prefs: Prefs
    var loans: [LoanRow]? = nil
    var worth: [WorthRow]? = nil
    var settings: Settings? = nil
    /// Land, a car, a watch… (newer files only).
    var belongings: [BelongingRow]? = nil

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    func data() throws -> Data { try Self.encoder().encode(self) }
}

extension ExportFile {
    /// Reads everything from the store.
    @MainActor
    init(store: LocalStore, now: Date = .now, defaults: UserDefaults = .standard) {
        let p = store.profile
        self.init(
            version: 2,
            exported: now,
            name: p?.name ?? "Nin",
            // Stable orders (whole seconds, then id) so export → restore → export gives the same file.
            entries: store.all(Entry.self).sorted { (Int($0.createdAt.timeIntervalSince1970), $0.id) < (Int($1.createdAt.timeIntervalSince1970), $1.id) }.map {
                EntryRow(id: $0.id, date: $0.date, title: $0.title, amount: $0.amount, flow: $0.flowRaw, category: $0.categoryRaw,
                         noteId: $0.noteId, source: $0.source, createdAt: $0.createdAt, billId: $0.billId, sample: $0.sample,
                         tags: $0.tags, comment: $0.comment, paidFrom: $0.paidFrom)
            },
            notes: store.all(DayNote.self).sorted { $0.date < $1.date }.map { NoteRow(date: $0.date, lines: $0.lines, updatedAt: $0.updatedAt) },
            bills: store.all(Bill.self).sorted { ($0.start, $0.id) < ($1.start, $1.id) }.map {
                BillRow(id: $0.id, kind: $0.kindRaw, name: $0.name, icon: $0.iconRaw, amount: $0.amount, varies: $0.varies,
                        start: $0.start, code: $0.code, payWith: $0.payWith, lender: $0.lender, principal: $0.principal,
                        payments: $0.payments, rate: $0.rate, fee: $0.fee, paid: $0.paid, sample: $0.sample)
            },
            assets: store.all(Asset.self).map {
                AssetRow(id: $0.id, name: $0.name, kind: $0.kindRaw, icon: $0.iconRaw, amount: $0.amount, updated: $0.updatedOn,
                         sample: $0.sample, note: $0.note, quantity: $0.quantity, unit: $0.unitRaw,
                         followsPrice: $0.followsPrice ? nil : false)
            }.sorted { $0.id < $1.id },
            moves: store.all(AssetMove.self).sorted { ($0.date, $0.id) < ($1.date, $1.id) }.map {
                MoveRow(id: $0.id, title: $0.title, icon: $0.iconRaw, amount: $0.amount, date: $0.date, sample: $0.sample,
                        assetId: $0.assetId, kind: $0.kindRaw)
            },
            care: store.all(CareGift.self).sorted { ($0.date, $0.id) < ($1.date, $1.id) }.map {
                CareRow(id: $0.id, who: $0.who, title: $0.title, amount: $0.amount, date: $0.date, sample: $0.sample)
            },
            prefs: Prefs(hideOnOpen: p?.hideOnOpen ?? false, hideAssets: p?.hideAssets ?? false,
                         joined: p?.joined ?? Day.today(), birthYear: p?.birthYear, customTags: p?.customTags ?? [],
                         banks: p?.banks ?? []),
            loans: store.all(FamilyLoan.self).sorted { ($0.date, $0.id) < ($1.date, $1.id) }.map {
                LoanRow(id: $0.id, who: $0.who, title: $0.title, kind: $0.kindRaw, amount: $0.amount, date: $0.date,
                        rate: $0.rate, sample: $0.sample)
            },
            worth: store.all(WorthPoint.self).sorted { $0.month < $1.month }.map {
                WorthRow(month: $0.month, value: $0.value, sample: $0.sample)
            },
            settings: Settings.read(defaults),
            belongings: store.all(Belonging.self).sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }.map {
                BelongingRow(id: $0.id, name: $0.name, icon: $0.iconRaw, mode: $0.modeRaw, paid: $0.paid,
                             boughtOn: $0.boughtOn, estimate: $0.estimate, estimatedOn: $0.estimatedOn,
                             lossPerYear: $0.lossPerYear, floorPct: $0.floorPct, quickSalePct: $0.quickSalePct,
                             source: $0.source, note: $0.note, createdAt: $0.createdAt, sample: $0.sample,
                             isCollection: $0.isCollection ? true : nil, parentId: $0.parentId, entryId: $0.entryId,
                             code: $0.code, year: $0.year, condition: $0.conditionRaw,
                             keeps: $0.keeps ? true : nil, soldOn: $0.soldOn, soldFor: $0.soldFor)
            })
    }
}

/// What ShareLink hands to the share sheet: a ready-made JSON file.
nonisolated struct ExportDocument: Transferable {
    var data: Data
    var fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { $0.fileName }
    }
}

extension ExportFile.Settings {
    /// The @AppStorage keys these come from.
    enum Key {
        static let savingGoal = "savingGoal", savingCountsBills = "savingCountsBills"
        static let depositPlans = "depositPlans", padRates = "padRates"
    }

    static func read(_ d: UserDefaults) -> Self {
        func json<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            guard let raw = d.string(forKey: key), !raw.isEmpty else { return nil }
            return try? JSONDecoder().decode(T.self, from: Data(raw.utf8))
        }
        return Self(
            savingGoal: d.object(forKey: Key.savingGoal) as? Int,
            savingCountsBills: d.object(forKey: Key.savingCountsBills) as? Bool,
            depositPlans: json(Key.depositPlans, [String: Int].self),
            padRates: json(Key.padRates, [String: Double].self))
    }

    /// Puts them back; a setting the file doesn't have is left as it is.
    func write(_ d: UserDefaults) {
        func json<T: Encodable>(_ value: T, _ key: String) {
            if let data = try? JSONEncoder().encode(value) { d.set(String(decoding: data, as: UTF8.self), forKey: key) }
        }
        if let savingGoal { d.set(savingGoal, forKey: Key.savingGoal) }
        if let savingCountsBills { d.set(savingCountsBills, forKey: Key.savingCountsBills) }
        if let depositPlans { json(depositPlans, Key.depositPlans) }
        if let padRates { json(padRates, Key.padRates) }
    }
}

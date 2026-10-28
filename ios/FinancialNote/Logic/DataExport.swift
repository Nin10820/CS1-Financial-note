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
    }
    struct MoveRow: Codable, Equatable, Sendable { var id, title, icon: String; var amount: Int; var date: String; var sample: Bool }
    struct CareRow: Codable, Equatable, Sendable { var id, who, title: String; var amount: Int; var date: String; var sample: Bool }
    struct Prefs: Codable, Equatable, Sendable { var hideOnOpen, hideAssets: Bool; var joined: String; var birthYear: Int? }

    var exported: Date
    var name: String
    var entries: [EntryRow]
    var notes: [NoteRow]
    var bills: [BillRow]
    var assets: [AssetRow]
    var moves: [MoveRow]
    var care: [CareRow]
    var prefs: Prefs

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
    init(store: LocalStore, now: Date = .now) {
        let p = store.profile
        self.init(
            exported: now,
            name: p?.name ?? "Nin",
            entries: store.all(Entry.self).sorted { $0.createdAt < $1.createdAt }.map {
                EntryRow(id: $0.id, date: $0.date, title: $0.title, amount: $0.amount, flow: $0.flowRaw, category: $0.categoryRaw,
                         noteId: $0.noteId, source: $0.source, createdAt: $0.createdAt, billId: $0.billId, sample: $0.sample)
            },
            notes: store.all(DayNote.self).sorted { $0.date < $1.date }.map { NoteRow(date: $0.date, lines: $0.lines, updatedAt: $0.updatedAt) },
            bills: store.all(Bill.self).sorted { $0.createdAt < $1.createdAt }.map {
                BillRow(id: $0.id, kind: $0.kindRaw, name: $0.name, icon: $0.iconRaw, amount: $0.amount, varies: $0.varies,
                        start: $0.start, code: $0.code, payWith: $0.payWith, lender: $0.lender, principal: $0.principal,
                        payments: $0.payments, rate: $0.rate, fee: $0.fee, paid: $0.paid, sample: $0.sample)
            },
            assets: store.all(Asset.self).map {
                AssetRow(id: $0.id, name: $0.name, kind: $0.kindRaw, icon: $0.iconRaw, amount: $0.amount, updated: $0.updatedOn, sample: $0.sample)
            },
            moves: store.all(AssetMove.self).sorted { $0.date < $1.date }.map {
                MoveRow(id: $0.id, title: $0.title, icon: $0.iconRaw, amount: $0.amount, date: $0.date, sample: $0.sample)
            },
            care: store.all(CareGift.self).sorted { $0.date < $1.date }.map {
                CareRow(id: $0.id, who: $0.who, title: $0.title, amount: $0.amount, date: $0.date, sample: $0.sample)
            },
            prefs: Prefs(hideOnOpen: p?.hideOnOpen ?? false, hideAssets: p?.hideAssets ?? false,
                         joined: p?.joined ?? Day.today(), birthYear: p?.birthYear))
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

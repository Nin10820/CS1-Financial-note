import Foundation
import Observation
import SwiftData

// MARK: - Restore

extension ExportFile {
    /// Reads a file made by "Download your data", the backup folder, or the web app.
    static func decode(_ data: Data) throws -> ExportFile {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = plain.date(from: raw) ?? fractional.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a date: \(raw)"))
        }
        return try d.decode(ExportFile.self, from: data)
    }

    /// How much is in it, for the "Replace everything?" question and the result.
    var summary: String {
        var parts = ["\(entries.count) spends and incomes", "\(bills.count) bills", "\(assets.count) assets"]
        if let loans, !loans.isEmpty { parts.append("\(loans.count) family loan moves") }
        if let belongings, !belongings.isEmpty { parts.append("\(belongings.count) belongings") }
        return parts.joined(separator: ", ")
    }
}

extension LocalStore {
    /// Replaces everything on this phone with what's in the file. Settings the file doesn't
    /// have are left as they are.
    func restore(_ file: ExportFile, defaults: UserDefaults = .standard) throws {
        for model in AppSchema.models { try context.delete(model: model) }
        try context.save()

        let prefs = file.prefs
        let profile = Profile(name: file.name, hideOnOpen: prefs.hideOnOpen, hideAssets: prefs.hideAssets,
                              joined: prefs.joined, birthYear: prefs.birthYear)
        profile.customTags = prefs.customTags
        profile.banks = prefs.banks ?? []
        context.insert(profile)

        for r in file.entries {
            let e = Entry(id: r.id, date: r.date, title: r.title, amount: r.amount, flow: .out, category: .other,
                          noteId: r.noteId, source: r.source, createdAt: r.createdAt, billId: r.billId, sample: r.sample)
            e.flowRaw = r.flow
            e.categoryRaw = r.category
            e.tags = r.tags
            e.comment = r.comment
            e.paidFrom = r.paidFrom
            context.insert(e)
        }
        for r in file.notes {
            context.insert(DayNote(date: r.date, lines: r.lines, updatedAt: r.updatedAt))
        }
        for r in file.bills {
            let b = Bill(id: r.id, kind: .recurring, name: r.name, icon: .bell, amount: r.amount, varies: r.varies,
                         start: r.start, code: r.code, payWith: r.payWith, lender: r.lender, principal: r.principal,
                         payments: r.payments, rate: r.rate, fee: r.fee, paid: r.paid, sample: r.sample)
            b.kindRaw = r.kind
            b.iconRaw = r.icon
            context.insert(b)
        }
        for r in file.assets {
            let a = Asset(id: r.id, name: r.name, kind: .available, icon: .cash, amount: r.amount, updated: r.updated,
                          sample: r.sample)
            a.kindRaw = r.kind
            a.iconRaw = r.icon
            a.note = r.note
            a.quantity = r.quantity
            a.unitRaw = r.unit
            a.followsPrice = r.followsPrice ?? true
            context.insert(a)
        }
        for r in file.moves {
            let m = AssetMove(id: r.id, title: r.title, icon: .cash, amount: r.amount, date: r.date, sample: r.sample,
                              assetId: r.assetId)
            m.iconRaw = r.icon
            if let kind = r.kind { m.kindRaw = kind }
            context.insert(m)
        }
        for r in file.care {
            context.insert(CareGift(id: r.id, who: r.who, title: r.title, amount: r.amount, date: r.date, sample: r.sample))
        }
        for r in file.loans ?? [] {
            let l = FamilyLoan(id: r.id, who: r.who, title: r.title, kind: .received, amount: r.amount, date: r.date,
                               rate: r.rate, sample: r.sample)
            l.kindRaw = r.kind
            context.insert(l)
        }
        for r in file.belongings ?? [] {
            let b = Belonging(id: r.id, name: r.name, icon: .other, mode: .estimate, paid: r.paid, boughtOn: r.boughtOn,
                              estimate: r.estimate, estimatedOn: r.estimatedOn, lossPerYear: r.lossPerYear,
                              floorPct: r.floorPct, quickSalePct: r.quickSalePct, source: r.source, note: r.note,
                              createdAt: r.createdAt, sample: r.sample)
            b.iconRaw = r.icon
            b.modeRaw = r.mode
            b.isCollection = r.isCollection ?? false
            b.parentId = r.parentId
            b.entryId = r.entryId
            b.code = r.code; b.year = r.year; b.conditionRaw = r.condition
            b.keeps = r.keeps ?? false; b.soldOn = r.soldOn; b.soldFor = r.soldFor
            context.insert(b)
        }
        for r in file.worth ?? [] {
            context.insert(WorthPoint(month: r.month, value: r.value, sample: r.sample))
        }
        try context.save()
        file.settings?.write(defaults)
    }
}

// MARK: - CSV

/// The same data as tables, to open in Excel, Numbers or Google Sheets. Reading only: the
/// JSON file is the one that restores. Money is whole đồng; dates are YYYY-MM-DD.
enum BackupCSV {
    static func files(_ f: ExportFile) -> [(name: String, data: Data)] {
        let assetNames = Dictionary(f.assets.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        func group(_ raw: String) -> String { AssetKind(rawValue: raw)?.label ?? raw }
        func sample(_ s: Bool) -> String { s ? "yes" : "" }
        return [
            ("entries.csv", table(
                ["date", "title", "amount", "flow", "category", "tags", "comment", "paid from", "sample", "id"],
                f.entries.sorted { ($0.date, $0.createdAt) < ($1.date, $1.createdAt) }.map {
                    [$0.date, $0.title, "\($0.amount)", $0.flow, $0.category, $0.tags.joined(separator: " "), $0.comment,
                     $0.paidFrom ?? "", sample($0.sample), $0.id]
                })),
            ("assets.csv", table(
                ["name", "group", "worth now", "updated", "note", "sample", "id"],
                f.assets.sorted { $0.name < $1.name }.map {
                    [$0.name, group($0.kind), "\($0.amount)", $0.updated, $0.note ?? "", sample($0.sample), $0.id]
                })),
            ("asset-moves.csv", table(
                ["date", "asset", "kind", "amount", "sample", "asset id", "id"],
                f.moves.map {
                    [$0.date, $0.assetId.flatMap { assetNames[$0] } ?? $0.title,
                     $0.kind.flatMap { AssetMoveKind(rawValue: $0)?.label } ?? $0.kind ?? "",
                     "\($0.amount)", sample($0.sample), $0.assetId ?? "", $0.id]
                })),
            ("bills.csv", table(
                ["name", "kind", "amount", "start", "changes", "pay with", "lender", "borrowed", "payments",
                 "monthly rate %", "fee %", "months paid", "sample", "id"],
                f.bills.map {
                    [$0.name, $0.kind, "\($0.amount)", $0.start, $0.varies ? "yes" : "", $0.payWith ?? "", $0.lender ?? "",
                     $0.principal.map(String.init) ?? "", $0.payments.map(String.init) ?? "",
                     $0.rate.map { "\($0)" } ?? "", $0.fee.map { "\($0)" } ?? "",
                     $0.paid.keys.sorted().joined(separator: " "), sample($0.sample), $0.id]
                })),
            ("family-loans.csv", table(
                ["date", "who", "kind", "amount", "yearly rate %", "title", "sample", "id"],
                (f.loans ?? []).map {
                    [$0.date, $0.who, LoanMove(rawValue: $0.kind)?.label ?? $0.kind, "\($0.amount)", "\($0.rate)",
                     $0.title, sample($0.sample), $0.id]
                })),
            ("belongings.csv", table(
                ["name", "valued by", "paid", "bought", "your value", "checked", "loses % a year", "quick sale %",
                 "source", "note", "sample", "id"],
                (f.belongings ?? []).map {
                    [$0.name, BelongingValue(rawValue: $0.mode)?.label ?? $0.mode, "\($0.paid)", $0.boughtOn,
                     "\($0.estimate)", $0.estimatedOn, "\($0.lossPerYear)", "\($0.quickSalePct)",
                     $0.source ?? "", $0.note ?? "", sample($0.sample), $0.id]
                })),
            ("worth.csv", table(
                ["month", "total asset"],
                (f.worth ?? []).map { [$0.month, "\($0.value)"] })),
        ]
    }

    /// UTF-8 with a byte-order mark so Excel shows Vietnamese right; CRLF line ends.
    static func table(_ header: [String], _ rows: [[String]]) -> Data {
        let lines = ([header] + rows).map { $0.map(field).joined(separator: ",") }
        return Data(("\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    /// Quoted when it holds a comma, a quote or a line break; quotes doubled.
    static func field(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Backup folder

/// Keeps a copy of everything in a folder the user picked in Files (iCloud Drive or On My
/// iPhone): financial-note.json to restore from, plus the CSV tables. It's rewritten a couple
/// of seconds after each change. The app itself never goes online; if the folder is in iCloud
/// Drive, the phone syncs it like any other file.
@MainActor
@Observable
final class BackupFolder {
    static let shared = BackupFolder()

    static let jsonName = "financial-note.json"
    private enum Key {
        static let bookmark = "backupFolderBookmark", name = "backupFolderName", saved = "backupLastSaved"
    }

    private let defaults: UserDefaults
    /// The folder's name, e.g. "Financial Note"; nil when backing up is off.
    private(set) var folderName: String?
    private(set) var lastSaved: Date?
    /// Why the last write didn't work, in plain words.
    private(set) var problem: String?
    private var pending: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        folderName = defaults.data(forKey: Key.bookmark) == nil ? nil : defaults.string(forKey: Key.name)
        lastSaved = defaults.object(forKey: Key.saved) as? Date
    }

    var isOn: Bool { folderName != nil }

    /// Remembers the folder picked in Files, then writes the first copy.
    func choose(_ url: URL, container: ModelContainer) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Key.bookmark)
            defaults.set(url.lastPathComponent, forKey: Key.name)
            folderName = url.lastPathComponent
            problem = nil
        } catch {
            problem = "Couldn't keep that folder. Try another one."
            return
        }
        saveNow(container: container)
    }

    func stop() {
        pending?.cancel()
        defaults.removeObject(forKey: Key.bookmark)
        defaults.removeObject(forKey: Key.name)
        folderName = nil
        problem = nil
    }

    /// After a change: wait a moment so a burst of edits makes one write.
    func changed(container: ModelContainer) {
        guard isOn else { return }
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.saveNow(container: container)
        }
    }

    func saveNow(container: ModelContainer) {
        pending?.cancel()
        guard let folder = resolve() else { return }
        let file = ExportFile(store: LocalStore(context: container.mainContext), defaults: defaults)
        do {
            let files = [(Self.jsonName, try file.data())] + BackupCSV.files(file)
            try Self.write(files, into: folder)
            lastSaved = .now
            defaults.set(lastSaved, forKey: Key.saved)
            problem = nil
        } catch {
            problem = "Couldn't save to \(folderName ?? "the folder"). Check it's still there, or pick it again."
        }
    }

    /// The JSON in the folder, to restore from without picking it again.
    func readBackup() throws -> ExportFile? {
        guard let folder = resolve() else { return nil }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        var result: Data?
        var coordError: NSError?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: folder.appendingPathComponent(Self.jsonName), options: [],
                                       error: &coordError) { url in
            do { result = try Data(contentsOf: url) } catch { readError = error }
        }
        if let e = coordError ?? readError { throw e }
        return try result.map(ExportFile.decode)
    }

    private func resolve() -> URL? {
        guard let bookmark = defaults.data(forKey: Key.bookmark) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else {
            problem = "The backup folder is gone. Pick a folder again."
            return nil
        }
        if stale, let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(fresh, forKey: Key.bookmark)
        }
        return url
    }

    /// Overwrites each file, coordinated so iCloud Drive and Files see a whole file.
    nonisolated private static func write(_ files: [(String, Data)], into folder: URL) throws {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        for (name, data) in files {
            var coordError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: folder.appendingPathComponent(name), options: .forReplacing,
                                           error: &coordError) { url in
                do { try data.write(to: url, options: .atomic) } catch { writeError = error }
            }
            if let e = coordError ?? writeError { throw e }
        }
    }
}

#if DEBUG
/// Developer-only: adds rows from Documents/import.json (the same row shapes as a backup file)
/// to the open data set. Belongings with an id already there are updated; other rows with an id
/// already there are skipped. The file is removed after.
enum DevImport {
    struct File: Decodable {
        var belongings: [ExportFile.BelongingRow]?
        var entries: [ExportFile.EntryRow]?
        var care: [ExportFile.CareRow]?
        var loans: [ExportFile.LoanRow]?
        var bills: [ExportFile.BillRow]?
    }

    @MainActor
    static func run(_ context: ModelContext) {
        let url = URL.documentsDirectory.appending(path: "import.json")
        guard let data = try? Data(contentsOf: url) else { return }
        let f: File
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        do { f = try d.decode(File.self, from: data) } catch {
            try? Data("\(error)".utf8).write(to: URL.documentsDirectory.appending(path: "import-error.txt"))
            return
        }
        let store = LocalStore(context: context)
        let have = Dictionary(store.all(Belonging.self).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for r in f.belongings ?? [] {
            let b = have[r.id] ?? Belonging(id: r.id, name: r.name, icon: .other, mode: .estimate, paid: 0, boughtOn: r.boughtOn)
            b.name = r.name; b.iconRaw = r.icon; b.modeRaw = r.mode; b.paid = r.paid; b.boughtOn = r.boughtOn
            b.estimate = r.estimate; b.estimatedOn = r.estimatedOn; b.lossPerYear = r.lossPerYear
            b.floorPct = r.floorPct; b.quickSalePct = r.quickSalePct; b.source = r.source; b.note = r.note
            b.isCollection = r.isCollection ?? false; b.parentId = r.parentId; b.entryId = r.entryId
            b.code = r.code; b.year = r.year; b.conditionRaw = r.condition
            b.keeps = r.keeps ?? false; b.soldOn = r.soldOn; b.soldFor = r.soldFor
            if have[r.id] == nil { b.createdAt = r.createdAt; context.insert(b) }
        }
        let entryIds = Set(store.all(Entry.self).map(\.id))
        for r in f.entries ?? [] where !entryIds.contains(r.id) {
            let e = Entry(id: r.id, date: r.date, title: r.title, amount: r.amount, flow: .out, category: .other,
                          noteId: r.noteId, source: r.source, createdAt: r.createdAt, billId: r.billId, sample: false)
            e.flowRaw = r.flow; e.categoryRaw = r.category; e.tags = r.tags; e.comment = r.comment; e.paidFrom = r.paidFrom
            context.insert(e)
        }
        let careIds = Set(store.all(CareGift.self).map(\.id))
        for r in f.care ?? [] where !careIds.contains(r.id) {
            context.insert(CareGift(id: r.id, who: r.who, title: r.title, amount: r.amount, date: r.date))
        }
        let loanIds = Set(store.all(FamilyLoan.self).map(\.id))
        for r in f.loans ?? [] where !loanIds.contains(r.id) {
            let l = FamilyLoan(id: r.id, who: r.who, title: r.title, kind: .received, amount: r.amount, date: r.date, rate: r.rate)
            l.kindRaw = r.kind
            context.insert(l)
        }
        let billIds = Set(store.all(Bill.self).map(\.id))
        for r in f.bills ?? [] where !billIds.contains(r.id) {
            let b = Bill(id: r.id, kind: .oneoff, name: r.name, icon: .bell, amount: r.amount, varies: r.varies, start: r.start,
                         code: r.code, payWith: r.payWith, lender: r.lender, principal: r.principal, payments: r.payments,
                         rate: r.rate, fee: r.fee, paid: r.paid)
            b.kindRaw = r.kind; b.iconRaw = r.icon
            context.insert(b)
        }
        try? context.save()
        try? FileManager.default.removeItem(at: url)
    }

    /// `-legoPictures`: gets the picture of every Lego piece that has a code and none yet.
    @MainActor
    static func legoPictures(_ context: ModelContext) async {
        for p in LocalStore(context: context).all(Belonging.self) where p.imageData == nil && p.parentId != nil {
            guard let set = p.code.flatMap(LegoCatalog.find), let data = await LegoCatalog.picture(for: set) else { continue }
            p.imageData = data
            try? context.save()
        }
    }
}
#endif

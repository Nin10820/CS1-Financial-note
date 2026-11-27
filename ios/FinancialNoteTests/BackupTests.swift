import SwiftData
import XCTest
@testable import FinancialNote

@MainActor
final class BackupTests: XCTestCase {
    private func makeStore() throws -> LocalStore {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return LocalStore(context: container.mainContext)
    }

    private func defaults(_ name: String) -> UserDefaults {
        let d = UserDefaults(suiteName: "BackupTests.\(name)")!
        d.removePersistentDomain(forName: "BackupTests.\(name)")
        return d
    }

    /// Export → restore on a clean phone → export again gives the very same file.
    func testRestoreGivesBackTheSameData() throws {
        let from = try makeStore()
        from.prepareOnLaunch(today: "2026-11-21")
        from.loadSample()
        let asset = Asset(name: "Vàng SJC, nhẫn", kind: .growing, icon: .gold, amount: 15_000_000, updated: "2026-11-20")
        asset.note = "Ở nhà \"két\""
        from.addAsset(asset)
        from.profile?.banks = ["tpbank"]
        let fromDefaults = defaults("from")
        fromDefaults.set(5_000_000, forKey: "savingGoal")
        fromDefaults.set(true, forKey: "savingCountsBills")
        fromDefaults.set(#"{"2024":2000000}"#, forKey: "depositPlans")
        fromDefaults.set(#"{"USD":26000}"#, forKey: "padRates")

        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let file = ExportFile(store: from, now: now, defaults: fromDefaults)
        XCTAssertFalse(file.loans?.isEmpty ?? true)
        XCTAssertFalse(file.worth?.isEmpty ?? true)
        XCTAssertEqual(file.assets.first { $0.id == asset.id }?.note, "Ở nhà \"két\"")
        XCTAssertEqual(file.settings?.depositPlans, ["2024": 2_000_000])

        let to = try makeStore()
        to.prepareOnLaunch(today: "2026-11-21")
        let toDefaults = defaults("to")
        try to.restore(ExportFile.decode(file.data()), defaults: toDefaults)

        let again = ExportFile(store: to, now: now, defaults: toDefaults)
        XCTAssertEqual(String(decoding: try again.data(), as: UTF8.self), String(decoding: try file.data(), as: UTF8.self))
        XCTAssertEqual(to.all(Profile.self).count, 1)
        XCTAssertEqual(toDefaults.integer(forKey: "savingGoal"), 5_000_000)
    }

    /// A file from before version 2 (or the web app) has no loans, worth line or settings.
    func testOldFileStillRestores() throws {
        let old = """
        {"exported":"2026-10-01T10:00:00Z","name":"Nin","entries":[],"notes":[],"bills":[],
         "assets":[{"id":"a1","name":"Cash","kind":"available","icon":"cash","amount":200000,"updated":"2026-10-01","sample":false}],
         "moves":[{"id":"m1","title":"Cash","icon":"cash","amount":200000,"date":"2026-10-01","sample":false}],
         "care":[],"prefs":{"hideOnOpen":false,"hideAssets":false,"joined":"2026-09-01","customTags":[]}}
        """
        let file = try ExportFile.decode(Data(old.utf8))
        XCTAssertNil(file.loans)
        let store = try makeStore()
        try store.restore(file, defaults: defaults("old"))
        XCTAssertEqual(store.all(Asset.self).map(\.amount), [200_000])
        XCTAssertEqual(store.all(AssetMove.self).first?.kind, .putIn)
        XCTAssertEqual(store.profile?.joined, "2026-09-01")
    }

    func testCSVQuotesAndBOM() {
        XCTAssertEqual(BackupCSV.field("plain"), "plain")
        XCTAssertEqual(BackupCSV.field("a, b"), "\"a, b\"")
        XCTAssertEqual(BackupCSV.field("say \"hi\""), "\"say \"\"hi\"\"\"")
        let data = BackupCSV.table(["name"], [["Vàng"]])
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\u{FEFF}name\r\nVàng\r\n")
    }

    /// Picking a folder writes the JSON and the six tables, and a later save overwrites them.
    func testBackupFolderWritesAndOverwrites() throws {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = LocalStore(context: container.mainContext)
        store.prepareOnLaunch(today: "2026-11-21")
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let backup = BackupFolder(defaults: defaults("folder"))
        backup.choose(folder, container: container)
        XCTAssertNil(backup.problem)
        XCTAssertNotNil(backup.lastSaved)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        XCTAssertEqual(names, ["asset-moves.csv", "assets.csv", "bills.csv", "entries.csv", "family-loans.csv",
                               "financial-note.json", "worth.csv"])

        store.addAsset(Asset(name: "Fund", kind: .growing, icon: .fund, amount: 3_000_000, updated: "2026-11-21"))
        backup.saveNow(container: container)
        let read = try XCTUnwrap(backup.readBackup())
        XCTAssertEqual(read.assets.map(\.name), ["Fund"])
        let csv = try String(contentsOf: folder.appendingPathComponent("assets.csv"), encoding: .utf8)
        XCTAssertTrue(csv.contains("Fund,Growing,3000000,2026-11-21"))
    }
}

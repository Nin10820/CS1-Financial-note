import Foundation
import Observation
import SwiftData

/// Three separate stores on this phone, picked in Profile › Data. They never mix:
/// - Nin: your own data (the store the app always had).
/// - Empty: a clean start, as someone who just got the app.
/// - Example: a full made-up life, for trying things and showing the app.
@MainActor
@Observable
final class DataSets {
    static let shared = DataSets()

    enum Kind: String, CaseIterable, Identifiable {
        case nin, empty, example
        var id: String { rawValue }
        var title: String {
            switch self {
            case .nin: "Nin"
            case .empty: "Empty"
            case .example: "Example"
            }
        }
        var hint: String {
            switch self {
            case .nin: "Your own data"
            case .empty: "Starts with nothing, like a new phone"
            case .example: "Full made-up data to try things"
            }
        }
    }

    private static let key = "dataSet"
    private(set) var current: Kind
    private(set) var container: ModelContainer

    private init() {
        let kind = Kind(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .nin
        current = kind
        container = Self.open(kind)
    }

    /// Saves what's open, then opens the other store. The screens start fresh on it.
    func switchTo(_ kind: Kind) {
        guard kind != current else { return }
        try? container.mainContext.save()
        UserDefaults.standard.set(kind.rawValue, forKey: Self.key)
        current = kind
        container = Self.open(kind)
    }

    /// Example back to a fresh full copy (dates move with today); Empty back to nothing.
    func reset() {
        let store = LocalStore(context: container.mainContext)
        switch current {
        case .nin: return
        case .empty: store.clearAll()
        case .example:
            store.clearAll()
            store.loadSample()
        }
    }

    private static var inMemory: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    private static func open(_ kind: Kind) -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let config: ModelConfiguration
        switch kind {
        // Nin keeps the store the app always used, so nothing has to move.
        case .nin: config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        default:
            config = ModelConfiguration(kind.rawValue, schema: schema, url: URL.applicationSupportDirectory
                .appending(path: "\(kind.rawValue).store"), cloudKitDatabase: .none)
        }
        do {
            let c = try ModelContainer(for: schema, configurations: inMemory && kind != .nin
                                       ? ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none) : config)
            let store = LocalStore(context: c.mainContext)
            store.prepareOnLaunch()
            switch kind {
            case .nin: NinFinanceOnly.run(c.mainContext)
            case .example: if store.all(Entry.self).isEmpty { store.loadSample() }
            case .empty: break
            }
            return c
        } catch {
            fatalError("Couldn't open the \(kind.rawValue) store on this phone: \(error)")
        }
    }
}

/// Once: Nin's store keeps only Finance (assets, their history, the Total Asset line, family
/// loans and gifts). The made-up spending in Today and every bill in Due go — they were never
/// Nin's. A copy of the store as it was is kept next to it first ("nin-before-split").
enum NinFinanceOnly {
    private static let doneKey = "ninFinanceOnly.v1"

    @MainActor
    static func run(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey), !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        let store = LocalStore(context: context)
        // A new phone has nothing to split.
        guard !store.all(Bill.self).isEmpty || store.all(Entry.self).contains(where: \.sample) else {
            defaults.set(true, forKey: doneKey)
            return
        }
        keepCopy()
        store.all(Bill.self).forEach(context.delete)
        store.all(Entry.self).filter { $0.sample || $0.billId != nil }.forEach(context.delete)
        store.all(DayNote.self).filter(\.sample).forEach(context.delete)
        // What's left is Nin's own: it no longer goes when example data is cleared.
        store.all(Asset.self).forEach { $0.sample = false }
        store.all(AssetMove.self).forEach { $0.sample = false }
        store.all(WorthPoint.self).forEach { $0.sample = false }
        store.all(FamilyLoan.self).forEach { $0.sample = false }
        store.all(CareGift.self).forEach { $0.sample = false }
        try? context.save()
        defaults.set(true, forKey: doneKey)
    }

    /// default.store (and its -wal / -shm) copied as nin-before-split.store, once.
    private static func keepCopy() {
        let dir = URL.applicationSupportDirectory
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let from = dir.appending(path: "default.store" + suffix)
            let to = dir.appending(path: "nin-before-split.store" + suffix)
            guard fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) else { continue }
            try? fm.copyItem(at: from, to: to)
        }
    }
}

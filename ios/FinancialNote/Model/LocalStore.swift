import Foundation
import SwiftData

/// The writes that touch more than one model, ported from `useStore()` in `src/lib/store.ts`.
/// Simple edits (rename, change an amount) are done on the model directly by the views.
struct LocalStore {
    let context: ModelContext

    // MARK: - Reading

    func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    var profile: Profile? { all(Profile.self).first }

    var hasSample: Bool {
        all(Entry.self).contains(where: \.sample) || all(Asset.self).contains(where: \.sample)
            || all(Bill.self).contains(where: \.sample)
    }

    // MARK: - First launch

    /// First launch on this phone: make the profile and start with the sample so every screen
    /// has something to show.
    func prepareOnLaunch(today: String = Day.today()) {
        guard profile == nil else { return }
        context.insert(Profile(joined: today))
        loadSample(today: today)
        try? context.save()
    }

    // MARK: - Sample data

    /// Adds the sample on top of what is there (old sample items removed first, so it never doubles).
    func loadSample(today: String = Day.today(), now: Date = .now) {
        clearSample()
        let x = SampleData.make(today: today, now: now)
        x.entries.forEach(context.insert)
        x.bills.forEach(context.insert)
        x.assets.forEach(context.insert)
        x.moves.forEach(context.insert)
        x.care.forEach(context.insert)
        // A day note from the sample only fills a day the user hasn't written yet.
        let written = Set(all(DayNote.self).map(\.date))
        x.notes.filter { !written.contains($0.date) }.forEach(context.insert)
        if all(WorthPoint.self).isEmpty { x.worth.forEach(context.insert) }
        if let p = profile, p.birthYear == nil { p.birthYear = x.birthYear }
        try? context.save()
    }

    /// Removes every sample item and leaves the user's own data alone.
    func clearSample() {
        let hadSample = all(Asset.self).contains(where: \.sample) || all(Entry.self).contains(where: \.sample)
        all(Entry.self).filter(\.sample).forEach(context.delete)
        all(Bill.self).filter(\.sample).forEach(context.delete)
        all(Asset.self).filter(\.sample).forEach(context.delete)
        all(AssetMove.self).filter(\.sample).forEach(context.delete)
        all(CareGift.self).filter(\.sample).forEach(context.delete)
        all(DayNote.self).filter(\.sample).forEach(context.delete)
        // The chart is made from the sample, so it goes with it.
        if hadSample { all(WorthPoint.self).forEach(context.delete) }
        try? context.save()
    }

    /// Wipes everything on this phone and starts clean (no sample).
    func clearAll(today: String = Day.today()) {
        for model in AppSchema.models { try? context.delete(model: model) }
        context.insert(Profile(joined: today))
        try? context.save()
    }

    // MARK: - Entries and notes

    func addEntries(_ list: [Entry]) {
        list.forEach(context.insert)
        try? context.save()
    }

    /// Removes every line saved from one note.
    func removeNote(_ noteId: String) {
        all(Entry.self).filter { $0.noteId == noteId }.forEach(context.delete)
        try? context.save()
    }

    func saveDayNote(date: String, lines: [String]) {
        if let note = all(DayNote.self).first(where: { $0.date == date }) {
            note.lines = lines
            note.updatedAt = .now
            // Once the user writes in it, it's theirs: removing the sample keeps it.
            note.sample = false
        } else {
            context.insert(DayNote(date: date, lines: lines))
        }
        try? context.save()
    }

    // MARK: - Bills

    /// Deleting a bill also removes the spending its check-offs recorded.
    func removeBill(_ bill: Bill) {
        let id = bill.id
        all(Entry.self).filter { $0.billId == id }.forEach(context.delete)
        context.delete(bill)
        try? context.save()
    }

    /// Checking a bill off also records it as Bills spending on `date`, so the list of entries
    /// stays complete. Unchecking removes that entry again.
    func setBillPaid(_ bill: Bill, month: String, paid: Bool, date: String, amount: Int? = nil, now: Date = .now) {
        var records = bill.paid
        if paid {
            guard records[month] == nil else { return }
            let value = amount ?? bill.amount
            let entry = Entry(
                date: date, title: bill.name, amount: value, flow: .out, category: .bills,
                noteId: "bill-\(bill.id)-\(month)", source: "Checked off “\(bill.name)” in Due",
                createdAt: now, billId: bill.id)
            context.insert(entry)
            records[month] = PaidRecord(amount: value, at: now, entryId: entry.id)
        } else {
            guard let record = records.removeValue(forKey: month) else { return }
            if let entryId = record.entryId {
                all(Entry.self).filter { $0.id == entryId }.forEach(context.delete)
            }
        }
        bill.paid = records
        try? context.save()
    }

    // MARK: - Assets

    /// Adding an asset also writes its first line in the history.
    func addAsset(_ asset: Asset) {
        context.insert(asset)
        context.insert(AssetMove(title: asset.name, icon: asset.icon, amount: asset.amount, date: asset.updatedOn,
                                 assetId: asset.id, kind: .putIn))
        recordWorth(on: asset.updatedOn)
        try? context.save()
    }

    /// Money put in, taken out, or the value now. Records a move and keeps the asset's amount right.
    /// `amount` is what was put in or taken out, or for `.value` what the asset is worth now.
    func move(_ asset: Asset, _ kind: AssetMoveKind, amount: Int, date: String) {
        recordStart(asset)
        let change: Int
        switch kind {
        case .putIn: change = amount
        case .takeOut: change = -min(amount, asset.amount)
        case .value: change = amount - asset.amount
        }
        guard change != 0 else { return }
        asset.amount += change
        if date > asset.updatedOn { asset.updatedOn = date }
        context.insert(AssetMove(title: asset.name, icon: asset.icon, amount: change, date: date, assetId: asset.id, kind: kind))
        recordWorth(on: date)
        try? context.save()
    }

    /// Renames or regroups an asset; its history keeps up with the new name.
    func editAsset(_ asset: Asset, name: String, kind: AssetKind) {
        asset.name = name
        asset.kind = kind
        asset.icon = AssetMath.guessIcon(name, kind: kind)
        for m in all(AssetMove.self) where m.assetId == asset.id {
            m.title = name
            m.iconRaw = asset.icon.rawValue
        }
        try? context.save()
    }

    /// Removes an asset and its history; the total for this month follows.
    func removeAsset(_ asset: Asset, today: String = Day.today()) {
        all(AssetMove.self).filter { $0.assetId == asset.id }.forEach(context.delete)
        context.delete(asset)
        recordWorth(on: today)
        try? context.save()
    }

    /// An asset written down before moves were kept (or from the sample) gets its amount at
    /// that time as a starting point, so "Put in" and growth have something to count from.
    private func recordStart(_ asset: Asset) {
        guard !all(AssetMove.self).contains(where: { $0.assetId == asset.id }) else { return }
        context.insert(AssetMove(title: asset.name, icon: asset.icon, amount: asset.amount, date: asset.updatedOn,
                                 assetId: asset.id, kind: .putIn))
    }

    /// The Total Asset line: this month's point is the total of everything now.
    private func recordWorth(on date: String) {
        let month = Month.of(date)
        let total = all(Asset.self).reduce(0) { $0 + $1.amount }
        if let p = all(WorthPoint.self).first(where: { $0.month == month }) {
            p.value = total
        } else {
            context.insert(WorthPoint(month: month, value: total))
        }
    }
}

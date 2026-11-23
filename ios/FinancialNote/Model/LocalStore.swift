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
        refreshAssetIcons()
        guard profile == nil else { return }
        // A new phone starts empty; the made-up data comes in only from Profile › Load sample data.
        context.insert(Profile(joined: today))
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
        x.loans.forEach(context.insert)
        // A day note from the sample only fills a day the user hasn't written yet.
        let written = Set(all(DayNote.self).map(\.date))
        x.notes.filter { !written.contains($0.date) }.forEach(context.insert)
        if all(WorthPoint.self).isEmpty { x.worth.forEach(context.insert) }
        if let p = profile, p.birthYear == nil { p.birthYear = x.birthYear }
        try? context.save()
    }

    /// Adds what's new in the sample (bills, their check-off entries) without touching anything
    /// already there, and fills in "paid from" / "pay with" on sample lines that have none.
    /// Edits made to sample items stay.
    func topUpSample(today: String = Day.today(), now: Date = .now) {
        guard all(Bill.self).contains(where: \.sample) || all(Entry.self).contains(where: \.sample) else { return }
        let x = SampleData.make(today: today, now: now)
        let bills = Dictionary(all(Bill.self).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for b in x.bills {
            if let old = bills[b.id] {
                if old.sample && old.payWith == nil { old.payWith = b.payWith }
            } else {
                context.insert(b)
            }
        }
        let entries = Dictionary(all(Entry.self).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for e in x.entries {
            if let old = entries[e.id] {
                if old.sample && old.paidFrom == nil { old.paidFrom = e.paidFrom }
            } else if e.billId != nil {
                context.insert(e)
            }
        }
        try? context.save()
    }

    /// Removes every sample item and leaves the user's own data alone.
    func clearSample() {
        let hadSample = all(Asset.self).contains(where: \.sample) || all(Entry.self).contains(where: \.sample)
        // Ticking a sample bill in Due writes an entry of its own; it goes with the bill.
        all(Entry.self).filter { $0.sample || ($0.billId?.hasPrefix("sample-") ?? false) }.forEach(context.delete)
        all(Bill.self).filter(\.sample).forEach(context.delete)
        all(Asset.self).filter(\.sample).forEach(context.delete)
        // Money added to a sample asset goes with it too.
        all(AssetMove.self).filter { $0.sample || ($0.assetId?.hasPrefix("sample-") ?? false) }.forEach(context.delete)
        all(CareGift.self).filter(\.sample).forEach(context.delete)
        all(FamilyLoan.self).filter(\.sample).forEach(context.delete)
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
        shiftWorth(by: asset.amount, from: asset.updatedOn)
        try? context.save()
    }

    /// Money put in, taken out, or the value now. Records a move and keeps the asset's amount right.
    /// `amount` is what was put in or taken out, or for `.value` what the asset is worth now.
    /// Returns the move it wrote, so it can be undone.
    @discardableResult
    func move(_ asset: Asset, _ kind: AssetMoveKind, amount: Int, date: String) -> AssetMove? {
        recordStart(asset)
        let change: Int
        switch kind {
        case .putIn: change = amount
        case .takeOut: change = -min(amount, asset.amount)
        case .value: change = amount - asset.amount
        }
        guard change != 0 else { return nil }
        asset.amount += change
        if date > asset.updatedOn { asset.updatedOn = date }
        // Held in units (gold, dollars, coins): money in or out buys or sells some at today's price.
        if kind != .value { shiftQuantity(asset, byDong: change) }
        let m = AssetMove(title: asset.name, icon: asset.icon, amount: change, date: date, assetId: asset.id, kind: kind)
        context.insert(m)
        shiftWorth(by: change, from: date)
        try? context.save()
        return m
    }

    /// Put in, take out or set what's held in the asset's own unit (2 phân, 100 $): the đồng
    /// follow from today's price, and the quantity is set exactly.
    @discardableResult
    func moveUnits(_ asset: Asset, _ kind: AssetMoveKind, units: Double, price: Double, date: String) -> AssetMove? {
        let held = asset.quantity ?? 0
        let newQuantity: Double
        let dong: Int
        switch kind {
        case .putIn:
            newQuantity = held + units
            dong = Int((units * price).rounded())
        case .takeOut:
            let out = min(units, held)
            newQuantity = held - out
            dong = Int((out * price).rounded())
        case .value:
            newQuantity = units
            dong = Int((units * price).rounded())
        }
        let m = move(asset, kind, amount: dong, date: date)
        asset.quantity = (newQuantity * 10_000).rounded() / 10_000
        try? context.save()
        return m
    }

    /// Deletes one line of an asset's history (or undoes the last one): the asset's amount and
    /// the Total Asset line go back as if it never happened.
    func removeMove(_ m: AssetMove) {
        if let id = m.assetId, let asset = all(Asset.self).first(where: { $0.id == id }) {
            asset.amount = max(0, asset.amount - m.amount)
            if m.kind != .value { shiftQuantity(asset, byDong: -m.amount) }
        }
        shiftWorth(by: -m.amount, from: m.date)
        context.delete(m)
        try? context.save()
    }

    /// Changes how much of its unit an asset holds by this many đồng at today's price.
    private func shiftQuantity(_ asset: Asset, byDong change: Int) {
        guard let q = asset.quantity, let unit = asset.unit, let price = Market.price(unit), price > 0 else { return }
        asset.quantity = max(0, ((q + Double(change) / price) * 10_000).rounded() / 10_000)
    }

    /// Sets every asset held in units to quantity × today's price. One "Value changed" line a
    /// day per asset: a second sync the same day adjusts that line instead of adding another.
    func revalueHoldings(today: String) {
        let moves = all(AssetMove.self)
        for asset in all(Asset.self) {
            guard let q = asset.quantity, let unit = asset.unit, let price = Market.price(unit) else { continue }
            let target = Int((q * price).rounded())
            let delta = target - asset.amount
            guard delta != 0 else { continue }
            recordStart(asset)
            let latest = moves.filter { $0.assetId == asset.id }.max { ($0.date, $0.id) < ($1.date, $1.id) }
            if let m = latest, m.kind == .value, m.date == today {
                m.amount += delta
                if m.amount == 0 { context.delete(m) }
            } else {
                context.insert(AssetMove(title: asset.name, icon: asset.icon, amount: delta, date: today,
                                         assetId: asset.id, kind: .value))
            }
            asset.amount = target
            asset.updatedOn = max(asset.updatedOn, today)
            shiftWorth(by: delta, from: today)
        }
        try? context.save()
    }

    /// Sets what an asset holds in its own unit (or clears it with nil).
    func setHolding(_ asset: Asset, quantity: Double?, unit: HoldingUnit?) {
        asset.quantity = unit == nil ? nil : quantity
        asset.unit = quantity == nil ? nil : unit
        try? context.save()
    }

    // MARK: - Saving goal

    /// The asset the saving goal fills ("Savings", put aside), made the first time something is saved.
    static let savingsId = "saving-goal"

    /// Notes money put aside toward the saving goal. The app moves no money: this only writes it
    /// down, on the Savings asset in Finance.
    func putAside(_ amount: Int, date: String) {
        guard amount > 0 else { return }
        let savings: Asset
        if let a = all(Asset.self).first(where: { $0.id == Self.savingsId }) {
            savings = a
        } else {
            savings = Asset(id: Self.savingsId, name: "Savings", kind: .aside, icon: .piggy, amount: 0, updated: date)
            context.insert(savings)
        }
        savings.amount += amount
        if date > savings.updatedOn { savings.updatedOn = date }
        context.insert(AssetMove(title: savings.name, icon: savings.icon, amount: amount, date: date,
                                 assetId: savings.id, kind: .putIn))
        recordWorth(on: date)
        try? context.save()
    }

    /// Takes back what was put aside on a day (the quick save's undo).
    func undoPutAside(on date: String) {
        guard let savings = all(Asset.self).first(where: { $0.id == Self.savingsId }) else { return }
        let moves = all(AssetMove.self).filter { $0.assetId == savings.id && $0.date == date && $0.kind == .putIn }
        savings.amount -= min(savings.amount, moves.reduce(0) { $0 + $1.amount })
        moves.forEach(context.delete)
        recordWorth(on: date)
        try? context.save()
    }

    /// Icons are picked from the name; assets saved before there were USD, stock and coin icons
    /// get the clearer one. The saving goal's asset is the piggy bank.
    func refreshAssetIcons() {
        let moves = all(AssetMove.self)
        var changed = false
        for a in all(Asset.self) {
            let icon = a.id == Self.savingsId ? .piggy : AssetMath.guessIcon(a.name, kind: a.kind)
            guard icon != a.icon else { continue }
            a.icon = icon
            for m in moves where m.assetId == a.id { m.iconRaw = icon.rawValue }
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Renames or regroups an asset; its history keeps up with the new name.
    func editAsset(_ asset: Asset, name: String, kind: AssetKind, note: String? = nil) {
        asset.name = name
        asset.kind = kind
        asset.note = note
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

    /// A change written down for an earlier day moves the Total Asset line from that month on, so
    /// money put in back in 2020 shows from 2020. This month's point is always the total now.
    private func shiftWorth(by change: Int, from date: String, today: String = Day.today()) {
        let month = Month.of(date), now = Month.of(today)
        if month < now {
            let points = all(WorthPoint.self)
            for p in points where p.month >= month && p.month < now { p.value = max(0, p.value + change) }
            if !points.contains(where: { $0.month == month }) {
                // Starts from the month before (0 if nothing was written down yet).
                let before = points.filter { $0.month < month }.max { $0.month < $1.month }?.value ?? 0
                context.insert(WorthPoint(month: month, value: max(0, before + change)))
            }
        }
        recordWorth(on: today)
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

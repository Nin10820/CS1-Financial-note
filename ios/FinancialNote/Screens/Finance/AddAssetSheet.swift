import SwiftData
import SwiftUI

/// New asset as one sentence, a line at a time, each line opening what it needs:
/// "What is it?" opens a list (Gold, Fund, Saving…, or type your own) and the group follows from
/// it; the amount opens the number pad; "Put in on" opens the calendar; then an optional note.
/// With `editing`, just its name, group and note — a change of worth goes through
/// Add money / Take out / Update value on the asset, so its history stays right.
struct AddAssetSheet: View {
    var editing: Asset? = nil
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount: Int?
    @State private var kind: AssetKind = .available
    /// When the money went in: today, or back when you started (it shows on the line from then).
    @State private var since = ""
    @State private var note = ""
    /// Held in units (5 chỉ, 1,000 $, 0.05 BTC): then the worth follows today's price.
    @State private var quantityText = ""
    @State private var unit: HoldingUnit?
    @State private var ready = false
    /// The line being answered now.
    @State private var active: Line?
    @State private var choosingName = false
    @State private var pickingDate = false
    @FocusState private var noteFocused: Bool

    enum Line: Hashable { case name, amount, since, note }

    /// What the pill in "Adding new [ … ]" says for each group.
    static func noun(_ k: AssetKind) -> String {
        switch k {
        case .available: "available money"
        case .growing: "growing asset"
        case .aside: "set-aside money"
        case .owed: "money owed to you"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if editing != nil { editForm } else { sentence }
            }
            .sheetHeader(editing == nil ? "New asset" : "Edit asset", trailing: .save(enabled: isValid, action: save))
        }
        .onAppear {
            guard !ready else { return }
            ready = true
            since = app.today
            if let a = editing {
                name = a.name
                kind = a.kind
                note = a.note ?? ""
                // Gold, dollars and coins: the unit is ready, so only how many is left to type.
                unit = a.unit ?? HoldingUnit.guess(a.icon)
                quantityText = a.quantity.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
            }
        }
    }

    private var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Worth in đồng at today's price, when held in units and there's a price.
    private var unitWorth: Int? {
        guard let q = quantity, let unit, let p = Market.price(unit) else { return nil }
        return Int((q * p).rounded())
    }

    /// "How many?" with the unit picker: on the new-asset sentence and in Edit.
    private var quantityField: some View {
        HStack(spacing: Space.s8) {
            TextField("How many?", text: $quantityText)
                .keyboardType(.decimalPad)
                .monospacedDigit()
            Menu {
                Picker("Unit", selection: $unit) {
                    Text("In đồng").tag(HoldingUnit?.none)
                    ForEach(HoldingUnit.allCases) { u in Text(u.isGold ? u.name : "\(u.name) (\(u.label))").tag(HoldingUnit?.some(u)) }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(unit?.label ?? "unit")
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(unit == nil ? Tokens.grey400 : Tokens.brand600)
            }
        }
        .onChange(of: quantityText) { _, _ in fillWorth() }
        .onChange(of: unit) { _, _ in fillWorth() }
    }

    /// A new asset held in units starts at today's price.
    private func fillWorth() {
        guard editing == nil, let w = unitWorth else { return }
        amount = w
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (editing != nil || (amount ?? 0) > 0)
    }

    // MARK: - The sentence

    private var sentence: some View {
        let past = since < app.today
        let named = !name.trimmingCharacters(in: .whitespaces).isEmpty
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.s12) {
                if named {
                    // The group comes from what it is; tap the sentence to change it.
                    Menu {
                        Picker("Group", selection: $kind) {
                            ForEach(AssetKind.allCases, id: \.self) { k in Text(k.label).tag(k) }
                        }
                    } label: {
                        AddingLead(label: Self.noun(kind), chosen: true).multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Changes the group")
                } else {
                    AddingLead(label: "kind of", chosen: false)
                }
                VStack(alignment: .leading, spacing: 10) {
                    tapLine("What is it?", value: named ? name : "Tap to choose", empty: !named, line: .name) {
                        choosingName = true
                    }
                    if named, unit != nil {
                        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                            label("How many:")
                            quantityField.font(AppFont.h6(.semibold)).foregroundStyle(Tokens.brand600)
                        }
                    }
                    if named {
                        moneyLine(past ? "Put in then:" : "Worth now:")
                        if (amount ?? 0) > 0 {
                            tapLine("Put in on", value: past ? DueText.ddmmyyyy(since) : "Today", empty: false, line: .since) {
                                go(.since)
                            }
                            noteLine
                            Text(past
                                 ? "It shows on your Total Asset line from \(FinanceText.monthLabel(Month.of(since))). Add later deposits with Add money on the asset."
                                 : "Adds \(Money.format(amount ?? 0)) đ to \(kind.label).")
                                .font(AppFont.body(.medium))
                                .foregroundStyle(Tokens.grey400)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, Space.s12)
                .padding(.vertical, Space.s8)
                .overlay(alignment: .leading) { Rectangle().fill(Tokens.bd2).frame(width: 3) }
                .animation(.snappy, value: named)
                .animation(.snappy, value: (amount ?? 0) > 0)
            }
            .padding(.horizontal, Space.s20)
            .padding(.vertical, Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if active == .amount {
                AmountPad(value: $amount) { go((amount ?? 0) > 0 ? .since : nil) }
                    .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $choosingName, onDismiss: {
            if !name.isEmpty { go((amount ?? 0) > 0 ? .since : .amount) }
        }) {
            AssetNameSheet { picked in
                name = picked.name
                kind = picked.kind
                if let a = picked.amount, a > 0 { amount = a }
                // Gold by the chỉ, dollars, coins: ask how many, and the price does the rest.
                unit = HoldingUnit.guess(AssetMath.guessIcon(picked.name, kind: picked.kind))
            }
            .sheetSurface()
        }
        .sheet(isPresented: $pickingDate, onDismiss: { go(.note) }) {
            DateSheet(date: $since, title: "Put in on", latest: app.today).sheetSurface()
        }
        .onAppear {
            // Straight to the first question.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                if name.isEmpty { choosingName = true }
            }
        }
        .onChange(of: noteFocused) { _, f in if f { withAnimation(.snappy) { active = .note } } }
    }

    /// Opens whatever the line needs: the number pad, the calendar, or the note's keyboard.
    private func go(_ line: Line?) {
        withAnimation(.snappy) { active = line }
        if line == .since { pickingDate = true }
        if line == .note {
            // After the calendar has gone, or the keyboard won't come up.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                noteFocused = true
            }
        } else {
            noteFocused = false
        }
    }

    // MARK: Lines

    private func label(_ text: String) -> some View {
        Text(text).font(AppFont.h6(.medium)).foregroundStyle(Tokens.text700).fixedSize()
    }

    private func underline(_ on: Bool) -> some View {
        Capsule().fill(on ? Tokens.brand500 : .clear).frame(height: 2).offset(y: 3)
    }

    /// A line answered in its own sheet: tap to open it.
    private func tapLine(_ title: String, value: String, empty: Bool, line: Line, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                label(title)
                Text(value).font(AppFont.h6(.semibold))
                    .foregroundStyle(empty ? Tokens.grey300 : Tokens.brand600)
                    .lineLimit(1)
                    .overlay(alignment: .bottom) { underline(active == line) }
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.grey300)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Space.s8, leading: Space.s16, bottom: Space.s8, trailing: Space.s16))
    }

    private func moneyLine(_ title: String) -> some View {
        Button { go(.amount) } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                label(title)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(amount.map(Money.format) ?? "0")
                        .font(AppFont.h6(.semibold))
                        .foregroundStyle(amount == nil ? Tokens.grey300 : Tokens.brand600)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("đ").font(AppFont.bodyLarge(.medium)).foregroundStyle(Tokens.text700)
                }
                .overlay(alignment: .bottom) { underline(active == .amount) }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(amount.map { "\(Money.format($0)) dong" } ?? "empty")")
    }

    private var noteLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            label("Note:")
            TextField("", text: $note, prompt: Text("optional").foregroundStyle(Tokens.grey300))
                .font(AppFont.h6(.semibold))
                .foregroundStyle(Tokens.brand600)
                .focused($noteFocused)
                .submitLabel(.done)
                .onSubmit { go(nil) }
        }
    }

    // MARK: - Edit: name, group and note

    private var editForm: some View {
        Form {
            Section("What is it?") {
                TextField("Gold, Saving - TP Bank, Fund…", text: $name)
            }
            .listRowBackground(Tokens.card)
            Section {
                // A plain iOS checklist: the header names it, so the picker's own label row is hidden.
                Picker("Which group?", selection: $kind) {
                    ForEach(AssetKind.allCases, id: \.self) { k in
                        HStack(spacing: Space.s12) {
                            Circle().fill(Tokens.assetKind(k)).frame(width: 10, height: 10)
                            Text(k.label)
                        }
                        .tag(k)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Which group?")
            } footer: {
                Text(FinanceText.hint(kind))
            }
            .listRowBackground(Tokens.card)
            Section {
                quantityField
            } header: {
                Text("How much do you hold?")
            } footer: {
                Text(unit == nil ? "Pick a unit (chỉ, $, BTC…) and the worth follows today's price."
                     : quantity == nil ? "Type how many \(unit?.label ?? "")."
                     : unitWorth.map { "≈ \(Money.format($0)) đ at today's price. Sync updates it." }
                       ?? "No price yet: it fills in on the next sync.")
            }
            .listRowBackground(Tokens.card)
            Section("Note") {
                TextField("Optional", text: $note, axis: .vertical).lineLimit(1...4)
            }
            .listRowBackground(Tokens.card)
        }
        .appListSurface()
        .font(AppFont.main(16))
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        let memo = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = editing {
            let store = LocalStore(context: context)
            store.editAsset(a, name: n, kind: kind, note: memo.isEmpty ? nil : memo)
            store.setHolding(a, quantity: quantity, unit: unit)
            store.revalueHoldings(today: app.today)
            dismiss()
            return
        }
        let asset = Asset(name: n, kind: kind, icon: AssetMath.guessIcon(n, kind: kind), amount: amount ?? 0,
                          updated: min(since.isEmpty ? app.today : since, app.today))
        asset.note = memo.isEmpty ? nil : memo
        if let quantity, let unit {
            asset.quantity = quantity
            asset.unit = unit
        }
        LocalStore(context: context).addAsset(asset)
        dismiss()
    }
}

/// "What is it?" for a new asset: the usual kinds by group (Gold, Fund, Saving - your bank…), or
/// type your own — the group is guessed from the words, and "vàng SJC 15tr" fills the amount too.
private struct AssetNameSheet: View {
    var onPick: ((name: String, amount: Int?, kind: AssetKind)) -> Void
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Profile]
    @State private var text = ""
    @FocusState private var typing: Bool

    private var banks: [String] {
        (profiles.first?.banks ?? []).compactMap { BankApp.named($0)?.name }
    }

    private func presets(_ k: AssetKind) -> [String] {
        switch k {
        case .available: ["Cash", "Main account", "MoMo", "ZaloPay"] + banks.map { "\($0) account" }
        case .growing: ["Gold", "Fund", "Stocks", "USD", "Coin"]
        case .aside: ["Saving"] + banks.map { "Saving - \($0)" }
        case .owed: ["Lent to a friend", "Lent to family", "Deposit to get back"]
        }
    }

    var body: some View {
        let typed = text.trimmingCharacters(in: .whitespaces)
        let query = typed.lowercased()
        NavigationStack {
            List {
                Section {
                    TextField("Type your own, e.g. vàng SJC 15tr", text: $text)
                        .focused($typing)
                        .submitLabel(.done)
                        .onSubmit { useTyped(typed) }
                    if !typed.isEmpty {
                        let read = AssetSentence.read(typed, today: app.today)
                        row(read.name, kind: read.kind,
                            sub: "Use this · \(read.kind.label)" + (read.amount.map { " · \(Money.format($0)) đ" } ?? "")) {
                            useTyped(typed)
                        }
                    }
                }
                .listRowBackground(Tokens.card)
                ForEach(AssetKind.allCases, id: \.self) { k in
                    let names = presets(k).filter { query.isEmpty || $0.lowercased().contains(query) }
                    if !names.isEmpty {
                        Section {
                            ForEach(names, id: \.self) { n in
                                row(n, kind: k, sub: nil) { pick(n, nil, k) }
                            }
                        } header: {
                            // A small uppercase label, so the groups don't shout over the rows.
                            HStack(spacing: Space.s6) {
                                RoundedRectangle(cornerRadius: 2).fill(Tokens.assetKind(k)).frame(width: 8, height: 8)
                                Text(k.label.uppercased())
                                    .font(AppFont.main(12, .semibold, relativeTo: .caption))
                                    .tracking(0.6)
                                    .foregroundStyle(Tokens.grey400)
                            }
                            .textCase(nil)
                        } footer: {
                            Text(FinanceText.hint(k))
                        }
                        .listRowBackground(Tokens.card)
                    }
                }
            }
            .appListSurface()
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 44)
            .contentMargins(.top, Space.s8, for: .scrollContent)
            .sheetHeader("What is it?")
        }
        .presentationDetents([.large])
    }

    private func row(_ name: String, kind: AssetKind, sub: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s12) {
                AssetTile(icon: AssetMath.guessIcon(name, kind: kind), size: 32, round: true)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(AppFont.table(15, .medium)).foregroundStyle(Tokens.text900).lineLimit(1)
                    if let sub {
                        Text(sub).font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                    }
                }
                // The line under each row starts at the name, even when the tile has text in it ("Au").
                .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: Space.s8, leading: Space.s16, bottom: Space.s8, trailing: Space.s16))
    }

    private func useTyped(_ typed: String) {
        guard !typed.isEmpty else { return }
        let read = AssetSentence.read(typed, today: app.today)
        pick(read.name, read.amount, read.kind)
    }

    private func pick(_ name: String, _ amount: Int?, _ kind: AssetKind) {
        onPick((name, amount, kind))
        dismiss()
    }
}

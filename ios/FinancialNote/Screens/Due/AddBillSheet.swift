import SwiftData
import SwiftUI

/// What the add-bill form holds, and how it becomes a Bill (ported from `AddBill.tsx`).
struct BillDraft {
    var kind: BillKind?
    var name = ""
    var code = ""
    var varies = false
    var amount: Int?
    var due: String
    var payWith = ""
    var principal: Int?
    var lender = ""
    var payments = 12
    var rate = 0.0
    var fee = 0.0

    /// Today when adding for this month, otherwise the 15th of the month on screen.
    init(month: String, today: String, kind: BillKind? = nil) {
        self.kind = kind
        due = month == Month.of(today) ? today : "\(month)-15"
    }

    /// Per payment: the installment maths for installments, the typed amount otherwise.
    var each: Int {
        kind == .installment
            ? BillMath.installmentPayment(principal: principal ?? 0, payments: max(1, payments), ratePct: rate)
            : amount ?? 0
    }

    var isValid: Bool {
        kind != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty && each > 0
            && (kind != .installment || payments >= 1)
    }

    func makeBill() -> Bill? {
        guard isValid, let kind else { return nil }
        let trimmed = { (s: String) -> String? in
            let t = s.trimmingCharacters(in: .whitespaces)
            return t.isEmpty ? nil : t
        }
        let inst = kind == .installment
        return Bill(
            kind: kind, name: name.trimmingCharacters(in: .whitespaces), icon: BillMath.guessIcon(name, kind: kind),
            amount: each, varies: kind == .recurring && varies, start: due, code: trimmed(code), payWith: trimmed(payWith),
            lender: inst ? trimmed(lender) : nil, principal: inst ? principal : nil, payments: inst ? payments : nil,
            rate: inst ? rate : nil, fee: inst ? fee : nil)
    }
}

/// Add a bill — Figma Due › "Adding new … — tell us what you know": pick the kind, then fill
/// a few lines. Everything stays on this phone.
struct AddBillSheet: View {
    var month: String
    var startKind: BillKind?
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft = BillDraft(month: Month.of(Day.today()), today: Day.today())
    @State private var ready = false
    @FocusState private var focus: Line?
    /// The money line the number pad is typing into.
    @State private var padLine: Line?
    @State private var pickingDate: DateLine?
    /// The line being answered now (its chips show at the bottom).
    @State private var active: Line?
    @Query private var profiles: [Profile]

    private static let kinds: [(BillKind, String, String)] = [
        (.recurring, "Recurring bill", "Electricity, water, internet — every month"),
        (.installment, "Installment", "Fixed parts until it's paid off"),
        (.oneoff, "One-off", "Just this once, no repeat"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if draft.kind == nil { kindPicker } else { form }
            }
            .background(draft.kind == nil ? Tokens.bg3 : Tokens.bg1)
            .onChange(of: draft.kind) { _, k in
                // Picked a kind (or said it): start typing straight away.
                if k != nil { startTyping() }
            }
            .navigationTitle("New bill")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if draft.kind != nil && startKind == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Change kind", systemImage: "chevron.left") {
                            animate { draft.kind = nil }
                        }
                    }
                } else {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
                if draft.kind != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save bill", systemImage: "checkmark", action: save)
                            .disabled(!draft.isValid)
                    }
                }
            }
        }
        .onAppear {
            guard !ready else { return }
            ready = true
            draft = BillDraft(month: month, today: app.today, kind: startKind)
        }
    }

    private var lead: some View {
        AddingLead(label: Self.kinds.first { $0.0 == draft.kind }?.1.lowercased() ?? "kind of", chosen: draft.kind != nil)
    }

    /// Step 1 (Figma Due 943:25329): pick the kind, or say the whole bill in one sentence.
    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            lead.padding(.horizontal, Space.s20).padding(.vertical, Space.s16)
            Spacer(minLength: 0)
            QuickPickCard(
                title: "What kind is this?",
                options: Self.kinds.map { QuickPickOption(id: $0.0, title: $0.1, hint: $0.2) },
                sayPlaceholder: "e.g. Internet 250k every month on the 5th",
                onPick: { draft.kind = $0 },
                onSay: { draft = BillSentence.read($0, month: month, today: app.today) })
            .padding(.horizontal, Space.s12)
            .padding(.top, Space.s24)
            .padding(.bottom, Space.s16)
        }
    }

    // MARK: - Step 2: the bill as sentences (Figma Due 943:25627)

    /// Each line of the sentence. Typed lines open the keyboard, money lines the number pad,
    /// lines with a few likely answers show tap-to-pick chips (above the keyboard if it's up).
    enum Line: Hashable { case name, code, amount, principal, lender, payWith, rate, fee, due, start, payments }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s12) {
                lead
                VStack(alignment: .leading, spacing: 10) {
                    textLine("What's it for?", text: $draft.name,
                             placeholder: draft.kind == .installment ? "e.g. iPhone 15 Pro" : "e.g. Water", line: .name)
                    if !draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        switch draft.kind {
                        case .installment: installmentLines
                        case .oneoff: oneOffLines
                        default: recurringLines
                        }
                    }
                }
                .padding(.horizontal, Space.s12)
                .padding(.vertical, Space.s8)
                .overlay(alignment: .leading) { Rectangle().fill(Tokens.bd2).frame(width: 3) }
                .animation(.snappy, value: draft.name.isEmpty)
                .animation(.snappy, value: draft.each > 0)
            }
            .padding(.horizontal, Space.s20)
            .padding(.vertical, Space.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                let picks = chips(for: active)
                if !picks.isEmpty { chipBar(picks) }
                if padLine != nil {
                    AmountPad(value: moneyBinding) { go(next(after: padLine)) }
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.snappy, value: active)
        }
        .sheet(item: $pickingDate, onDismiss: { go(next(after: active)) }) { which in
            BillDateSheet(date: $draft.due, title: which == .due ? "Due" : "Starting from")
        }
        .onAppear { startTyping() }
        .onChange(of: focus) { _, f in
            if let f { active = f; if padLine != nil { padLine = nil } }
        }
    }

    @ViewBuilder
    private var recurringLines: some View {
        textLine("Bill code:", text: $draft.code, placeholder: "optional", line: .code, prefix: "#")
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            label("Amount each time:")
            toggleChip("Fixed", on: !draft.varies) { draft.varies = false }
            toggleChip("Changes", on: draft.varies) { draft.varies = true }
        }
        moneyLine(draft.varies ? "Roughly how much?" : "Amount:", value: draft.amount, line: .amount)
        if (draft.amount ?? 0) > 0 {
            pickLine("Due", value: DueText.ddmmyyyy(draft.due), line: .due)
            textLine("Pay with", text: $draft.payWith, placeholder: "(optional)", line: .payWith)
        }
    }

    @ViewBuilder
    private var oneOffLines: some View {
        moneyLine("Amount:", value: draft.amount, line: .amount)
        if (draft.amount ?? 0) > 0 {
            pickLine("Due", value: DueText.ddmmyyyy(draft.due), line: .due)
            textLine("Pay with", text: $draft.payWith, placeholder: "(optional)", line: .payWith)
        }
    }

    @ViewBuilder
    private var installmentLines: some View {
        moneyLine("Amount borrowed:", value: draft.principal, line: .principal)
        if (draft.principal ?? 0) > 0 {
            textLine("Lender / bank:", text: $draft.lender, placeholder: "optional", line: .lender)
            pickLine("Starting from:", value: DueText.ddmmyyyy(draft.due), line: .start)
            pickLine("Num of payments:", value: "\(draft.payments) payments", line: .payments)
            percentLine("Monthly interest rate:", value: $draft.rate, line: .rate)
            percentLine("Conversion fee", value: $draft.fee, line: .fee)
            if draft.each > 0 {
                Text("≈ \(Money.format(draft.each)) đ each month for \(draft.payments) months")
                    .font(AppFont.body(.medium))
                    .foregroundStyle(Tokens.grey400)
            }
        }
    }

    // MARK: Moving through the lines

    /// The name first, with the keyboard already up.
    private func startTyping() {
        guard draft.kind != nil else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            go(draft.name.isEmpty ? .name : next(after: .name))
        }
    }

    /// The line after this one that still needs something (optional lines are skipped).
    private func next(after line: Line?) -> Line? {
        let order: [Line] = draft.kind == .installment
            ? [.name, .principal, .lender, .start, .payments, .rate, .fee]
            : [.name, .amount, .due, .payWith]
        guard let line, let i = order.firstIndex(of: line) else {
            // From the bill code: on to the amount if it's still empty.
            return line == .code && (draft.amount ?? 0) == 0 ? .amount : nil
        }
        return i + 1 < order.count ? order[i + 1] : nil
    }

    /// Opens whatever the line needs: keyboard, number pad, or just its chips.
    private func go(_ line: Line?) {
        active = line
        switch line {
        case .name, .code, .lender, .payWith, .rate, .fee:
            padLine = nil
            focus = line
        case .amount, .principal:
            focus = nil
            withAnimation(.snappy) { padLine = line }
        default:
            focus = nil
            withAnimation(.snappy) { padLine = nil }
        }
    }

    // MARK: Quick picks

    private struct Pick: Identifiable { let id: String; let action: () -> Void }

    private var myBanks: [String] {
        (profiles.first?.banks ?? []).compactMap { BankApp.named($0)?.name }
    }

    private func dayPick(_ title: String, day: Int) -> Pick {
        Pick(id: title) {
            let (y, m, _) = Day.parts(month + "-01")
            draft.due = String(format: "%@-%02d", month, min(day, Day.daysIn(year: y, month: m)))
            go(next(after: active))
        }
    }

    private func chips(for line: Line?) -> [Pick] {
        func set(_ items: [String], _ apply: @escaping (String) -> Void) -> [Pick] {
            items.map { v in Pick(id: v) { apply(v); go(next(after: line)) } }
        }
        switch line {
        case .name:
            let names = switch draft.kind {
            case .installment: ["iPhone", "Laptop", "Motorbike", "TV", "Fridge"]
            case .oneoff: ["Insurance", "Tuition", "Repair", "Tax"]
            default: ["Electricity", "Water", "Internet", "Rent", "Phone", "Gas", "Netflix", "Gym"]
            }
            return set(names) { draft.name = $0 }
        case .due, .start:
            return [Pick(id: "Today") { draft.due = month == Month.of(app.today) ? app.today : "\(month)-01"; go(next(after: line)) }]
                + [5, 10, 15, 20, 25].map { dayPick("\($0)th", day: $0) }
                + [Pick(id: "Pick a date…") { pickingDate = line == .start ? .start : .due }]
        case .payWith:
            return set(myBanks + ["Cash", "Card", "Transfer"]) { draft.payWith = $0 }
        case .lender:
            return set(myBanks + ["Home Credit", "FE Credit", "HD Saison"]) { draft.lender = $0 }
        case .payments:
            return set(["3", "6", "9", "12", "18", "24", "36"]) { draft.payments = Int($0) ?? 12 }
                .map { p in Pick(id: "\(p.id) payments", action: p.action) }
        case .rate:
            return set(["0", "0.5", "1", "1.5", "2"]) { draft.rate = Double($0) ?? 0 }.map { Pick(id: $0.id + "%", action: $0.action) }
        case .fee:
            return set(["0", "1", "1.5", "2"]) { draft.fee = Double($0) ?? 0 }.map { Pick(id: $0.id + "%", action: $0.action) }
        default:
            return []
        }
    }

    /// Glass chips in a row, above the keyboard when it's up.
    private func chipBar(_ picks: [Pick]) -> some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: Space.s8) {
                HStack(spacing: Space.s8) {
                    ForEach(picks) { p in
                        Button(action: p.action) {
                            Text(p.id)
                                .font(AppFont.body(.medium))
                                .foregroundStyle(Tokens.text900)
                                .padding(.horizontal, Space.s16)
                                .frame(minHeight: 40)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                }
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
            }
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
    }

    // MARK: Lines

    private func label(_ text: String) -> some View {
        Text(text).font(AppFont.h6(.medium)).foregroundStyle(Tokens.text700).fixedSize()
    }

    private func textLine(_ title: String, text: Binding<String>, placeholder: String, line: Line, prefix: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            label(title)
            if let prefix { Text(prefix).font(AppFont.bodyLarge(.medium)).foregroundStyle(Tokens.grey400) }
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Tokens.grey300))
                .font(AppFont.h6(.semibold))
                .foregroundStyle(Tokens.brand600)
                .focused($focus, equals: line)
                .textContentType(nil)
                .submitLabel(.next)
                .onSubmit { go(next(after: line)) }
        }
    }

    private func moneyLine(_ title: String, value: Int?, line: Line) -> some View {
        Button { go(line) } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                label(title)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value.map(Money.format) ?? "0")
                        .font(AppFont.h6(.semibold))
                        .foregroundStyle(value == nil ? Tokens.grey300 : Tokens.brand600)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("đ").font(AppFont.bodyLarge(.medium)).foregroundStyle(Tokens.text700)
                }
                .overlay(alignment: .bottom) {
                    if padLine == line { Capsule().fill(Tokens.brand500).frame(height: 2).offset(y: 3) }
                }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(value.map { "\(Money.format($0)) dong" } ?? "empty")")
    }

    /// A line answered by picking: tap it to show its chips.
    private func pickLine(_ title: String, value: String, line: Line) -> some View {
        Button { go(line) } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
                label(title)
                Text(value).font(AppFont.h6(.semibold)).foregroundStyle(Tokens.brand600)
                    .overlay(alignment: .bottom) {
                        if active == line { Capsule().fill(Tokens.brand500).frame(height: 2).offset(y: 3) }
                    }
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func toggleChip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { animate { action() } } label: {
            Text(title)
                .font(AppFont.body(.semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(on ? Tokens.brand700 : Tokens.grey400)
                .padding(.horizontal, Space.s12)
                .frame(minHeight: 32)
                .background(on ? Tokens.brand100 : Tokens.bg4, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func percentLine(_ title: String, value: Binding<Double>, line: Line) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s8) {
            label(title)
            TextField("", text: Binding(
                get: { value.wrappedValue == 0 ? "" : BillDetailSheet.percent(value.wrappedValue) },
                set: { value.wrappedValue = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }),
                      prompt: Text("0").foregroundStyle(Tokens.grey300))
                .font(AppFont.h6(.semibold))
                .foregroundStyle(Tokens.brand600)
                .keyboardType(.decimalPad)
                .focused($focus, equals: line)
                .fixedSize()
            Text("%").font(AppFont.h6(.semibold)).foregroundStyle(Tokens.brand600)
        }
    }

    enum DateLine: Identifiable { case due, start; var id: Self { self } }

    private var moneyBinding: Binding<Int?> {
        padLine == .principal ? $draft.principal : $draft.amount
    }

    private func save() {
        guard let bill = draft.makeBill() else { return }
        context.insert(bill)
        try? context.save()
        // Stay on this month if the new bill shows up here; otherwise jump to when it starts.
        if BillMath.dueIn(bill, month: app.dueMonth) == nil { app.dueMonth = Month.of(bill.start) }
        dismiss()
    }
}

/// Due / starting date for a bill: any day, past or future (a calendar, then Done).
struct BillDateSheet: View {
    @Binding var date: String
    var title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: Binding(get: { Day.date(date) }, set: { date = Day.iso($0) }),
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Tokens.brand500)
                .padding(.horizontal)
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }.foregroundStyle(Tokens.brand700)
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

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
            .background(Tokens.bg1)
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
        let label = Self.kinds.first { $0.0 == draft.kind }?.1.lowercased() ?? "kind of"
        let kind = Text(label).foregroundStyle(draft.kind == nil ? Tokens.grey400 : Tokens.brand600)
        return Text("Adding new \(kind)\n— tell us what you know:")
            .font(AppFont.page)
            .foregroundStyle(Tokens.text700)
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            lead.padding(Space.s20)
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Step 1 of 2").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    Text("What kind is this?").font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                }
                .padding(Space.s16)
                Divider().overlay(Tokens.bd0)
                ForEach(Self.kinds, id: \.0) { kind, label, hint in
                    Button {
                        animate { draft.kind = kind }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                                Text(hint).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.grey300)
                        }
                        .padding(.horizontal, Space.s16)
                        .padding(.vertical, Space.s12)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
            .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd1))
            .padding(Space.s12)
        }
    }

    private var form: some View {
        Form {
            Section { lead.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
            Section {
                TextField(draft.kind == .installment ? "iPhone 15 Pro" : "Water", text: $draft.name)
            } header: { Text("What's it for?") }

            if draft.kind == .installment {
                Section {
                    moneyField("Amount borrowed", value: $draft.principal, placeholder: "12,120,000")
                    TextField("Lender / bank (optional)", text: $draft.lender)
                    dateField("Starting from")
                    Stepper("\(draft.payments) payments", value: $draft.payments, in: 1...120)
                    percentField("Monthly interest", value: $draft.rate)
                    percentField("Conversion fee", value: $draft.fee)
                } footer: {
                    if draft.each > 0 {
                        Text("≈ \(Money.format(draft.each)) đ each month for \(draft.payments) months")
                            .font(AppFont.main(12, .medium))
                    }
                }
            } else {
                Section {
                    if draft.kind == .recurring {
                        TextField("Bill code (optional)", text: $draft.code)
                        Picker("Amount each time", selection: $draft.varies) {
                            Text("Fixed").tag(false)
                            Text("Changes").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                    moneyField(draft.kind == .recurring && draft.varies ? "Roughly how much?" : "Amount",
                               value: $draft.amount, placeholder: "340,000")
                    dateField("Due")
                    TextField("Pay with (optional)", text: $draft.payWith)
                } footer: {
                    if draft.kind == .recurring {
                        Text("Repeats monthly on day \(Day.parts(draft.due).d).")
                    }
                }
            }
        }
        .font(AppFont.main(16))
        .scrollDismissesKeyboard(.interactively)
    }

    private func moneyField(_ label: String, value: Binding<Int?>, placeholder: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: Space.s4) {
                TextField(placeholder, text: Binding(
                    get: { value.wrappedValue.map(Money.format) ?? "" },
                    set: { value.wrappedValue = Int($0.filter(\.isNumber)) }))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                Text("đ").foregroundStyle(Tokens.grey400)
            }
        }
    }

    private func percentField(_ label: String, value: Binding<Double>) -> some View {
        LabeledContent(label) {
            HStack(spacing: Space.s4) {
                TextField("0", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                Text("%").foregroundStyle(Tokens.grey400)
            }
        }
    }

    private func dateField(_ label: String) -> some View {
        DatePicker(label, selection: Binding(get: { Day.date(draft.due) }, set: { draft.due = Day.iso($0) }),
                   displayedComponents: .date)
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

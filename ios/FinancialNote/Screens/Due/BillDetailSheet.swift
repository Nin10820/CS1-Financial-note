import SwiftData
import SwiftUI

/// Bill / installment detail (Figma Due › bill detail): what it is, this month, the facts,
/// history, then Check or Undo. Deleting asks first and also removes what its check-offs recorded.
struct BillDetailSheet: View {
    @Bindable var bill: Bill
    var month: String
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var confirmDelete = false

    var body: some View {
        let due = BillMath.dueIn(bill, month: month)
        let record = bill.paid[month]
        let step = bill.kind == .installment ? BillMath.installmentStep(bill, month: month) : nil

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s20) {
                    head(step: step)
                    thisMonth(due: due, record: record)
                    facts(due: due)
                    history
                }
                .padding(Space.s20)
            }
            .background(Tokens.bg1)
            .safeAreaInset(edge: .bottom) { footer(due: due, record: record) }
            .navigationTitle(bill.kind == .installment ? "Installment" : "Bill")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear { amountText = Money.format(record?.amount ?? bill.amount) }
        .confirmationDialog("Delete “\(bill.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete bill", role: .destructive) {
                LocalStore(context: context).removeBill(bill)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("The spending its check-offs recorded is removed too.")
        }
    }

    // MARK: - Parts

    private func head(step: BillMath.Step?) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            BillTile(icon: bill.icon, size: 40)
            Text(bill.name)
                .font(AppFont.h6(.bold))
                .foregroundStyle(Tokens.text900)
            HStack(spacing: Space.s4) {
                Text("Status:").foregroundStyle(Tokens.grey400)
                if bill.paid[month] != nil {
                    Image(systemName: "checkmark.circle").foregroundStyle(Tokens.brand600)
                }
                Text(DueText.status(bill, month: month, today: app.today))
                    .foregroundStyle(bill.paid[month] != nil ? Tokens.brand700 : Tokens.text700)
                if let step {
                    Text("· \(step.paidCount)/\(step.total) paid").foregroundStyle(Tokens.grey400)
                }
            }
            .font(AppFont.main(12, .medium, relativeTo: .caption))
            .accessibilityElement(children: .combine)
            if let step {
                ProgressView(value: Double(step.paidCount), total: Double(max(step.total, 1)))
                    .tint(Tokens.brand500)
                    .accessibilityLabel("\(step.paidCount) of \(step.total) payments made")
            }
        }
    }

    @ViewBuilder
    private func thisMonth(due: String?, record: PaidRecord?) -> some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            Text("This month")
                .font(AppFont.main(12, .medium, relativeTo: .caption))
                .foregroundStyle(Tokens.grey400)
            if due != nil && record == nil && bill.varies {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    TextField("0", text: $amountText)
                        .font(AppFont.amount(32))
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                        .fixedSize()
                        .accessibilityLabel("Amount paid this month")
                        .onChange(of: amountText) { _, new in
                            let digits = new.filter(\.isNumber)
                            let formatted = digits.isEmpty ? "" : Money.format(Int(digits) ?? 0)
                            if formatted != new { amountText = formatted }
                        }
                    Text("đ").font(AppFont.currency(for: 32)).foregroundStyle(Tokens.grey400)
                    Image(systemName: "pencil").foregroundStyle(Tokens.grey300).accessibilityHidden(true)
                }
                Text("Changes each month — type what you actually paid")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
            } else {
                AmountText(value: due == nil ? 0 : (record?.amount ?? bill.amount), size: 28, hidden: app.hidden)
            }
        }
    }

    private func facts(due: String?) -> some View {
        let rows: [(String, String)] = bill.kind == .installment
            ? [
                ("Amount borrowed", "\(Money.format(bill.principal ?? 0)) đ"),
                ("Pay with", bill.lender ?? bill.payWith ?? "—"),
                ("Starting from", DueText.ddmmyyyy(bill.start)),
                ("Last payment", DueText.ddmmyyyy(BillMath.lastDue(bill))),
                ("Number of payments", "\(bill.payments ?? 1) payments"),
                ("Amount each time", "\(Money.format(bill.amount)) đ"),
                ("Monthly interest", "\(Self.percent(bill.rate))%"),
                ("Conversion fee", "\(Self.percent(bill.fee))%"),
            ]
            : (bill.code.map { [("Bill code", $0)] } ?? []) + [
                ("Amount each time", bill.varies ? "Changes" : "Fixed"),
                (bill.varies ? "Roughly how much" : "Amount", "\(bill.varies ? "~" : "")\(Money.format(bill.amount)) đ"),
                ("Repeats", bill.kind == .recurring ? "Monthly" : "Just once"),
                ("Due", DueText.ddmmyyyy(due ?? bill.start)),
                ("Pay with", bill.payWith ?? "—"),
            ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text(row.0).foregroundStyle(Tokens.text700)
                    Spacer(minLength: Space.s16)
                    Text(row.1).foregroundStyle(Tokens.text900).multilineTextAlignment(.trailing)
                }
                .font(AppFont.main(14))
                .padding(.vertical, Space.s12)
                .accessibilityElement(children: .combine)
                if i < rows.count - 1 { Divider().overlay(Tokens.bd0) }
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.bg2, in: .rect(cornerRadius: Corner.c12))
        .overlay(RoundedRectangle(cornerRadius: Corner.c12).strokeBorder(Tokens.bd1))
    }

    private var history: some View {
        let rows = bill.paid.sorted { $0.key > $1.key }
        return VStack(alignment: .leading, spacing: Space.s8) {
            Text("History")
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(Tokens.text900)
                .accessibilityAddTraits(.isHeader)
            if rows.isEmpty {
                Text("No payments checked off yet.")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
            }
            ForEach(rows, id: \.key) { m, p in
                HStack {
                    Text(DueText.monthLabel(m)).font(AppFont.main(14)).foregroundStyle(Tokens.text700)
                    Spacer()
                    AmountText(value: p.amount, hidden: app.hidden)
                }
                .accessibilityElement(children: .combine)
            }
            if bill.kind != .oneoff {
                Text("Next: \(DueText.nextDue(bill, today: app.today).map(DueText.ddmmyyyy) ?? "nothing left")")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
                    .padding(.top, Space.s4)
            }
        }
    }

    private func footer(due: String?, record: PaidRecord?) -> some View {
        let typed = Int(amountText.filter(\.isNumber)) ?? 0
        return HStack(spacing: Space.s12) {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash").frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .tint(Tokens.text700)
            .accessibilityLabel("Delete bill")

            if due != nil {
                if record != nil {
                    Button {
                        LocalStore(context: context).setBillPaid(bill, month: month, paid: false, date: app.today)
                    } label: {
                        Text("Undo check").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                } else {
                    Button {
                        LocalStore(context: context).setBillPaid(
                            bill, month: month, paid: true, date: app.today, amount: bill.varies ? typed : nil)
                    } label: {
                        Text("Check").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
                    .disabled(bill.varies && typed <= 0)
                }
            } else {
                Text("Nothing to pay in \(DueText.monthName(month))")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(AppFont.main(16, .semibold))
        .controlSize(.large)
        .padding(.horizontal, Space.s20)
        .padding(.vertical, Space.s12)
        .background(Tokens.bg1)
        .overlay(alignment: .top) { Divider().overlay(Tokens.bd0) }
    }

    /// "1.5" or "0" — no trailing ".0".
    static func percent(_ v: Double?) -> String {
        let x = v ?? 0
        return x == x.rounded() ? String(Int(x)) : String(x)
    }
}

private struct HistoryRow: Identifiable {
    let bill: Bill
    let month: String
    let paid: PaidRecord
    var id: String { "\(bill.id)-\(month)" }
}

/// "History" on the Remaining card: everything checked off, newest first.
struct PaidHistorySheet: View {
    var bills: [Bill]
    var onOpen: (String, String) -> Void
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let rows = bills
            .flatMap { b in b.paid.map { HistoryRow(bill: b, month: $0.key, paid: $0.value) } }
            .sorted { $0.paid.at > $1.paid.at }
        NavigationStack {
            List {
                if rows.isEmpty {
                    Text("Bills you check off will show up here.")
                        .font(AppFont.main(14))
                        .foregroundStyle(Tokens.grey400)
                }
                ForEach(rows) { row in
                    Button {
                        onOpen(row.bill.id, row.month)
                    } label: {
                        HStack(spacing: Space.s12) {
                            BillTile(icon: row.bill.icon, size: 32, soft: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.bill.name).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                                Text(DueText.monthLabel(row.month)).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            }
                            Spacer()
                            AmountText(value: row.paid.amount, hidden: app.hidden)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .navigationTitle("History")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

import SwiftData
import SwiftUI
import UIKit

/// Bill / installment detail (Figma Due 943:25750 Bill, 943:25499 Installment): the icon, the name
/// in Merriweather, its status (and for installments the payment progress), "This month", the
/// facts with small chips, its history, then ✏️ + Check. ✏️ switches to editing: 🗑 to delete
/// (asks first, and removes what its check-offs recorded) and Chat to edit.
struct BillDetailSheet: View {
    @Bindable var bill: Bill
    var month: String
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var confirmDelete = false
    @State private var editing = false
    @State private var allHistory = false
    @State private var chatNotice = false
    @State private var copied = false

    var body: some View {
        let due = BillMath.dueIn(bill, month: month)
        let record = bill.paid[month]
        let step = bill.kind == .installment ? BillMath.installmentStep(bill, month: month) : nil

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    head(step: step, record: record)
                    VStack(spacing: Space.s12) {
                        thisMonth(due: due, record: record)
                        facts(due: due)
                        history
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s16)
                .padding(.bottom, Space.s24)
            }
            .background(alignment: .top) { glow }
            .background(Tokens.bg3)
            .safeAreaInset(edge: .bottom, spacing: 0) { footer(due: due, record: record) }
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
        .alert("Comes later", isPresented: $chatNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changing a bill by saying it is coming. For now, delete it and add it again with Say it your way.")
        }
    }

    // MARK: - Parts

    /// Soft light in the bill's colour behind the top (Figma: blue for water).
    private var glow: some View {
        RadialGradient(colors: [Tokens.billTile(bill.icon).opacity(0.28), .clear],
                       center: .top, startRadius: 0, endRadius: 360)
            .frame(height: 360)
            .blur(radius: 30)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func head(step: BillMath.Step?, record: PaidRecord?) -> some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            BillTile(icon: bill.icon, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.name)
                    .font(AppFont.title(24, .bold))
                    .foregroundStyle(Tokens.text900)
                HStack(spacing: 4) {
                    Text("Status:").italic().foregroundStyle(Tokens.text700)
                    if record != nil {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.success)
                        Text("Done").fontWeight(.medium).italic().foregroundStyle(Tokens.success)
                    } else {
                        Text(DueText.status(bill, month: month, today: app.today)).fontWeight(.medium).italic()
                            .foregroundStyle(Tokens.text700)
                    }
                }
                .font(AppFont.body())
                .accessibilityElement(children: .combine)
            }
            if let step {
                VStack(alignment: .leading, spacing: Space.s6) {
                    HStack {
                        Text("Payment progress").foregroundStyle(Tokens.grey400)
                        Spacer()
                        Text("\(step.paidCount) / \(step.total) paid").foregroundStyle(Tokens.brand600)
                    }
                    .font(AppFont.capture())
                    ProgressView(value: Double(step.paidCount), total: Double(max(step.total, 1)))
                        .tint(Tokens.brand500)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(step.paidCount) of \(step.total) payments made")
            }
        }
        .padding(.horizontal, Space.s12)
    }

    /// "This month 456.000 đ" in a small white box (typed in when it changes and isn't paid yet).
    @ViewBuilder
    private func thisMonth(due: String?, record: PaidRecord?) -> some View {
        VStack(spacing: 4) {
            Text("This month").font(AppFont.body(.semibold)).foregroundStyle(Tokens.brand600)
            if due != nil && record == nil && bill.varies {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $amountText)
                        .font(AppFont.main(28, .semibold, relativeTo: .title))
                        .keyboardType(.numberPad)
                        .monospacedDigit()
                        .fixedSize()
                        .accessibilityLabel("Amount paid this month")
                        .onChange(of: amountText) { _, new in
                            let digits = new.filter(\.isNumber)
                            let formatted = digits.isEmpty ? "" : Money.format(Int(digits) ?? 0)
                            if formatted != new { amountText = formatted }
                        }
                    Text("đ").font(AppFont.main(24, .medium)).foregroundStyle(Tokens.grey400)
                }
                Text("Changes each month — type what you actually paid")
                    .font(AppFont.capture())
                    .foregroundStyle(Tokens.grey400)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(app.hidden ? "••••••" : Money.format(due == nil ? 0 : (record?.amount ?? bill.amount)))
                        .font(AppFont.main(28, .semibold, relativeTo: .title))
                        .foregroundStyle(Tokens.text900)
                        .monospacedDigit()
                    Text("đ").font(AppFont.main(24, .medium)).foregroundStyle(Tokens.grey400)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.s16)
        .padding(.top, Space.s12)
        .padding(.bottom, Space.s8)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
        .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Color(hex: 0x0D121C).opacity(0.12), lineWidth: 0.5))
    }

    /// One fact: label on the left; on the right green text, or a small grey chip.
    private enum Value {
        case green(String), chip(String), date(String), percent(Double), code(String), none
    }

    private func facts(due: String?) -> some View {
        let rows: [(String, Value)] = bill.kind == .installment
            ? [
                ("Amount borrowed", .green("\(Money.format(bill.principal ?? 0)) đ")),
                ("Pay with", (bill.lender ?? bill.payWith).map { .chip($0) } ?? .chip("–")),
                ("Starting from", .date(bill.start)),
                ("Last payment", .date(BillMath.lastDue(bill))),
                ("Num of payments", .chip("\(bill.payments ?? 1) payments")),
                ("Amount each time", .green("\(Money.format(bill.amount)) đ")),
                ("Monthly interest", .percent(bill.rate ?? 0)),
                ("Conversion fee", .percent(bill.fee ?? 0)),
            ]
            : (bill.code.map { [("Bill code", Value.code($0))] } ?? []) + [
                ("Amount each time", .chip(bill.varies ? "Changes" : "Fixed")),
                (bill.varies ? "Roughly how much?" : "Amount", .green("\(bill.varies ? "~" : "")\(Money.format(bill.amount)) đ")),
                ("Repeats", .chip(bill.kind == .recurring ? "Monthly" : "Just once")),
                ("Due", .date(due ?? bill.start)),
                ("Pay with", .chip(bill.payWith ?? "–")),
            ]
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text(row.0).font(AppFont.body(.medium)).foregroundStyle(Tokens.text900)
                    Spacer(minLength: Space.s16)
                    valueView(row.1)
                }
                .frame(minHeight: 48)
                .padding(.horizontal, Space.s4)
                .accessibilityElement(children: .combine)
                if i < rows.count - 1 { Divider().overlay(Tokens.bd0) }
            }
        }
        .padding(.horizontal, Space.s12)
        .padding(.vertical, 2)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
        .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Color(hex: 0x0D121C).opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private func valueView(_ v: Value) -> some View {
        switch v {
        case .green(let t):
            Text(app.hidden && t.contains("đ") ? "•••••• đ" : t)
                .font(AppFont.bodyLarge(.medium)).foregroundStyle(Tokens.brand600).monospacedDigit()
        case .code(let c):
            Button {
                UIPasteboard.general.string = c
                copied = true
            } label: {
                HStack(spacing: 4) {
                    Text(c).font(AppFont.bodyLarge(.medium)).foregroundStyle(Tokens.brand600)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 14)).foregroundStyle(Tokens.grey400)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bill code \(c). Copy")
        case .chip(let t):
            chip { Text(t).foregroundStyle(t == "–" ? Tokens.grey400 : Tokens.text900) }
        case .date(let d):
            chip {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.system(size: 13)).foregroundStyle(Tokens.text700)
                    Text(DueText.ddmmyyyy(d)).foregroundStyle(Tokens.text900)
                }
            }
        case .percent(let p):
            chip {
                HStack(spacing: 4) {
                    Text(Self.percent(p)).foregroundStyle(Tokens.text700)
                    Text("%").foregroundStyle(Tokens.grey400)
                }
            }
        case .none:
            EmptyView()
        }
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(AppFont.body(.medium))
            .padding(.horizontal, Space.s12)
            .frame(minHeight: 28)
            .background(Tokens.bg3, in: .capsule)
    }

    /// History: newest first; four rows, "See more" for the rest.
    private var history: some View {
        let rows = bill.paid.sorted { $0.key > $1.key }
        let shown = allHistory ? rows : Array(rows.prefix(4))
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("History").font(AppFont.body(.semibold)).foregroundStyle(Tokens.text700)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if rows.count > 4 {
                    Button { animate { allHistory.toggle() } } label: {
                        HStack(spacing: 2) {
                            Text(allHistory ? "Show less" : "See more")
                            Image(systemName: allHistory ? "chevron.up" : "chevron.right").font(.system(size: 10, weight: .semibold))
                        }
                        .font(AppFont.capture(.medium))
                        .foregroundStyle(Tokens.brand700)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.s12)
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("No payments checked off yet.")
                        .font(AppFont.body(.medium))
                        .foregroundStyle(Tokens.grey400)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, Space.s4)
                }
                ForEach(Array(shown.enumerated()), id: \.element.key) { i, item in
                    HStack {
                        Text(DueText.monthLabel(item.key)).foregroundStyle(Tokens.grey400)
                        Spacer()
                        HStack(spacing: 6) {
                            Text(app.hidden ? "••••••" : Money.format(item.value.amount)).foregroundStyle(Tokens.text700)
                            Text("đ").foregroundStyle(Tokens.grey400)
                        }
                        .monospacedDigit()
                    }
                    .font(AppFont.body(.medium))
                    .frame(minHeight: 44)
                    .padding(.horizontal, Space.s4)
                    .accessibilityElement(children: .combine)
                    if i < shown.count - 1 { Divider().overlay(Tokens.bd0) }
                }
            }
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s4)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c14))
            .overlay(RoundedRectangle(cornerRadius: Corner.c14).strokeBorder(Tokens.bd0))
            if bill.kind != .oneoff {
                Text("Next: \(DueText.nextDue(bill, today: app.today).map(DueText.ddmmyyyy) ?? "nothing left")")
                    .font(AppFont.capture())
                    .foregroundStyle(Tokens.grey400)
                    .padding(.horizontal, Space.s12)
            }
        }
    }

    /// ✏️ + Check (or Undo check). Editing: 🗑 + Chat to edit.
    private func footer(due: String?, record: PaidRecord?) -> some View {
        let typed = Int(amountText.filter(\.isNumber)) ?? 0
        return HStack(spacing: Space.s12) {
            if editing {
                Button(role: .destructive) { confirmDelete = true } label: {
                    AppIcon(.trash, size: 20).foregroundStyle(Tokens.todayRed).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Delete bill")
                Spacer()
                Button { chatNotice = true } label: {
                    Label { Text("Chat to edit") } icon: { AppIcon(.ai, size: 18) }
                        .font(AppFont.body(.medium))
                        .foregroundStyle(Tokens.text900)
                        .padding(.horizontal, Space.s16)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                Button { animate { editing = false } } label: {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Tokens.action).interactive(), in: .circle)
                .accessibilityLabel("Done editing")
            } else {
                Button { animate { editing = true } } label: {
                    AppIcon(.pencil, size: 20).foregroundStyle(Tokens.text900).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Edit")
                if due != nil {
                    let paid = record != nil
                    let off = !paid && bill.varies && typed <= 0
                    Button {
                        LocalStore(context: context).setBillPaid(
                            bill, month: month, paid: !paid, date: app.today, amount: !paid && bill.varies ? typed : nil)
                    } label: {
                        Text(paid ? "Undo check" : "Check")
                            .font(AppFont.bodyLarge(.semibold))
                            .foregroundStyle(paid ? Tokens.text900 : .white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(paid ? .regular.interactive() : .regular.tint(off ? Tokens.grey400 : Tokens.action).interactive(), in: .capsule)
                    .disabled(off)
                } else {
                    Text("Nothing to pay in \(DueText.monthName(month))")
                        .font(AppFont.body())
                        .foregroundStyle(Tokens.grey400)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.top, Space.s12)
        .padding(.bottom, Space.s8)
        .background(alignment: .top) {
            LinearGradient(colors: [Tokens.bg3.opacity(0), Tokens.bg3.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
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

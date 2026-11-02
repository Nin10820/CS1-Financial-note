import SwiftData
import SwiftUI

/// Installments (Figma Due › Statement 943:25807): every installment together and what this
/// month asks for. Opened from Due's "…" menu.
struct InstallmentsView: View {
    @Binding var sheet: DueSheet?
    @Environment(AppState.self) private var app
    @Query(sort: \Bill.createdAt) private var bills: [Bill]

    var body: some View {
        @Bindable var app = app
        let month = app.dueMonth
        let list = bills.filter { $0.kind == .installment }
        let thisMonth = list.filter { BillMath.dueIn($0, month: month) != nil }
        let statement = thisMonth.reduce(0) { $0 + $1.amount }
        let comingUp = thisMonth.filter { $0.paid[month] == nil }.reduce(0) { $0 + $1.amount }
        let remaining = list.reduce(0) { $0 + BillMath.installmentStep($1, month: month).left * $1.amount }
        let lastDay = thisMonth.compactMap { BillMath.dueIn($0, month: month) }.max()

        ScrollView {
            VStack(alignment: .leading, spacing: Space.s20) {
                HeroCard(
                    label: "Statement · \(Day.monthsShort[Day.parts(month + "-01").m - 1]) \(Day.parts(month + "-01").y)",
                    amount: statement,
                    sub: lastDay.map { "Due \(DueText.ddmmyyyy($0))" },
                    rows: [("Coming up", comingUp), ("Remaining", remaining)],
                    hidden: $app.hidden,
                    showEye: true
                ) {
                    HeroButton(title: "History", systemImage: "clock.arrow.circlepath") { sheet = .history }
                    HeroButton(title: "Coming up", systemImage: "calendar") { sheet = .comingUp }
                }

                VStack(alignment: .leading, spacing: Space.s8) {
                    Text("Statement List")
                        .font(AppFont.main(18, .semibold, relativeTo: .headline))
                        .foregroundStyle(Tokens.text900)
                        .padding(.horizontal, Space.s12)
                        .accessibilityAddTraits(.isHeader)
                    if list.isEmpty {
                        Text("No installments yet.")
                            .font(AppFont.main(14))
                            .foregroundStyle(Tokens.grey400)
                            .padding(.horizontal, Space.s12)
                    }
                    ForEach(list) { b in
                        InstallmentCard(bill: b, month: month, hidden: app.hidden) { sheet = .bill(b.id) }
                    }
                }
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s24)
        }
        .background(Tokens.bg3)
        .navigationTitle("Installments")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheet = .add(.installment)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add an installment")
            }
        }
    }
}

private struct InstallmentCard: View {
    var bill: Bill
    var month: String
    var hidden: Bool
    var onOpen: () -> Void

    var body: some View {
        let st = BillMath.installmentStep(bill, month: month)
        Button(action: onOpen) {
            VStack(spacing: 0) {
                HStack(spacing: Space.s12) {
                    BillTile(icon: bill.icon, size: 32, soft: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name).font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                        Text(DueText.installmentLine(bill, month: month))
                            .font(AppFont.main(12))
                            .foregroundStyle(Tokens.grey400)
                    }
                    Spacer()
                    Text("\(st.paidCount)/\(st.total) paid")
                        .font(AppFont.main(12, .medium))
                        .foregroundStyle(Tokens.brand700)
                }
                .padding(Space.s12)
                Divider().overlay(Tokens.bd0)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hidden ? "••••••" : Money.format(bill.amount))
                        .font(AppFont.main(14, .semibold))
                        .foregroundStyle(Tokens.brand700)
                        .monospacedDigit()
                    Text("đ /month").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.grey300)
                }
                .padding(Space.s12)
                .background(Tokens.bg2)
            }
            .background(Tokens.bgWhite)
            .clipShape(.rect(cornerRadius: Corner.c12))
            .overlay(RoundedRectangle(cornerRadius: Corner.c12).strokeBorder(Tokens.bd1))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the details")
    }
}

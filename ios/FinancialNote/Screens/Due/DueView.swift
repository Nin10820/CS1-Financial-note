import SwiftData
import SwiftUI

/// Which sheet is open on Due or Installments.
enum DueSheet: Identifiable {
    case bill(String)
    case add(BillKind?)
    case comingUp
    case history

    var id: String {
        switch self {
        case .bill(let id): "bill-\(id)"
        case .add(let k): "add-\(k?.rawValue ?? "")"
        case .comingUp: "coming"
        case .history: "history"
        }
    }
}

/// Due — Figma High Fi 2 › Due (943:25260): month, what's left to pay, then STILL / DONE bills.
/// Ticking a bill records a "Bills" entry on the day it's ticked; unticking removes it.
struct DueView: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Bill.createdAt) private var bills: [Bill]

    @State private var sheet: DueSheet?
    @State private var showStill = true
    @State private var showDone = true
    @State private var path: [DueRoute] = []
    @State private var ticks = 0

    enum DueRoute: Hashable { case installments }

    var body: some View {
        @Bindable var app = app
        let s = BillMath.monthSummary(bills, month: app.dueMonth)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Space.s16) {
                    monthSwitcher
                    HeroCard(
                        label: "Remaining", amount: s.remaining, sub: nil,
                        rows: [("Paid", s.paid), ("Total remaining", s.totalRemaining)],
                        hidden: $app.hidden
                    ) {
                        HeroButton(title: "History", systemImage: "clock.arrow.circlepath") { sheet = .history }
                    }
                    if s.due.isEmpty {
                        empty
                    } else {
                        VStack(alignment: .leading, spacing: Space.s12) {
                            if !s.still.isEmpty {
                                GroupHeader(label: "Still", count: s.still.count, done: false, open: $showStill)
                                if showStill {
                                    ForEach(s.still, id: \.bill.id) { item in
                                        BillCard(bill: item.bill, date: item.date, month: app.dueMonth, today: app.today,
                                                 hidden: app.hidden, onTick: { tick(item.bill, true) },
                                                 onOpen: { sheet = .bill(item.bill.id) })
                                    }
                                }
                            }
                            if !s.done.isEmpty {
                                GroupHeader(label: "Done", count: s.done.count, done: true, open: $showDone)
                                    .padding(.top, s.still.isEmpty ? 0 : Space.s8)
                                if showDone {
                                    ForEach(s.done, id: \.bill.id) { item in
                                        BillCard(bill: item.bill, date: item.date, month: app.dueMonth, today: app.today,
                                                 hidden: app.hidden, onTick: { tick(item.bill, false) },
                                                 onOpen: { sheet = .bill(item.bill.id) })
                                    }
                                }
                            }
                        }
                        .padding(Space.s16)
                        .background(Tokens.bg2, in: .rect(cornerRadius: Corner.c20))
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.bottom, Space.s24)
            }
            .background(alignment: .top) {
                LinearGradient(colors: [Tokens.brand100, Tokens.bg3], startPoint: .top, endPoint: .bottom)
                    .frame(height: 320).ignoresSafeArea().accessibilityHidden(true)
            }
            .background(Tokens.bg3)
            .navigationTitle("Due")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbar(hasInstallments: bills.contains { $0.kind == .installment }) }
            .navigationDestination(for: DueRoute.self) { _ in
                InstallmentsView(sheet: $sheet)
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .bill(let id):
                    if let bill = bills.first(where: { $0.id == id }) {
                        BillDetailSheet(bill: bill, month: app.dueMonth)
                    }
                case .add(let kind):
                    AddBillSheet(month: app.dueMonth, startKind: kind)
                case .comingUp:
                    ComingUpSheet(bills: bills)
                case .history:
                    PaidHistorySheet(bills: bills) { id, month in
                        app.dueMonth = month
                        sheet = .bill(id)
                    }
                }
            }
            .sensoryFeedback(.success, trigger: ticks)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(hasInstallments: Bool) -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                app.dueMonth = Month.of(app.today)
            } label: {
                Image(systemName: "calendar")
            }
            .accessibilityLabel("This month")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button("Coming up", systemImage: "calendar.badge.clock") { sheet = .comingUp }
                Button("Installments", systemImage: "iphone") { path.append(.installments) }
                    .disabled(!hasInstallments)
                Button("History", systemImage: "clock.arrow.circlepath") { sheet = .history }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More")
            Button {
                sheet = .add(nil)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add a bill")
        }
    }

    private var monthSwitcher: some View {
        @Bindable var app = app
        return HStack(spacing: Space.s16) {
            Button {
                app.dueMonth = Month.add(app.dueMonth, -1)
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(.rect)
            }
            .accessibilityLabel("Previous month")
            Text(DueText.monthLabel(app.dueMonth))
                .font(AppFont.title(24, .bold, relativeTo: .title))
                .foregroundStyle(Tokens.text900)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)
            Button {
                app.dueMonth = Month.add(app.dueMonth, 1)
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(.rect)
            }
            .accessibilityLabel("Next month")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Tokens.text700)
        .buttonStyle(.plain)
        .padding(.top, Space.s4)
    }

    private var empty: some View {
        VStack(spacing: Space.s12) {
            Text("No bills due in \(DueText.monthName(app.dueMonth)).")
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.grey400)
            Button("Add a bill", systemImage: "plus") { sheet = .add(nil) }
                .font(AppFont.main(15, .semibold))
                .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s32)
        .background(Tokens.bg2, in: .rect(cornerRadius: Corner.c20))
    }

    /// The spending is recorded on the day the bill is ticked — the day the money actually left.
    private func tick(_ bill: Bill, _ paid: Bool) {
        LocalStore(context: context).setBillPaid(bill, month: app.dueMonth, paid: paid, date: app.today)
        if paid { ticks += 1 }
    }
}

/// "STILL (2) ⌄" / "DONE (2) ⌄" — tap to fold the group.
private struct GroupHeader: View {
    var label: String
    var count: Int
    var done: Bool
    @Binding var open: Bool

    var body: some View {
        Button {
            animate { open.toggle() }
        } label: {
            HStack(spacing: Space.s6) {
                Image(systemName: done ? "checkmark.circle" : "circle.dashed")
                Text(label.uppercased()).tracking(0.4)
                Text("(\(count))")
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .rotationEffect(.degrees(open ? 0 : -90))
            }
            .font(AppFont.main(13, .semibold, relativeTo: .caption))
            .foregroundStyle(done ? Tokens.brand700 : Tokens.text700)
            .padding(.horizontal, Space.s12)
            .padding(.vertical, Space.s6)
            .background(done ? Tokens.brand100 : Tokens.bg4, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(count) \(count == 1 ? "bill" : "bills")")
        .accessibilityValue(open ? "Shown" : "Folded")
    }
}

/// One bill in the Due list (Figma bill-item): tile, name, date, tick; amount and details below.
struct BillCard: View {
    var bill: Bill
    var date: String
    var month: String
    var today: String
    var hidden: Bool
    var onTick: () -> Void
    var onOpen: () -> Void

    var body: some View {
        let record = bill.paid[month]
        let paid = record != nil
        let amount = record?.amount ?? bill.amount
        VStack(spacing: 0) {
            HStack(spacing: Space.s12) {
                BillTile(icon: bill.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(bill.name)
                        .font(AppFont.main(16, .semibold))
                        .foregroundStyle(Tokens.text900)
                    Text(DueText.listDate(date, paid: paid, today: today))
                        .font(AppFont.main(12, .medium, relativeTo: .caption))
                        .foregroundStyle(Tokens.grey400)
                }
                Spacer()
                Button(action: onTick) {
                    Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(paid ? Tokens.text900 : Tokens.grey300)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(paid ? "Mark \(bill.name) as not paid" : "Mark \(bill.name) as paid")
                .accessibilityAddTraits(paid ? .isSelected : [])
            }
            .padding(.leading, Space.s12)
            .padding(.vertical, Space.s4)
            Divider().overlay(Tokens.bd0)
            Button(action: onOpen) {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text((!paid && bill.varies ? "~" : "") + (hidden ? "••••••" : Money.format(amount)))
                            .font(AppFont.main(15, .semibold))
                            .foregroundStyle(Tokens.text900)
                            .monospacedDigit()
                        Text("đ").font(AppFont.main(12, .medium)).foregroundStyle(Tokens.grey400)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Tokens.grey300)
                }
                .padding(.horizontal, Space.s12)
                .padding(.vertical, Space.s12)
                .background(Tokens.bg2)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(bill.name) details, \(hidden ? "amount hidden" : "\(Money.format(amount)) dong")")
        }
        .background(Tokens.bgWhite)
        .clipShape(.rect(cornerRadius: Corner.c12))
        .overlay(RoundedRectangle(cornerRadius: Corner.c12).strokeBorder(Tokens.bd1))
    }
}

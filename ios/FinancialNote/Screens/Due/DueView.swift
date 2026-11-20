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
    /// The card's All / Still / Done row, applied to the list.
    @State private var filter: DueFilter = .all
    @State private var path: [DueRoute] = []
    @State private var ticks = 0
    @State private var pageHeight: CGFloat = 0
    /// Bills ticked or unticked while looking: they stay in the group they were in (true = Done)
    /// so the list doesn't jump under the finger. They settle when the month changes or Due is left.
    @State private var stay: [String: Bool] = [:]
    @State private var toast: TickToast?

    enum DueRoute: Hashable { case installments }

    var body: some View {
        @Bindable var app = app
        let s = BillMath.monthSummary(bills, month: app.dueMonth)
        let inDone = { (i: BillMath.DueItem) in stay[i.bill.id] ?? (i.bill.paid[app.dueMonth] != nil) }
        let still = s.due.filter { !inDone($0) }
        let done = s.due.filter(inDone)

        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: Space.s16) {
                    header
                    // Edge to edge: the outer months run off the screen.
                    DueMonthStrip(month: $app.dueMonth, today: app.today, bills: bills, hidden: app.hidden)
                        .padding(.horizontal, -Space.s20)
                    DueCard(remaining: s.remaining, paid: s.paid, totalRemaining: s.totalRemaining,
                            stillCount: still.count, doneCount: done.count,
                            hidden: $app.hidden, filter: $filter) { sheet = .history }
                    if s.due.isEmpty {
                        empty
                    } else {
                        VStack(alignment: .leading, spacing: Space.s8) {
                            if filter != .done && !still.isEmpty { group("Still", still) }
                            if filter != .still && !done.isEmpty {
                                group("Done", done).padding(.top, filter == .all && !still.isEmpty ? Space.s8 : 0)
                            }
                            if (filter == .still && still.isEmpty) || (filter == .done && done.isEmpty) {
                                Text(filter == .still ? "Everything's paid this month." : "Nothing ticked yet this month.")
                                    .font(AppFont.body()).foregroundStyle(Tokens.grey400)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                                    .background(Tokens.bg4.opacity(0.6), in: .rect(cornerRadius: Corner.c20))
                            }
                        }
                        .animation(.snappy, value: filter)
                    }
                }
                .padding(.horizontal, Space.s20)
                .frame(minHeight: pageHeight, alignment: .top)
                .pageSwipe(back: { animate { app.dueMonth = Month.add(app.dueMonth, -1) } },
                           forward: { animate { app.dueMonth = Month.add(app.dueMonth, 1) } })
                // Room so the last bill scrolls clear of the floating tab bar.
                .padding(.bottom, 96)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
            .onChange(of: app.addBillRequest) { _, _ in sheet = .add(nil) }
            .onChange(of: app.dueMonth) { _, _ in stay = [:]; toast = nil }
            .onDisappear { stay = [:]; toast = nil }
            .modifier(MinimizesTabBar())
            .background(alignment: .top) {
                LinearGradient(colors: [Tokens.brand100, Tokens.bg3], startPoint: .top, endPoint: .bottom)
                    .frame(height: 320).ignoresSafeArea().accessibilityHidden(true)
            }
            .background(Tokens.canvas)
            .navigationTitle("Due")
            .toolbarTitleDisplayMode(.inline)
            .toolbar { toolbar(hasInstallments: bills.contains { $0.kind == .installment }) }
            .navigationDestination(for: DueRoute.self) { _ in
                InstallmentsView(sheet: $sheet)
            }
            .sheet(item: $sheet) { which in Group {
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
            }.sheetSurface() }
            .sensoryFeedback(.success, trigger: ticks)
        }
        // On the whole stack, not the scroll view, so it sits above the tab bar.
        .overlay(alignment: .bottom) {
            if let toast {
                TickToastView(toast: toast, hidden: app.hidden) { undo(toast) }
                    .id(toast.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task(id: toast?.id) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            animate(.smooth) { toast = nil }
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
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) { ProfileButton() }
    }

    /// "Nov 2026" large, like Today's date; a red dot when it's this month.
    private var header: some View {
        let (y, m, _) = Day.parts(app.dueMonth + "-01")
        return HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
            HStack(alignment: .top, spacing: 2) {
                Text(Day.monthsShort[m - 1])
                    .font(AppFont.heading(44, .medium, relativeTo: .largeTitle))
                    .foregroundStyle(Tokens.text900)
                if app.dueMonth == Month.of(app.today) {
                    Circle().fill(Tokens.todayRed).frame(width: 8, height: 8).padding(.top, 8)
                }
            }
            Text(String(y))
                .font(AppFont.heading(24, .medium, relativeTo: .title))
                .foregroundStyle(Tokens.grey400)
            Spacer()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(DueText.monthLabel(app.dueMonth))")
        .accessibilityAddTraits(.isHeader)
    }

    /// "STILL · 3" then the bills in one white card, rows split by thin lines (like Recent).
    private func group(_ title: String, _ items: [BillMath.DueItem]) -> some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            Text("\(title) · \(items.count)".uppercased())
                .font(AppFont.main(12, .semibold, relativeTo: .caption))
                .tracking(0.4)
                .foregroundStyle(Tokens.grey400)
                .padding(.leading, Space.s4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.bill.id) { i, item in
                    if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 52).padding(.trailing, Space.s12) }
                    BillRow(bill: item.bill, date: item.date, month: app.dueMonth, today: app.today, hidden: app.hidden,
                            onTick: { tick(item.bill) }, onOpen: { sheet = .bill(item.bill.id) })
                }
            }
            // Finance's list padding; the tick's own 44 pt target makes the right edge.
            .padding(.leading, Space.s16)
            .padding(.trailing, Space.s4)
            .padding(.vertical, Space.s4)
            .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
        }
    }

    private var empty: some View {
        VStack(spacing: Space.s12) {
            Text("No bills due in \(DueText.monthName(app.dueMonth)).")
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.grey400)
            Button("Add a bill", systemImage: "plus") { sheet = .add(nil) }
                .font(AppFont.main(14, .semibold))
                .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s32)
        .background(Tokens.bg2, in: .rect(cornerRadius: Corner.c20))
    }

    /// The spending is recorded on the day the bill is ticked — the day the money actually left.
    /// Ticks or unticks in place: the card keeps its spot, only the check changes.
    private func tick(_ bill: Bill) {
        let paid = bill.paid[app.dueMonth] == nil
        if stay[bill.id] == nil { stay[bill.id] = !paid }
        LocalStore(context: context).setBillPaid(bill, month: app.dueMonth, paid: paid, date: app.today)
        if paid { ticks += 1 }
        animate(.spring(duration: 0.4, bounce: 0.25)) {
            toast = TickToast(billId: bill.id, name: bill.name,
                              amount: bill.paid[app.dueMonth]?.amount ?? bill.amount, paid: paid)
        }
    }

    /// Undo puts the bill back the way it was and closes the note quietly.
    private func undo(_ t: TickToast) {
        if let bill = bills.first(where: { $0.id == t.billId }) {
            LocalStore(context: context).setBillPaid(bill, month: app.dueMonth, paid: !t.paid, date: app.today)
        }
        animate(.smooth) { toast = nil }
    }
}

/// Three months side by side — before | this one | after — with what's due in each, the picked
/// one in the middle (the same strip as Today's months). Bills are known ahead, so the months
/// to come can be picked too.
struct DueMonthStrip: View {
    @Binding var month: String
    var today: String
    var bills: [Bill]
    var hidden: Bool

    var body: some View {
        let now = Month.of(today)
        let earliest = bills.map { Month.of($0.start) }.min() ?? now
        let first = min(earliest, Month.add(now, -12))
        let last = Month.add(now, 12)
        let keys = (0...Month.between(first, last)).map { Month.add(first, $0) }
        var due: [String: Int] = [:]
        for k in keys {
            let s = BillMath.monthSummary(bills, month: k)
            due[k] = s.due.reduce(0) { $0 + ($1.bill.paid[k]?.amount ?? $1.bill.amount) }
        }
        return PeriodStrip(
            keys: keys,
            last: last,
            selected: $month,
            spent: due,
            hidden: hidden,
            title: { Day.monthsLong[Int($0.suffix(2))! - 1] },
            spoken: { "\(Day.monthsLong[Int($0.suffix(2))! - 1]) \($0.prefix(4))" },
            name: "Months",
            peek: true)
    }
}

/// What the note under the list says after a tick.
struct TickToast: Equatable {
    var id = UUID()
    var billId: String
    var name: String
    var amount: Int
    var paid: Bool
}

/// "Paid Rent · 2,500,000đ added to Today  Undo" — a small glass note that goes by itself.
private struct TickToastView: View {
    var toast: TickToast
    var hidden: Bool
    var onUndo: () -> Void

    var body: some View {
        HStack(spacing: Space.s12) {
            Image(systemName: toast.paid ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(toast.paid ? Tokens.success : Tokens.grey400)
                .symbolEffect(.bounce, value: toast.id)
            VStack(alignment: .leading, spacing: 0) {
                Text(toast.paid ? "Paid \(toast.name)" : "\(toast.name) not paid yet")
                    .font(AppFont.main(14, .semibold))
                    .foregroundStyle(Tokens.text900)
                    .lineLimit(1)
                Text(toast.paid
                     ? (hidden ? "Added to Today" : "\(Money.format(toast.amount))đ added to Today")
                     : "Taken off Today")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.s8)
            Button("Undo", action: onUndo)
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(Tokens.brand600)
                .padding(.horizontal, Space.s12)
                .frame(minHeight: 44)
                .contentShape(.rect)
                .buttonStyle(.plain)
        }
        .padding(.leading, Space.s16)
        .padding(.trailing, Space.s4)
        .padding(.vertical, Space.s6)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Space.s20)
        .padding(.bottom, Space.s12)
        .accessibilityElement(children: .contain)
    }
}

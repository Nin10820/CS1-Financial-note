import SwiftUI

/// Coming up (Figma Due › Coming up, Card / Month): what each month will ask for.
/// Tapping a month opens it on Due.
struct ComingUpSheet: View {
    var bills: [Bill]
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var view: ViewKind = .month

    enum ViewKind: String, CaseIterable { case card = "Card", month = "Month" }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    Group { if view == .month { grid } else { timeline } }
                        .padding(Space.s20)
                }
                // Card / Month stays on top while the years scroll under it.
                .safeAreaInset(edge: .top, spacing: 0) {
                    Picker("View", selection: $view) {
                        Label("Card", systemImage: "list.bullet").tag(ViewKind.card)
                        Label("Month", systemImage: "square.grid.2x2").tag(ViewKind.month)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Space.s20)
                    .padding(.vertical, Space.s8)
                    .background(Tokens.canvas)
                }
                // Opens on the year of the month on Due; scroll up for older years, down for later ones.
                .onAppear { jump(proxy) }
                .onChange(of: view) { _, _ in jump(proxy) }
            }
            .background(Tokens.canvas)
            .sheetHeader("Coming up")
        }
        .presentationDetents([.large])
    }

    private var openYear: Int { Day.parts(app.dueMonth + "-01").y }

    /// From the year of the first bill (or last year) to two years ahead.
    private var years: [Int] {
        let now = Day.parts(app.today).y
        let first = min(bills.map { Day.parts($0.start).y }.min() ?? now, now - 1)
        return Array(first...(max(now, openYear) + 2))
    }

    /// Month opens on the year of the month on Due; Card starts at this month, at the top.
    private func jump(_ proxy: ScrollViewProxy) {
        let target = view == .month ? "year-\(openYear)" : "timeline-top"
        Task { @MainActor in proxy.scrollTo(target, anchor: .top) }
    }

    private func pick(_ month: String) {
        app.dueMonth = month
        dismiss()
    }

    // MARK: - Month grid

    /// Every year one under the other, each with its twelve months.
    private var grid: some View {
        VStack(spacing: Space.s24) {
            ForEach(years, id: \.self) { year in
                VStack(alignment: .leading, spacing: Space.s12) {
                    Text(String(year))
                        .font(AppFont.heading(20, .semibold))
                        .foregroundStyle(year == Day.parts(app.today).y ? Tokens.text900 : Tokens.text700)
                        .padding(.leading, Space.s4)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s8), count: 3), spacing: Space.s8) {
                        ForEach(1...12, id: \.self) { i in
                            let m = String(format: "%04d-%02d", year, i)
                            MonthCell(month: m, bills: bills, selected: m == app.dueMonth, hidden: app.hidden) { pick(m) }
                        }
                    }
                }
                .id("year-\(year)")
            }
            HStack(spacing: Space.s4) {
                Image(systemName: "checkmark.circle")
                Text("all paid · dashed = nothing due")
            }
            .font(AppFont.main(12))
            .foregroundStyle(Tokens.grey400)
        }
    }

    // MARK: - Card timeline (next 12 months)

    private var timeline: some View {
        let now = Month.of(app.today)
        let months = (0..<12).map { Month.add(now, $0) }
            .map { (m: $0, s: BillMath.monthSummary(bills, month: $0)) }
            .filter { !$0.s.due.isEmpty }
        return VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).id("timeline-top")
            if months.isEmpty {
                Text("Nothing due in the next 12 months.")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
            }
            ForEach(months, id: \.m) { row in
                Button { pick(row.m) } label: {
                    HStack(alignment: .top, spacing: Space.s12) {
                        VStack(spacing: 0) {
                            Circle().fill(row.s.still.isEmpty ? Tokens.brand500 : Tokens.text900).frame(width: 10, height: 10)
                            Rectangle().fill(Tokens.bd1).frame(width: 1).frame(maxHeight: .infinity)
                        }
                        .padding(.top, 5)
                        VStack(alignment: .leading, spacing: Space.s4) {
                            Text(DueText.monthLabel(row.m) + (row.m == now ? " · this month" : ""))
                                .font(AppFont.main(12, .medium))
                                .foregroundStyle(Tokens.grey400)
                            AmountText(value: row.s.remaining + row.s.paid, size: 18, hidden: app.hidden)
                            // What's in it: one line each, name and amount.
                            VStack(spacing: Space.s4) {
                                ForEach(row.s.due, id: \.bill.id) { item in
                                    let paid = item.bill.paid[row.m]
                                    HStack(spacing: Space.s8) {
                                        Circle().fill(Tokens.billColor(item.bill)).frame(width: 6, height: 6)
                                        Text(item.bill.name).lineLimit(1)
                                        Spacer(minLength: Space.s8)
                                        Text(app.hidden ? "•••" : Money.format(paid?.amount ?? item.bill.amount) + "đ")
                                            .monospacedDigit()
                                    }
                                    .font(AppFont.main(13))
                                    .foregroundStyle(paid == nil ? Tokens.text700 : Tokens.grey400)
                                }
                            }
                            .padding(.top, Space.s4)
                        }
                        .padding(.bottom, Space.s20)
                        Spacer()
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// One month in the grid: selected (dark green), all paid (light green with a tick),
/// nothing due (dashed), or still to pay (white).
private struct MonthCell: View {
    var month: String
    var bills: [Bill]
    var selected: Bool
    var hidden: Bool
    var action: () -> Void

    var body: some View {
        let s = BillMath.monthSummary(bills, month: month)
        let total = DueText.monthTotal(bills, month: month)
        let empty = s.due.isEmpty
        let allPaid = !empty && s.still.isEmpty
        let ink: Color = selected ? .white : empty ? Tokens.grey300 : Tokens.text900
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s4) {
                HStack {
                    Text(Day.monthsShort[Day.parts(month + "-01").m - 1])
                        .font(AppFont.main(12, .medium))
                    Spacer()
                    if allPaid && !selected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.brand600)
                    }
                }
                Text(hidden ? "•••" : DueText.short(total))
                    .font(AppFont.main(14, .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(s.due.count) \(s.due.count == 1 ? "bill" : "bills")")
                    .font(AppFont.main(11))
                    .opacity(0.7)
            }
            .foregroundStyle(ink)
            .padding(Space.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if selected {
                    CardGradient().clipShape(.rect(cornerRadius: Corner.c14))
                } else if empty {
                    RoundedRectangle(cornerRadius: Corner.c14)
                        .strokeBorder(Tokens.bd2, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                } else {
                    RoundedRectangle(cornerRadius: Corner.c14)
                        .fill(allPaid ? Tokens.brand50 : Tokens.bgWhite)
                        .strokeBorder(allPaid ? Tokens.brand200 : Tokens.bd1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(DueText.monthLabel(month)), \(s.due.count) bills"
                            + (empty ? "" : hidden ? "" : ", \(Money.format(total)) dong")
                            + (allPaid ? ", all paid" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

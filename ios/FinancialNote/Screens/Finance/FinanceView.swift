import Charts
import SwiftData
import SwiftUI

/// Finance — Figma High Fi 2 › Asset (943:25860 overview, 943:25978 scrolled, 943:26145 family).
/// Everything here is what the user wrote down; the app never connects to a bank.
struct FinanceView: View {
    @Environment(AppState.self) private var app
    @Query(sort: \Asset.amount, order: .reverse) private var assets: [Asset]
    @Query(sort: \AssetMove.date, order: .reverse) private var moves: [AssetMove]
    @Query(sort: \CareGift.date, order: .reverse) private var care: [CareGift]
    @Query(sort: \WorthPoint.month) private var worth: [WorthPoint]
    @Query(sort: \Bill.createdAt) private var bills: [Bill]
    @Query private var profiles: [Profile]

    @State private var view: FinanceTab = .overview
    @State private var adding = false
    @State private var path: [Route] = []

    enum FinanceTab: String, CaseIterable { case overview = "Overview", total = "Total Asset", debt = "Debt" }
    enum Route: Hashable { case family }

    var body: some View {
        @Bindable var app = app
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    Picker("Finance view", selection: $view) {
                        ForEach(FinanceTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch view {
                    case .overview: overview
                    case .total: TotalAssetsSection(assets: assets, hidden: app.assetsHidden) { adding = true }
                    case .debt: DebtSection(bills: bills, hidden: app.assetsHidden)
                    }
                }
                .padding(.horizontal, Space.s20)
                .padding(.bottom, Space.s24)
            }
            .background(Tokens.bg3)
            .navigationTitle("Finance")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button(app.assetsHidden ? "Show amounts" : "Hide amounts",
                               systemImage: app.assetsHidden ? "eye" : "eye.slash") { app.assetsHidden.toggle() }
                        Button("For your family", systemImage: "person.2") { path.append(.family) }
                            .disabled(care.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add an asset")
                }
            }
            .navigationDestination(for: Route.self) { _ in
                FamilyView(care: care, birthYear: profiles.first?.birthYear)
            }
            .sheet(isPresented: $adding) { AddAssetSheet() }
        }
    }

    // MARK: - Overview

    @ViewBuilder
    private var overview: some View {
        if assets.isEmpty {
            VStack(spacing: Space.s12) {
                Text("Nothing written down yet")
                    .font(AppFont.main(17, .semibold))
                    .foregroundStyle(Tokens.text900)
                Text("Add what you keep — cash, savings, gold, a fund — and this page adds it up. Nothing connects to your bank.")
                    .font(AppFont.main(14))
                    .foregroundStyle(Tokens.grey400)
                    .multilineTextAlignment(.center)
                Button("Add an asset", systemImage: "plus") { adding = true }
                    .font(AppFont.main(15, .semibold))
                    .buttonStyle(.glassProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(Space.s24)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        } else {
            let shares = AssetMath.shares(assets)
            let growth = FinanceText.growth(worth.map { ($0.month, $0.value) })
            VStack(spacing: 0) {
                TotalBlock(total: shares.total, groups: shares.groups, growth: growth, hidden: app.assetsHidden)
                    .padding(Space.s16)
                Divider().overlay(Tokens.bd0)
                if worth.count > 1 {
                    WorthChart(points: worth, growth: growth, hidden: app.assetsHidden)
                        .padding(Space.s16)
                } else {
                    Text("The line appears after your second month of updates.")
                        .font(AppFont.main(13))
                        .foregroundStyle(Tokens.grey400)
                        .padding(Space.s16)
                }
            }
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))

            MovesCard(moves: moves, hidden: app.assetsHidden)

            if !care.isEmpty {
                Text("FOR YOUR FAMILY")
                    .font(AppFont.main(12, .semibold, relativeTo: .caption))
                    .tracking(0.4)
                    .foregroundStyle(Tokens.text700)
                    .padding(.top, Space.s8)
                Button { path.append(.family) } label: {
                    CareCard(care: care, birthYear: profiles.first?.birthYear, today: app.today, hidden: app.assetsHidden) {
                        HStack {
                            Text("See what it went to")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(AppFont.main(14, .medium))
                        .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Total + allocation

private struct TotalBlock: View {
    var total: Int
    var groups: [AssetMath.Group]
    var growth: Int?
    var hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Total Asset").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                Text(hidden ? "••••••" : Money.format(total))
                    .font(AppFont.main(28, .bold, relativeTo: .title))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.text900)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("đ").font(AppFont.main(22, .semibold)).foregroundStyle(Tokens.grey300)
                if let growth, !hidden { GrowthBadge(pct: growth) }
            }
            .accessibilityElement(children: .combine)

            GeometryReader { g in
                let shown = groups.filter { $0.pct > 0 }
                let gaps = CGFloat(max(shown.count - 1, 0)) * 4
                HStack(spacing: 4) {
                    ForEach(shown, id: \.kind) { grp in
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Tokens.assetKind(grp.kind))
                            .frame(width: max(0, (g.size.width - gaps) * CGFloat(grp.pct) / 100))
                    }
                }
            }
            .frame(height: 32)
            .accessibilityHidden(true)

            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: Space.s8) {
                ForEach(groups, id: \.kind) { grp in
                    HStack(spacing: Space.s6) {
                        RoundedRectangle(cornerRadius: 3).fill(Tokens.assetKind(grp.kind)).frame(width: 12, height: 12)
                        Text("\(grp.kind.label):").foregroundStyle(Tokens.text700)
                        Text("\(grp.pct)%").foregroundStyle(Tokens.text900)
                    }
                    .font(AppFont.main(13, .medium))
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct GrowthBadge: View {
    var pct: Int

    var body: some View {
        Label("\(abs(pct))%", systemImage: pct < 0 ? "arrow.down.right" : "arrow.up.right")
            .font(AppFont.main(12, .semibold))
            .foregroundStyle(Tokens.brand700)
            .padding(.horizontal, Space.s6)
            .padding(.vertical, 2)
            .background(Tokens.brand100, in: .rect(cornerRadius: Corner.c6))
            .accessibilityLabel("\(pct < 0 ? "Down" : "Up") \(abs(pct)) percent on a year ago")
    }
}

// MARK: - Net-worth chart (Swift Charts)

private struct WorthChart: View {
    var points: [WorthPoint]
    var growth: Int?
    var hidden: Bool
    @State private var selected: Date?

    private func date(_ month: String) -> Date { Day.date(month + "-01") }

    var body: some View {
        let last = points[points.count - 1]
        let focus = selected.flatMap { s in points.min { abs(date($0.month).timeIntervalSince(s)) < abs(date($1.month).timeIntervalSince(s)) } } ?? last
        Chart {
            ForEach(points, id: \.month) { p in
                AreaMark(x: .value("Month", date(p.month)), y: .value("Worth", p.value))
                    .foregroundStyle(LinearGradient(colors: [Tokens.brand500.opacity(0.28), Tokens.brand500.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Month", date(p.month)), y: .value("Worth", p.value))
                    .foregroundStyle(Tokens.brand500)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.monotone)
            }
            RuleMark(x: .value("Month", date(focus.month)))
                .foregroundStyle(Tokens.grey300)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            PointMark(x: .value("Month", date(focus.month)), y: .value("Worth", focus.value))
                .foregroundStyle(Tokens.bgWhite)
                .symbolSize(40)
                .annotation(position: .top, spacing: 8, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    if !hidden {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(FinanceText.monthLabel(focus.month)).font(AppFont.main(12, .semibold)).foregroundStyle(Tokens.text900)
                            HStack(spacing: 4) {
                                Text(DueText.short(focus.value))
                                if focus.month == last.month, let growth {
                                    Text("·")
                                    Image(systemName: growth < 0 ? "arrow.down.right" : "arrow.up.right")
                                    Text("\(abs(growth))%")
                                }
                            }
                            .font(AppFont.main(11, .medium))
                            .foregroundStyle(Tokens.brand700)
                        }
                        .padding(Space.s8)
                        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c8))
                        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    }
                }
            PointMark(x: .value("Month", date(focus.month)), y: .value("Worth", focus.value))
                .foregroundStyle(Tokens.brand500)
                .symbolSize(14)
        }
        .chartXSelection(value: $selected)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                AxisGridLine().foregroundStyle(Tokens.bd0)
                AxisValueLabel {
                    if !hidden, let n = v.as(Int.self) { Text(Money.format(n / 1000)).font(AppFont.main(11)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: [date(points[0].month), date(last.month)]) { v in
                AxisValueLabel(anchor: v.index == 0 ? .topLeading : .topTrailing) {
                    if let d = v.as(Date.self) { Text(FinanceText.monthLabel(Month.of(Day.iso(d)))).font(AppFont.main(11)) }
                }
            }
        }
        .frame(height: 170)
        .accessibilityLabel("Net worth from \(FinanceText.monthLabel(points[0].month)) to \(FinanceText.monthLabel(last.month))")
        .accessibilityValue(hidden ? "Hidden" : "Now \(Money.format(last.value)) dong")
    }
}

// MARK: - History

/// A coloured tile with a short mark ("Au", "fm", "TP"…) for an asset row.
struct AssetTile: View {
    var icon: AssetIcon

    var body: some View {
        Text(icon.mark)
            .font(AppFont.main(13, .bold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Tokens.assetTile(icon), in: .rect(cornerRadius: Corner.c8))
            .accessibilityHidden(true)
    }
}

struct MoneyRow: View {
    var title: String
    var sub: String
    var amount: Int
    var icon: AssetIcon?
    var hidden: Bool

    var body: some View {
        HStack(spacing: Space.s12) {
            if let icon { AssetTile(icon: icon) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.main(15, .semibold)).foregroundStyle(Tokens.text900)
                Text(sub).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
            Spacer()
            AmountText(value: amount, hidden: hidden)
        }
        .padding(.vertical, Space.s8)
        .accessibilityElement(children: .combine)
    }
}

private struct MovesCard: View {
    var moves: [AssetMove]
    var hidden: Bool
    @State private var all = false

    var body: some View {
        if !moves.isEmpty {
            VStack(alignment: .leading, spacing: Space.s4) {
                HStack {
                    Text("History").font(AppFont.main(18, .semibold, relativeTo: .headline)).foregroundStyle(Tokens.text900)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if moves.count > 3 {
                        Button(all ? "Show less" : "See all") { withAnimation(.snappy) { all.toggle() } }
                            .font(AppFont.main(14, .medium))
                            .foregroundStyle(Tokens.brand600)
                    }
                }
                ForEach(Array((all ? moves : Array(moves.prefix(3))).enumerated()), id: \.element.id) { i, m in
                    if i > 0 { Divider().overlay(Tokens.bd0) }
                    MoneyRow(title: m.title, sub: FinanceText.dayLabel(m.date), amount: m.amount, icon: m.icon, hidden: hidden)
                }
            }
            .padding(Space.s16)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
        }
    }
}

// MARK: - Total Asset and Debt

private struct TotalAssetsSection: View {
    var assets: [Asset]
    var hidden: Bool
    var onAdd: () -> Void

    var body: some View {
        let s = AssetMath.shares(assets)
        VStack(alignment: .leading, spacing: Space.s12) {
            ForEach(s.groups, id: \.kind) { g in
                let list = assets.filter { $0.kind == g.kind }
                VStack(alignment: .leading, spacing: Space.s4) {
                    HStack(spacing: Space.s8) {
                        RoundedRectangle(cornerRadius: 3).fill(Tokens.assetKind(g.kind)).frame(width: 12, height: 12)
                        Text(g.kind.label).font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                        Text("\(g.pct)%").font(AppFont.main(13, .medium)).foregroundStyle(Tokens.grey400)
                        Spacer()
                        AmountText(value: g.sum, hidden: hidden)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                    if list.isEmpty {
                        Text("Nothing here yet.").font(AppFont.main(13)).foregroundStyle(Tokens.grey400).padding(.vertical, Space.s4)
                    }
                    ForEach(list) { a in
                        Divider().overlay(Tokens.bd0)
                        MoneyRow(title: a.name, sub: "Updated \(FinanceText.dayLabel(a.updatedOn))", amount: a.amount, icon: a.icon, hidden: hidden)
                    }
                }
                .padding(Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }
            HStack(spacing: Space.s4) {
                Text("\(hidden ? "••••••" : Money.format(s.total)) đ in total ·")
                Button("Add an asset", action: onAdd).foregroundStyle(Tokens.brand600)
            }
            .font(AppFont.main(13))
            .foregroundStyle(Tokens.grey400)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct DebtSection: View {
    var bills: [Bill]
    var hidden: Bool

    var body: some View {
        let d = FinanceText.debt(bills)
        VStack(alignment: .leading, spacing: Space.s12) {
            VStack(alignment: .leading, spacing: Space.s8) {
                Text("Still to pay on installments").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
                AmountText(value: d.total, size: 28, hidden: hidden)
                Text("Worked out from your installments in Due. Paying one off there updates this.")
                    .font(AppFont.main(12))
                    .foregroundStyle(Tokens.grey400)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.s16)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))

            if d.rows.isEmpty {
                Text("No installments left to pay.").font(AppFont.main(13)).foregroundStyle(Tokens.grey400)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(d.rows.enumerated()), id: \.element.bill.id) { i, r in
                        if i > 0 { Divider().overlay(Tokens.bd0) }
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: Space.s6) {
                                Text(r.bill.name).font(AppFont.main(15, .semibold)).foregroundStyle(Tokens.text900)
                                Text("\(r.bill.lender.map { "\($0) · " } ?? "")\(r.left) of \(r.bill.payments ?? 0) left")
                                    .font(AppFont.main(12))
                                    .foregroundStyle(Tokens.grey400)
                                ProgressView(value: Double(r.paid), total: Double(max(r.bill.payments ?? 1, 1)))
                                    .tint(Tokens.brand500)
                                    .frame(maxWidth: 160)
                            }
                            Spacer()
                            AmountText(value: r.owe, hidden: hidden)
                        }
                        .padding(.vertical, Space.s12)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }
        }
    }
}

// MARK: - Add asset

struct AddAssetSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount: Int?
    @State private var kind: AssetKind = .available

    var body: some View {
        NavigationStack {
            Form {
                Section("What is it?") {
                    TextField("Gold, Saving - TP Bank, Fund…", text: $name)
                }
                Section("How much is it worth now?") {
                    HStack {
                        TextField("0", text: Binding(
                            get: { amount.map(Money.format) ?? "" },
                            set: { amount = Int($0.filter(\.isNumber)) }))
                            .keyboardType(.numberPad)
                            .monospacedDigit()
                        Text("đ").foregroundStyle(Tokens.grey400)
                    }
                }
                Section {
                    Picker("Which group?", selection: $kind) {
                        ForEach(AssetKind.allCases, id: \.self) { k in
                            Label {
                                Text(k.label)
                            } icon: {
                                Image(systemName: "square.fill").foregroundStyle(Tokens.assetKind(k))
                            }
                            .tag(k)
                        }
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Which group?")
                } footer: {
                    Text(FinanceText.hint(kind))
                }
            }
            .font(AppFont.main(16))
            .navigationTitle("New asset")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        LocalStore(context: context).addAsset(
            Asset(name: n, kind: kind, icon: AssetMath.guessIcon(n, kind: kind), amount: amount ?? 0, updated: app.today))
        dismiss()
    }
}

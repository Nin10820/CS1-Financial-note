import Charts
import SwiftUI

/// What you own by group, as a ring with the biggest share in the middle, the legend beside it.
/// Money others owe you (Owed) counts like any other group. Tap a group to
/// show only its assets in the list below; tap it again for all.
struct AssetsPie: View {
    var assets: [Asset]
    var hidden: Bool
    @Binding var picked: AssetKind?

    var body: some View {
        let shares = AssetMath.shares(assets)
        let owned = shares.groups.filter { $0.sum > 0 }
        let top = owned.max { $0.sum < $1.sum }
        let shown = picked.flatMap { p in owned.first { $0.kind == p } } ?? top
        PieCard(title: "Where your money is") {
            ZStack {
                Chart(owned, id: \.kind) { g in
                    SectorMark(angle: .value("Share", g.sum), innerRadius: .ratio(0.78), angularInset: 3)
                        .foregroundStyle(Tokens.assetKind(g.kind))
                        .opacity(picked == nil || picked == g.kind ? 1 : 0.3)
                        .cornerRadius(8)
                }
                .chartLegend(.hidden)
                if let shown {
                    VStack(spacing: 0) {
                        Text("\(shown.pct)%").font(AppFont.heading(24, .medium)).foregroundStyle(Tokens.assetKind(shown.kind))
                            .contentTransition(.numericText())
                        Text(shown.kind.label.lowercased()).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
                    }
                }
            }
        } legend: {
            ForEach(shares.groups, id: \.kind) { g in
                row(g.kind, amount: g.sum, pct: "\(g.pct)%")
            }
        }
    }

    private func row(_ kind: AssetKind, amount: Int, pct: String, muted: Bool = false) -> some View {
        Button {
            withAnimation(.snappy) { picked = picked == kind ? nil : kind }
        } label: {
            PieLegend(color: Tokens.assetKind(kind), name: kind.label,
                      amount: hidden ? "•••" : AnalyticsView.compact(amount), pct: pct, muted: muted)
                .padding(.horizontal, Space.s6)
                .frame(minHeight: 32)
                .background(picked == kind ? Tokens.assetKind(kind).opacity(0.14) : .clear, in: .rect(cornerRadius: Corner.c8))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -Space.s6)
        .accessibilityAddTraits(picked == kind ? .isSelected : [])
        .accessibilityHint(picked == kind ? "Shows all assets" : "Shows only these assets below")
    }
}

/// What you owe by source — each installment, each family member with interest — as a solid
/// pie with its slices apart, the legend beside it.
struct DebtPie: View {
    var bills: [Bill]
    var loans: [FamilyLoan]
    var today: String
    var hidden: Bool

    var body: some View {
        let debts = Self.debts(bills: bills, loans: loans, today: today)
        let total = max(debts.reduce(0) { $0 + $1.sum }, 1)
        PieCard(title: "Who you still owe") {
            if debts.isEmpty {
                Circle().fill(Tokens.bg4).padding(Space.s12)
                    .overlay(Text("None").font(AppFont.main(12)).foregroundStyle(Tokens.grey400))
            } else {
                Chart(debts.indices, id: \.self) { i in
                    SectorMark(angle: .value("Owed", debts[i].sum), angularInset: 4)
                        .foregroundStyle(debts[i].color)
                        .cornerRadius(10)
                }
                .chartLegend(.hidden)
            }
        } legend: {
            ForEach(debts.indices, id: \.self) { i in
                let pct = Int((Double(debts[i].sum) / Double(total) * 100).rounded())
                PieLegend(color: debts[i].color, name: debts[i].name,
                          amount: hidden ? "•••" : AnalyticsView.compact(debts[i].sum), pct: pct == 0 ? "<1%" : "\(pct)%")
                    .frame(minHeight: 32)
            }
        }
    }

    /// What's owed, by source: each installment left, then each family member with interest.
    static func debts(bills: [Bill], loans: [FamilyLoan], today: String) -> [(name: String, sum: Int, color: Color)] {
        let palette = [Color(hex: 0xF97066), Color(hex: 0xFDB022), Color(hex: 0x7A5AF8), Color(hex: 0x2E90FA),
                       Color(hex: 0x00BA90), Color(hex: 0xEE46BC)]
        let rows = FinanceText.debt(bills).rows.map { ($0.bill.name, $0.owe) }
            + LoanMath.people(loans, today: today).filter { $0.owed > 0 }.map { ($0.who, $0.owed) }
        return rows.sorted { $0.1 > $1.1 }.enumerated().map { i, r in (r.0, r.1, palette[i % palette.count]) }
    }
}

/// A white card: title, the chart on the left, the legend on the right.
private struct PieCard<ChartView: View, Legend: View>: View {
    var title: String
    @ViewBuilder var chart: ChartView
    @ViewBuilder var legend: Legend

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(title).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
            HStack(alignment: .center, spacing: Space.s20) {
                chart.frame(width: 140, height: 140)
                VStack(alignment: .leading, spacing: 0) { legend }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(Space.s16)
        .accessibilityElement(children: .contain)
    }
}

/// "● Mom   41.1M   47%"
private struct PieLegend: View {
    var color: Color
    var name: String
    var amount: String
    var pct: String
    var muted = false

    var body: some View {
        HStack(spacing: Space.s6) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name).font(AppFont.table(13, .medium)).foregroundStyle(muted ? Tokens.grey400 : Tokens.text900)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: Space.s4)
            Text(amount).font(AppFont.table(12)).foregroundStyle(Tokens.grey400).monospacedDigit()
            Text(pct).font(AppFont.table(muted ? 11 : 13, muted ? .regular : .semibold))
                .foregroundStyle(muted ? Tokens.grey400 : Tokens.text900).monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

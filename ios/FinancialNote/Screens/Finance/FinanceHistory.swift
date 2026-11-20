import SwiftUI

/// A card row that opens a history sheet: "History · 12 changes · last 16 Nov ›".
struct HistoryLink: View {
    var sub: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Tokens.grey400, in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("History").font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900)
                    Text(sub).font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                }
                Spacer(minLength: Space.s4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.grey300)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s12)
            .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the history")
    }
}

/// One line in a history sheet: a solid round tile, what and when, the amount.
private struct HistoryLine: View {
    var tile: AnyView
    var title: String
    var sub: String
    var amount: String

    var body: some View {
        HStack(spacing: Space.s12) {
            tile.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                Text(sub).font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
            }
            Spacer(minLength: Space.s4)
            Text(amount).font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900)
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .padding(.vertical, Space.s4)
        .accessibilityElement(children: .combine)
    }
}

/// The sheet's frame: a list of lines, newest first, with Close.
private struct HistoryList<Rows: View>: View {
    var title: String
    var empty: String
    var isEmpty: Bool
    /// Filter chips over the list ("All", "Installments"…); the first means everything.
    var filters: [String]
    @Binding var filter: String
    @ViewBuilder var rows: Rows
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.s8) {
                            ForEach(filters, id: \.self) { f in
                                FilterChip(label: f, selected: filter == f) { withAnimation(.snappy) { filter = f } }
                            }
                        }
                        .padding(.horizontal, Space.s20)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                .listSectionSpacing(Space.s12)
                if isEmpty {
                    Text(empty).font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                        .listRowBackground(Tokens.card)
                }
                Section { rows }.listRowBackground(Tokens.card)
            }
            .appListSurface()
            // The chips sit close under the title, not a whole section gap below it.
            .contentMargins(.top, Space.s8, for: .scrollContent)
            .listSectionSpacing(.compact)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
                }
            }
        }
    }
}

private func signed(_ v: Int, hidden: Bool) -> String {
    hidden ? "•••" : (v < 0 ? "−" : "+") + Money.format(abs(v)) + "đ"
}

/// Every change to the assets: money put in or taken out, values updated.
struct AssetHistorySheet: View {
    var moves: [AssetMove]
    var hidden: Bool
    @State private var filter = "All"

    var body: some View {
        let kinds: [String: AssetMoveKind] = ["Put in": .putIn, "Took out": .takeOut, "Value": .value]
        let rows = moves.filter { m in kinds[filter].map { m.kind == $0 } ?? true }.sorted { $0.date > $1.date }
        HistoryList(title: "Asset history", empty: "Nothing here yet.", isEmpty: rows.isEmpty,
                    filters: ["All", "Put in", "Took out", "Value"], filter: $filter) {
            ForEach(rows) { m in
                HistoryLine(tile: AnyView(AssetTile(icon: m.icon, size: 40, round: true)),
                            title: m.title,
                            sub: (m.assetId == nil ? "" : "\(m.kind.label) · ") + HoldingsTable.shortDay(m.date),
                            amount: signed(m.amount, hidden: hidden))
            }
        }
    }
}

/// Every move on what you owe: installments paid, money from family and paying it back.
struct DebtHistorySheet: View {
    var bills: [Bill]
    var loans: [FamilyLoan]
    var today: String
    var hidden: Bool
    @State private var filter = "All"

    private struct Row: Identifiable {
        let id: String
        /// "Installments" or the family member's name, for the filter.
        let group: String
        let date: String
        let title: String
        let sub: String
        let amount: Int
        let tile: AnyView
    }

    var body: some View {
        let paid: [Row] = bills.filter { $0.kind == .installment }.flatMap { b in
            b.paid.map { month, rec in
                let day = Day.iso(rec.at)
                return Row(id: "\(b.id)-\(month)", group: "Installments", date: day, title: b.name,
                           sub: "Installment paid · " + HoldingsTable.shortDay(day), amount: -rec.amount,
                           tile: AnyView(Image(systemName: b.icon.symbol)
                                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Tokens.billTile(b.icon), in: .circle)))
            }
        }
        // Same colour per person as on the Debt pie.
        let colors = Dictionary(DebtPie.debts(bills: bills, loans: loans, today: today).map { ($0.name, $0.color) },
                                uniquingKeysWith: { a, _ in a })
        let family: [Row] = loans.map { l in
            Row(id: l.id, group: l.who, date: l.date, title: l.who,
                sub: l.kind.label + " · " + HoldingsTable.shortDay(l.date),
                amount: l.kind == .received ? l.amount : -l.amount,
                tile: AnyView(Text(String(l.who.prefix(1)).uppercased())
                    .font(AppFont.table(16, .bold)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(colors[l.who] ?? Tokens.grey400, in: .circle)))
        }
        // All, Installments, then each family member.
        let people = Array(Set(loans.map(\.who))).sorted()
        let filters = ["All"] + (paid.isEmpty ? [] : ["Installments"]) + people
        let rows = (paid + family).filter { filter == "All" || $0.group == filter }.sorted { $0.date > $1.date }
        HistoryList(title: "Debt history", empty: "Nothing here yet.", isEmpty: rows.isEmpty,
                    filters: filters, filter: $filter) {
            ForEach(rows) { r in
                HistoryLine(tile: r.tile, title: r.title, sub: r.sub, amount: signed(r.amount, hidden: hidden))
            }
        }
    }
}

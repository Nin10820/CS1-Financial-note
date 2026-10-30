import SwiftData
import SwiftUI

/// The dark "Taken care of" card: total given to family, since when, and an optional footer.
struct CareCard<Footer: View>: View {
    var care: [CareGift]
    var birthYear: Int?
    var today: String
    var hidden: Bool
    @ViewBuilder var footer: Footer

    var body: some View {
        let total = care.reduce(0) { $0 + $1.amount }
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("Taken care of")
                .font(AppFont.main(16, .medium))
                .foregroundStyle(Color(hex: 0xC6F36A))
            HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                Text(hidden ? "••••••" : Money.format(total))
                    .font(AppFont.amount(40))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("đ").font(AppFont.currency(for: 40)).foregroundStyle(Tokens.onDark)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hidden ? "Taken care of, hidden" : "Taken care of, \(Money.format(total)) dong")
            Text(FinanceText.since(careDates: care.map(\.date), birthYear: birthYear, today: today))
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.onDark)
            Divider().overlay(.white.opacity(0.16)).padding(.vertical, Space.s4)
            footer
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { CardGradient().clipShape(.rect(cornerRadius: Corner.c20)) }
    }
}

/// "Taken care of" — Figma High Fi 2 943:26145: who the money went to, a plain line about
/// what it means, and the history. Money given to family is never counted as spending.
struct FamilyView: View {
    var care: [CareGift]
    var birthYear: Int?
    @Environment(AppState.self) private var app
    @Query private var entries: [Entry]
    @State private var showAll = false
    @State private var talkLater = false

    var body: some View {
        let groups = Dictionary(grouping: care, by: \.who)
            .map { (who: $0.key, list: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.list.count > $1.list.count }
        let share = FinanceText.familyShare(
            incoming: entries.filter { $0.flow == .in }.map { ($0.date, $0.amount) },
            care: care.map { ($0.date, $0.amount) },
            today: app.today)
        let rows = care.sorted { $0.date > $1.date }

        ScrollView {
            if care.isEmpty {
                ContentUnavailableView(
                    "Nothing here yet", systemImage: "person.2",
                    description: Text("Money you give to family shows up here. It is never counted as spending."))
                    .padding(.top, Space.s32)
            } else {
            VStack(alignment: .leading, spacing: Space.s16) {
                CareCard(care: care, birthYear: birthYear, today: app.today, hidden: app.assetsHidden) {
                    VStack(spacing: Space.s8) {
                        ForEach(groups, id: \.who) { g in
                            HStack(spacing: Space.s8) {
                                Circle().fill(Color(hex: 0x83C853)).frame(width: 8, height: 8)
                                Text(g.who).font(AppFont.main(14, .medium)).foregroundStyle(.white)
                                Spacer()
                                Text(FinanceText.cadence(who: g.who, firstTitle: g.list.last?.title ?? "", count: g.list.count))
                                    .font(AppFont.main(12))
                                    .foregroundStyle(Tokens.onDark)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Space.s8) {
                    Text("Financial progress isn't only what you keep. \(Text("It's also what you carry for the people you love.").bold())")
                        .font(AppFont.main(16))
                        .foregroundStyle(Tokens.text900)
                    if let share, !app.assetsHidden {
                        Text("About \(share)% of what you earned in the last 30 days")
                            .font(AppFont.main(12, .medium))
                            .foregroundStyle(Tokens.brand600)
                    }
                }
                .padding(Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.brand50, in: .rect(cornerRadius: Corner.c16))
                .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.brand200))

                Text("History")
                    .font(AppFont.main(18, .semibold, relativeTo: .headline))
                    .foregroundStyle(Tokens.text900)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array((showAll ? rows : Array(rows.prefix(6))).enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider().overlay(Tokens.bd0) }
                        MoneyRow(title: c.title, sub: FinanceText.dayLabel(c.date), amount: c.amount, icon: nil, hidden: app.assetsHidden)
                    }
                    if rows.count > 6 {
                        Button(showAll ? "Show less" : "Show all \(rows.count)") { animate { showAll.toggle() } }
                            .font(AppFont.main(14, .medium))
                            .foregroundStyle(Tokens.brand700)
                            .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s24)
            }
        }
        .background(Tokens.bg3)
        .safeAreaInset(edge: .bottom) {
            Button { talkLater = true } label: {
                Label("Talk with Monez", systemImage: "sparkles")
                    .font(AppFont.main(16, .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s8)
        }
        .navigationTitle("Taken care of")
        .toolbarTitleDisplayMode(.inline)
        .alert("Comes later", isPresented: $talkLater) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Talking about family money comes later. For now I record what you spend and receive, and keep track of bills.")
        }
    }
}

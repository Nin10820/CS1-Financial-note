import SwiftUI

/// Which bills the Due list shows.
enum DueFilter: Hashable { case all, still, done }

/// Due's dark card, in the same style as Today's Total Amount card: what's left to pay this
/// month, a line with what's paid and what's left overall, then a row — All |
/// Still · Done | History — that picks what the list below shows.
struct DueCard: View {
    var remaining: Int
    var paid: Int
    var totalRemaining: Int
    var stillCount: Int
    var doneCount: Int
    @Binding var hidden: Bool
    @Binding var filter: DueFilter
    var onHistory: () -> Void
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Remaining")
                .font(AppFont.body(.medium))
                .foregroundStyle(.white.opacity(0.8))
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(hidden ? "••••••" : Money.format(remaining))
                        .font(AppFont.heading(40, .medium, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(LinearGradient(
                            stops: [.init(color: .white, location: 0.3), .init(color: .white.opacity(0.24), location: 1)],
                            startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("đ")
                        .font(AppFont.heading(28, .regular, relativeTo: .title))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "Remaining, hidden" : "Remaining, \(Money.format(remaining)) dong")
                Spacer(minLength: Space.s8)
            }
            HStack(spacing: Space.s8) {
                Text("paid " + (hidden ? "••••" : SpendCard.short(paid) + "đ"))
                Circle().fill(.white.opacity(0.64)).frame(width: 4, height: 4).accessibilityHidden(true)
                Text("left overall " + (hidden ? "••••" : SpendCard.short(totalRemaining) + "đ"))
            }
            .font(AppFont.capture())
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)

            // [All]  [○ Still n | ✓ Done n]  [History]
            HStack(spacing: Space.s4) {
                chip(.all) { Text("All").font(AppFont.heading(16, .medium, relativeTo: .body)) }
                    .frame(width: 43)
                    .padding(Space.s4)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.36), in: .rect(cornerRadius: Corner.c14))
                    .innerEdge(cornerRadius: Corner.c14, top: 0.14, bottom: 0.06)
                HStack(spacing: 0) {
                    chip(.still) { count("circle.dashed", "Still", stillCount) }
                    chip(.done) { count("checkmark.circle.fill", "Done", doneCount, tint: Tokens.brand400) }
                }
                .padding(Space.s4)
                .frame(minHeight: 44)
                .background(.black.opacity(0.36), in: .rect(cornerRadius: Corner.c14))
                .innerEdge(cornerRadius: Corner.c14, top: 0.14, bottom: 0.06)
                Button(action: onHistory) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 43, height: 36)
                        .padding(Space.s4)
                        .frame(minHeight: 44)
                        .background(.black.opacity(0.36), in: .rect(cornerRadius: Corner.c14))
                        .innerEdge(cornerRadius: Corner.c14, top: 0.14, bottom: 0.06)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("History")
            }
            .padding(.top, Space.s12)
        }
        .padding(.top, 20.5)
        .padding(.horizontal, 16.5)
        .padding(.bottom, 12.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: Corner.c24)
        .shadow(color: .black.opacity(0.16), radius: 9, y: 6)
    }

    private func count(_ symbol: String, _ label: String, _ n: Int, tint: Color = .white) -> some View {
        HStack(spacing: Space.s8) {
            Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
            Text(label).font(AppFont.heading(16, .medium, relativeTo: .body))
                .padding(.trailing, -2)
            Text("\(n)").font(AppFont.heading(14, .regular, relativeTo: .body)).foregroundStyle(.white.opacity(0.64))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func chip<Label: View>(_ f: DueFilter, @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.82)) { filter = f }
        } label: {
            label()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 36)
                .padding(.horizontal, f == .all ? 0 : Space.s8)
                .background {
                    if filter == f {
                        RoundedRectangle(cornerRadius: Corner.c12, style: .continuous)
                            .fill(.white.opacity(0.16))
                            .innerEdge(cornerRadius: Corner.c12, top: 0.35, bottom: 0.12)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f == .all ? "All bills" : f == .still ? "Still to pay, \(stillCount)" : "Done, \(doneCount)")
        .accessibilityAddTraits(filter == f ? .isSelected : [])
    }
}

/// One bill as a row in the white list card (like Today's Recent): tile, name and date, the
/// amount, and the tick.
struct BillRow: View {
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
        HStack(spacing: Space.s8) {
            Button(action: onOpen) {
                HStack(spacing: Space.s12) {
                    // Round and soft, like the tiles in Today's Recent.
                    Image(systemName: bill.icon.symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.billTileSoft(bill.icon).ink)
                        .frame(width: 36, height: 36)
                        .background(Tokens.billTileSoft(bill.icon).bg, in: .circle)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name)
                            .font(AppFont.body(.medium))
                            .foregroundStyle(paid ? Tokens.grey400 : Tokens.text900)
                            .lineLimit(1)
                        Text(DueText.listDate(date, paid: paid, today: today))
                            .font(AppFont.capture())
                            .foregroundStyle(Tokens.grey400)
                    }
                    Spacer(minLength: Space.s8)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text((!paid && bill.varies ? "~" : "") + (hidden ? "••••••" : Money.format(amount)))
                            .font(AppFont.heading(14, .medium, relativeTo: .body))
                            .foregroundStyle(paid ? Tokens.grey400 : Tokens.text700)
                            .monospacedDigit()
                        Text("đ")
                            .font(AppFont.heading(14, .regular, relativeTo: .body))
                            .foregroundStyle(Tokens.grey400)
                    }
                    .fixedSize()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(bill.name), \(DueText.listDate(date, paid: paid, today: today)), \(hidden ? "amount hidden" : "\(Money.format(amount)) dong")")
            .accessibilityHint("Opens the details")
            Button(action: onTick) {
                Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: paid ? .regular : .light))
                    .foregroundStyle(paid ? Tokens.brand500 : Tokens.grey300)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce.up, value: paid)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(paid ? "Mark \(bill.name) as not paid" : "Mark \(bill.name) as paid")
            .accessibilityAddTraits(paid ? .isSelected : [])
        }
        .padding(.leading, Space.s4)
        .padding(.vertical, Space.s4)
        .frame(minHeight: 60)
    }
}

import SwiftUI

/// Which bills the Due list shows.
enum DueFilter: Hashable { case all, still, done }

extension Bill {
    /// Where the bill comes from or goes to: the lender of an installment, who a one-off is paid
    /// to, or the bank it's paid with. nil when nothing was written.
    var source: String? {
        guard let s = (lender ?? payWith)?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        return s
    }
}

extension BillKind {
    /// Due's name for the kind: "Bill", "Installment", "Other".
    var badge: String {
        switch self {
        case .recurring: "Bill"
        case .installment: "Installment"
        case .oneoff: "Other"
        }
    }
}

/// A small label on a bill row: the kind in grey, where it's from in green.
struct BillBadge: View {
    var text: String
    var green = false

    var body: some View {
        Text(text)
            .font(AppFont.table(11, .medium))
            .foregroundStyle(green ? Tokens.brand800 : Tokens.text700)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(green ? Tokens.brand100 : Tokens.bg4, in: .capsule)
    }
}

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
                        .font(AppFont.amount(36))
                        .monospacedDigit()
                        .foregroundStyle(LinearGradient(
                            stops: [.init(color: .white, location: 0.3), .init(color: .white.opacity(0.24), location: 1)],
                            startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("đ")
                        .font(AppFont.currency(for: 36))
                        .foregroundStyle(.white.opacity(0.48))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(hidden ? "Remaining, hidden" : "Remaining, \(Money.format(remaining)) dong")
                .doubleTapToHide($hidden)
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
        let line = DueText.listDate(date, paid: paid, today: today)
        // "To Minh" for a one-off paid to someone; the bank or lender otherwise.
        let source = bill.source.map { bill.kind == .oneoff && bill.lender != nil ? "To \($0)" : $0 }
        HStack(spacing: Space.s8) {
            Button(action: onOpen) {
                HStack(spacing: Space.s12) {
                    // Same row as Finance's lists: a solid round tile, name and date, amount.
                    Image(systemName: bill.icon.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Tokens.billColor(bill), in: .circle)
                        .opacity(paid ? 0.6 : 1)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name)
                            .font(AppFont.table(15, .semibold))
                            .foregroundStyle(paid ? Tokens.grey400 : Tokens.text900)
                            .lineLimit(1)
                        // One badge: where the money is owed. The kind is the tile's colour.
                        if let source {
                            BillBadge(text: source, green: true)
                                .opacity(paid ? 0.7 : 1)
                        }
                    }
                    Spacer(minLength: Space.s8)
                    // The amount, and the day under it.
                    VStack(alignment: .trailing, spacing: 2) {
                        Text((!paid && bill.varies ? "~" : "") + (hidden ? "•••" : Money.format(amount) + "đ"))
                            .font(AppFont.heading(16, .semibold))
                            .foregroundStyle(paid ? Tokens.grey400 : Tokens.text900)
                            .monospacedDigit()
                        Text(line)
                            .font(AppFont.table(12))
                            .foregroundStyle(Tokens.grey400)
                    }
                    .fixedSize()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(bill.name), \(line), \(bill.kind.badge)\(source.map { ", \($0)" } ?? ""), \(hidden ? "amount hidden" : "\(Money.format(amount)) dong")")
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
        .padding(.vertical, Space.s8)
        .frame(minHeight: 64)
    }
}

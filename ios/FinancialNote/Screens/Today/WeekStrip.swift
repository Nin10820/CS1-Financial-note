import SwiftUI

/// Mo–Su strip under the month (Figma Day picker 962:32146). Swipe sideways for the previous or
/// next week (never past this week). Days with notes read darker; future days can't be picked.
struct WeekStrip: View {
    @Binding var day: String
    var today: String
    var marked: Set<String>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    var body: some View {
        let monday = Day.monday(of: day)
        HStack(spacing: Space.s4) {
            ForEach(0..<7, id: \.self) { i in
                let d = Day.addDays(monday, i)
                cell(d, name: Self.names[i], today: today)
            }
        }
        // Seven days must fit across the phone; past this size the strip stops growing.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 20).onEnded { g in
                if g.translation.width > 50 { move(-7) }
                else if g.translation.width < -50 { move(7) }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Week of \(Day.short(monday))")
        .accessibilityAction(named: "Previous week") { move(-7) }
        .accessibilityAction(named: "Next week") { move(7) }
    }

    private func move(_ days: Int) {
        let next = Day.addDays(day, days)
        withAnimation(reduceMotion ? nil : .snappy) { day = next > today ? today : next }
    }

    @ViewBuilder
    private func cell(_ d: String, name: String, today: String) -> some View {
        let picked = d == day
        let future = d > today
        let strong = marked.contains(d) || d == today
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { day = d }
        } label: {
            VStack(spacing: Space.s4) {
                Text(String(d.suffix(2)))
                    .font(AppFont.heading(20, picked ? .medium : .regular, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(picked ? Tokens.brand700 : strong ? Tokens.text900 : Tokens.grey300)
                Text(name)
                    .font(AppFont.capture(.medium))
                    .foregroundStyle(d == today ? Tokens.todayRed : picked ? Tokens.brand700 : Tokens.grey400)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s8)
            .background {
                if picked {
                    RoundedRectangle(cornerRadius: Corner.c12)
                        .fill(Tokens.brand100)
                        .strokeBorder(Tokens.brand300, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(future)
        .opacity(future ? 0.6 : 1)
        .accessibilityLabel(Day.spoken(d) + (d == today ? ", today" : ""))
        .accessibilityAddTraits(d == day ? .isSelected : [])
    }
}

/// Day picker (Figma 962:32146): Today / Day / Done over the system graphical calendar, whose
/// month title opens the month / year wheel (964:33538) on its own.
struct DayPickerSheet: View {
    @Binding var day: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker(
                "Day",
                selection: Binding(get: { Day.date(day) }, set: { day = Day.iso($0) }),
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Tokens.brand500)
            .padding(.horizontal)
            .navigationTitle("Day")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { day = Day.today() }
                        .foregroundStyle(Tokens.text900)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(AppFont.main(14, .semibold))
                        .foregroundStyle(Tokens.brand700)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Monthly (Figma Today › Monthly): months side by side, each with what went out,
/// "4,608K đ / October". The picked one sits in the middle; scroll sideways or tap one to change it.
struct MonthStrip: View {
    @Binding var day: String
    var today: String
    var entries: [Entry]
    var hidden: Bool

    var body: some View {
        let now = Month.of(today)
        let firstYear = min(Int(now.prefix(4))! - 1, entries.map { Int($0.date.prefix(4)) ?? 9999 }.min() ?? 9999)
        let first = "\(firstYear)-01"
        var spent: [String: Int] = [:]
        for e in entries where e.flow == .out { spent[Month.of(e.date), default: 0] += e.amount }
        return PeriodStrip(
            // Through December, the months still to come shown greyed out.
            keys: (0...Month.between(first, "\(now.prefix(4))-12")).map { Month.add(first, $0) },
            last: now,
            selected: Binding(
                get: { Month.of(day) },
                set: { m in day = m == now ? today : "\(m)-01" }),
            spent: spent,
            hidden: hidden,
            title: { Day.monthsLong[Int($0.suffix(2))! - 1] },
            spoken: { "\(Day.monthsLong[Int($0.suffix(2))! - 1]) \($0.prefix(4))" },
            name: "Months")
    }
}

/// Yearly: years side by side with what went out in each; same behaviour as the months.
struct YearStrip: View {
    @Binding var day: String
    var today: String
    var entries: [Entry]
    var hidden: Bool

    var body: some View {
        let now = Int(today.prefix(4))!
        let first = min(now - 2, entries.map { Int($0.date.prefix(4)) ?? 9999 }.min() ?? 9999)
        var spent: [String: Int] = [:]
        for e in entries where e.flow == .out { spent[String(e.date.prefix(4)), default: 0] += e.amount }
        return PeriodStrip(
            // Two years ahead, greyed out.
            keys: (first...now + 2).map(String.init),
            last: String(now),
            selected: Binding(
                get: { String(day.prefix(4)) },
                set: { y in day = y == String(now) ? today : "\(y)-01-01" }),
            spent: spent,
            hidden: hidden,
            title: { $0 },
            spoken: { $0 },
            name: "Years")
    }
}

/// Three cells across, the picked one held in the middle. Scrolling picks whatever lands in
/// the middle; tapping a cell picks it too.
private struct PeriodStrip: View {
    var keys: [String]
    /// The latest one that can be picked; later ones are shown but disabled.
    var last: String
    @Binding var selected: String
    var spent: [String: Int]
    var hidden: Bool
    var title: (String) -> String
    var spoken: (String) -> String
    var name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var centred: String?
    @State private var width: CGFloat = 0

    var body: some View {
        let cellWidth = max((width - 2 * Space.s4) / 3, 1)
        ScrollView(.horizontal) {
            LazyHStack(spacing: Space.s4) {
                ForEach(keys, id: \.self) { k in
                    cell(k).frame(width: cellWidth)
                }
            }
            .scrollTargetLayout()
            // Room on both sides so the first and last cell can sit in the middle.
            .padding(.horizontal, cellWidth + Space.s4)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred, anchor: .center)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { w in
            width = w
            centred = nil
            Task { centred = selected }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear { centred = selected }
        .onChange(of: selected) { _, k in
            if centred != k { withAnimation(reduceMotion ? nil : .snappy) { centred = k } }
        }
        .onChange(of: centred) { _, k in
            guard let k, k != selected else { return }
            if k > last {
                // Scrolled onto a period that hasn't come yet: go back to the latest one.
                withAnimation(reduceMotion ? nil : .snappy) { centred = last }
            } else {
                selected = k
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
    }

    private func cell(_ k: String) -> some View {
        let picked = selected == k
        let future = k > last
        let v = spent[k] ?? 0
        let amount = future ? "—" : hidden ? "•••" : v >= 1000 ? "\(Money.format(v / 1000))K" : Money.format(v)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { selected = k }
        } label: {
            VStack(spacing: Space.s4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(amount).font(AppFont.capture(picked ? .semibold : .medium)).monospacedDigit()
                    Text("đ").font(AppFont.main(11))
                }
                .foregroundStyle(picked ? Tokens.brand700 : Tokens.grey400)
                Text(title(k))
                    .font(AppFont.capture(.medium))
                    .foregroundStyle(picked ? Tokens.brand700 : Tokens.text700)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.s12)
            .background {
                if picked {
                    RoundedRectangle(cornerRadius: Corner.c12)
                        .fill(Tokens.brand100)
                        .strokeBorder(Tokens.brand300, lineWidth: 1)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(future)
        .opacity(future ? 0.4 : 1)
        .accessibilityLabel("\(spoken(k)), \(hidden ? "amount hidden" : "\(Money.format(v)) dong spent")")
        .accessibilityAddTraits(picked ? .isSelected : [])
    }
}

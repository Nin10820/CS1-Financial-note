import SwiftUI

/// Mo–Su strip under the month (Figma Day picker 962:32146). Swipe sideways for the previous or
/// next week (never past this week). Days with notes read darker; future days can't be picked.
struct WeekStrip: View {
    @Binding var day: String
    var range: DayRange
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
        .padding(range == .week ? Space.s4 : 0)
        .background {
            if range == .week {
                RoundedRectangle(cornerRadius: Corner.c14)
                    .fill(Tokens.brand100)
                    .strokeBorder(Tokens.brand300, lineWidth: 1)
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
        let picked = range != .week && d == day
        let future = d > today
        let strong = marked.contains(d) || d == today
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { day = d }
        } label: {
            VStack(spacing: Space.s4) {
                Text(String(d.suffix(2)))
                    .font(AppFont.heading(20, .medium, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(picked ? Tokens.brand700 : strong ? Tokens.text900 : Tokens.grey300)
                Text(name)
                    .font(AppFont.heading(12, .medium, relativeTo: .caption))
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
                        .font(AppFont.main(15, .semibold))
                        .foregroundStyle(Tokens.brand700)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

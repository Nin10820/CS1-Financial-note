import SwiftUI

/// D / W / M / Y / All on View Analysis.
enum AnalysisPeriod: String, CaseIterable, Identifiable {
    case day = "D", week = "W", month = "M", year = "Y", all = "All"
    var id: String { rawValue }

    var spoken: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All time"
        }
    }
}

/// One bar: money out (dark) and money in (striped) for a slot of the period.
struct AnalysisBar {
    var label: String
    var title: String
    var out: Int
    var incoming: Int
}

/// Builds the bars for a period around a day.
enum AnalysisBars {
    static func full(_ iso: String) -> String {
        let (y, m, d) = Day.parts(iso)
        return "\(d) \(Day.monthsShort[m - 1]) \(y)"
    }

    static func monday(_ iso: String) -> String {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: Day.date(iso)) // 1 = Sunday
        return Day.addDays(iso, -((weekday + 5) % 7))
    }

    /// "16 – 22 Nov 2026", "Nov 2026", "2026"…
    static func periodTitle(_ p: AnalysisPeriod, anchor: String, custom: (from: String, to: String)) -> String {
        switch p {
        case .day: return full(anchor)
        case .week:
            let a = monday(anchor), b = Day.addDays(a, 6)
            let (_, am, ad) = Day.parts(a), (_, bm, _) = Day.parts(b)
            return am == bm ? "\(ad) – \(full(b))" : "\(ad) \(Day.monthsShort[am - 1]) – \(full(b))"
        case .month:
            let (y, m, _) = Day.parts(anchor)
            return "\(Day.monthsLong[m - 1]) \(y)"
        case .year: return String(anchor.prefix(4))
        case .all: return "All time"
        }
    }

    /// First and last day the period covers.
    static func range(_ p: AnalysisPeriod, anchor: String, custom: (from: String, to: String)) -> (from: String, to: String) {
        switch p {
        case .day: return (anchor, anchor)
        case .week: let a = monday(anchor); return (a, Day.addDays(a, 6))
        case .month:
            let (y, m, _) = Day.parts(anchor)
            return (Month.of(anchor) + "-01", String(format: "%@-%02d", Month.of(anchor), Day.daysIn(year: y, month: m)))
        case .year: return (anchor.prefix(4) + "-01-01", anchor.prefix(4) + "-12-31")
        case .all: return custom
        }
    }

    static func make(_ p: AnalysisPeriod, anchor: String, custom: (from: String, to: String), entries: [Entry]) -> [AnalysisBar] {
        var byDay: [String: (out: Int, incoming: Int)] = [:]
        for e in entries {
            var s = byDay[e.date] ?? (0, 0)
            if e.flow == .out { s.out += e.amount } else { s.incoming += e.amount }
            byDay[e.date] = s
        }
        func day(_ iso: String, label: String) -> AnalysisBar {
            let s = byDay[iso] ?? (0, 0)
            return AnalysisBar(label: label, title: full(iso), out: s.out, incoming: s.incoming)
        }
        func monthBar(_ month: String, label: String) -> AnalysisBar {
            let s = byDay.filter { $0.key.hasPrefix(month) }.values
            let (y, m, _) = Day.parts(month + "-01")
            return AnalysisBar(label: label, title: "\(Day.monthsLong[m - 1]) \(y)",
                               out: s.reduce(0) { $0 + $1.out }, incoming: s.reduce(0) { $0 + $1.incoming })
        }
        func days(_ from: String, _ to: String) -> [AnalysisBar] {
            var out: [AnalysisBar] = []
            var d = from
            while d <= to {
                let n = Day.parts(d).d
                out.append(day(d, label: "\(n)"))
                d = Day.addDays(d, 1)
            }
            return out
        }

        switch p {
        case .day:
            // Eight three-hour slots, from when each line was written.
            let lines = entries.filter { $0.date == anchor }
            return (0..<8).map { k in
                let slot = lines.filter { Calendar.current.component(.hour, from: $0.createdAt) / 3 == k }
                return AnalysisBar(label: "\(k * 3)h", title: "\(full(anchor)), \(k * 3):00–\(k * 3 + 3):00",
                                   out: slot.filter { $0.flow == .out }.reduce(0) { $0 + $1.amount },
                                   incoming: slot.filter { $0.flow == .in }.reduce(0) { $0 + $1.amount })
            }
        case .week:
            let names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            let start = monday(anchor)
            return (0..<7).map { day(Day.addDays(start, $0), label: names[$0]) }
        case .month:
            let (y, m, _) = Day.parts(anchor)
            let month = Month.of(anchor)
            return days(month + "-01", String(format: "%@-%02d", month, Day.daysIn(year: y, month: m)))
        case .year:
            let y = anchor.prefix(4)
            return (1...12).map { monthBar(String(format: "%@-%02d", String(y), $0), label: Day.monthsShort[$0 - 1]) }
        case .all:
            let count = Calendar.current.dateComponents([.day], from: Day.date(custom.from), to: Day.date(custom.to)).day ?? 0
            if count <= 31 { return days(custom.from, custom.to) }
            var bars: [AnalysisBar] = []
            var m = Month.of(custom.from)
            while m <= Month.of(custom.to) {
                bars.append(monthBar(m, label: Day.monthsShort[Day.parts(m + "-01").m - 1]))
                m = Month.add(m, 1)
            }
            return bars
        }
    }
}

/// "D  W  M  Y  Cus" — grey capsule, the picked one on a white pill.
struct PeriodPicker: View {
    @Binding var period: AnalysisPeriod
    var onPick: (AnalysisPeriod) -> Void
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisPeriod.allCases) { p in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { period = p }
                    onPick(p)
                } label: {
                    Text(p.rawValue)
                        .font(AppFont.main(14, period == p ? .semibold : .regular))
                        .foregroundStyle(Tokens.text900)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background {
                            if period == p {
                                Capsule().fill(Tokens.segmentOn)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "period", in: pill)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(p.spoken)
                .accessibilityAddTraits(period == p ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Tokens.bg4, in: .capsule)
    }
}

/// Bars with the scale on the right (Figma View Analysis): for each day (or month) two bars
/// side by side — dark green for money out, green stripes for money in. Every pair keeps at
/// least the week view's width; when they don't fit (month, year, long ranges) the bars slide
/// sideways while the scale stays put. Tap a pair to see its day; tap it again for the total.
struct AnalysisBarChart: View {
    var bars: [AnalysisBar]
    var filter: FlowFilter
    var picked: Int?
    var hidden: Bool
    /// The pair to bring into view when the period changes (today, or the day being looked at).
    var focus: Int? = nil
    /// What one bar stands for, for the average line ("day", "month").
    var unit = "day"
    /// Height of the bars' area; View Analysis shrinks it while the page scrolls.
    var plot: CGFloat = 210
    var onPick: (Int) -> Void

    private let axis: CGFloat = 40
    private let labels: CGFloat = 28
    private let gap: CGFloat = 10
    private let minGroup: CGFloat = 36

    /// The pairs on screen while the bars slide; the scale fits them, not the whole period.
    @State private var window: ClosedRange<Int>?

    var body: some View {
        let showOut = filter != .in, showIn = filter != .out
        GeometryReader { g in
            let room = g.size.width - axis
            let n = CGFloat(max(bars.count, 1))
            let group = max(minGroup, (room - gap * (n - 1)) / n)
            let content = group * n + gap * (n - 1)
            // Before any scroll (or when everything fits), all pairs count.
            let inView = window.map { Array($0).filter(bars.indices.contains) } ?? []
            let seen = inView.isEmpty ? Array(bars.indices) : inView
            let top = Self.niceMax(seen.map { max(showOut ? bars[$0].out : 0, showIn ? bars[$0].incoming : 0) }.max() ?? 0)
            ZStack(alignment: .topLeading) {
                // Scale: five lines across, labels at the right end; they stay while the bars slide.
                ForEach(0..<5, id: \.self) { k in
                    let y = plot - plot * CGFloat(k) / 4
                    Rectangle().fill(Tokens.bd0).frame(width: g.size.width, height: 1).position(x: g.size.width / 2, y: y)
                    // A short chart (shrunk while scrolling) keeps only 0, the middle and the top.
                    if !hidden && (plot >= 150 || k % 2 == 0) {
                        Text(AnalyticsView.compact(top * k / 4))
                            .font(AppFont.main(11))
                            .foregroundStyle(Tokens.grey400)
                            .frame(width: axis - 4, alignment: .trailing)
                            .position(x: g.size.width - (axis - 4) / 2, y: y - 9)
                    }
                }
                .accessibilityHidden(true)
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        VStack(spacing: Space.s8) {
                            HStack(alignment: .bottom, spacing: gap) {
                                ForEach(bars.indices, id: \.self) { i in
                                    pair(bars[i], index: i, top: top, showOut: showOut, showIn: showIn)
                                        .frame(width: group)
                                        .id(i)
                                }
                            }
                            .frame(height: plot)
                            .animation(.snappy, value: top)
                            HStack(spacing: gap) {
                                ForEach(bars.indices, id: \.self) { i in
                                    Text(bars[i].label)
                                        .font(AppFont.main(14))
                                        .foregroundStyle(picked == i ? Tokens.text900 : Tokens.grey400)
                                        .lineLimit(1)
                                        .fixedSize()
                                        .frame(width: group)
                                }
                            }
                            .accessibilityHidden(true)
                        }
                        .frame(width: content, alignment: .leading)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDisabled(content <= room + 0.5)
                    .frame(width: room)
                    // Which pairs are in view (a sliver counts), so the scale fits what you see.
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                        let step = group + gap
                        let first = max(0, Int((x + gap) / step))
                        let last = min(bars.count - 1, Int((x + room - 1) / step))
                        guard first <= last, window != first...last else { return }
                        window = first...last
                    }
                    .onAppear { reveal(proxy) }
                    .onChange(of: bars.map(\.title)) { _, _ in window = nil; reveal(proxy) }
                }
                // Dashed average across the bars, labelled at the left ("avg 162K/day").
                let values = Self.dropFuture(bars.map { filter == .in ? $0.incoming : $0.out })
                let avg = values.isEmpty ? 0 : values.reduce(0, +) / values.count
                if avg > 0 && !hidden {
                    let y = plot - min(plot, (plot - 4) * CGFloat(avg) / CGFloat(max(top, 1)))
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: room, y: y))
                    }
                    .stroke(Tokens.text700.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .allowsHitTesting(false)
                    // The same white bubble as the tooltips on the charts below.
                    Tooltip(title: "Avg a \(unit)", value: AnalyticsView.compact(avg) + "đ")
                        .fixedSize()
                        .offset(x: 2, y: max(0, y - 58))
                        .allowsHitTesting(false)
                        .animation(.snappy, value: top)
                }
            }
        }
        .frame(height: plot + Space.s8 + labels)
        .noPageSwipe()
    }

    /// Waits a beat so the new bars are laid out, then brings the focused pair to the middle.
    private func reveal(_ proxy: ScrollViewProxy) {
        guard let focus, bars.indices.contains(focus) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.snappy) { proxy.scrollTo(focus, anchor: .center) }
        }
    }

    private func pair(_ b: AnalysisBar, index i: Int, top: Int, showOut: Bool, showIn: Bool) -> some View {
        // Capped at the chart's height: a tall bar off screen (the scale fits only what's in
        // view) must not stretch the row and push every bar out of sight.
        func h(_ v: Int) -> CGFloat { v == 0 ? 0 : min(plot, max(4, (plot - 4) * CGFloat(v) / CGFloat(max(top, 1)))) }
        let shape = UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
        return HStack(alignment: .bottom, spacing: 4) {
            if showOut {
                shape.fill(Tokens.brand900).frame(maxWidth: .infinity).frame(height: h(b.out))
            }
            if showIn {
                Hatch().clipShape(shape).frame(maxWidth: .infinity).frame(height: h(b.incoming))
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .opacity(picked == nil || picked == i ? 1 : 0.35)
        .contentShape(.rect)
        .onTapGesture { onPick(i) }
        .accessibilityElement()
        .accessibilityLabel(b.title)
        .accessibilityValue(hidden ? "Amounts hidden" : "Out \(Money.format(b.out)) dong, in \(Money.format(b.incoming)) dong")
        .accessibilityAddTraits(.isButton)
    }

    /// Days still to come (the empty tail) don't pull the average down.
    static func dropFuture(_ v: [Int]) -> [Int] {
        var v = v
        while let last = v.last, last == 0 { v.removeLast() }
        return v
    }

    /// A round top for the scale whose quarters read well: 2M → 500K, 1M, 1.5M, 2M.
    static func niceMax(_ v: Int) -> Int {
        guard v > 0 else { return 1_000_000 }
        var unit = 1
        while unit * 10 <= v { unit *= 10 }
        for step in [1, 2, 4, 5, 8, 10] where step * unit >= v { return step * unit }
        return 10 * unit
    }
}

/// Light green with darker green stripes — money in.
struct Hatch: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Tokens.brand100))
            var p = Path()
            var x = -size.height
            while x < size.width {
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            ctx.stroke(p, with: .color(Tokens.brand300), lineWidth: 2)
        }
    }
}

/// [All]  [− out | + in] on a light page — the same filter as Today's green card.
struct LightFlowFilter: View {
    @Binding var filter: FlowFilter
    var out: Int
    var incoming: Int
    var hidden: Bool
    @Namespace private var pill

    var body: some View {
        HStack(spacing: Space.s8) {
            chip(.all) { Text("All").font(AppFont.heading(16, .medium, relativeTo: .body)) }
                .frame(width: 51)
                .padding(Space.s4)
                .background(Tokens.bg4, in: .rect(cornerRadius: Corner.c14))
            HStack(spacing: 0) {
                chip(.out) { amount(out, sign: .minusCircle, tint: Color(hex: 0xE5562A)) }
                chip(.in) { amount(incoming, sign: .plusCircle, tint: Tokens.brand400) }
            }
            .padding(Space.s4)
            .background(Tokens.bg4, in: .rect(cornerRadius: Corner.c14))
        }
    }

    private func chip<Label: View>(_ f: FlowFilter, @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { filter = f }
        } label: {
            label()
                .foregroundStyle(Tokens.text900)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background {
                    if filter == f {
                        RoundedRectangle(cornerRadius: Corner.c12, style: .continuous)
                            .fill(Tokens.segmentOn)
                            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                            .matchedGeometryEffect(id: "flow", in: pill)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f == .all ? "All lines" : f == .out
            ? "Money out, \(hidden ? "hidden" : "\(Money.format(out)) dong")"
            : "Money in, \(hidden ? "hidden" : "\(Money.format(incoming)) dong")")
        .accessibilityAddTraits(filter == f ? .isSelected : [])
    }

    private func amount(_ v: Int, sign: Icon, tint: Color) -> some View {
        HStack(spacing: Space.s6) {
            AppIcon(sign, size: 18)
                .foregroundStyle(tint)
                .background(Circle().fill(.white).padding(4))
            Text(hidden ? "••••" : SpendCard.short(v))
                .font(AppFont.heading(16, .medium, relativeTo: .body))
                .monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("đ").font(AppFont.heading(14, .regular)).foregroundStyle(Tokens.grey400)
        }
        .padding(.horizontal, Space.s8)
    }
}

/// Out over in, stacked, for the pinned bar. Tap one to see only it; tap it again for all.
struct FlowColumn: View {
    @Binding var filter: FlowFilter
    var out: Int
    var incoming: Int
    var hidden: Bool
    @Namespace private var pill

    var body: some View {
        VStack(spacing: 2) {
            row(.out, out, sign: .minusCircle, tint: Color(hex: 0xE5562A))
            row(.in, incoming, sign: .plusCircle, tint: Tokens.brand400)
        }
        .padding(3)
        .background(Tokens.bg4, in: .rect(cornerRadius: Corner.c14))
    }

    private func row(_ f: FlowFilter, _ v: Int, sign: Icon, tint: Color) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { filter = filter == f ? .all : f }
        } label: {
            HStack(spacing: Space.s6) {
                AppIcon(sign, size: 16)
                    .foregroundStyle(tint)
                    .background(Circle().fill(.white).padding(3))
                Text(hidden ? "••••" : SpendCard.short(v))
                    .font(AppFont.heading(14, .medium, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.text900)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text("đ").font(AppFont.heading(12, .regular)).foregroundStyle(Tokens.grey400)
            }
            .padding(.horizontal, Space.s8)
            .frame(minHeight: 30)
            .background {
                if filter == f {
                    RoundedRectangle(cornerRadius: Corner.c12, style: .continuous)
                        .fill(Tokens.segmentOn)
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "flow", in: pill)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(f == .out
            ? "Money out, \(hidden ? "hidden" : "\(Money.format(out)) dong")"
            : "Money in, \(hidden ? "hidden" : "\(Money.format(incoming)) dong")")
        .accessibilityHint(filter == f ? "Shows all lines again" : "Shows only these lines")
        .accessibilityAddTraits(filter == f ? .isSelected : [])
    }
}

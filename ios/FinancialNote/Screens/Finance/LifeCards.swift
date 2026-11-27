import SwiftUI

// "Invested in people" on Overview: what went to your family (pink) and into yourself (blue).
// Each card opens a short reveal line first, then the page.

/// The two tints. Family leans pink, yourself leans blue.
enum LifeTint {
    case family, yourself
    /// Belongings by what they are: things that hold value (amber), everyday things (teal),
    /// collections (slate blue).
    case lasting, everyday, collection

    var accent: Color {
        switch self {
        case .family: Color(light: 0xDD2590, dark: 0xF670C7)
        case .yourself: Color(light: 0x1570EF, dark: 0x53B1FD)
        case .lasting: Color(light: 0xB54708, dark: 0xFDB022)
        case .everyday: Color(light: 0x0E9384, dark: 0x2ED3B7)
        case .collection: Color(light: 0x4E5BA6, dark: 0x9EA5D1)
        }
    }

    var gradient: LinearGradient {
        let c: [Color] = switch self {
        case .family: [Color(light: 0xFDF2FA, dark: 0x3D0F2E), Color(light: 0xFCE7F6, dark: 0x1E0A18)]
        case .yourself: [Color(light: 0xEFF8FF, dark: 0x0B2545), Color(light: 0xD1E9FF, dark: 0x081526)]
        case .lasting: [Color(light: 0xFFFAEB, dark: 0x3A2608), Color(light: 0xFEF0C7, dark: 0x1F1404)]
        case .everyday: [Color(light: 0xF0FDF9, dark: 0x0A3029), Color(light: 0xCCFBEF, dark: 0x061A16)]
        case .collection: [Color(light: 0xF8F9FC, dark: 0x1B1F36), Color(light: 0xEAECF5, dark: 0x10121F)]
        }
        return LinearGradient(colors: c, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var symbol: String {
        switch self {
        case .family: "heart.fill"
        case .yourself: "figure.run"
        case .lasting: "house.fill"
        case .everyday: "iphone.gen3"
        case .collection: "square.stack.3d.up.fill"
        }
    }

    /// The line on the reveal page before the details show.
    var reveal: String {
        switch self {
        case .family: "The things you've given the people you love, that you may never have noticed…"
        case .yourself: "The things you've put into yourself — learning, moving, staying well…"
        case .lasting, .everyday, .collection: ""
        }
    }
}

/// A half-width card: icon, who it's for, the total, a short line under it.
struct LifeCard: View {
    var tint: LifeTint
    var title: String
    var amount: Int
    var sub: String
    var hidden: Bool
    /// Shown instead of the amount, e.g. "Nothing yet" on an empty card.
    var amountText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            HStack {
                Image(systemName: tint.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(tint.accent, in: .circle)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.grey400)
            }
            Spacer(minLength: 0)
            Text(title).font(AppFont.table(13, .medium)).foregroundStyle(tint.accent)
            if let amountText {
                Text(amountText).font(AppFont.heading(20, .medium)).foregroundStyle(Tokens.grey400)
                    .frame(minHeight: 34, alignment: .bottomLeading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(hidden ? "•••" : AnalyticsView.compact(amount))
                        .font(AppFont.amount(28)).foregroundStyle(Tokens.text900).monospacedDigit()
                    Text("đ").font(AppFont.currency(for: 28)).foregroundStyle(Tokens.grey400)
                }
                .lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(sub).font(AppFont.table(12)).foregroundStyle(Tokens.text700).lineLimit(2)
        }
        .padding(Space.s16)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .background(tint.gradient, in: .rect(cornerRadius: Corner.c20))
        .overlay(RoundedRectangle(cornerRadius: Corner.c20).strokeBorder(tint.accent.opacity(0.25), lineWidth: 0.5))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens what it went to")
    }
}

/// A LifeCard laid out as one wide row, for cards stacked down the page: the tile, the title over
/// a grey line, the amount on the right.
struct LifeRowCard: View {
    var tint: LifeTint
    var title: String
    var amount: Int
    var sub: String
    var hidden: Bool
    var amountText: String? = nil

    var body: some View {
        HStack(spacing: Space.s12) {
            Image(systemName: tint.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(tint.accent, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.table(15, .semibold)).foregroundStyle(tint.accent).lineLimit(1)
                Text(sub).font(AppFont.table(12)).foregroundStyle(Tokens.text700).lineLimit(1)
            }
            Spacer(minLength: Space.s8)
            Group {
                if let amountText {
                    Text(amountText).font(AppFont.table(13, .medium)).foregroundStyle(Tokens.grey400)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(hidden ? "•••" : AnalyticsView.compact(amount))
                            .font(AppFont.heading(18, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                        Text("đ").font(AppFont.currency(for: 18)).foregroundStyle(Tokens.grey400)
                    }
                }
            }
            .fixedSize()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.grey400)
        }
        .padding(.horizontal, Space.s16)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(tint.gradient, in: .rect(cornerRadius: Corner.c20))
        .overlay(RoundedRectangle(cornerRadius: Corner.c20).strokeBorder(tint.accent.opacity(0.25), lineWidth: 0.5))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens what's in it")
    }
}

/// Shows one quiet line for a moment, then fades into the page.
struct RevealPage<Content: View>: View {
    var tint: LifeTint
    @ViewBuilder var content: Content
    @State private var shown = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if shown {
                content.transition(.opacity)
            } else {
                VStack(spacing: Space.s24) {
                    Image(systemName: tint.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(tint.accent, in: .circle)
                        .background(tint.accent.opacity(0.25), in: .circle.scale(pulse ? 1.6 : 1.1))
                    Text(tint.reveal)
                        .font(AppFont.heading(22, .medium))
                        .foregroundStyle(Tokens.text900)
                        .multilineTextAlignment(.center)
                    ProgressView().tint(tint.accent)
                }
                .padding(.horizontal, Space.s32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tint.gradient)
                .transition(.opacity)
            }
        }
        .background(Tokens.canvas)
        .task {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
            }
            try? await Task.sleep(for: .seconds(reduceMotion ? 1 : 2.4))
            withAnimation(.easeInOut(duration: 0.5)) { shown = true }
        }
    }
}

// MARK: - Yourself

/// What you spent on yourself, found in what you already wrote down: learning, moving, health.
enum SelfMath {
    enum Group: String, CaseIterable {
        case learning = "Learning"
        case fitness = "Moving"
        case health = "Health"

        var symbol: String {
            switch self {
            case .learning: "book.fill"
            case .fitness: "figure.run"
            case .health: "cross.case.fill"
            }
        }

        var color: Color {
            switch self {
            case .learning: Color(hex: 0x2E90FA)
            case .fitness: Color(hex: 0x0BA5EC)
            case .health: Color(hex: 0x6172F3)
            }
        }

        var keywords: [String] {
            switch self {
            case .learning: ["khoa hoc", "course", "sach", "book", "ielts", "toeic", "workshop", "tai lieu", "udemy", "lop hoc", "class", "hoc phi"]
            case .fitness: ["gym", "boi", "yoga", "cau long", "chay bo", "swim", "tennis", "bong da", "pilates"]
            case .health: ["kham", "thuoc", "vitamin", "nha khoa", "nieng rang", "tram rang"]
            }
        }
    }

    struct Line: Identifiable {
        let id: String
        let group: Group
        let title: String
        let date: String
        let amount: Int
    }

    static func group(for title: String) -> Group? {
        let t = title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .replacingOccurrences(of: "đ", with: "d")
        // Parking at the gym is a ticket, not the workout.
        if t.contains("gui xe") { return nil }
        return Group.allCases.first { g in g.keywords.contains { t.contains($0) } }
    }

    /// Money out that matches a group, plus installments paid on study bills (a course).
    static func lines(entries: [Entry], bills: [Bill]) -> [Line] {
        let spent = entries.filter { $0.flow == .out }.compactMap { e in
            group(for: e.title).map { Line(id: e.id, group: $0, title: e.title, date: e.date, amount: e.amount) }
        }
        let study = bills.filter { $0.icon == .student }.flatMap { b in
            b.paid.map { month, rec in
                Line(id: "\(b.id)-\(month)", group: .learning, title: b.name, date: Day.iso(rec.at), amount: rec.amount)
            }
        }
        return (spent + study).sorted { $0.date > $1.date }
    }
}

struct YourselfView: View {
    var entries: [Entry]
    var bills: [Bill]
    @Environment(AppState.self) private var app
    @State private var showAll = false

    var body: some View {
        let lines = SelfMath.lines(entries: entries, bills: bills)
        let total = lines.reduce(0) { $0 + $1.amount }
        let groups = SelfMath.Group.allCases.map { g in (g, lines.filter { $0.group == g }) }.filter { !$0.1.isEmpty }
        let hidden = app.assetsHidden
        ScrollView {
            if lines.isEmpty {
                ContentUnavailableView("Nothing here yet", systemImage: "figure.run",
                                       description: Text("Courses, books, the gym, a check-up — what you spend on yourself shows up here."))
                    .padding(.top, Space.s32)
            } else {
                VStack(alignment: .leading, spacing: Space.s16) {
                    // The total, in the blue card.
                    VStack(alignment: .leading, spacing: Space.s8) {
                        Text("Invested in yourself").font(AppFont.main(16, .medium)).foregroundStyle(LifeTint.yourself.accent)
                        HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                            Text(hidden ? "••••••" : Money.format(total)).font(AppFont.amount(36)).monospacedDigit()
                                .foregroundStyle(Tokens.text900).lineLimit(1).minimumScaleFactor(0.7)
                            Text("đ").font(AppFont.currency(for: 36)).foregroundStyle(Tokens.grey400)
                        }
                        Text("\(lines.count) things since \(FinanceText.monthLabel(String(lines.last!.date.prefix(7))))")
                            .font(AppFont.main(14)).foregroundStyle(Tokens.text700)
                    }
                    .padding(Space.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifeTint.yourself.gradient, in: .rect(cornerRadius: Corner.c20))
                    .overlay(RoundedRectangle(cornerRadius: Corner.c20).strokeBorder(LifeTint.yourself.accent.opacity(0.25), lineWidth: 0.5))

                    Text("Growing yourself isn't only spending. \(Text("It's what you carry into everything else.").bold())")
                        .font(AppFont.main(16)).foregroundStyle(Tokens.text900)
                        .padding(.horizontal, Space.s4)

                    // By group.
                    VStack(spacing: 0) {
                        ForEach(Array(groups.enumerated()), id: \.element.0) { i, g in
                            if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 52) }
                            HStack(spacing: Space.s12) {
                                Image(systemName: g.0.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                                    .frame(width: 40, height: 40).background(g.0.color, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(g.0.rawValue).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900)
                                    Text(Self.examples(g.1)).font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                                }
                                Spacer(minLength: Space.s4)
                                Text(hidden ? "•••" : Money.format(g.1.reduce(0) { $0 + $1.amount }) + "đ")
                                    .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                            }
                            .padding(.vertical, Space.s12)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.horizontal, Space.s16)
                    .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))

                    FinanceSectionTitle(title: "History") { EmptyView() }
                    VStack(spacing: 0) {
                        ForEach(Array((showAll ? lines : Array(lines.prefix(8))).enumerated()), id: \.element.id) { i, l in
                            if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 52) }
                            HStack(spacing: Space.s12) {
                                Image(systemName: l.group.symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                    .frame(width: 40, height: 40).background(l.group.color, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(l.title).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                                    Text(l.group.rawValue + " · " + HoldingsTable.shortDay(l.date))
                                        .font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                                }
                                Spacer(minLength: Space.s4)
                                Text(hidden ? "•••" : Money.format(l.amount) + "đ")
                                    .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                            }
                            .padding(.vertical, Space.s12)
                            .accessibilityElement(children: .combine)
                        }
                        if lines.count > 8 {
                            Button(showAll ? "Show less" : "Show all \(lines.count)") { animate { showAll.toggle() } }
                                .font(AppFont.main(14, .medium)).foregroundStyle(LifeTint.yourself.accent)
                                .frame(minHeight: 44)
                        }
                    }
                    .padding(.horizontal, Space.s16)
                    .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                }
                .padding(.horizontal, Space.s20)
                .padding(.bottom, 96)
            }
        }
        .background(Tokens.canvas)
        .navigationTitle("Yourself")
        .toolbarTitleDisplayMode(.inline)
    }

    /// "Gym tháng, Bơi, Cầu lông"
    private static func examples(_ lines: [SelfMath.Line]) -> String {
        var seen: [String] = []
        for l in lines where !seen.contains(l.title) {
            seen.append(l.title)
            if seen.count == 3 { break }
        }
        return seen.joined(separator: ", ")
    }
}

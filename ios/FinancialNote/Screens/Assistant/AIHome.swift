import SwiftUI

/// The AI tab before a conversation starts (layout from the reference the owner sent):
/// Shortcuts as two big cards, Suggestions as a scrolling row of questions, and Recents.
/// Every answer is worked out on the phone from what is saved.
struct AIHome: View {
    var entries: [Entry]
    var hidden: Bool
    var onAsk: (LocalAnswers.Ask) -> Void
    var onOpen: (ChatHistoryView.Note) -> Void
    var onTalk: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s24) {
            section("Shortcuts") {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s12) {
                        ShortcutCard(title: "Talk With AI", subtitle: "Say what you spent",
                                     symbol: "waveform", colors: [Tokens.brand300, Tokens.brand100], action: onTalk)
                        ShortcutCard(title: LocalAnswers.Ask.week.title, subtitle: nil,
                                     symbol: "calendar", colors: [Color(hex: 0xBDE7FA), Tokens.bg4]) { onAsk(.week) }
                        ShortcutCard(title: LocalAnswers.Ask.month.title, subtitle: nil,
                                     symbol: "chart.bar.fill", colors: [Color(hex: 0xA4DA7C), Color(hex: 0xF8C9C0)]) { onAsk(.month) }
                    }
                    .padding(.horizontal, Space.s20)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -Space.s20)
            }

            section("Suggestions") {
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        ForEach([LocalAnswers.Ask.today, .bills, .lastMonth, .received], id: \.self) { q in
                            Button { onAsk(q) } label: {
                                Label(q.question, systemImage: Self.symbol(q))
                                    .font(AppFont.main(14, .medium))
                                    .foregroundStyle(Tokens.text900)
                                    .padding(.horizontal, Space.s16)
                                    .frame(minHeight: 48)
                                    .background(Tokens.bgWhite, in: .capsule)
                                    .overlay(Capsule().strokeBorder(Tokens.bd1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Space.s20)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -Space.s20)
            }

            let recents = Array(ChatHistoryView.notes(entries).prefix(4))
            section("Recents") {
                if recents.isEmpty {
                    Text("Notes you save show up here.")
                        .font(AppFont.main(14))
                        .foregroundStyle(Tokens.grey400)
                }
                VStack(spacing: 0) {
                    ForEach(recents) { note in
                        Button { onOpen(note) } label: {
                            HStack(spacing: Space.s16) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Tokens.text700)
                                    .frame(width: 48, height: 48)
                                    .background(Tokens.bg4, in: .circle)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.source)
                                        .font(AppFont.main(16))
                                        .foregroundStyle(Tokens.text900)
                                        .lineLimit(1)
                                    Text(Day.dayHeading(note.date, today: Day.today()))
                                        .font(AppFont.main(12))
                                        .foregroundStyle(Tokens.text700)
                                }
                                Spacer(minLength: Space.s8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Tokens.grey300)
                            }
                            .padding(.vertical, Space.s8)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(.top, Space.s8)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text(title)
                .font(AppFont.section)
                .foregroundStyle(Tokens.text900)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    static func symbol(_ q: LocalAnswers.Ask) -> String {
        switch q {
        case .today: "sun.max"
        case .week: "calendar"
        case .month, .lastMonth: "chart.bar"
        case .bills: "doc.text"
        case .received: "arrow.down.circle"
        }
    }
}

/// A big shortcut card: soft colour on top, a round icon over the seam, the title below.
private struct ShortcutCard: View {
    var title: String
    var subtitle: String?
    var symbol: String
    var colors: [Color]
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 76)
                    .overlay(alignment: .bottomLeading) {
                        Image(systemName: symbol)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Tokens.brand700)
                            .frame(width: 56, height: 56)
                            .background(Tokens.bgWhite, in: .circle)
                            .offset(x: Space.s16, y: 28)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.main(16, .semibold))
                        .foregroundStyle(Tokens.text900)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2, reservesSpace: true)
                    if let subtitle {
                        Text(subtitle).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                }
                .padding(.horizontal, Space.s16)
                .padding(.top, 40)
                .padding(.bottom, Space.s16)
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(width: 176, height: 204)
            .background(Tokens.bg4.opacity(0.6))
            .clipShape(.rect(cornerRadius: 28))
            .contentShape(.rect(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// An answer: the summary sentence, then a white card of rows.
struct ReportCard: View {
    var report: LocalAnswers.Report
    var hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(hidden ? report.summary.replacingOccurrences(of: #"[\d,]+ đ"#, with: "••• đ", options: .regularExpression) : report.summary)
                .font(AppFont.main(14))
                .foregroundStyle(Tokens.text700)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !report.rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(report.rows.enumerated()), id: \.offset) { i, row in
                        if i > 0 { Divider().overlay(Tokens.bd0) }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label).font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                                if let d = row.detail {
                                    Text(d).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                                }
                            }
                            Spacer()
                            AmountText(value: row.amount, hidden: hidden)
                        }
                        .padding(.vertical, Space.s12)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd1))
            }
            Text("Worked out on your phone from what you saved.")
                .font(AppFont.main(11))
                .foregroundStyle(Tokens.grey400)
        }
    }
}

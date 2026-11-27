import SwiftData
import SwiftUI

struct PersonID: Identifiable { var id: String }

/// One person's loan: what's owed now, then every payment in and out, newest first.
struct LoanPersonSheet: View {
    var who: String
    var loans: [FamilyLoan]
    var today: String
    var hidden: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var adding = false

    var body: some View {
        let p = LoanMath.person(who, loans, today: today)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Space.s8) {
                        Text("Owed today").font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
                        AmountText(value: p.owed, size: 32, hidden: hidden)
                        HStack(spacing: Space.s12) {
                            stat("Borrowed", p.principal)
                            stat("Interest so far", p.interest)
                            stat("Interest paid", p.interestPaid)
                        }
                        Text(String(format: "%g%% a year, counted day by day.", p.rate))
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                    .padding(.vertical, Space.s4)
                }
                .listRowBackground(Tokens.card)
                Section("History") {
                    ForEach(loans.sorted { $0.date > $1.date }) { l in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(l.title).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
                                Text("\(l.kind.label) · \(FinanceText.dayLabel(l.date))")
                                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            }
                            Spacer()
                            AmountText(value: l.amount, sign: l.kind == .received ? "+" : "−", hidden: hidden,
                                       color: l.kind == .received ? Tokens.text900 : Tokens.brand600)
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                context.delete(l)
                                try? context.save()
                            }
                        }
                    }
                }
                .listRowBackground(Tokens.card)
            }
            .appListSurface()
            .sheetHeader(who, leading: .icon("Add", systemImage: "plus") { adding = true })
            .sheet(isPresented: $adding) { AddLoanSheet(people: [who], who: who, today: today).sheetSurface() }
        }
    }

    private func stat(_ label: String, _ v: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(hidden ? "•••" : AnalyticsView.compact(v)).font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900)
            Text(label).font(AppFont.main(11)).foregroundStyle(Tokens.grey400)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Add money received from family, a payment back, or interest paid: who, what, how much,
/// the day and the yearly rate (6% unless changed).
struct AddLoanSheet: View {
    var people: [String]
    @State var who: String = ""
    var today: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: LoanMove = .received
    @State private var value: Int?
    @State private var date = Date()
    @State private var rate = 6.0
    @State private var note = ""

    init(people: [String], who: String = "", today: String) {
        self.people = people
        _who = State(initialValue: who)
        self.today = today
        _date = State(initialValue: Day.date(today))
    }

    var body: some View {
        let names = Array(Set(people + ["Mom", "Dad", "Grand"])).sorted()
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s12) {
                Picker("What", selection: $kind) {
                    ForEach(LoanMove.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                ScrollView(.horizontal) {
                    HStack(spacing: Space.s8) {
                        ForEach(names, id: \.self) { n in
                            Button { who = n } label: {
                                Text(n).font(AppFont.main(14, .medium)).padding(.horizontal, Space.s12).frame(height: 34)
                            }
                            .buttonStyle(.glass)
                            .tint(who == n ? Tokens.brand600 : nil)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                TextField("Who (Mom, Grand…)", text: $who)
                    .font(AppFont.main(16))
                    .textInputAutocapitalization(.words)
                TextField("Note (optional)", text: $note).font(AppFont.main(14))
                HStack(alignment: .firstTextBaseline, spacing: Space.s4) {
                    Text(Money.format(value ?? 0))
                        .font(AppFont.heading(36, .medium))
                        .foregroundStyle(value == nil ? Tokens.grey300 : Tokens.text900)
                        .monospacedDigit().contentTransition(.numericText())
                    Text("đ").font(AppFont.heading(24)).foregroundStyle(Tokens.grey400)
                }
                HStack {
                    DatePicker("Day", selection: $date, in: ...Day.date(today), displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                    if kind == .received {
                        Stepper(String(format: "%g%% a year", rate), value: $rate, in: 0...30, step: 0.5)
                            .font(AppFont.main(14, .medium))
                            .fixedSize()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
            .safeAreaInset(edge: .bottom, spacing: 0) { AmountPad(value: $value) }
            .sheetHeader("Family loan", trailing: .save(enabled: (value ?? 0) > 0 && !who.trimmingCharacters(in: .whitespaces).isEmpty, action: save))
        }
        .presentationDetents([.large])
    }

    private func save() {
        let name = who.trimmingCharacters(in: .whitespaces)
        let title = note.trimmingCharacters(in: .whitespaces).isEmpty
            ? (kind == .received ? "\(name) sent" : kind == .paidBack ? "Paid back \(name)" : "Interest for \(name)")
            : note
        context.insert(FamilyLoan(who: name, title: title, kind: kind, amount: value ?? 0, date: Day.iso(date), rate: rate))
        try? context.save()
        dismiss()
    }
}

import SwiftData
import SwiftUI

/// What kind of line this is (Figma "Kind of"): spending, money in, a bill, or a bill that
/// comes back every month (also added to Due).
enum EntryKind: String, CaseIterable, Identifiable {
    case expense = "Expense", receive = "Receive", bill = "Bill", monthly = "Monthly bill"
    var id: String { rawValue }
}

/// Entry sheet — Figma Quick-note (1072:18481): Amount on top, Name with its category, then
/// Date, Kind of, Currency, From; Category tags with Suggest tag; Comment; delete in the corner.
/// Opened on a saved line it edits it; opened with `nil` (Template) it starts blank and has a
/// composer at the bottom that fills the form from one typed line. The green check saves.
struct EntrySheet: View {
    var entry: Entry?
    /// A new line already filled in (from a scanned QR code).
    var prefill: EntryEdit? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @Query private var assets: [Asset]

    @State private var d = EntryEdit()
    @State private var start = EntryEdit()
    @State private var loaded = false
    @State private var confirmDelete = false
    @State private var pickingTags = false
    @State private var pickingDate = false
    @State private var dateSet = true
    @State private var commenting = false
    @State private var line = ""
    @State private var lineHint: String?
    @FocusState private var focus: Field?

    enum Field { case amount, name, comment, line }

    private var isNew: Bool { entry == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s12) {
                    amountHeader
                    nameCard
                    detailsCard
                    tagsCard
                    commentBlock
                    if let source = entry?.source, !source.isEmpty {
                        Text("From your note: “\(source)”")
                            .font(AppFont.main(12))
                            .foregroundStyle(Tokens.grey400)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Space.s4)
                    }
                }
                .padding(.horizontal, Space.s16)
                .padding(.bottom, Space.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            // Grey sheet so the white cards stand out, as in Figma (bg-3 #F3F4F6).
            .background(Tokens.bg3)
            .safeAreaInset(edge: .bottom) { isNew ? AnyView(composer) : AnyView(footer) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(Tokens.action)
                        .disabled(!d.isValid || (!isNew && d == start))
                }
            }
            .sheet(isPresented: $pickingTags) {
                TagPickerSheet(selected: $d.tags, suggestion: Tags.suggest(title: d.title, category: d.category))
            }
            .sheet(isPresented: $pickingDate) { EntryDateSheet(date: $d.date) { dateSet = true } }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let entry {
                d = EntryEdit(entry)
            } else if let prefill {
                d = prefill
                dateSet = true
                focus = prefill.amount == nil ? .amount : nil
            } else {
                d = EntryEdit()
                d.date = app.day
                dateSet = false
                focus = .line
            }
            start = d
        }
    }

    // MARK: - Parts

    private var amountHeader: some View {
        VStack(spacing: Space.s4) {
            Text("Amount")
                .font(AppFont.body(.medium))
                .foregroundStyle(Tokens.grey400)
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                TextField("0", text: Binding(
                    get: { d.amount.map(Money.format) ?? "" },
                    set: { d.amount = Int($0.filter(\.isNumber)) }))
                    .font(AppFont.amount(44))
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .focused($focus, equals: .amount)
                    .accessibilityLabel("Amount in dong")
                Text("đ")
                    .font(AppFont.currency(for: 44))
                    .foregroundStyle(Tokens.grey400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }

    private var nameCard: some View {
        HStack(spacing: Space.s12) {
            TextField("Name", text: $d.title)
                .font(AppFont.heading(18, .regular))
                .focused($focus, equals: .name)
            Menu {
                Picker("Category", selection: categoryBinding) {
                    ForEach(Category.allCases, id: \.self) { c in
                        Label(c.rawValue, systemImage: c.symbol).tag(c)
                    }
                }
            } label: {
                Image(systemName: d.category.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.category(d.category))
                    .frame(width: 40, height: 40)
                    .background(Tokens.category(d.category).opacity(0.14), in: .circle)
            }
            .accessibilityLabel("Category, \(d.category.rawValue)")
        }
        .padding(.leading, Space.s16)
        .padding(.trailing, Space.s12)
        .padding(.vertical, Space.s8)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            row("Date") {
                Button { pickingDate = true } label: {
                    HStack(spacing: Space.s6) {
                        if dateSet {
                            chip(Self.dateText(d.date), systemImage: "calendar", trailing: nil)
                        } else {
                            Text("Select Date").font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.grey400)
                    }
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Date, \(dateSet ? Day.long(d.date) : "not set")")
            }
            Divider().overlay(Tokens.bd0)
            row("Kind of") {
                Menu {
                    Picker("Kind of", selection: kindBinding) {
                        ForEach(kinds) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    valueLabel(d.kind.rawValue, trailing: "chevron.up.chevron.down")
                }
                .accessibilityLabel("Kind of, \(d.kind.rawValue)")
            }
            Divider().overlay(Tokens.bd0)
            row("Currency") {
                Menu {
                    Picker("Currency", selection: .constant("VND")) { Text("(đ) Vietnam Đồng").tag("VND") }
                } label: {
                    valueLabel("(đ) Vietnam Đồng", trailing: "chevron.up.chevron.down")
                }
                .accessibilityLabel("Currency, Vietnam Đồng")
            }
            Divider().overlay(Tokens.bd0)
            row("From") {
                Menu {
                    Picker("From", selection: $d.paidFrom) {
                        Text("Not set").tag(String?.none)
                        ForEach(paidFromOptions, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                } label: {
                    HStack(spacing: Space.s6) {
                        if let p = d.paidFrom {
                            Image(systemName: Self.paidSymbol(p)).foregroundStyle(Tokens.secondary500)
                        }
                        valueLabel(d.paidFrom ?? "Not set", trailing: "chevron.up.chevron.down", muted: d.paidFrom == nil)
                    }
                }
                .accessibilityLabel("From, \(d.paidFrom ?? "not set")")
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
    }

    private var tagsCard: some View {
        let suggestion = Tags.suggest(title: d.title, category: d.category)
        return VStack(alignment: .leading, spacing: Space.s12) {
            HStack {
                Text("Category").font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                Spacer()
                if let suggestion, !d.tags.contains(suggestion) {
                    Button {
                        animate { d.tags.append(suggestion) }
                    } label: {
                        Label("Suggest tag", systemImage: "sparkles")
                            .font(AppFont.main(12, .medium))
                            .foregroundStyle(Tokens.text900)
                            .padding(.horizontal, Space.s12)
                            .padding(.vertical, Space.s6)
                            .background(Tokens.bgWhite, in: .capsule)
                            .overlay(Capsule().strokeBorder(Tokens.bd1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Adds “\(suggestion)”")
                }
            }
            if d.tags.isEmpty {
                Button { pickingTags = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.text700)
                        .frame(width: 32, height: 32)
                        .background(Tokens.bg4, in: .circle)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(RoundedRectangle(cornerRadius: Corner.c14).strokeBorder(Tokens.bd2, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add tags")
            } else {
                FlowLayout {
                    ForEach(d.tags, id: \.self) { t in
                        TagChip(name: t, selected: true) { animate { d.tags.removeAll { $0 == t } } }
                    }
                    Button { pickingTags = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Tokens.text700)
                            .frame(width: 34, height: 34)
                            .background(Tokens.bg4, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tags")
                }
            }
        }
        .padding(Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
    }

    @ViewBuilder
    private var commentBlock: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text("COMMENT")
                .font(AppFont.main(12, .semibold, relativeTo: .caption))
                .tracking(0.4)
                .foregroundStyle(Tokens.grey400)
                .padding(.leading, Space.s4)
                .padding(.top, Space.s8)
            if commenting || !d.comment.isEmpty {
                TextField("Add comment", text: $d.comment, axis: .vertical)
                    .font(AppFont.main(14))
                    .lineLimit(3...6)
                    .focused($focus, equals: .comment)
                    .padding(Space.s16)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
            } else {
                Button {
                    commenting = true
                    focus = .comment
                } label: {
                    Label("Add comment", systemImage: "plus")
                        .font(AppFont.body(.medium))
                        .foregroundStyle(Tokens.text700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.s16)
                        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Saved lines: the bin, with "Are you sure…" next to it.
    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color(light: 0xD92D20, dark: 0xF97066))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Delete")
            .confirmationDialog("Are you sure you want to delete this?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Yes, delete", role: .destructive) {
                    if let entry {
                        context.delete(entry)
                        try? context.save()
                    }
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(.horizontal, Space.s16)
        .padding(.bottom, Space.s8)
    }

    /// Template: type one line ("cơm tấm 35k · cash") and the form fills itself.
    private var composer: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            if let lineHint {
                Text(lineHint).font(AppFont.main(12)).foregroundStyle(Tokens.grey400).padding(.horizontal, Space.s4)
            }
            HStack(alignment: .bottom, spacing: Space.s12) {
                TextField("e.g. coffee 24k, breakfast 35k…", text: $line, axis: .vertical)
                    .font(AppFont.main(16))
                    .lineLimit(1...3)
                    .focused($focus, equals: .line)
                    .submitLabel(.done)
                    .accessibilityLabel("Fill from a line")
                    .padding(.vertical, Space.s12)
                    .onChange(of: line) { _, new in
                        if new.hasSuffix("\n") {
                            line = String(new.dropLast())
                            fill()
                        }
                    }
                SendButton(enabled: !line.trimmingCharacters(in: .whitespaces).isEmpty, action: fill)
                    .accessibilityLabel("Fill the form")
            }
            .padding(.leading, Space.s20)
            .padding(.trailing, Space.s12)
            .padding(.vertical, Space.s8)
            .composerGlass()
        }
        .padding(.horizontal, Space.s12)
        .padding(.bottom, Space.s8)
    }

    // MARK: - Helpers

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(AppFont.body(.medium)).foregroundStyle(Color(light: 0x202939, dark: 0xE3E8EF))
            Spacer()
            content()
        }
        .frame(minHeight: 52)
    }

    private func chip(_ text: String, systemImage: String?, trailing: String?) -> some View {
        HStack(spacing: Space.s6) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(Tokens.text700) }
            Text(text).foregroundStyle(Tokens.text900)
            if let trailing {
                Image(systemName: trailing).font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.grey400)
            }
        }
        .font(AppFont.main(14, .medium))
        .padding(.horizontal, Space.s12)
        .padding(.vertical, Space.s8)
        .background(Tokens.bg4, in: .capsule)
    }

    private func valueLabel(_ text: String, trailing: String, muted: Bool = false) -> some View {
        HStack(spacing: Space.s6) {
            Text(text).foregroundStyle(muted ? Tokens.grey400 : Tokens.text900)
            Image(systemName: trailing).font(.system(size: 10, weight: .semibold)).foregroundStyle(Tokens.grey400)
        }
        .font(AppFont.main(14, .medium))
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    /// "15 Oct 2026"
    static func dateText(_ iso: String) -> String {
        let (y, m, dd) = Day.parts(iso)
        return "\(dd) \(Day.monthsShort[m - 1]) \(y)"
    }

    /// A monthly bill can only be started from a new line.
    private var kinds: [EntryKind] { isNew ? EntryKind.allCases : [.expense, .receive, .bill] }

    /// Cash, card or transfer, plus the user's own accounts written in Finance.
    private var paidFromOptions: [String] {
        var out = ["Cash", "Card", "Transfer"]
        for a in assets where (a.kind == .available || a.kind == .aside) && !out.contains(a.name) { out.append(a.name) }
        if let current = d.paidFrom, !out.contains(current) { out.append(current) }
        return out
    }

    static func paidSymbol(_ name: String) -> String {
        switch name {
        case "Cash": "banknote"
        case "Card": "creditcard"
        case "Transfer": "arrow.left.arrow.right"
        default: "building.columns"
        }
    }

    private var kindBinding: Binding<EntryKind> {
        Binding(get: { d.kind }, set: { d.setKind($0) })
    }

    private var categoryBinding: Binding<Category> {
        Binding(get: { d.category }, set: { c in
            d.category = c
            if c == .received { d.setKind(.receive) } else if d.kind == .receive { d.setKind(.expense) }
            if c == .bills && d.kind == .expense { d.kind = .bill }
        })
    }

    private func fill() {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let drafts = NoteParser.parse(text, day: d.date)
        guard let first = drafts.first else { return }
        animate {
            d.title = first.title
            if let a = first.amount { d.amount = a }
            d.category = first.category
            d.setKind(first.flow == .in ? .receive : first.category == .bills ? .bill : .expense)
            d.date = first.date
            dateSet = true
            if let p = first.paidFrom { d.paidFrom = p }
            if d.tags.isEmpty, let t = Tags.suggest(title: first.title, category: first.category) { d.tags = [t] }
            d.source = text
        }
        lineHint = drafts.count > 1
            ? "Filled from the first line. For several lines at once, use Talk With AI."
            : first.amount == nil ? "No amount in that line — type it above." : nil
        line = ""
        focus = nil
    }

    private func save() {
        if let entry {
            d.apply(to: entry)
        } else {
            let e = Entry(date: d.date, title: "", amount: 0, flow: .out, category: .other,
                          noteId: UUID().uuidString, source: d.source)
            d.apply(to: e)
            context.insert(e)
            if d.kind == .monthly {
                // Also remember it in Due as a monthly bill, already paid for this month.
                let bill = Bill(kind: .recurring, name: e.title, icon: BillMath.guessIcon(e.title, kind: .recurring),
                                amount: e.amount, start: e.date, payWith: e.paidFrom,
                                paid: [Month.of(e.date): PaidRecord(amount: e.amount, at: .now, entryId: e.id)])
                context.insert(bill)
                e.billId = bill.id
                e.noteId = "bill-\(bill.id)-\(Month.of(e.date))"
            }
        }
        try? context.save()
        dismiss()
    }
}

/// The date for one line (Figma 1085:24326): X, title, ✓ over the system calendar.
struct EntryDateSheet: View {
    @Binding var date: String
    var onPick: () -> Void
    @State private var picked = Date.now
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $picked, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Tokens.brand500)
                .padding(.horizontal)
                .navigationTitle("Date")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", systemImage: "checkmark") {
                            date = Day.iso(picked)
                            onPick()
                            dismiss()
                        }
                        .tint(Tokens.action)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear { picked = Day.date(date) }
    }
}

/// Everything the entry sheet can change, compared with the saved entry to enable Save.
struct EntryEdit: Equatable {
    var title = ""
    var amount: Int?
    var flow: Flow = .out
    var category: Category = .other
    var kind: EntryKind = .expense
    var date = Day.today()
    var paidFrom: String?
    var tags: [String] = []
    var comment = ""
    /// The line typed into Template, kept as the entry's source.
    var source = ""

    init() {}

    init(_ e: Entry) {
        title = e.title
        amount = e.amount
        flow = e.flow
        category = e.category
        kind = e.flow == .in ? .receive : e.category == .bills ? .bill : .expense
        date = e.date
        paidFrom = e.paidFrom
        tags = e.tags
        comment = e.comment
        source = e.source
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0 }

    /// Kind decides money in or out, and Bill / Monthly bill file the line under Bills.
    mutating func setKind(_ k: EntryKind) {
        kind = k
        switch k {
        case .receive:
            flow = .in
            category = .received
        case .bill, .monthly:
            flow = .out
            category = .bills
        case .expense:
            flow = .out
            if category == .received || category == .bills { category = .other }
        }
    }

    func apply(to e: Entry) {
        e.title = title.trimmingCharacters(in: .whitespaces)
        e.amount = amount ?? 0
        e.flow = flow
        e.category = category
        e.date = date
        e.paidFrom = paidFrom
        e.tags = tags
        e.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Editable copy of an entry or a draft line.
struct EntryDraft {
    var title = ""
    var amount: Int?
    var flow: Flow = .out
    var category: Category = .other
    var date = Day.today()

    init() {}

    init(_ e: Entry) {
        title = e.title
        amount = e.amount
        flow = e.flow
        category = e.category
        date = e.date
    }

    init(_ d: Draft) {
        title = d.title
        amount = d.amount
        flow = d.flow
        category = d.category
        date = d.date
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0 }

    func apply(to e: Entry) {
        e.title = title.trimmingCharacters(in: .whitespaces)
        e.amount = amount ?? 0
        e.flow = flow
        e.category = category
        e.date = date
    }

    func apply(to d: inout Draft) {
        d.title = title.trimmingCharacters(in: .whitespaces)
        d.amount = amount
        d.flow = flow
        d.category = category
        d.date = date
        d.assumedThousands = false
    }
}

/// The native form used to edit a saved entry or fix a line before saving.
struct EntryForm: View {
    @Binding var draft: EntryDraft

    var body: some View {
        Form {
            Section("What it was") {
                TextField("Name", text: $draft.title)
            }
            Section("Amount (đ)") {
                TextField("0", text: amountText)
                    .keyboardType(.numberPad)
                    .monospacedDigit()
            }
            Section {
                Picker("Type", selection: flowBinding) {
                    Text("Expense").tag(Flow.out)
                    Text("Receive").tag(Flow.in)
                }
                .pickerStyle(.segmented)
                Picker("Category", selection: $draft.category) {
                    ForEach(Category.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                DatePicker(
                    "Day",
                    selection: Binding(get: { Day.date(draft.date) }, set: { draft.date = Day.iso($0) }),
                    in: ...Date.now,
                    displayedComponents: .date)
            }
        }
        .font(AppFont.main(16))
        .scrollDismissesKeyboard(.interactively)
    }

    /// "42,000" while typing; only digits are kept.
    private var amountText: Binding<String> {
        Binding(
            get: { draft.amount.map(Money.format) ?? "" },
            set: { draft.amount = Int($0.filter(\.isNumber)) })
    }

    /// Switching to Receive makes it "Received"; switching back leaves it "Other".
    private var flowBinding: Binding<Flow> {
        Binding(
            get: { draft.flow },
            set: { f in
                draft.flow = f
                if f == .in { draft.category = .received }
                else if draft.category == .received { draft.category = .other }
            })
    }
}

/// "Summary" on the green card: where the money went, biggest first.
struct SummarySheet: View {
    var title: String
    var entries: [Entry]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app

    var body: some View {
        let out = entries.filter { $0.flow == .out }
        let total = out.reduce(0) { $0 + $1.amount }
        let received = entries.filter { $0.flow == .in }.reduce(0) { $0 + $1.amount }
        let rows = Dictionary(grouping: out, by: \.category)
            .map { (cat: $0.key, sum: $0.value.reduce(0) { $0 + $1.amount }, n: $0.value.count) }
            .sorted { $0.sum > $1.sum }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s20) {
                    HStack {
                        totalBlock(label: "Out", value: total)
                        Spacer()
                        totalBlock(label: "In", value: received)
                    }
                    if rows.isEmpty {
                        Text("No spending here.").font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                    }
                    ForEach(rows, id: \.cat) { row in
                        VStack(alignment: .leading, spacing: Space.s6) {
                            HStack {
                                Text(row.cat.rawValue)
                                    .font(AppFont.main(14, .medium))
                                    .foregroundStyle(Tokens.category(row.cat))
                                Text("\(row.n) \(row.n == 1 ? "item" : "items")")
                                    .font(AppFont.main(12))
                                    .foregroundStyle(Tokens.grey400)
                                Spacer()
                                AmountText(value: row.sum, hidden: app.hidden)
                            }
                            GeometryReader { g in
                                Capsule().fill(Tokens.bg4)
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Tokens.category(row.cat))
                                            .frame(width: max(6, g.size.width * CGFloat(row.sum) / CGFloat(max(total, 1))))
                                    }
                            }
                            .frame(height: 6)
                            .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Space.s20)
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func totalBlock(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            Text(label).font(AppFont.main(12, .medium)).foregroundStyle(Tokens.grey400)
            AmountText(value: value, size: 18, hidden: app.hidden)
        }
    }
}

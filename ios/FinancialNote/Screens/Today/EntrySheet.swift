import SwiftData
import SwiftUI

/// Entry sheet — Figma High Fi 2 (994:10250, 1052:6286): the amount on top, then name and
/// category, day / paid from / kind, tags, a comment, and delete in the corner. Everything is
/// editable in place; the green check saves.
struct EntrySheet: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @Query private var assets: [Asset]

    @State private var d = EntryEdit()
    @State private var loaded = false
    @State private var confirmDelete = false
    @State private var pickingTags = false
    @State private var commenting = false
    @FocusState private var focus: Field?

    enum Field { case amount, name, comment }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s12) {
                    amountHeader
                    nameCard
                    detailsCard
                    tagsCard
                    commentBlock
                    if !entry.source.isEmpty {
                        Text("From your note: “\(entry.source)”")
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
            .background(Tokens.bg1)
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .buttonStyle(.glassProminent)
                        .tint(Tokens.action)
                        .disabled(!d.isValid || d == EntryEdit(entry))
                }
            }
            .sheet(isPresented: $pickingTags) { TagPickerSheet(selected: $d.tags) }
        }
        .presentationDetents([.large])
        .onAppear {
            guard !loaded else { return }
            loaded = true
            d = EntryEdit(entry)
        }
    }

    // MARK: - Parts

    private var amountHeader: some View {
        VStack(spacing: Space.s4) {
            Text(d.flow == .out ? "Amount spent" : "Amount received")
                .font(AppFont.main(13))
                .foregroundStyle(Tokens.grey400)
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                TextField("0", text: Binding(
                    get: { d.amount.map(Money.format) ?? "" },
                    set: { d.amount = Int($0.filter(\.isNumber)) }))
                    .font(AppFont.main(36, .bold, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .focused($focus, equals: .amount)
                    .accessibilityLabel("Amount in dong")
                Text("đ")
                    .font(AppFont.main(28, .semibold, relativeTo: .title))
                    .foregroundStyle(Tokens.grey400)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }

    private var nameCard: some View {
        HStack(spacing: Space.s12) {
            TextField("Name", text: $d.title)
                .font(AppFont.main(16, .medium))
                .focused($focus, equals: .name)
            Menu {
                Picker("Category", selection: $d.category) {
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
            row("Day") {
                DatePicker("Day", selection: Binding(get: { Day.date(d.date) }, set: { d.date = Day.iso($0) }),
                           in: ...Date.now, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            Divider().overlay(Tokens.bd0)
            row("Paid from") {
                Menu {
                    Picker("Paid from", selection: $d.paidFrom) {
                        Text("Not set").tag(String?.none)
                        ForEach(paidFromOptions, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                } label: {
                    chip(d.paidFrom ?? "Not set", systemImage: d.paidFrom.map(Self.paidSymbol) ?? "questionmark.circle", trailing: "chevron.down")
                }
                .accessibilityLabel("Paid from, \(d.paidFrom ?? "not set")")
            }
            Divider().overlay(Tokens.bd0)
            row("Kind of") {
                Menu {
                    Picker("Kind of", selection: flowBinding) {
                        Text("Expense").tag(Flow.out)
                        Text("Receive").tag(Flow.in)
                    }
                } label: {
                    chip(d.flow == .out ? "Expense" : "Receive", systemImage: nil, trailing: "chevron.up.chevron.down")
                }
                .accessibilityLabel("Kind of, \(d.flow == .out ? "Expense" : "Receive")")
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
    }

    private var tagsCard: some View {
        let suggestion = Tags.suggest(title: d.title, category: d.category)
        return VStack(alignment: .leading, spacing: Space.s12) {
            HStack {
                Text("Tags").font(AppFont.main(15)).foregroundStyle(Tokens.text700)
                Spacer()
                if let suggestion, !d.tags.contains(suggestion) {
                    Button {
                        animate { d.tags.append(suggestion) }
                    } label: {
                        Label("Suggest tag", systemImage: "sparkles")
                            .font(AppFont.main(13, .medium))
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
            if !d.tags.isEmpty {
                FlowLayout {
                    ForEach(d.tags, id: \.self) { t in
                        TagChip(name: t, selected: true) { animate { d.tags.removeAll { $0 == t } } }
                    }
                }
            }
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
                TextField("Write a comment", text: $d.comment, axis: .vertical)
                    .font(AppFont.main(15))
                    .lineLimit(1...5)
                    .focused($focus, equals: .comment)
                    .padding(Space.s16)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
            } else {
                Button {
                    commenting = true
                    focus = .comment
                } label: {
                    Label("Add comment", systemImage: "plus")
                        .font(AppFont.main(15))
                        .foregroundStyle(Tokens.text700)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Space.s16)
                        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                }
                .buttonStyle(.plain)
            }
        }
    }

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
                    context.delete(entry)
                    try? context.save()
                    dismiss()
                }
            }
            Spacer()
        }
        .padding(.horizontal, Space.s16)
        .padding(.bottom, Space.s8)
    }

    // MARK: - Helpers

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(AppFont.main(15)).foregroundStyle(Tokens.text700)
            Spacer()
            content()
        }
        .frame(minHeight: 52)
    }

    private func chip(_ text: String, systemImage: String?, trailing: String) -> some View {
        HStack(spacing: Space.s6) {
            if let systemImage { Image(systemName: systemImage).foregroundStyle(Tokens.brand600) }
            Text(text).foregroundStyle(Tokens.text900)
            Image(systemName: trailing)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Tokens.grey400)
        }
        .font(AppFont.main(14, .medium))
        .padding(.horizontal, Space.s12)
        .padding(.vertical, Space.s8)
        .background(Tokens.bg4, in: .capsule)
    }

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

    private var flowBinding: Binding<Flow> {
        Binding(get: { d.flow }, set: { f in
            d.flow = f
            if f == .in { d.category = .received } else if d.category == .received { d.category = .other }
        })
    }

    private func save() {
        d.apply(to: entry)
        try? context.save()
        dismiss()
    }
}

/// Everything the entry sheet can change, compared with the saved entry to enable Save.
struct EntryEdit: Equatable {
    var title = ""
    var amount: Int?
    var flow: Flow = .out
    var category: Category = .other
    var date = Day.today()
    var paidFrom: String?
    var tags: [String] = []
    var comment = ""

    init() {}

    init(_ e: Entry) {
        title = e.title
        amount = e.amount
        flow = e.flow
        category = e.category
        date = e.date
        paidFrom = e.paidFrom
        tags = e.tags
        comment = e.comment
    }

    var isValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0 }

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

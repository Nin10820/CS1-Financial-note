import SwiftData
import SwiftUI

/// Entry detail (High Fi "Expense" 584:6591): category tag, the amount, the facts, then
/// Delete / Edit. Editing is a native form; deleting asks first.
struct EntrySheet: View {
    @Bindable var entry: Entry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app

    @State private var editing = false
    @State private var confirmDelete = false
    @State private var draft = EntryDraft()

    var body: some View {
        NavigationStack {
            Group {
                if editing { form } else { details }
            }
            .navigationTitle(editing ? "Edit" : entry.flow == .out ? "Expense" : "Received")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                if editing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editing = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") { save() }
                            .disabled(!draft.isValid)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", systemImage: "xmark") { dismiss() }
                    }
                }
            }
        }
        .presentationDetents(editing ? [.large] : [.medium, .large])
        .confirmationDialog("Delete “\(entry.title)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete for good", role: .destructive) {
                context.delete(entry)
                try? context.save()
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("It's removed from this phone.")
        }
    }

    private var details: some View {
        ScrollView {
            VStack(spacing: Space.s12) {
                Text(entry.category.rawValue)
                    .font(AppFont.main(13, .medium))
                    .foregroundStyle(Tokens.category(entry.category))
                    .padding(.horizontal, Space.s12)
                    .padding(.vertical, Space.s4)
                    .background(Tokens.category(entry.category).opacity(0.12), in: .rect(cornerRadius: Corner.c8))
                AmountText(value: entry.amount, size: 32, sign: entry.flow == .out ? "-" : "+", hidden: app.hidden)
                Text(entry.title)
                    .font(AppFont.main(14, .medium))
                    .foregroundStyle(Tokens.text700)
                    .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    fact("Day", Day.long(entry.date))
                    Divider().overlay(Tokens.bd0)
                    fact("Category", entry.category.rawValue)
                    Divider().overlay(Tokens.bd0)
                    fact("Saved", "\(Day.short(Day.iso(entry.createdAt))) · \(Day.clock(entry.createdAt))")
                    Divider().overlay(Tokens.bd0)
                    fact("From your note", "“\(entry.source)”")
                }
                .padding(.horizontal, Space.s16)
                .background(Tokens.bg2, in: .rect(cornerRadius: Corner.c12))
                .overlay(RoundedRectangle(cornerRadius: Corner.c12).strokeBorder(Tokens.bd1))
                .padding(.top, Space.s12)

                HStack(spacing: Space.s12) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("Delete").frame(maxWidth: .infinity).foregroundStyle(Tokens.text900)
                    }
                    .buttonStyle(.glass)
                    Button {
                        draft = EntryDraft(entry)
                        editing = true
                    } label: {
                        Text("Edit").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                .font(AppFont.main(16, .semibold))
                .controlSize(.large)
                .padding(.top, Space.s16)
            }
            .padding(Space.s20)
        }
        .background(Tokens.bg1)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(Tokens.text700)
            Spacer(minLength: Space.s16)
            Text(value).foregroundStyle(Tokens.text900).multilineTextAlignment(.trailing)
        }
        .font(AppFont.main(14))
        .padding(.vertical, Space.s12)
        .accessibilityElement(children: .combine)
    }

    private var form: some View {
        EntryForm(draft: $draft)
    }

    private func save() {
        draft.apply(to: entry)
        try? context.save()
        editing = false
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

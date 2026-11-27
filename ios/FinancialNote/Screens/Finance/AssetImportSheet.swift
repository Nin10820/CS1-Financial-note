import SwiftData
import SwiftUI

/// What the Finance + menu hands over: a quick note to write, lines the camera read, or a photo.
struct AssetImportSeed: Identifiable {
    enum Input {
        case note
        case lines([String])
        case photo(Data)
    }
    let id = UUID()
    var input: Input
}

/// Add assets from a quick note, a scan or a photo (a bank app screenshot, a savings book, a gold
/// receipt). Everything is read on the phone — Apple Intelligence when the iPhone has it, the rule
/// reader otherwise — then listed to check. Nothing is added until ✓; a name that matches an
/// asset you already have updates it instead of adding a second one.
struct AssetImportSheet: View {
    let seed: AssetImportSeed
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]

    enum Phase { case writing, reading, review }
    @State private var phase: Phase = .reading
    @State private var note = ""
    @State private var read: [String] = []
    @State private var drafts: [AssetDraft] = []
    @State private var skipped: Set<UUID> = []
    @State private var byAI = false
    @FocusState private var focused: Bool

    private var picked: [AssetDraft] { drafts.filter { !skipped.contains($0.id) } }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .writing: writing
                case .reading: reading
                case .review: review
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Tokens.canvas)
            .sheetHeader(title, trailing: phase == .review && !drafts.isEmpty
                         ? .save(enabled: !picked.isEmpty, action: add) : .close)
        }
        .task { await start() }
    }

    private var isNote: Bool { if case .note = seed.input { true } else { false } }

    private var title: String {
        switch seed.input {
        case .note: "Quick note"
        case .lines: "From a scan"
        case .photo: "From a photo"
        }
    }

    // MARK: - Phases

    private var writing: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            Text("Write what you have, one per line.")
                .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("vàng 5 chỉ\ntiết kiệm TPBank 50tr\nMoMo 1tr2\nUSD 700")
                        .font(AppFont.main(17))
                        .foregroundStyle(Tokens.grey300)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $note)
                    .font(AppFont.main(17))
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("What you have, one per line")
            }
            .padding(Space.s12)
            .frame(minHeight: 180)
            .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
            Button {
                let lines = note.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                Task { await readLines(lines, typed: true) }
            } label: {
                Text("Read").font(AppFont.main(16, .semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glassProminent)
            .tint(Tokens.action)
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Text("Read on this phone. Nothing is sent anywhere.")
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
        }
        .padding(Space.s20)
        .onAppear { focused = true }
    }

    private var reading: some View {
        VStack(spacing: Space.s12) {
            ProgressView()
            Text(AssetReader.usesAI && !isNote ? "Apple Intelligence is reading it on this phone…" : "Reading it on this phone…")
                .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 120)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var review: some View {
        if drafts.isEmpty {
            VStack(spacing: Space.s12) {
                Text("Couldn't find an asset with an amount")
                    .font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                Text("Try lines like “vàng 5 chỉ” or “TPBank 50tr”.")
                    .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                Button("Write it instead") {
                    note = read.joined(separator: "\n")
                    animate { phase = .writing }
                }
                .font(AppFont.main(14, .semibold))
                .buttonStyle(.glassProminent)
                .tint(Tokens.action)
                if !read.isEmpty { readBox }
            }
            .padding(Space.s20)
            .padding(.top, Space.s32)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s12) {
                    Text("Tick what to add. Nothing is saved until ✓.")
                        .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                    VStack(spacing: 0) {
                        ForEach(Array(drafts.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 56) }
                            row(d)
                        }
                    }
                    .padding(.horizontal, Space.s12)
                    .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
                    Label(byAI ? "Read by Apple Intelligence on this phone · check before adding"
                               : "Read on this phone · check before adding",
                          systemImage: byAI ? "apple.intelligence" : "iphone")
                        .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    if !read.isEmpty { readBox }
                }
                .padding(Space.s20)
            }
        }
    }

    private func row(_ d: AssetDraft) -> some View {
        let on = !skipped.contains(d.id)
        let match = existing(d)
        return Button {
            animate { if on { skipped.insert(d.id) } else { skipped.remove(d.id) } }
        } label: {
            HStack(spacing: Space.s12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Tokens.brand600 : Tokens.grey300)
                AssetTile(icon: match?.icon ?? AssetMath.guessIcon(d.name, kind: d.kind), size: 32, round: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name).font(AppFont.main(16, .medium)).foregroundStyle(Tokens.text900).lineLimit(1)
                    Text(match.map { "Updates \($0.name)" } ?? "New · \(d.kind.label)")
                        .font(AppFont.main(12)).foregroundStyle(match == nil ? Tokens.grey400 : Tokens.brand600)
                }
                Spacer(minLength: Space.s8)
                VStack(alignment: .trailing, spacing: 2) {
                    if let q = d.quantity, let u = d.unit {
                        Text(app.assetsHidden ? "•••" : AssetDraftText.quantity(q, u))
                            .font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                        Text(d.amount.map { app.assetsHidden ? "≈ •••" : "≈ " + Money.format($0) + "đ" } ?? "price after Sync")
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    } else if let a = d.amount {
                        Text(app.assetsHidden ? "•••" : Money.format(a) + "đ")
                            .font(AppFont.main(16, .semibold)).foregroundStyle(Tokens.text900)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .layoutPriority(1)
            }
            .padding(.vertical, Space.s12)
            .opacity(on ? 1 : 0.5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// What the camera or photo read, folded away: handy when a line came out wrong.
    private var readBox: some View {
        DisclosureGroup("What was read") {
            Text(read.joined(separator: "\n"))
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .font(AppFont.main(14))
        .tint(Tokens.grey400)
    }

    // MARK: - Logic

    private func start() async {
        switch seed.input {
        case .note:
            phase = .writing
        case .lines(let lines):
            await readLines(lines)
        case .photo(let data):
            phase = .reading
            await readLines(await AssetReader.lines(inImage: data))
        }
    }

    private func readLines(_ lines: [String], typed: Bool = false) async {
        focused = false
        read = lines
        animate { phase = .reading }
        let result = await AssetReader.read(lines, today: app.today, typed: typed)
        animate {
            drafts = result.drafts
            byAI = result.byAI
            skipped = []
            phase = .review
        }
    }

    /// An asset you already have with the same name (accents and case aside).
    private func existing(_ d: AssetDraft) -> Asset? {
        let key = Self.key(d.name)
        return assets.first { Self.key($0.name) == key }
    }

    static func key(_ s: String) -> String {
        s.replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func add() {
        let store = LocalStore(context: context)
        let today = app.today
        for d in picked {
            if let a = existing(d) {
                if let q = d.quantity, let u = d.unit {
                    store.setHolding(a, quantity: q, unit: u)
                } else if let amount = d.amount {
                    store.move(a, .value, amount: amount, date: today)
                }
            } else {
                let asset = Asset(name: d.name, kind: d.kind, icon: AssetMath.guessIcon(d.name, kind: d.kind),
                                  amount: d.amount ?? 0, updated: today)
                if let q = d.quantity, let u = d.unit {
                    asset.quantity = q
                    asset.unit = u
                }
                store.addAsset(asset)
            }
        }
        store.revalueHoldings(today: today)
        dismiss()
    }
}

enum AssetDraftText {
    /// "5 chỉ 3 phân", "700 $", "0.01 BTC".
    static func quantity(_ q: Double, _ u: HoldingUnit) -> String {
        if let cp = HoldingUnit.chiPhan(q, u) {
            let phan = cp.phan == 0 ? "" : " \(cp.phan.formatted(.number.precision(.fractionLength(0...2)))) phân"
            return cp.chi == 0 ? phan.trimmingCharacters(in: .whitespaces) : "\(cp.chi) chỉ" + phan
        }
        return q.formatted(.number.precision(.fractionLength(0...8))) + " " + u.label
    }
}

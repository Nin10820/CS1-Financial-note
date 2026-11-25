import SwiftData
import SwiftUI

/// Add or edit something you own whose price is hard to pin down (land, a car, a watch, Lego).
/// Same shape as a spending line: how it's valued on top, the big amount on the number pad,
/// then white cards of rows. Shows what it's worth now and what a quick sale would fetch.
struct BelongingSheet: View {
    var editing: Belonging? = nil
    /// Adding a piece to this collection (a Lego set to the Lego collection).
    var parent: Belonging? = nil
    /// Kept from a spending line in Today: its name, price and day are filled in.
    var from: Entry? = nil
    /// Starts as a collection ("Other…" on the new-collection picker).
    var asCollection = false
    @Query private var all: [Belonging]
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon: BelongingIcon = .other
    @State private var mode: BelongingValue = .estimate
    @State private var paid: Int?
    @State private var bought = Day.today()
    @State private var estimate: Int?
    @State private var lossPerYear = 10.0
    @State private var floorPct = 10.0
    @State private var quickSalePct = 70.0
    @State private var source = ""
    @State private var note = ""
    @State private var ready = false
    /// The icon and mode follow the name until you pick one yourself.
    @State private var pickedIcon = false
    @State private var pickedMode = false
    @State private var confirmDelete = false
    /// A collection holds pieces; its worth is theirs.
    @State private var isCollection = false
    /// A piece in a collection: code or model, year, condition.
    @State private var code = ""
    @State private var year: Int?
    @State private var condition: BelongingCondition = .sealed
    /// The value follows the condition until you type your own.
    @State private var typedValue = false
    /// Lego: find the set by code or name; its picture comes once it's picked.
    @State private var query = ""
    @State private var imageData: Data?
    @State private var fetching = false
    /// Which amount the number pad types into (nil: pad down).
    @State private var pad: PadTarget?
    @State private var pickingDate = false
    /// The family's, kept for use: no quick-sale number.
    @State private var keeps = false
    /// Sold: what it fetched and when.
    @State private var sold = false
    @State private var soldFor: Int?
    @State private var soldOn = Day.today()
    @State private var pickingSoldDate = false
    @FocusState private var focus: Field?

    enum PadTarget { case main, paid, sold }
    enum Field { case name, source, note, code, search }

    private var isPiece: Bool { parent != nil || editing?.parentId != nil }

    /// A piece of a Lego collection: search the bundled set list.
    private var isLego: Bool {
        let p = parent ?? all.first { $0.id == editing?.parentId }
        return isPiece && (p?.icon == .lego || icon == .lego)
    }

    /// The big number: your value when you estimate it, what you paid otherwise.
    private var main: Binding<Int?> { mode == .estimate ? $estimate : $paid }

    private var draft: Belonging {
        Belonging(name: name, icon: icon, mode: mode, paid: paid ?? 0, boughtOn: bought, estimate: estimate ?? 0,
                  estimatedOn: app.today, lossPerYear: lossPerYear, floorPct: floorPct, quickSalePct: quickSalePct)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (isCollection || (main.wrappedValue ?? 0) > 0)
    }

    private var title: String {
        if isCollection { return editing == nil ? "New collection" : "Collection" }
        if parent != nil || editing?.parentId != nil { return editing == nil ? "New piece" : "Piece" }
        return editing == nil ? "New belonging" : "Belonging"
    }

    /// Only a new thing on its own can become a collection.
    private var canBeCollection: Bool { editing == nil && parent == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.s12) {
                    if isCollection {
                        nameCard.padding(.top, Space.s8)
                        if canBeCollection { collectionCard }
                        hint("Save it, then add each piece inside (each Lego set, each watch). Its worth is what its pieces are worth together.")
                        noteCard
                    } else if isPiece {
                        if let imageData, let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 180)
                                .padding(Space.s12)
                                .background(.white, in: .rect(cornerRadius: Corner.c16))
                                .padding(.top, Space.s8)
                                .accessibilityLabel("Picture of \(name)")
                        } else if fetching {
                            ProgressView("Getting the picture…").font(AppFont.main(12)).frame(height: 60).padding(.top, Space.s8)
                        }
                        // Finding the set is for a new piece; an existing one is updated, not re-picked.
                        if isLego && editing == nil { legoSearch.padding(.top, imageData == nil ? Space.s8 : 0) }
                        amountHeader.padding(.top, (isLego && editing == nil) || imageData != nil ? 0 : Space.s8)
                        nameCard
                        pieceCard
                        if editing == nil {
                            hint("The value starts from what you paid and its condition: new keeps its price, used and damaged ones are worth less. Type your own when you see a real price.")
                        }
                        if editing != nil { statusCard }
                        if !sold { sellCard }
                        noteCard
                    } else {
                        ModeTrack(mode: Binding(get: { mode }, set: { mode = $0; pickedMode = true }))
                            .padding(.top, Space.s8)
                        amountHeader
                        nameCard
                        if KeepSuggestion.isClothes(name) && !isCollection {
                            hint("Clothes are usually spending: they're in Today › Shopping. Keep them here only if they'd sell for real money.")
                        }
                        if canBeCollection && from == nil { collectionCard }
                        detailsCard
                        hint(modeHint)
                        statusCard
                        if !sold {
                            sellCard
                            if !keeps {
                                hint("Buyers rarely pay what an owner thinks something is worth. Quick sale is the lower number to keep in mind.")
                            }
                        }
                        noteCard
                    }
                    if editing != nil {
                        Button(isCollection ? "Delete this collection" : "Delete", role: .destructive) { confirmDelete = true }
                            .font(AppFont.main(14, .medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
                .padding(.horizontal, Space.s16)
                .padding(.bottom, Space.s24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.canvas)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let target = pad {
                    AmountPad(value: target == .main ? main : target == .sold ? $soldFor : $paid) { animate { pad = nil } }
                        .transition(.move(edge: .bottom))
                }
            }
            // A piece's value follows what you paid and its condition, until you type your own.
            .onChange(of: estimate) { old, new in if isPiece && pad == .main && old != new { typedValue = true } }
            .onChange(of: paid) { _, _ in suggestValue() }
            .onChange(of: condition) { _, _ in suggestValue() }
            .onChange(of: focus) { _, f in if f != nil { animate { pad = nil } } }
            .sheetHeader(title, trailing: .save(enabled: isValid, action: save))
            .sheet(isPresented: $pickingDate) {
                DateSheet(date: $bought, title: "Bought", latest: app.today, today: app.today).sheetSurface()
            }
            .sheet(isPresented: $pickingSoldDate) {
                DateSheet(date: $soldOn, title: "Sold on", latest: app.today, today: app.today).sheetSurface()
            }
            .onChange(of: name) { _, n in
                if !pickedIcon { icon = BelongingMath.guessIcon(n) }
                if !pickedMode && editing == nil {
                    mode = BelongingMath.guessMode(icon)
                    lossPerYear = BelongingMath.usualLoss(icon)
                }
            }
            .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let editing {
                        // A collection goes with its pieces.
                        BelongingMath.pieces(of: editing, in: all).forEach(context.delete)
                        context.delete(editing)
                        try? context.save()
                    }
                    dismiss()
                }
            } message: {
                if isCollection { Text("Its pieces go too.") }
            }
        }
        .presentationDetents([.large])
        .onAppear(perform: load)
    }

    // MARK: Parts

    /// "Your value" / "You paid" and the big number, typed on the number pad.
    private var amountHeader: some View {
        VStack(spacing: Space.s4) {
            Text(mode == .estimate ? "Your value" : "You paid")
                .font(AppFont.body(.medium))
                .foregroundStyle(Tokens.grey400)
            Button {
                focus = nil
                animate { pad = .main }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                    BigAmount(value: main.wrappedValue)
                        .foregroundStyle(main.wrappedValue == nil ? Tokens.grey300 : Tokens.text900)
                        .overlay(alignment: .bottom) {
                            if pad == .main { Capsule().fill(Tokens.brand500).frame(height: 2).offset(y: 2) }
                        }
                    Text("đ").font(AppFont.currency(for: 44)).foregroundStyle(Tokens.grey400)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mode == .estimate ? "Your value in dong" : "What you paid in dong")
            .accessibilityValue(main.wrappedValue.map(Money.format) ?? "empty")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s8)
    }

    /// The name, with the kind as its round tile (tap it to change the kind).
    private var nameCard: some View {
        HStack(spacing: Space.s12) {
            TextField(isCollection ? "Lego, watches, sneakers…"
                      : parent != nil || editing?.parentId != nil ? "e.g. Millennium Falcon 75192"
                      : "Land in Long An, Rolex, Lego…", text: $name)
                .font(AppFont.heading(18, .regular))
                .focused($focus, equals: .name)
            Menu {
                Picker("Kind", selection: Binding(get: { icon }, set: { icon = $0; pickedIcon = true })) {
                    ForEach(BelongingIcon.allCases, id: \.self) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
            } label: {
                BelongingTile(icon: icon, size: 40, color: isCollection || parent != nil ? LifeTint.collection.accent
                              : BelongingMath.group(draft).tint.accent)
            }
            .accessibilityLabel("Kind, \(icon.label)")
        }
        .padding(.leading, Space.s16)
        .padding(.trailing, Space.s12)
        .padding(.vertical, Space.s8)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    /// A piece: what it is (code or model, year) and the shape it's in.
    private var pieceCard: some View {
        VStack(spacing: 0) {
            row("Condition") {
                Menu {
                    Picker("Condition", selection: $condition) {
                        ForEach(BelongingCondition.allCases, id: \.self) {
                            Text($0.label + " · " + BelongingMath.pct($0.share * 100)).tag($0)
                        }
                    }
                } label: { valueLabel(condition.label) }
            }
            divider
            row("Code / model") {
                TextField("21060, PSA 10…", text: $code)
                    .font(AppFont.main(14))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.text700)
                    .focused($focus, equals: .code)
            }
            divider
            row("Year") {
                Menu {
                    Picker("Year", selection: $year) {
                        Text("Not set").tag(Int?.none)
                        ForEach((1980...Day.parts(app.today).y).reversed(), id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                    }
                } label: { valueLabel(year.map(String.init) ?? "Not set", muted: year == nil) }
            }
            divider
            row("You paid") {
                Button {
                    focus = nil
                    animate { pad = .paid }
                } label: {
                    valueLabel(paid.map { Money.format($0) + " đ" } ?? "Optional", muted: paid == nil,
                               active: pad == .paid, symbol: nil)
                }
                .buttonStyle(.plain)
            }
            divider
            row("Bought") {
                Button { pickingDate = true } label: { valueLabel(DueText.ddmmyyyy(bought), symbol: "chevron.right") }
                    .buttonStyle(.plain)
            }
            divider
            row("Price from") {
                TextField("A shop, a group, an app…", text: $source)
                    .font(AppFont.main(14))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.text700)
                    .focused($focus, equals: .source)
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    /// Lego: type a code or a name, pick the set: name, code, year and its picture fill in.
    private var legoSearch: some View {
        let results = LegoCatalog.search(query, limit: 8)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.s8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Tokens.grey400)
                TextField("Find the set: 21060 or Himeji", text: $query)
                    .font(AppFont.main(16))
                    .focused($focus, equals: .search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Tokens.grey300) }
                        .buttonStyle(.plain).accessibilityLabel("Clear")
                }
            }
            .frame(minHeight: 48)
            ForEach(results) { s in
                Divider().overlay(Tokens.bd0)
                Button { pick(s) } label: {
                    HStack(spacing: Space.s12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                            Text("\(s.code) · \(String(s.year)) · \(s.theme) · \(Money.format(s.parts)) pcs")
                                .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill").foregroundStyle(Tokens.brand500)
                    }
                    .frame(minHeight: 52)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            if query.count >= 2 && results.isEmpty {
                Divider().overlay(Tokens.bd0)
                Text("No set found. Type the name yourself below.")
                    .font(AppFont.main(12)).foregroundStyle(Tokens.grey400).frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    /// Fills the piece from a set in the list and gets its picture (once, kept on the phone).
    private func pick(_ s: LegoSet) {
        name = s.name
        code = s.code
        year = s.year
        if note.isEmpty { note = "\(Money.format(s.parts)) pieces · \(s.theme)" }
        query = ""
        focus = nil
        Task {
            fetching = true
            imageData = await LegoCatalog.picture(for: s)
            fetching = false
        }
    }

    /// What you paid × the condition's share, until you type a value of your own.
    private func suggestValue() {
        guard isPiece, !typedValue, let p = paid, p > 0 else { return }
        estimate = Int((Double(p) * condition.share).rounded())
    }

    /// "It's a collection": for Lego, watches, cards — many pieces, each with its own value.
    private var collectionCard: some View {
        Toggle(isOn: $isCollection.animation(.snappy)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("It's a collection").font(AppFont.main(16)).foregroundStyle(Tokens.text900)
                Text("Many pieces, each with its own value").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
            }
        }
        .tint(Tokens.brand500)
        .padding(.horizontal, Space.s16)
        .frame(minHeight: 60)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            if mode == .estimate {
                row("You paid") {
                    Button {
                        focus = nil
                        animate { pad = .paid }
                    } label: {
                        valueLabel(paid.map { Money.format($0) + " đ" } ?? "Optional", muted: paid == nil,
                                   active: pad == .paid, symbol: nil)
                    }
                    .buttonStyle(.plain)
                }
            }
            if mode == .estimate { divider }
            row("Bought") {
                Button { pickingDate = true } label: { valueLabel(DueText.ddmmyyyy(bought), symbol: "chevron.right") }
                    .buttonStyle(.plain)
            }
            switch mode {
            case .estimate:
                divider
                row("Price from") {
                    TextField("Chợ Tốt, a shop…", text: $source)
                        .font(AppFont.main(14))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Tokens.text700)
                        .focused($focus, equals: .source)
                }
            case .depreciate:
                divider
                row("Down each year") { percentMenu($lossPerYear, [5, 10, 15, 20, 25, 30, 40]) }
                divider
                row("Never below") { percentMenu($floorPct, [0, 10, 20, 30, 40, 50], suffix: " of price") }
            case .paid:
                EmptyView()
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    /// "The family's" (you wouldn't sell it) and, once it's saved, "Sold": what it fetched and when.
    private var statusCard: some View {
        VStack(spacing: 0) {
            // A collection's piece is never just the family's.
            if !sold && !isPiece {
                Toggle(isOn: $keeps.animation(.snappy)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The family's").font(AppFont.main(16)).foregroundStyle(Tokens.text900)
                        Text("Used at home, you wouldn't sell it").font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                }
                .tint(Tokens.brand500)
                .frame(minHeight: 60)
            }
            if editing != nil {
                if !sold && !isPiece { divider }
                Toggle(isOn: Binding(get: { sold }, set: { on in
                    animate {
                        sold = on
                        if on {
                            keeps = false
                            if soldFor == nil { soldFor = main.wrappedValue }
                            soldOn = app.today
                        }
                    }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sold").font(AppFont.main(16)).foregroundStyle(Tokens.text900)
                        Text(sold ? "Kept in the list, no longer counted" : "Mark it when it's gone")
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                    }
                }
                .tint(Tokens.brand500)
                .frame(minHeight: 60)
                if sold {
                    divider
                    row("Sold for") {
                        Button {
                            focus = nil
                            animate { pad = .sold }
                        } label: {
                            valueLabel(soldFor.map { Money.format($0) + " đ" } ?? "How much?", muted: soldFor == nil,
                                       active: pad == .sold, symbol: nil)
                        }
                        .buttonStyle(.plain)
                    }
                    divider
                    row("Sold on") {
                        Button { pickingSoldDate = true } label: { valueLabel(DueText.ddmmyyyy(soldOn), symbol: "chevron.right") }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    private var sellCard: some View {
        VStack(spacing: 0) {
            if !keeps {
                row("Quick sale at") { percentMenu($quickSalePct, [50, 60, 70, 75, 80, 85, 90, 100], suffix: " of value") }
            }
            if isValid {
                if !keeps { divider }
                row("Worth now") {
                    Text(Money.format(BelongingMath.value(draft, today: app.today)) + " đ")
                        .font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                }
                if !keeps {
                    divider
                    row("Quick sale") {
                        Text(Money.format(BelongingMath.quickSale(draft, today: app.today)) + " đ")
                            .font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text700).monospacedDigit()
                    }
                }
            }
        }
        .padding(.horizontal, Space.s16)
        .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    private var noteCard: some View {
        TextField("Note: papers, condition, box…", text: $note, axis: .vertical)
            .font(AppFont.main(14))
            .lineLimit(2...5)
            .focused($focus, equals: .note)
            .padding(Space.s16)
            .background(Tokens.card, in: .rect(cornerRadius: Corner.c16))
    }

    private var divider: some View { Divider().overlay(Tokens.bd0) }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(AppFont.main(12))
            .foregroundStyle(Tokens.grey400)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.s4)
    }

    private func row<V: View>(_ title: String, @ViewBuilder value: () -> V) -> some View {
        HStack(spacing: Space.s12) {
            Text(title).font(AppFont.main(16)).foregroundStyle(Tokens.text900)
            Spacer(minLength: Space.s8)
            value()
        }
        .frame(minHeight: 52)
    }

    private func valueLabel(_ text: String, muted: Bool = false, active: Bool = false,
                            symbol: String? = "chevron.up.chevron.down") -> some View {
        HStack(spacing: Space.s6) {
            Text(text)
                .font(AppFont.main(14))
                .foregroundStyle(active ? Tokens.brand600 : muted ? Tokens.grey400 : Tokens.text700)
                .monospacedDigit()
            if let symbol {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(Tokens.grey400)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
    }

    private func percentMenu(_ value: Binding<Double>, _ options: [Double], suffix: String = "") -> some View {
        Menu {
            Picker("", selection: value) {
                ForEach(options, id: \.self) { Text(BelongingMath.pct($0) + suffix).tag($0) }
            }
        } label: { valueLabel(BelongingMath.pct(value.wrappedValue) + suffix) }
    }

    private var modeHint: String {
        switch mode {
        case .estimate: "For land, watches, bags, collectibles: you set the value. Update it when you see a real price."
        case .depreciate: "For phones, laptops, keyboards, headphones, bikes, cars: its worth goes down a little each year, worked out from what you paid."
        case .paid: "Keeps what you paid. Good when you'd rather not guess."
        }
    }

    // MARK: Load and save

    private func load() {
        guard !ready else { return }
        ready = true
        if editing == nil, let e = from {
            name = e.title
            paid = e.amount
            bought = e.date
            icon = BelongingMath.guessIcon(e.title)
            mode = BelongingMath.guessMode(icon)
            lossPerYear = BelongingMath.usualLoss(icon)
            pickedIcon = true
            pickedMode = true
            // You know what you paid; your estimate starts there too.
            if mode == .estimate { estimate = e.amount }
            return
        }
        if asCollection && editing == nil { isCollection = true }
        guard let b = editing else {
            // A piece starts with its collection's kind (a Lego set in Lego).
            if let parent {
                icon = parent.icon
                pickedIcon = true
                pickedMode = true
                mode = .estimate
            }
            // A new one starts on its name.
            Task { try? await Task.sleep(for: .milliseconds(400)); focus = .name }
            return
        }
        name = b.name
        icon = b.icon
        mode = b.mode
        isCollection = b.isCollection
        code = b.code ?? ""
        year = b.year
        imageData = b.imageData
        condition = b.condition ?? .sealed
        typedValue = true
        paid = b.paid > 0 ? b.paid : nil
        bought = b.boughtOn
        estimate = b.estimate > 0 ? b.estimate : nil
        lossPerYear = b.lossPerYear
        floorPct = b.floorPct
        quickSalePct = b.quickSalePct
        source = b.source ?? ""
        note = b.note ?? ""
        keeps = b.keeps
        sold = b.soldOn != nil
        soldOn = b.soldOn ?? app.today
        soldFor = b.soldFor
        pickedIcon = true
        pickedMode = true
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        let src = source.trimmingCharacters(in: .whitespaces)
        let memo = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = editing ?? Belonging(name: n, icon: icon, mode: mode, paid: paid ?? 0, boughtOn: bought)
        // A new value (or a new way of valuing) counts as checked today.
        if editing == nil || b.estimate != (estimate ?? 0) || b.mode != mode { b.estimatedOn = app.today }
        b.name = n
        b.icon = icon
        b.mode = mode
        b.paid = paid ?? 0
        b.boughtOn = bought
        if mode == .estimate { b.estimate = estimate ?? 0 }
        b.lossPerYear = lossPerYear
        b.floorPct = floorPct
        b.quickSalePct = quickSalePct
        b.source = src.isEmpty ? nil : src
        b.note = memo.isEmpty ? nil : memo
        b.keeps = keeps && !sold
        b.soldOn = sold ? soldOn : nil
        b.soldFor = sold ? soldFor : nil
        if isPiece {
            let c = code.trimmingCharacters(in: .whitespaces)
            b.code = c.isEmpty ? nil : c
            b.year = year
            b.condition = condition
            if let imageData { b.imageData = imageData }
        }
        if editing == nil {
            b.isCollection = isCollection
            b.parentId = parent?.id
            b.entryId = from?.id
            context.insert(b)
        }
        try? context.save()
        dismiss()
    }
}

/// "Your estimate · Loses value · What you paid": the app's grey track with a white pill
/// (like D / W / M / Y on Analysis), not the system segmented control.
private struct ModeTrack: View {
    @Binding var mode: BelongingValue
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BelongingValue.allCases, id: \.self) { m in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { mode = m }
                } label: {
                    Text(m.label)
                        .font(AppFont.main(14, mode == m ? .semibold : .regular))
                        .foregroundStyle(Tokens.text900)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if mode == m {
                                Capsule().fill(Tokens.segmentOn)
                                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "mode", in: pill)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
        .padding(Space.s4)
        .background(Tokens.bg4, in: .capsule)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How to value it")
    }
}

/// A round tile with the belonging's symbol, in one warm colour for the whole group.
struct BelongingTile: View {
    var icon: BelongingIcon
    var size: CGFloat = 40
    /// The colour of how it's valued (the Overview card's), or the group's brown.
    var color: Color = Tokens.belonging

    var body: some View {
        Image(systemName: icon.symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Which belonging sheet is open: a new one, or one to edit.
enum BelongingSheetID: Identifiable, Hashable {
    case new
    case edit(String)
    /// A collection's own page: its pieces.
    case collection(String)
    /// One of Overview's cards: what holds value, everyday things, collections.
    case group(BelongingGroup)
    var id: String {
        switch self {
        case .new: "new"
        case .edit(let id): id
        case .collection(let id): "c-" + id
        case .group(let g): "g-" + g.rawValue
        }
    }
}

/// Total Asset › Belongings: each thing, its value now and the quick-sale number under it.
struct BelongingsList: View {
    var belongings: [Belonging]
    var today: String
    var hidden: Bool
    var counted: Bool
    var onOpen: (BelongingSheetID) -> Void

    var body: some View {
        let total = BelongingMath.total(belongings, today: today)
        let quick = BelongingMath.quickTotal(belongings, today: today)
        let shown = BelongingMath.topLevel(belongings)
        VStack(alignment: .leading, spacing: Space.s8) {
            // New ones come from the + button › Belonging, like every other add.
            FinanceSectionTitle(title: "Belongings") { EmptyView() }
            VStack(alignment: .leading, spacing: 0) {
                if belongings.isEmpty {
                    Text("Land, a car, a watch, a bag, Lego: things with a price that's hard to pin down. Add one with + › Belonging.")
                        .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).padding(.vertical, Space.s16)
                } else {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your value").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                            Text(hidden ? "•••" : Money.format(total) + "đ").font(AppFont.heading(16, .semibold)).monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Quick sale").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                            Text(hidden ? "•••" : Money.format(quick) + "đ").font(AppFont.heading(16, .semibold))
                                .foregroundStyle(Tokens.text700).monospacedDigit()
                        }
                    }
                    .padding(.vertical, Space.s12)
                    .accessibilityElement(children: .combine)
                    ForEach(shown) { b in
                        Divider().overlay(Tokens.bd0).padding(.leading, b.id == shown.first?.id ? 0 : 56)
                        BelongingRow(belonging: b, all: belongings, today: today, hidden: hidden) {
                            onOpen(b.isCollection ? .collection(b.id) : .edit(b.id))
                        }
                    }
                }
            }
            .padding(.horizontal, Space.s16)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            Text(counted ? "Counted in Total Asset. Change it in Finance › •••."
                         : "Not counted in Total Asset: hard to sell fast, and owners tend to price high.")
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                .padding(.horizontal, Space.s4)
        }
    }

}

/// One belonging in a list: tile, name over its value line, worth over the quick-sale number.
/// A collection shows a stack of tiles and the sum of its pieces.
struct BelongingRow: View {
    var belonging: Belonging
    var all: [Belonging]
    var today: String
    var hidden: Bool
    /// Before the value line, e.g. the collection a piece is in: "Lego · Estimate · 30 days ago".
    var prefix: String? = nil
    var onTap: () -> Void

    var body: some View {
        let b = belonging
        Button(action: onTap) {
            HStack(spacing: Space.s12) {
                Group {
                    if let d = b.imageData, let image = UIImage(data: d) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .padding(3)
                            .frame(width: 40, height: 40)
                            .background(.white, in: .rect(cornerRadius: Corner.c8))
                            .accessibilityHidden(true)
                    } else {
                        BelongingTile(icon: b.icon, size: 40, color: BelongingMath.group(b).tint.accent)
                    }
                }
                    .overlay(alignment: .bottomTrailing) {
                        if b.isCollection {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Tokens.belonging)
                                .frame(width: 18, height: 18)
                                .background(Tokens.card, in: .circle)
                                .offset(x: 3, y: 3)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.name).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900).lineLimit(1)
                    Text((prefix.map { $0 + " · " } ?? "") + BelongingMath.line(b, in: all, today: today))
                        .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).lineLimit(1)
                }
                Spacer(minLength: Space.s8)
                VStack(alignment: .trailing, spacing: 2) {
                    // Short amounts so the name keeps its room; the exact numbers are in the sheet.
                    if b.soldOn != nil {
                        // Sold: what it fetched, in grey; it no longer counts.
                        Text(hidden ? "•••" : b.soldFor.map { AnalyticsView.compact($0) + "đ" } ?? "—")
                            .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.grey400).monospacedDigit()
                        Text("sold").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                    } else {
                        Text(hidden ? "•••" : AnalyticsView.compact(BelongingMath.worth(b, in: all, today: today)) + "đ")
                            .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text900).monospacedDigit()
                        Text(b.keeps ? "keeping" : hidden ? "quick •••" : "quick " + AnalyticsView.compact(BelongingMath.quickWorth(b, in: all, today: today)) + "đ")
                            .font(AppFont.table(12)).foregroundStyle(Tokens.grey400).monospacedDigit()
                    }
                }
                .fixedSize()
                if b.isCollection {
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Tokens.grey300)
                }
            }
            .padding(.vertical, Space.s12)
            .opacity(b.soldOn != nil ? 0.6 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint(b.isCollection ? "Opens its pieces" : "Opens it to update the value")
    }
}

/// A collection's page: what it's worth together, then each piece. Add a piece at the end of
/// the list; tap one to update its value.
struct CollectionSheet: View {
    var collectionId: String
    @Environment(AppState.self) private var app
    @Query private var all: [Belonging]
    @State private var open: BelongingSheetID?
    @State private var addingPiece = false
    @State private var gettingPictures = false
    @Environment(\.modelContext) private var context

    var body: some View {
        let hidden = app.assetsHidden
        NavigationStack {
            if let c = all.first(where: { $0.id == collectionId }) {
                let pieces = BelongingMath.pieces(of: c, in: all)
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.s12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your value").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                                Text(hidden ? "•••" : Money.format(BelongingMath.worth(c, in: all, today: app.today)) + "đ")
                                    .font(AppFont.heading(16, .semibold)).monospacedDigit()
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Quick sale").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                                Text(hidden ? "•••" : Money.format(BelongingMath.quickWorth(c, in: all, today: app.today)) + "đ")
                                    .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text700).monospacedDigit()
                            }
                        }
                        .padding(Space.s16)
                        .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                        .accessibilityElement(children: .combine)
                        if !pieces.isEmpty {
                            // What went in, and the shape the pieces are in.
                            let kept = pieces.filter { $0.soldOn == nil }
                            let paidIn = kept.reduce(0) { $0 + $1.paid }
                            let soldCount = pieces.count - kept.count
                            let shapes = BelongingCondition.allCases.compactMap { k -> String? in
                                let n = kept.filter { $0.condition == k }.count
                                return n > 0 ? "\(n) \(k.short.lowercased())" : nil
                            } + (soldCount > 0 ? ["\(soldCount) sold"] : [])
                            Text((paidIn > 0 ? "Paid " + (hidden ? "•••" : AnalyticsView.compact(paidIn) + "đ") : "")
                                 + (paidIn > 0 && !shapes.isEmpty ? " · " : "") + shapes.joined(separator: " · "))
                                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                                .padding(.horizontal, Space.s4)
                        }

                        FinanceSectionTitle(title: "\(pieces.count) \(pieces.count == 1 ? "piece" : "pieces")") {
                            Button { open = .edit(c.id) } label: {
                                Text("Edit")
                                    .font(AppFont.main(14, .semibold))
                                    .foregroundStyle(Tokens.brand600)
                                    .frame(minHeight: 44)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit the collection")
                        }
                        VStack(spacing: 0) {
                            ForEach(pieces) { p in
                                BelongingRow(belonging: p, all: all, today: app.today, hidden: hidden) { open = .edit(p.id) }
                                Divider().overlay(Tokens.bd0).padding(.leading, 56)
                            }
                            // Text and icon, no border: the same as Sync.
                            Button { addingPiece = true } label: {
                                HStack(spacing: Space.s4) {
                                    Image(systemName: "plus")
                                    Text("Add a piece")
                                }
                                .font(AppFont.main(14, .semibold))
                                .foregroundStyle(Tokens.brand600)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 52)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Space.s16)
                        .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                        let missing = c.icon == .lego ? pieces.filter { $0.imageData == nil && $0.code.flatMap(LegoCatalog.find) != nil } : []
                        if !missing.isEmpty {
                            // Text and icon, no border: the same as Sync.
                            Button { Task { await getPictures(missing) } } label: {
                                HStack(spacing: Space.s4) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text(gettingPictures ? "Getting pictures…" : "Get set pictures (\(missing.count))")
                                }
                                .font(AppFont.main(14, .semibold))
                                .foregroundStyle(Tokens.brand600)
                                .frame(minHeight: 44)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .disabled(gettingPictures)
                            .padding(.horizontal, Space.s4)
                        }
                        Text("Each piece keeps its own value, from what you paid and its condition. Update one when you see a real price.")
                            .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                            .padding(.horizontal, Space.s4)
                    }
                    .padding(.horizontal, Space.s16)
                    .padding(.vertical, Space.s8)
                }
                .background(Tokens.canvas)
                .sheetHeader(c.name)
                .sheet(isPresented: $addingPiece) { BelongingSheet(parent: c).sheetSurface() }
                .sheet(item: $open) { which in
                    Group {
                        if case .edit(let id) = which, let b = all.first(where: { $0.id == id }) {
                            BelongingSheet(editing: b)
                        }
                    }
                    .sheetSurface()
                }
            } else {
                // Deleted from its own edit sheet.
                Color.clear.sheetHeader("Collection")
            }
        }
        .presentationDetents([.large])
    }

    /// Lego pieces with a code: their pictures, one at a time, kept on the phone.
    private func getPictures(_ pieces: [Belonging]) async {
        gettingPictures = true
        for p in pieces {
            guard let set = p.code.flatMap(LegoCatalog.find), let data = await LegoCatalog.picture(for: set) else { continue }
            p.imageData = data
            try? context.save()
        }
        gettingPictures = false
    }
}

extension BelongingGroup {
    var tint: LifeTint {
        switch self {
        case .lasting: .lasting
        case .everyday: .everyday
        case .collection: .collection
        }
    }
}

/// Overview › Belongings: three cards like "Invested in people": what holds value, everyday
/// things, collections. Kept out of Total Asset unless counted in (Finance › •••).
struct BelongingCards: View {
    var belongings: [Belonging]
    var today: String
    var hidden: Bool
    var counted: Bool
    var onOpen: (BelongingGroup) -> Void
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            FinanceSectionTitle(title: "Things you own") {
                if !belongings.isEmpty {
                    Text("≈ " + (hidden ? "•••" : AnalyticsView.compact(BelongingMath.total(belongings, today: today)) + "đ"))
                        .font(AppFont.main(14, .semibold)).foregroundStyle(Tokens.text700).monospacedDigit()
                }
            }
            ScrollView(.horizontal) {
                HStack(spacing: Space.s12) {
                    ForEach(BelongingGroup.allCases, id: \.self) { g in
                        let items = BelongingMath.counted(g, in: belongings)
                        let shown = BelongingMath.shown(g, in: belongings)
                        Button { belongings.isEmpty ? onAdd() : onOpen(g) } label: {
                            LifeCard(tint: g.tint, title: g.title,
                                     amount: BelongingMath.total(items, today: today),
                                     sub: shown.isEmpty ? g.emptyLine : Self.count(shown.count, g)
                                         + " · " + shown.prefix(2).map(\.name).joined(separator: ", "),
                                     hidden: hidden,
                                     amountText: shown.isEmpty ? "Nothing yet"
                                         : items.isEmpty ? "Nothing inside yet" : nil)
                                .frame(width: 168)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Space.s20)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -Space.s20)
            Text(counted ? "Counted in your Total Asset." : "Kept apart from your Total Asset.")
                .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                .padding(.horizontal, Space.s4)
        }
    }
}

extension BelongingCards {
    /// "3 things", "1 collection".
    static func count(_ n: Int, _ g: BelongingGroup) -> String {
        let word = g == .collection ? (n == 1 ? "collection" : "collections") : (n == 1 ? "thing" : "things")
        return "\(n) \(word)"
    }
}

/// One card opened: the things in that group. A collection opens its pieces.
struct BelongingGroupSheet: View {
    var group: BelongingGroup
    @Environment(AppState.self) private var app
    @Query private var all: [Belonging]
    @State private var open: BelongingSheetID?
    @State private var startingCollection = false
    /// The collection just made on the picker: its page opens once the picker is gone.
    @State private var made: String?

    var body: some View {
        let hidden = app.assetsHidden
        let items = BelongingMath.counted(group, in: all)
        let shown = BelongingMath.shown(group, in: all)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Your value").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                            Text(hidden ? "•••" : Money.format(BelongingMath.total(items, today: app.today)) + "đ")
                                .font(AppFont.heading(16, .semibold)).monospacedDigit()
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Quick sale").font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                            Text(hidden ? "•••" : Money.format(BelongingMath.quickTotal(items, today: app.today)) + "đ")
                                .font(AppFont.heading(16, .semibold)).foregroundStyle(Tokens.text700).monospacedDigit()
                        }
                    }
                    .padding(Space.s16)
                    .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                    .accessibilityElement(children: .combine)

                    // Text and icon, no border: the same as Sync.
                    FinanceSectionTitle(title: group == .collection ? "Your collections" : "Your things") {
                        Button { group == .collection ? (startingCollection = true) : (open = .new) } label: {
                            HStack(spacing: Space.s4) {
                                Image(systemName: "plus")
                                Text("Add")
                            }
                            .font(AppFont.main(14, .semibold))
                            .foregroundStyle(Tokens.brand600)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(group == .collection ? "Start a collection" : "Add a thing")
                    }
                    VStack(spacing: 0) {
                        if shown.isEmpty {
                            Text("Nothing yet: " + group.emptyLine.lowercased() + ".")
                                .font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, Space.s16)
                        }
                        ForEach(Array(shown.enumerated()), id: \.element.id) { i, b in
                            if i > 0 { Divider().overlay(Tokens.bd0).padding(.leading, 56) }
                            BelongingRow(belonging: b, all: all, today: app.today, hidden: hidden) {
                                open = b.isCollection ? .collection(b.id) : .edit(b.id)
                            }
                        }
                    }
                    .padding(.horizontal, Space.s16)
                    .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                    Text(group.hint)
                        .font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                        .padding(.horizontal, Space.s4)
                }
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
            }
            .background(Tokens.canvas)
            .sheetHeader(group.title)
            .sheet(item: $open) { which in
                Group {
                    switch which {
                    case .new: BelongingSheet()
                    case .edit(let id): if let b = all.first(where: { $0.id == id }) { BelongingSheet(editing: b) }
                    case .collection(let id): CollectionSheet(collectionId: id)
                    default: EmptyView()
                    }
                }
                .sheetSurface()
            }
            .sheet(isPresented: $startingCollection, onDismiss: {
                if let id = made { made = nil; open = .collection(id) }
            }) {
                CollectionStartSheet { made = $0 }.sheetSurface()
            }
        }
        .presentationDetents([.large])
    }
}

/// Start a collection: pick what you collect — a kind, or a brand under it — and its page opens
/// to add the pieces. Brands are just names to tap (no logos).
struct CollectionStartSheet: View {
    /// The collection picked or made (an existing one with the same name opens instead).
    var onPick: (String) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @Query private var all: [Belonging]
    @State private var custom = false

    struct Kind: Identifiable {
        var id: String { title }
        var title: String
        var hint: String
        var icon: BelongingIcon
        var brands: [String]
    }

    static let kinds: [Kind] = [
        Kind(title: "Building toys", hint: "Sets you build", icon: .lego,
             brands: ["Lego", "Bandai / Gundam", "Mega Bloks", "Keeppley"]),
        Kind(title: "Cards", hint: "Trading and sports cards", icon: .cards,
             brands: ["Pokémon TCG", "One Piece Card Game", "Yu-Gi-Oh!", "Magic: The Gathering", "Panini"]),
        Kind(title: "Board games", hint: "Boxes on the shelf", icon: .boardGame,
             brands: ["Catan", "Ma Sói", "Splendor", "Monopoly"]),
        Kind(title: "Figures & art toys", hint: "Figures, blind boxes, models", icon: .figure,
             brands: ["Pop Mart / Labubu", "Funko Pop", "Bearbrick", "Hot Wheels", "Nendoroid"]),
        Kind(title: "Sneakers", hint: "Pairs worth keeping", icon: .sneakers,
             brands: ["Nike / Jordan", "Adidas", "New Balance", "Converse"]),
        Kind(title: "Bags & fashion", hint: "Pieces that keep a resale price", icon: .bag,
             brands: ["Louis Vuitton", "Chanel", "Gucci", "Coach", "Charles & Keith"]),
        Kind(title: "Watches", hint: "One or many", icon: .watch,
             brands: ["Rolex", "Omega", "Seiko", "Casio / G-Shock", "Citizen"]),
        Kind(title: "Coins & notes", hint: "Old money, commemorative coins", icon: .coins,
             brands: ["Tiền xu", "Tiền giấy cũ", "Xu kỷ niệm", "Xu vàng / bạc"]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s12) {
                    Text("What do you collect? Tap a kind, or a name under it.")
                        .font(AppFont.main(14)).foregroundStyle(Tokens.grey400)
                        .padding(.horizontal, Space.s4)
                    ForEach(Self.kinds) { k in
                        VStack(alignment: .leading, spacing: Space.s12) {
                            Button { pick(k.title, k.icon) } label: {
                                HStack(spacing: Space.s12) {
                                    BelongingTile(icon: k.icon, size: 40, color: LifeTint.collection.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(k.title).font(AppFont.table(15, .semibold)).foregroundStyle(Tokens.text900)
                                        Text(k.hint).font(AppFont.table(12)).foregroundStyle(Tokens.grey400)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Tokens.grey300)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            FlowLayout {
                                ForEach(k.brands, id: \.self) { b in
                                    Button { pick(b, k.icon) } label: {
                                        Text(b)
                                            .font(AppFont.main(13, .medium))
                                            .foregroundStyle(Tokens.text700)
                                            .padding(.horizontal, Space.s12)
                                            .frame(minHeight: 32)
                                            .background(Tokens.bg4, in: .capsule)
                                            .frame(minHeight: 44)
                                            .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Start a \(b) collection")
                                }
                            }
                        }
                        .padding(Space.s16)
                        .background(Tokens.card, in: .rect(cornerRadius: Corner.c20))
                    }
                    Button { custom = true } label: {
                        HStack(spacing: Space.s4) {
                            Image(systemName: "plus")
                            Text("Something else…")
                        }
                        .font(AppFont.main(14, .semibold))
                        .foregroundStyle(Tokens.brand600)
                        .frame(minHeight: 44)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Space.s4)
                }
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s8)
            }
            .background(Tokens.canvas)
            .sheetHeader("New collection")
            .sheet(isPresented: $custom, onDismiss: {
                // Made by hand: open the newest collection.
                if let newest = all.filter(\.isCollection).max(by: { $0.createdAt < $1.createdAt }),
                   newest.createdAt > .now.addingTimeInterval(-120) {
                    onPick(newest.id)
                    dismiss()
                }
            }) {
                BelongingSheet(asCollection: true).sheetSurface()
            }
        }
        .presentationDetents([.large])
    }

    /// Opens the collection with this name, or makes it.
    private func pick(_ name: String, _ icon: BelongingIcon) {
        let key = AssetImportSheet.key(name)
        if let have = all.first(where: { $0.isCollection && AssetImportSheet.key($0.name) == key }) {
            onPick(have.id)
        } else {
            let c = Belonging(name: name, icon: icon, mode: .estimate, paid: 0, boughtOn: app.today)
            c.isCollection = true
            context.insert(c)
            try? context.save()
            onPick(c.id)
        }
        dismiss()
    }
}

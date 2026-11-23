import Charts
import SwiftData
import SwiftUI

/// One asset: what it is worth, how much was put in, how much it grew, its line over time and
/// everything that happened to it. Add money, take some out, or write down what it is worth now.
/// Only what the user writes down — nothing connects to a bank or a market.
struct AssetDetailView: View {
    let assetId: String
    /// Opened as a sheet from the asset list (half height, drag up for full): a ✕ to close
    /// instead of a back button, and no room kept for the tab bar.
    var asSheet = false
    /// Called when Add money / Take out / Update value opens, so the sheet can grow to full
    /// height and the small number-pad sheet only covers its lower part.
    var onAct: (() -> Void)? = nil
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @Query(sort: \AssetMove.date, order: .reverse) private var moves: [AssetMove]

    @State private var moving: AssetMoveKind?
    /// The move just saved, offered for undo for a few seconds.
    @State private var justSaved: AssetMove?
    /// A history line waiting for "Delete" to be confirmed.
    @State private var deletingMove: AssetMove?
    @State private var editing = false
    @State private var confirmDelete = false
    /// Bumped after a sync so the price line redraws.
    @State private var synced = 0
    @State private var settingPremium = false
    @State private var premiumText = ""

    var body: some View {
        if let asset = assets.first(where: { $0.id == assetId }) {
            content(asset)
        } else {
            Text("This asset was removed.")
                .font(AppFont.body())
                .foregroundStyle(Tokens.grey400)
        }
    }

    private func content(_ asset: Asset) -> some View {
        let growth = AssetMath.growth(asset, moves: moves)
        let mine = moves.filter { $0.assetId == asset.id }
        let line = AssetMath.valueLine(asset, moves: moves)
        let hidden = app.assetsHidden
        return ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                // Worth now, put in, growth
                VStack(alignment: .leading, spacing: Space.s12) {
                    HStack(spacing: Space.s12) {
                        AssetTile(icon: asset.icon)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(asset.name).font(AppFont.bodyLarge(.semibold)).foregroundStyle(Tokens.text900)
                            Text("\(asset.kind.label) · updated \(FinanceText.dayLabel(asset.updatedOn))")
                                .font(AppFont.capture())
                                .foregroundStyle(Tokens.grey400)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    if let note = asset.note, !note.isEmpty {
                        Text(note).font(AppFont.body()).foregroundStyle(Tokens.text700)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let q = asset.quantity, let unit = asset.unit {
                        // Held in units: what you hold is the big number; đồng is just the reading.
                        Text("You hold").font(AppFont.body(.medium)).foregroundStyle(Tokens.text700)
                        // Numbers big, units small: "5 chỉ 5 phân", "780 $".
                        HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                            if hidden {
                                Text("••••••").font(AppFont.amount(32)).foregroundStyle(Tokens.text900)
                            } else {
                                ForEach(Array(Self.quantityParts(q, unit).enumerated()), id: \.offset) { _, part in
                                    Text(part.number).font(AppFont.amount(32)).foregroundStyle(Tokens.text900).monospacedDigit()
                                    Text(part.unit).font(AppFont.currency(for: 32)).foregroundStyle(Tokens.grey400)
                                        .padding(.trailing, Space.s4)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                        holdingLine(asset, unit, hidden: hidden).id(synced)
                    } else {
                        Text("Worth now").font(AppFont.body(.medium)).foregroundStyle(Tokens.text700)
                        AmountText(value: asset.amount, size: 32, hidden: hidden)
                    }
                    Divider().overlay(Tokens.bd0)
                    if let growth {
                        stat("Put in so far", amount: growth.putIn, hidden: hidden)
                        HStack {
                            Text("Growth").foregroundStyle(Tokens.text700)
                            Spacer()
                            if hidden {
                                Text("••••••").foregroundStyle(Tokens.text900)
                            } else {
                                Text(Self.signed(growth.change) + " đ" + (growth.pct.map { "  (\(Self.signedPct($0)))" } ?? ""))
                                    .foregroundStyle(growth.change >= 0 ? Tokens.brand700 : Tokens.text700)
                                    .monospacedDigit()
                            }
                        }
                        .font(AppFont.body(.medium))
                        .accessibilityElement(children: .combine)
                    } else {
                        Text("Add money or update the value once, and this shows how much you put in and how much it grew.")
                            .font(AppFont.capture())
                            .foregroundStyle(Tokens.grey400)
                    }
                }
                .padding(Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))

                // Looks like gold, dollars or a coin but kept in đồng: offer to keep it in its unit.
                if asset.unit == nil, let guess = HoldingUnit.guess(asset.icon) {
                    Button { editing = true } label: {
                        HStack(spacing: Space.s8) {
                            Image(systemName: "scalemass").foregroundStyle(Tokens.brand600)
                            Text("Keep this in \(guess.label)? Type how many you hold, and the price does the rest.")
                                .font(AppFont.capture()).foregroundStyle(Tokens.text700)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Tokens.grey300)
                        }
                        .padding(Space.s12)
                        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                    }
                    .buttonStyle(.plain)
                }

                // Actions
                HStack(spacing: Space.s8) {
                    // Held in units you add or take out chỉ / $ / BTC, and correct how many you hold.
                    let inUnits = asset.unit != nil && asset.quantity != nil
                    action(inUnits ? "Add" : "Add money", .plus, .putIn)
                    action("Take out", .minus, .takeOut)
                    action(inUnits ? "Set amount" : "Update value", inUnits ? .pencilBold : .chartLineUpBold, .value)
                }

                // Line over time
                if line.count > 1 {
                    VStack(alignment: .leading, spacing: Space.s8) {
                        Text("Over time").font(AppFont.h6()).foregroundStyle(Tokens.text900)
                            .accessibilityAddTraits(.isHeader)
                        Chart(line, id: \.date) { p in
                            AreaMark(x: .value("Day", Day.date(p.date)), y: .value("Worth", p.value))
                                .foregroundStyle(LinearGradient(colors: [Tokens.brand500.opacity(0.25), Tokens.brand500.opacity(0)],
                                                                startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Day", Day.date(p.date)), y: .value("Worth", p.value))
                                .foregroundStyle(Tokens.brand500)
                                .lineStyle(StrokeStyle(lineWidth: 1.5))
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                                AxisGridLine().foregroundStyle(Tokens.bd0)
                                AxisValueLabel {
                                    if !hidden, let n = v.as(Int.self) { Text(DueText.short(n)).font(AppFont.main(11)) }
                                }
                            }
                        }
                        .frame(height: 150)
                        .accessibilityLabel("\(asset.name) over time")
                        .accessibilityValue(hidden ? "Hidden" : "From \(Money.format(line[0].value)) to \(Money.format(asset.amount)) dong")
                    }
                    .padding(Space.s16)
                    .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
                }

                // History
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text("History").font(AppFont.h6()).foregroundStyle(Tokens.text900)
                        .accessibilityAddTraits(.isHeader)
                    if mine.isEmpty {
                        Text("Nothing recorded yet.").font(AppFont.capture()).foregroundStyle(Tokens.grey400)
                            .padding(.vertical, Space.s8)
                    }
                    ForEach(Array(mine.enumerated()), id: \.element.id) { i, m in
                        if i > 0 { Divider().overlay(Tokens.bd0) }
                        HStack(spacing: Space.s12) {
                            Image(systemName: m.kind == .putIn ? "arrow.down.to.line" : m.kind == .takeOut ? "arrow.up.right" : "chart.line.uptrend.xyaxis")
                                .font(.system(size: 14))
                                .foregroundStyle(Tokens.text700)
                                .frame(width: 32, height: 32)
                                .background(Tokens.bg3, in: .circle)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.kind.label).font(AppFont.body(.semibold)).foregroundStyle(Tokens.text900)
                                Text(FinanceText.dayLabel(m.date)).font(AppFont.capture()).foregroundStyle(Tokens.grey400)
                            }
                            Spacer()
                            AmountText(value: abs(m.amount), sign: m.amount < 0 ? "-" : "+", hidden: hidden,
                                       color: m.amount >= 0 ? Tokens.brand700 : Tokens.text900)
                        }
                        .padding(.vertical, Space.s8)
                        .contentShape(.rect)
                        .accessibilityElement(children: .combine)
                        // Hold a line to delete it (a mistake, a double entry).
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { deletingMove = m }
                        }
                        .accessibilityAction(named: "Delete") { deletingMove = m }
                    }
                }
                .padding(Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }
            .padding(.horizontal, Space.s20)
            // Room for the floating tab bar, so the end of the page can scroll clear of it.
            .padding(.bottom, asSheet ? Space.s24 : 96)
        }
        .background(Tokens.canvas)
        .modifier(AssetDetailTop(title: asset.name, asSheet: asSheet,
                                 goldPremium: asset.unit?.isGold == true ? { askPremium() } : nil,
                                 onEdit: { editing = true }, onDelete: { confirmDelete = true }))
        .alert("Gold price in Vietnam", isPresented: $settingPremium) {
            TextField("e.g. 18", text: $premiumText).keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                Market.goldPremium = Double(premiumText.replacingOccurrences(of: ",", with: ".")) ?? 0
                LocalStore(context: context).revalueHoldings(today: app.today)
                synced += 1
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("How many percent above the world price you pay, like SJC. 0 uses the world price as it is.")
        }

        // The number pad slides up over the lower part, down to the bottom edge; tap above to close.
        .overlay(alignment: .bottom) {
            if let kind = moving {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { close(nil) }
                        .accessibilityHidden(true)
                    QuickMoveSheet(move: QuickMove(asset: asset, kind: kind), moves: moves, today: app.today) { close($0) }
                        .transition(.move(edge: .bottom))
                }
                .transition(.opacity)
            } else if let m = justSaved {
                undoBar(m, hidden: hidden)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // The undo offer goes away on its own after a few seconds.
        .task(id: justSaved?.id) {
            guard justSaved != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.snappy) { justSaved = nil }
        }
        .confirmationDialog("Delete this line?", isPresented: Binding(
            get: { deletingMove != nil }, set: { if !$0 { deletingMove = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let m = deletingMove { withAnimation(.snappy) { LocalStore(context: context).removeMove(m) } }
                deletingMove = nil
            }
            Button("Keep it", role: .cancel) { deletingMove = nil }
        } message: {
            Text("What it's worth and what you put in go back as if it never happened.")
        }
        .sheet(isPresented: $editing) { AddAssetSheet(editing: asset).sheetSurface() }
        .confirmationDialog("Delete “\(asset.name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete asset", role: .destructive) {
                LocalStore(context: context).removeAsset(asset, today: app.today)
                dismiss()
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Its history goes with it.")
        }
    }

    /// "≈ 55,005,530 đ", then "1 chỉ = 11,001,106 đ · price 22 Nov 23:12 · world gold price"
    /// (Sync is on Finance's top bar).
    private func holdingLine(_ asset: Asset, _ unit: HoldingUnit, hidden: Bool) -> some View {
        let price = Market.price(unit)
        return VStack(alignment: .leading, spacing: 2) {
            Text(hidden ? "≈ ••• đ" : "≈ " + Money.format(asset.amount) + " đ")
                .font(AppFont.bodyLarge(.semibold)).foregroundStyle(Tokens.text700)
                .monospacedDigit()
            Text((price.map { "1 \(unit.label) = " + Money.format(Int($0.rounded())) + " đ" } ?? "No price yet")
                 + (Market.updatedAt.map { " · " + $0.formatted(.dateTime.day().month(.abbreviated).hour().minute()) } ?? "")
                 + (unit.isGold ? (Market.goldPremium == 0 ? " · world price" : " · world +\(Self.plain(Market.goldPremium))%") : ""))
                .font(AppFont.capture()).foregroundStyle(Tokens.grey400)
                .monospacedDigit()
                .lineLimit(2)
        }
    }

    /// "5 chỉ 5 phân", "1000 $", "0,05 BTC": gold in chỉ and phân, a comma for decimals.
    static func quantityText(_ q: Double, _ unit: HoldingUnit) -> String {
        if let (chi, phan) = HoldingUnit.chiPhan(q, unit) {
            if chi == 0 { return plainNumber(phan) + " phân" }
            return "\(chi) chỉ" + (phan == 0 ? "" : " " + plainNumber(phan) + " phân")
        }
        return plainNumber(q) + " " + unit.label
    }

    /// [("5", "chỉ"), ("5", "phân")], or [("780", "$")].
    static func quantityParts(_ q: Double, _ unit: HoldingUnit) -> [(number: String, unit: String)] {
        if let (chi, phan) = HoldingUnit.chiPhan(q, unit) {
            var parts: [(String, String)] = []
            if chi > 0 || phan == 0 { parts.append(("\(chi)", "chỉ")) }
            if phan > 0 { parts.append((plainNumber(phan), "phân")) }
            return parts
        }
        return [(plainNumber(q), unit.label)]
    }

    static func plainNumber(_ q: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "vi")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 6
        return f.string(from: NSNumber(value: q)) ?? "\(q)"
    }

    private static func plain(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }

    private func askPremium() {
        premiumText = Market.goldPremium == 0 ? "" : Self.plain(Market.goldPremium)
        settingPremium = true
    }

    private func close(_ saved: AssetMove?) {
        withAnimation(.snappy) {
            moving = nil
            justSaved = saved
        }
    }

    /// "Put in +50,000,000đ · Undo", at the bottom for a few seconds after saving.
    private func undoBar(_ m: AssetMove, hidden: Bool) -> some View {
        HStack(spacing: Space.s12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Tokens.brand500)
            Text(m.kind.label + " " + (hidden ? "•••" : (m.amount < 0 ? "−" : "+") + Money.format(abs(m.amount)) + "đ"))
                .font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text900)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: Space.s8)
            Button("Undo") {
                withAnimation(.snappy) {
                    LocalStore(context: context).removeMove(m)
                    justSaved = nil
                }
            }
            .font(AppFont.main(14, .semibold))
            .foregroundStyle(Tokens.brand600)
        }
        .padding(.horizontal, Space.s16)
        .frame(minHeight: 48)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Space.s20)
        .padding(.bottom, Space.s8)
    }

    private func stat(_ label: String, amount: Int, hidden: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(Tokens.text700)
            Spacer()
            AmountText(value: amount, hidden: hidden)
        }
        .font(AppFont.body(.medium))
        .accessibilityElement(children: .combine)
    }

    private func action(_ title: String, _ icon: Icon, _ kind: AssetMoveKind) -> some View {
        Button { withAnimation(.snappy) { moving = kind }; onAct?() } label: {
            // Every icon sits in the same box, so the icons and the labels line up across buttons.
            VStack(spacing: Space.s6) {
                AppIcon(icon, size: 20, relativeTo: .caption)
                    .frame(width: 24, height: 24)
                Text(title).font(AppFont.capture(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    .frame(height: 18)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .foregroundStyle(Tokens.brand700)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
            .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd1))
        }
        .buttonStyle(.plain)
    }

    static func signed(_ n: Int) -> String { (n < 0 ? "-" : "+") + Money.format(abs(n)) }
    static func signedPct(_ n: Int) -> String { (n < 0 ? "-" : "+") + "\(abs(n))%" }
}

extension AssetMoveKind: Identifiable {
    public var id: String { rawValue }
}

/// The asset's top bar: as a page, its name and a ••• menu (Edit, Delete) on the right; as a
/// sheet, the same menu on the left and ✕ on the right.
private struct AssetDetailTop: ViewModifier {
    let title: String
    let asSheet: Bool
    /// For gold held by the chỉ: set how much above the world price you pay.
    let goldPremium: (() -> Void)?
    let onEdit: () -> Void
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        if asSheet {
            content
                .sheetHeader(title, trailing: .close)
                .toolbar { ToolbarItem(placement: .topBarLeading) { menu } }
        } else {
            content
                .navigationTitle(title)
                .toolbarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { menu } }
        }
    }

    private var menu: some View {
        Menu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            if let goldPremium {
                Button("Gold price in Vietnam…", systemImage: "percent", action: goldPremium)
            }
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
        }
        .tint(Tokens.text900)
        .accessibilityLabel("More")
    }
}

/// An asset opened from a list: the detail at half height; drag or scroll up for the full page.
struct AssetSheet: View {
    let assetId: String
    @State private var detent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            AssetDetailView(assetId: assetId, asSheet: true) {
                withAnimation(.snappy) { detent = .large }
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .sheetSurface()
    }
}

/// Which asset's sheet is open.
struct AssetSheetID: Identifiable {
    let id: String
}

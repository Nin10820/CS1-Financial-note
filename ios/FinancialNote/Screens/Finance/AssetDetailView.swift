import Charts
import SwiftData
import SwiftUI

/// One asset: what it is worth, how much was put in, how much it grew, its line over time and
/// everything that happened to it. Add money, take some out, or write down what it is worth now.
/// Only what the user writes down — nothing connects to a bank or a market.
struct AssetDetailView: View {
    let assetId: String
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var assets: [Asset]
    @Query(sort: \AssetMove.date, order: .reverse) private var moves: [AssetMove]

    @State private var moving: AssetMoveKind?
    @State private var editing = false
    @State private var confirmDelete = false

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
                    Text("Worth now").font(AppFont.body(.medium)).foregroundStyle(Tokens.text700)
                    AmountText(value: asset.amount, size: 32, hidden: hidden)
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

                // Actions
                HStack(spacing: Space.s8) {
                    action("Add money", "plus", .putIn)
                    action("Take out", "minus", .takeOut)
                    action("Update value", "chart.line.uptrend.xyaxis", .value)
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
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Space.s16)
                .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s24)
        }
        .background(Tokens.bg3)
        .navigationTitle(asset.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", systemImage: "pencil") { editing = true }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $moving) { kind in AssetMoveSheet(asset: asset, kind: kind) }
        .sheet(isPresented: $editing) { AddAssetSheet(editing: asset) }
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

    private func stat(_ label: String, amount: Int, hidden: Bool) -> some View {
        HStack {
            Text(label).foregroundStyle(Tokens.text700)
            Spacer()
            AmountText(value: amount, hidden: hidden)
        }
        .font(AppFont.body(.medium))
        .accessibilityElement(children: .combine)
    }

    private func action(_ title: String, _ symbol: String, _ kind: AssetMoveKind) -> some View {
        Button { moving = kind } label: {
            VStack(spacing: Space.s4) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                Text(title).font(AppFont.capture(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
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

/// Add money, take some out, or write down what the asset is worth now.
struct AssetMoveSheet: View {
    let asset: Asset
    let kind: AssetMoveKind
    @Environment(AppState.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Int?
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0", text: Binding(
                            get: { amount.map(Money.format) ?? "" },
                            set: { amount = Int($0.filter(\.isNumber)) }))
                            .keyboardType(.numberPad)
                            .monospacedDigit()
                            .accessibilityLabel(question)
                        Text("đ").foregroundStyle(Tokens.grey400)
                    }
                } header: {
                    Text(question)
                } footer: {
                    Text(footer)
                }
                Section {
                    DatePicker("Day", selection: $date, in: ...Date.now, displayedComponents: .date)
                        .tint(Tokens.brand600)
                }
            }
            .font(AppFont.bodyLarge())
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        LocalStore(context: context).move(asset, kind, amount: amount ?? 0, date: Day.iso(date))
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { if kind == .value { amount = asset.amount } }
    }

    private var valid: Bool {
        guard let a = amount else { return false }
        switch kind {
        case .putIn: return a > 0
        case .takeOut: return a > 0 && a <= asset.amount
        case .value: return a >= 0 && a != asset.amount
        }
    }

    private var title: String {
        switch kind {
        case .putIn: "Add money"
        case .takeOut: "Take out"
        case .value: "Update value"
        }
    }

    private var question: String {
        switch kind {
        case .putIn: "How much did you put in?"
        case .takeOut: "How much did you take out?"
        case .value: "What is it worth now?"
        }
    }

    private var footer: String {
        switch kind {
        case .putIn: "Counted in \"Put in so far\"."
        case .takeOut: "Up to \(Money.format(asset.amount)) đ. Taken off \"Put in so far\"."
        case .value: "For a change in price or interest — not money you added. It shows as growth."
        }
    }
}

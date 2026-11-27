import SwiftUI

/// The number pad for amounts (Figma Finance App › Quick-note 1070:18153): a 3×4 grid
/// (7 8 9 / 4 5 6 / 1 2 3 / 000 0 ,) and a column on the right with the currency, delete and
/// a tall ✓ (next). Typing appends digits; "000" adds three zeros; delete drops the last digit.
/// In đồng the comma is off (no decimals); in another currency "000" becomes "00".
/// Amounts are kept in whole đồng. Pick another currency ($, €, gold by the chỉ…) and type in it:
/// the pad uses today's rate from ExchangeRate-API (see LiveRates), or a rate you type, and
/// hands back đồng, marked ≈. Gold has no live rate, so you type it once.
struct AmountPad: View {
    @Binding var value: Int?
    /// The ✓ key: go to the next line, or put the pad away. Without it there's no ✓ key
    /// (the sheet has its own Save).
    var onDone: (() -> Void)? = nil
    /// Typing in an asset's own unit (5 chỉ, 100 $, 0.05 BTC) instead of đồng: what's typed goes
    /// here as text ("2,5"), `value` is left alone, and the unit key just shows `unitLabel`.
    var unitText: Binding<String>? = nil
    var unitLabel = ""
    /// Decimals allowed in that unit (coins need more than gold).
    var unitDecimals = 2
    /// The ✓ key greys out and does nothing until there's something to save.
    var doneEnabled = true
    /// When set, the unit key switches units (gold: chỉ ⇄ phân) instead of being fixed.
    var onUnitTap: (() -> Void)? = nil
    /// Where typing goes, counted in digits from the right end (0 = at the end). Lets you tap
    /// into a number and change one digit (118 → 120) instead of typing it all again.
    var cursor: Binding<Int>? = nil

    private static let digits = ["7", "8", "9", "4", "5", "6", "1", "2", "3"]
    private static let limit = 100_000_000_000
    private static let keyHeight: CGFloat = 60

    /// The currency being typed in; đồng each time the pad opens.
    @State private var currency = PadCurrency.vnd
    /// What's typed while the currency isn't đồng, e.g. "12,5".
    @State private var typed = ""
    /// Rates in đồng the user typed, {"USD": 26000}. They win over today's rates.
    @AppStorage("padRates") private var ratesRaw = ""
    /// Today's rates in đồng, downloaded, and when that list was made.
    @AppStorage("padLiveRates") private var liveRaw = ""
    @AppStorage("padLiveRatesAt") private var liveAt: Double = 0
    @State private var askingRate: PadCurrency?
    @State private var rateText = ""

    private var rates: [String: Double] { Self.decode(ratesRaw) }
    private var live: [String: Double] { Self.decode(liveRaw) }

    private static func decode(_ raw: String) -> [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: Data(raw.utf8))) ?? [:]
    }

    private func rate(_ c: PadCurrency) -> Double? { c == .vnd ? 1 : rates[c.code] ?? live[c.code] }

    var body: some View {
        VStack(spacing: 0) {
            if currency != .vnd && unitText == nil { conversionLine }
            keypad
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.top, currency == .vnd || unitText != nil ? Space.s24 : Space.s12)
        .padding(.bottom, Space.s8)
        // Liquid Glass tray tinted the keyboard's grey: rounded on top, following the phone's
        // corners at the bottom, reaching under the home indicator. The system draws the glass
        // (and makes it solid with Reduce Transparency).
        .background {
            Color.clear
                .glassEffect(.regular.tint(Tokens.keypadTray.opacity(0.9)), in: UnevenRoundedRectangle(
                    topLeadingRadius: 28, bottomLeadingRadius: 48, bottomTrailingRadius: 48, topTrailingRadius: 28,
                    style: .continuous))
                .ignoresSafeArea(edges: .bottom)
        }
        // Place it at the bottom edge (a bottom safe-area inset): the tray runs under the home
        // indicator, so its round corners sit below the keys.
        .padding(.horizontal, Space.s4)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .task { await refreshRates() }
        .alert(askingRate.map { "1 \($0.symbol) = ? đ" } ?? "", isPresented: Binding(
            get: { askingRate != nil }, set: { if !$0 { askingRate = nil } })) {
            TextField(askingRate?.rateHint ?? "", text: $rateText).keyboardType(.decimalPad)
            Button("Cancel", role: .cancel) { askingRate = nil }
            // The main button: filled green, and only once there's a rate to save.
            Button("Save") { saveRate() }
                .keyboardShortcut(.defaultAction)
                .disabled(Double(rateText.replacingOccurrences(of: ",", with: ".")).map { $0 <= 0 } ?? true)
        } message: {
            Text("Type the rate you use. It stays on this phone.")
        }
    }

    /// "12,5 $ × 26,000 đ ≈ 325,000 đ" on a white card, and tap to change the rate.
    private var conversionLine: some View {
        Button { ask(currency) } label: {
            HStack(alignment: .firstTextBaseline, spacing: Space.s6) {
                Text((typed.isEmpty ? "0" : typed) + " " + currency.symbol)
                    .font(AppFont.main(17, .semibold)).foregroundStyle(Tokens.text900)
                Text("× " + Money.format(Int(rate(currency) ?? 0)) + " đ")
                    .font(AppFont.main(14, .medium)).foregroundStyle(Tokens.text700)
                Spacer(minLength: Space.s4)
                Text("≈ " + Money.format(value ?? 0) + " đ")
                    .font(AppFont.main(17, .semibold)).foregroundStyle(Tokens.brand700)
                Image(systemName: "pencil").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.text700)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Space.s16)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Tokens.keypadKey, in: .rect(cornerRadius: Corner.c16))
            .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd2, lineWidth: 0.5))
            .contentShape(.rect)
        }
        .buttonStyle(KeyPress())
        .padding(.bottom, Space.s8)
        .accessibilityHint("Changes the rate")
    }

    private var keypad: some View {
        HStack(alignment: .top, spacing: Space.s6) {
            Grid(horizontalSpacing: Space.s6, verticalSpacing: Space.s6) {
                ForEach(0..<3) { row in
                    GridRow {
                        ForEach(Self.digits[(row * 3)..<(row * 3 + 3)], id: \.self) { k in key(k) }
                    }
                }
                GridRow {
                    key(currency == .vnd && unitText == nil ? "000" : "00")
                    key("0")
                    key(",")
                }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: Space.s6) {
                currencyKey
                deleteKey.frame(maxHeight: onDone == nil ? .infinity : Self.keyHeight)
                if let onDone { confirmKey(onDone) }
            }
            .frame(width: 68)
            .frame(height: Self.keyHeight * 4 + Space.s6 * 3)
        }
    }

    /// A white key with a hairline edge and a soft shadow, as in Figma.
    private func face<Content: View>(_ fill: Color, edge: Bool = true,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(fill, in: .rect(cornerRadius: Corner.c16))
            .overlay {
                if edge {
                    RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd2, lineWidth: 0.5)
                }
            }
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            .contentShape(.rect)
    }

    private func key(_ k: String) -> some View {
        // Đồng has no decimals, so the comma is faded and does nothing.
        let off = k == "," && currency == .vnd && unitText == nil
        return Button { press(k) } label: {
            face(Tokens.keypadKey.opacity(0.8)) {
                Text(k).font(.system(size: 22, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(off ? Tokens.grey300 : Tokens.text900)
            }
            .frame(height: Self.keyHeight)
        }
        .buttonStyle(KeyPress())
        .disabled(off)
        .accessibilityLabel(k == "000" ? "Three zeros" : k == "00" ? "Two zeros"
                            : k == "," ? (off ? "Comma, not used for đồng" : "Comma") : k)
    }

    /// The currency to type in. Đồng by default; the others need a rate you type once.
    @ViewBuilder
    private var currencyKey: some View {
        if unitText != nil, let onUnitTap {
            // Gold: tap to type in chỉ or in phân.
            Button(action: onUnitTap) {
                face(Tokens.keypadKey.opacity(0.8)) {
                    HStack(spacing: 3) {
                        Text(unitLabel).font(AppFont.main(unitLabel.count > 3 ? 14 : 17, .semibold)).foregroundStyle(Tokens.text700)
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Tokens.grey400)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: Self.keyHeight)
            }
            .buttonStyle(KeyPress())
            .accessibilityLabel("Typing in \(unitLabel)")
            .accessibilityHint("Switches between chỉ and phân")
        } else if unitText != nil {
            // The asset's own unit: nothing to pick.
            face(Tokens.keypadKey.opacity(0.5), edge: false) {
                Text(unitLabel).font(AppFont.main(unitLabel.count > 2 ? 14 : 18, .semibold)).foregroundStyle(Tokens.grey400)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
            }
            .frame(height: Self.keyHeight)
            .accessibilityLabel("Typing in \(unitLabel)")
        } else {
            currencyMenu
        }
    }

    private var currencyMenu: some View {
        Menu {
            currencyPicker
            if liveAt > 0 {
                // The free rates ask to name their source.
                Section {
                    Text("Rates by \(LiveRates.source), \(Date(timeIntervalSince1970: liveAt).formatted(.dateTime.day().month(.abbreviated)))")
                }
            }
            if currency != .vnd {
                Button("Change the rate", systemImage: "pencil") { ask(currency) }
                if rates[currency.code] != nil, live[currency.code] != nil {
                    Button("Use today's rate", systemImage: "arrow.clockwise") { useLive(currency) }
                }
            }
        } label: {
            face(Tokens.keypadKey.opacity(0.8)) {
                HStack(spacing: 3) {
                    Text(currency.symbol).font(AppFont.main(currency.symbol.count > 1 ? 15 : 18, .semibold)).foregroundStyle(Tokens.text700)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.grey400)
                }
                .padding(.horizontal, 4)
            }
            .frame(height: Self.keyHeight)
        }
        .buttonStyle(KeyPress())
        .accessibilityLabel("Currency, \(currency.name)")
    }

    private var currencyPicker: some View {
        Picker("Currency", selection: Binding(get: { currency }, set: { pick($0) })) {
            ForEach(PadCurrency.allCases) { c in
                Text("\(c.name) (\(c.symbol))").tag(c)
            }
        }
    }

    // MARK: Currency

    private func pick(_ c: PadCurrency) {
        guard c != currency else { return }
        if rate(c) != nil { switchTo(c); return }
        // No rate yet: try today's list first, and ask only if that fails (or it's gold).
        Task {
            await refreshRates(force: true)
            if rate(c) != nil { switchTo(c) } else { ask(c) }
        }
    }

    /// Download today's rates when the list is missing or older than 12 hours. Quietly does
    /// nothing when offline; typed rates still work.
    private func refreshRates(force: Bool = false) async {
        let fetchedAt = UserDefaults.standard.double(forKey: "padLiveRatesFetched")
        guard force || Date().timeIntervalSince1970 - fetchedAt > 12 * 3600 else { return }
        let codes = PadCurrency.allCases.filter { $0 != .vnd && $0 != .gold }.map(\.code)
        guard let got = try? await LiveRates.fetch(codes: codes), !got.rates.isEmpty,
              let data = try? JSONEncoder().encode(got.rates) else { return }
        liveRaw = String(decoding: data, as: UTF8.self)
        liveAt = got.updated.timeIntervalSince1970
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "padLiveRatesFetched")
        if currency != .vnd { recompute() }
    }

    /// Forget the typed rate and go back to today's.
    private func useLive(_ c: PadCurrency) {
        var set = rates
        set[c.code] = nil
        if let data = try? JSONEncoder().encode(set) { ratesRaw = String(decoding: data, as: UTF8.self) }
        recompute()
    }

    private func switchTo(_ c: PadCurrency) {
        withAnimation(.snappy) { currency = c }
        typed = ""
    }

    private func ask(_ c: PadCurrency) {
        rateText = rate(c).map { Self.plain($0) } ?? ""
        askingRate = c
    }

    private func saveRate() {
        guard let c = askingRate,
              let r = Double(rateText.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }),
              r > 0 else { askingRate = nil; return }
        var set = rates
        set[c.code] = r
        if let data = try? JSONEncoder().encode(set) { ratesRaw = String(decoding: data, as: UTF8.self) }
        askingRate = nil
        if c == currency { recompute() } else { switchTo(c) }
    }

    /// "26000" not "26000.0".
    private static func plain(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }

    private func recompute() {
        guard let r = rate(currency) else { return }
        let n = Double(typed.replacingOccurrences(of: ",", with: ".")) ?? 0
        let v = Int((n * r).rounded())
        value = typed.isEmpty ? nil : min(v, Self.limit - 1)
    }

    private var deleteKey: some View {
        Button { press("⌫") } label: {
            face(Tokens.keypadDelete, edge: false) {
                Image(systemName: "delete.left.fill").font(.system(size: 20))
                    .foregroundStyle(Tokens.text700)
            }
        }
        .buttonStyle(KeyPress())
        .accessibilityLabel("Delete")
    }

    /// The tall green ✓, two keys high: next line, or close the pad.
    private func confirmKey(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            face(doneEnabled ? Tokens.keypadConfirm : Tokens.keypadDelete, edge: false) {
                Image(systemName: "checkmark").font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(doneEnabled ? Tokens.onKeypadConfirm : Tokens.grey400)
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(KeyPress())
        .disabled(!doneEnabled)
        .accessibilityLabel("Next")
    }

    private func pressTyped(_ k: String) {
        var t = typed
        pressTypedImpl(k, &t)
        typed = t
        recompute()
    }

    private func press(_ k: String) {
        if let unitText {
            var t = unitText.wrappedValue
            if let cursor, cursor.wrappedValue > 0 {
                guard let edited = Self.insert(k, into: t, fromRight: cursor.wrappedValue, decimals: unitDecimals) else { return }
                t = edited
                cursor.wrappedValue = min(cursor.wrappedValue, t.count)
            } else {
                pressTypedImpl(k, &t, decimals: unitDecimals)
            }
            unitText.wrappedValue = t
            return
        }
        if currency != .vnd { pressTyped(k); return }
        if let cursor, cursor.wrappedValue > 0 {
            // In the middle of the number: put the digits (or take one away) right there.
            guard k != ",", let s = Self.insert(k, into: value.map(String.init) ?? "", fromRight: cursor.wrappedValue,
                                                decimals: nil) else { return }
            let digits = String(s.drop { $0 == "0" })
            guard let v = Int(digits.isEmpty ? "0" : digits), v < Self.limit else { return }
            value = v == 0 ? nil : v
            cursor.wrappedValue = min(cursor.wrappedValue, digits.count)
            return
        }
        var v = value ?? 0
        switch k {
        case "⌫": v /= 10
        case "000": v *= 1000
        default: v = v * 10 + (Int(k) ?? 0)
        }
        guard v < Self.limit else { return }
        value = v == 0 && k == "⌫" ? nil : v
    }
}

extension AmountPad {
    /// `text` with `k` typed (or ⌫ pressed) at `fromRight` characters before the end. Nil when it
    /// can't go there: a second comma, or more decimals than allowed.
    static func insert(_ k: String, into text: String, fromRight: Int, decimals: Int?) -> String? {
        var t = text
        let n = min(fromRight, t.count)
        let i = t.index(t.endIndex, offsetBy: -n)
        switch k {
        case "⌫":
            guard i > t.startIndex else { return nil }
            t.remove(at: t.index(before: i))
        case ",":
            guard decimals != nil, !t.contains(",") else { return nil }
            t.insert(",", at: i)
        default:
            t.insert(contentsOf: k, at: i)
        }
        if let decimals, let c = t.firstIndex(of: ","), t.distance(from: c, to: t.endIndex) - 1 > decimals { return nil }
        return t
    }

    /// Typing in another currency: digits, one comma, two decimals at most.
    fileprivate func pressTypedImpl(_ k: String, _ typed: inout String, decimals: Int = 2) {
        switch k {
        case "⌫": if !typed.isEmpty { typed.removeLast() }
        case ",": if !typed.contains(",") { typed = (typed.isEmpty ? "0" : typed) + "," }
        case "000": if !typed.isEmpty && !typed.contains(",") && typed.count < 12 { typed += "000" }
        case "00":
            // Before the comma it's a hundred; right after it, ",00".
            guard !typed.isEmpty, typed.count < 13 else { return }
            if let i = typed.firstIndex(of: ",") {
                if typed.distance(from: i, to: typed.endIndex) == 1 { typed += "00" }
            } else {
                typed += "00"
            }
        default:
            if let i = typed.firstIndex(of: ","), typed.distance(from: i, to: typed.endIndex) > decimals { return }
            guard typed.count < 14 else { return }
            typed = typed == "0" ? k : typed + k
        }
    }
}

/// The currencies you can type in. Gold is by the chỉ, the way it's sold in Vietnam.
enum PadCurrency: String, CaseIterable, Identifiable {
    case vnd, usd, eur, jpy, krw, cny, sgd, thb, aud, gold
    var id: Self { self }
    var code: String { self == .gold ? "GOLD" : rawValue.uppercased() }
    var symbol: String {
        switch self {
        case .vnd: "đ"
        case .usd: "$"
        case .eur: "€"
        case .jpy: "¥"
        case .krw: "₩"
        case .cny: "元"
        case .sgd: "S$"
        case .thb: "฿"
        case .aud: "A$"
        case .gold: "chỉ"
        }
    }
    var name: String {
        switch self {
        case .vnd: "Vietnam dong"
        case .usd: "US dollar"
        case .eur: "Euro"
        case .jpy: "Japanese yen"
        case .krw: "Korean won"
        case .cny: "Chinese yuan"
        case .sgd: "Singapore dollar"
        case .thb: "Thai baht"
        case .aud: "Australian dollar"
        case .gold: "Gold"
        }
    }
    /// A rough example for the rate box, so the size of the number is clear.
    var rateHint: String {
        switch self {
        case .usd: "e.g. 26000"
        case .eur: "e.g. 30000"
        case .jpy: "e.g. 170"
        case .krw: "e.g. 18"
        case .cny: "e.g. 3600"
        case .sgd: "e.g. 20000"
        case .thb: "e.g. 800"
        case .aud: "e.g. 17000"
        case .gold: "price of 1 chỉ"
        case .vnd: ""
        }
    }
}

/// Keys dim a little while pressed, like the system keyboard.
private struct KeyPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.55 : 1)
    }
}

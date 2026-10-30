import SwiftData
import SwiftUI

/// After scanning a payment QR: who it goes to, the amount on a keypad, category and note,
/// the bank to pay from, then "Open bank app". The app never sends money itself: the bank's
/// own app opens with the transfer and the user confirms it there. Coming back, the app asks
/// whether it went through and only then saves it as spending.
struct TransferSheet: View {
    @State var draft: TransferDraft
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var profiles: [Profile]
    @State private var picking = false
    @State private var failed = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.s16) {
                payee
                amount
                details
                Spacer(minLength: 0)
                if !noteFocused { keypad }
                footer
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s8)
            .background(Tokens.bg3)
            .navigationTitle("Check payment")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(Tokens.brand700)
                }
            }
        }
        .sheet(isPresented: $picking) {
            PayFromSheet(selected: draft.from) { bank in
                draft.from = bank
                remember(bank)
            }
        }
        .alert("Couldn't open the bank app", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check that \(draft.from?.name ?? "the bank")'s app is on this phone.")
        }
        .onAppear {
            if draft.from == nil, let id = profiles.first?.banks.first { draft.from = BankApp.named(id) }
        }
    }

    // MARK: - Parts

    private var payee: some View {
        VStack(spacing: Space.s4) {
            Text(draft.payee)
                .font(AppFont.h6(.semibold))
                .foregroundStyle(Tokens.text900)
                .multilineTextAlignment(.center)
            Text([draft.bankName, draft.account].compactMap { $0 }.joined(separator: " · "))
                .font(AppFont.body())
                .foregroundStyle(Tokens.grey400)
                .monospacedDigit()
        }
        .padding(.top, Space.s8)
        .accessibilityElement(children: .combine)
    }

    private var amount: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(Money.format(draft.amount))
                .font(AppFont.amount(44))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("đ").font(AppFont.currency(for: 44))
        }
        .foregroundStyle(draft.amount == 0 ? Tokens.grey300 : Tokens.text900)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount, \(Money.format(draft.amount)) dong")
    }

    private var details: some View {
        VStack(spacing: 0) {
            HStack(spacing: Space.s12) {
                tile("tag")
                Text("Category").foregroundStyle(Tokens.text700)
                Spacer()
                Picker("Category", selection: $draft.category) {
                    ForEach(Category.allCases.filter { $0 != .received }, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .labelsHidden()
                .tint(Tokens.text900)
            }
            .frame(minHeight: 56)
            Divider().overlay(Tokens.bd1)
            HStack(spacing: Space.s12) {
                tile("pencil")
                Text("Note").foregroundStyle(Tokens.text700)
                TextField("Optional", text: $draft.note)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Tokens.text900)
                    .focused($noteFocused)
                    .submitLabel(.done)
                    .accessibilityLabel("Note")
            }
            .frame(minHeight: 56)
        }
        .font(AppFont.body())
        .padding(.horizontal, Space.s16)
        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c20))
    }

    private func tile(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15))
            .foregroundStyle(Tokens.text700)
            .frame(width: 36, height: 36)
            .background(Tokens.bg3, in: .circle)
            .accessibilityHidden(true)
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "000", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 0) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Group {
                        if k == "⌫" { Image(systemName: "delete.left") } else { Text(k) }
                    }
                    .font(AppFont.heading(26, .regular, relativeTo: .title2))
                    .foregroundStyle(Tokens.text900)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(k == "⌫" ? "Delete" : k == "000" ? "Three zeros" : k)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var footer: some View {
        VStack(spacing: Space.s8) {
            Text(hint)
                .font(AppFont.capture())
                .foregroundStyle(Tokens.grey400)
                .multilineTextAlignment(.center)
            HStack(spacing: Space.s12) {
                Button { picking = true } label: {
                    Text(draft.from?.name ?? "Bank")
                        .font(AppFont.capture(.bold))
                        .foregroundStyle(Tokens.text900)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: 44, height: 44)
                        .background(Tokens.bg3, in: .rect(cornerRadius: Corner.c12))
                        .padding(Space.s6)
                        .background(Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                        .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(Tokens.bd1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pay from, \(draft.from?.name ?? "pick a bank")")

                Button(action: openBank) {
                    Text(draft.from == nil ? "Pick a bank" : "Open \(draft.from!.name)")
                        .font(AppFont.bodyLarge(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(Tokens.action)
                .controlSize(.large)
                .disabled(draft.from != nil && draft.amount == 0)
            }
        }
    }

    private var hint: String {
        guard let b = draft.from else { return "Pick the bank you pay from. The app never moves money itself." }
        return b.fills
            ? "\(b.name) opens with the account and amount filled in. Confirm it there."
            : "\(b.name) opens, but can't take the details: scan the code or type them there."
    }

    // MARK: - Actions

    private func press(_ k: String) {
        var v = draft.amount
        switch k {
        case "⌫": v /= 10
        case "000": v *= 1000
        default: v = v * 10 + (Int(k) ?? 0)
        }
        guard v < 100_000_000_000 else { return }
        withAnimation(.snappy) { draft.amount = v }
    }

    private func openBank() {
        guard let bank = draft.from else { picking = true; return }
        guard let url = bank.transferURL(account: draft.account, bankBIN: draft.bankBIN, amount: draft.amount,
                                         note: draft.note, name: draft.name) else {
            failed = true
            return
        }
        app.handedOff = draft
        openURL(url) { ok in
            if ok {
                dismiss()
            } else {
                app.handedOff = nil
                failed = true
            }
        }
    }

    /// The bank just used goes first in Profile's list, so it is picked next time.
    private func remember(_ bank: BankApp) {
        guard let p = profiles.first else { return }
        p.banks = [bank.id] + p.banks.filter { $0 != bank.id }
    }
}

/// "Pay from": the banks the user pays from, two across. ⚡ means the app opens filled in.
/// Each shows what was sent from it this month (lines saved after "Open bank app").
struct PayFromSheet: View {
    var selected: BankApp?
    var onPick: (BankApp) -> Void
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Profile]
    @Query private var entries: [Entry]
    @State private var adding = false

    var body: some View {
        let mine = (profiles.first?.banks ?? []).compactMap(BankApp.named)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s16) {
                    if mine.isEmpty || adding {
                        Text(mine.isEmpty ? "Which banks do you use?" : "Add a bank")
                            .font(AppFont.body(.semibold))
                            .foregroundStyle(Tokens.text700)
                        grid(BankApp.all.filter { !mine.contains($0) }, all: true)
                    } else {
                        grid(mine, all: false)
                        Button {
                            withAnimation(.snappy) { adding = true }
                        } label: {
                            Label("Add another bank", systemImage: "plus.circle")
                                .font(AppFont.body())
                                .foregroundStyle(Tokens.text700)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    Label("Fills in the account and amount", systemImage: "bolt.fill")
                        .font(AppFont.capture())
                        .foregroundStyle(Tokens.grey400)
                }
                .padding(Space.s20)
            }
            .background(Tokens.bg3)
            .navigationTitle("Pay from")
            .toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private func grid(_ banks: [BankApp], all: Bool) -> some View {
        let month = Month.of(app.today)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s12), GridItem(.flexible())], spacing: Space.s12) {
            ForEach(banks) { b in
                let sent = entries.filter { $0.paidFrom == b.name && Month.of($0.date) == month }.reduce(0) { $0 + $1.amount }
                let on = b == selected
                Button {
                    onPick(b)
                    dismiss()
                } label: {
                    HStack(spacing: Space.s8) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 15))
                            .frame(width: 32, height: 32)
                            .background(on ? .white.opacity(0.18) : Tokens.bg3, in: .rect(cornerRadius: Corner.c8))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: Space.s4) {
                                Text(b.name).font(AppFont.body(.semibold))
                                if b.fills { Image(systemName: "bolt.fill").font(.system(size: 11)) }
                            }
                            if !all {
                                Text(sent == 0 || app.hidden ? (app.hidden ? "••••" : "Nothing this month")
                                                            : "\(Money.format(sent)) đ this month")
                                    .font(AppFont.capture())
                                    .foregroundStyle(on ? Tokens.onDark : Tokens.grey400)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(on ? .white : Tokens.text900)
                    .padding(Space.s12)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(on ? Tokens.action : Tokens.bgWhite, in: .rect(cornerRadius: Corner.c16))
                    .overlay(RoundedRectangle(cornerRadius: Corner.c16).strokeBorder(on ? .clear : Tokens.bd1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(b.name)\(b.fills ? ", fills in the details" : "")\(all ? "" : ", \(sent) dong sent this month")")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

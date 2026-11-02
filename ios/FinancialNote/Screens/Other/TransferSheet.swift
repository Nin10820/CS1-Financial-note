import UniformTypeIdentifiers
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
    @Query private var profiles: [Profile]
    @State private var picking = false
    @State private var failed = false
    /// After copying and saving: how to finish in the bank app, then open it.
    @State private var guiding = false
    @State private var savedQR = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.s16) {
                VStack(spacing: Space.s16) {
                    payee
                    amount
                    details
                }
                .padding(.horizontal, Space.s20)
                Spacer(minLength: 0)
                footer.padding(.horizontal, Space.s20)
                if !noteFocused {
                    AmountPad(value: Binding(get: { draft.amount == 0 ? nil : draft.amount },
                                             set: { v in withAnimation(.snappy) { draft.amount = v ?? 0 } }))
                }
            }
            .padding(.bottom, noteFocused ? Space.s8 : 0)
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
        .alert("Ready to pay", isPresented: $guiding) {
            Button("Open \(draft.from?.name ?? "bank")") { launchBank() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(guide)
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

                // Same 56 pt height as the bank chip beside it.
                let off = draft.from != nil && draft.amount == 0
                Button(action: openBank) {
                    Text(draft.from == nil ? "Pick a bank" : "Open \(draft.from!.name)")
                        .font(AppFont.bodyLarge(.semibold))
                        .foregroundStyle(.white.opacity(off ? 0.6 : 1))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(off ? Tokens.grey400 : Tokens.action).interactive(), in: .capsule)
                .disabled(off)
                #if DEBUG
                .contextMenu {
                    ForEach(Array(tryWays.enumerated()), id: \.offset) { _, way in
                        Button(way.0, action: way.1)
                    }
                }
                #endif
            }
        }
    }

    private var hint: String {
        guard let b = draft.from else { return "Pick the bank you pay from. The app never moves money itself." }
        return b.id == "tpb"
            ? "Copies the transfer, then opens TPBank: ChatPay → Paste fills it in."
            : "Saves a QR with the amount to Photos and copies the details, then opens \(b.name)."
    }

    // MARK: - Actions

    /// Hands the transfer over every way at once, so nothing has to be typed again:
    /// a QR with the amount in Photos (Scan QR → Photos in any bank app), the details and the
    /// QR on the clipboard (TPBank ChatPay → Paste), and VietQR's link for the apps it fills in.
    private func openBank() {
        guard let bank = draft.from else { picking = true; return }
        // TPBank: one sentence on the clipboard for ChatPay's "Paste to Pay" — no photo.
        if bank.id == "tpb" {
            UIPasteboard.general.setItems([[UTType.plainText.identifier: transferText]],
                                          options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)])
            savedQR = false
            guiding = true
            return
        }
        let code = VietQR.withAmount(draft.payload, amount: draft.amount, note: draft.note)
        let image = code.flatMap {
            TransferQRImage.make(payload: $0, payee: draft.payee,
                                 detail: [draft.bankName, draft.account].compactMap { $0 }.joined(separator: " · "),
                                 amount: draft.amount)
        }
        var item: [String: Any] = [UTType.plainText.identifier: transferText]
        if let png = image?.pngData() { item[UTType.png.identifier] = png }
        UIPasteboard.general.setItems([item], options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)])
        Task {
            savedQR = if let image { await TransferQRImage.save(image) } else { false }
            guiding = true
        }
    }

    /// Opens the bank's own app; when the user comes back they're asked whether it went through.
    private func launchBank() {
        guard let bank = draft.from else { failed = true; return }
        if bank.vietQRFills, let acc = draft.account, let bin = draft.bankBIN,
           let link = bank.vietQRLink(account: acc, receiverBIN: bin, amount: draft.amount, note: draft.note) {
            open(link)
        } else if let url = bank.schemeURL {
            open(url)
        } else {
            failed = true
        }
    }

    private var guide: String {
        let name = draft.from?.name ?? "your bank"
        if draft.from?.id == "tpb" {
            return "The transfer is copied. In TPBank, open ChatPay → Transfer → Paste transfer details: account, bank and \(Money.format(draft.amount)) đ fill in."
        }
        let photo = savedQR
            ? "Tap Scan QR, then Photos, and pick the newest QR: account, bank and \(Money.format(draft.amount)) đ are in it."
            : "Allow Photos for Financial Note in Settings to get the QR with the amount."
        let paste = draft.from?.id == "tpb" ? " Or open ChatPay and paste." : " Or paste where it asks for the account."
        return "In \(name): " + photo + paste
    }

    private func open(_ url: URL) {
        app.handedOff = draft
        UIApplication.shared.open(url) { ok in
            if ok {
                dismiss()
            } else {
                app.handedOff = nil
                failed = true
            }
        }
    }

    /// The transfer as text for the bank app to read when pasted (TPBank ChatPay reads the account,
    /// bank and amount from a message like this). Stays on this phone — not shared with other
    /// devices — and clears itself after 10 minutes.
    /// Stays on this phone (not shared with other devices) and clears itself after 10 minutes.
    private func copy(_ text: String) {
        UIPasteboard.general.setItems([[UTType.plainText.identifier: text]],
                                      options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)])
    }

    #if DEBUG
    /// Ways to hand the transfer to a bank app, to find on a real phone which one fills it in.
    /// Debug builds only — press and hold the Open button. Removed once one is known to work.
    private var tryWays: [(String, () -> Void)] {
        // Each copies the ChatPay sentence first, then tries a link that might land on ChatPay or
        // Transfer instead of TPBank's home screen. Guesses — TPBank publishes none.
        func go(_ s: String) {
            UIPasteboard.general.setItems([[UTType.plainText.identifier: transferText]],
                                          options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(600)])
            if let u = URL(string: s) { open(u) } else { failed = true }
        }
        let links = [
            "hydro://chatpay", "hydro://ChatPay", "hydro://chat-pay", "hydro://chat",
            "hydro://transfer", "hydro://pastetopay", "hydro://open?screen=chatpay",
            "tpb://chatpay", "tpb://transfer",
        ]
        return links.enumerated().map { i, link in ("\(i + 1) · \(link)", { go(link) }) }
    }

    /// VietQR's deeplink as the open-source projects build it: `tn` with + for spaces, `url` not encoded.
    private func vietQRLink(receiver: String) -> String {
        let app = draft.from?.id ?? "tpb"
        let note = VietQR.ascii(draft.note).replacingOccurrences(of: " ", with: "+")
        return "https://dl.vietqr.io/pay?app=\(app)&ba=\(draft.account ?? "")@\(receiver)&am=\(draft.amount)&tn=\(note)&url=https://www.vietqr.io/deeplink"
    }
    #endif

    /// One plain sentence, the way people send transfer details in a chat — TPBank ChatPay reads
    /// the name, account, bank and amount out of it: "Chuyển 58.000đ đến STK 5116… TPBank - AU THIEN VY. Nội dung: …"
    var transferText: String {
        let amount = Money.format(draft.amount).replacingOccurrences(of: ",", with: ".")
        var s = "Chuyển \(amount)đ đến STK \(draft.account ?? "") \(draft.bankName ?? "")"
        if let name = draft.name { s += " - \(name.uppercased(with: Locale(identifier: "vi")))" }
        if !draft.note.isEmpty { s += ". Nội dung: \(draft.note)" }
        return s
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
                    Text("Your bank app opens; the transfer is confirmed there.")
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
                .accessibilityLabel("\(b.name)\(all ? "" : ", \(sent) dong sent this month")")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

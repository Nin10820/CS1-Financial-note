import SwiftData
import SwiftUI

/// Profile — Figma Draft › Account (707:7360): profile, data & privacy, display, help.
/// There is no account in this app, so sign-in, password, Face ID and log-out are left out
/// rather than shown as switches that do nothing.
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]
    @Query private var entries: [Entry]
    @Query private var assets: [Asset]
    @Query private var bills: [Bill]

    static let version = "0.1 · MVP"

    var body: some View {
        NavigationStack {
            List {
                if let p = profiles.first {
                    Section {
                        NavigationLink {
                            ProfileDetail(profile: p)
                        } label: {
                            HStack(spacing: Space.s12) {
                                Avatar(name: p.name, size: 48)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(AppFont.main(17, .semibold))
                                    Text("Using it since \(FinanceText.monthLabel(Month.of(p.joined)))")
                                        .font(AppFont.main(13)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("Account") {
                        NavigationLink("Profile") { ProfileDetail(profile: p) }
                        LabeledContent("Currency", value: "VND")
                    }

                    Section("Data & privacy") {
                        NavigationLink { YourDataView() } label: { row("Your data", "See what the app keeps") }
                        NavigationLink { AIInfoView() } label: { row("What the AI does with notes", "Only reads what you write") }
                        ExportLink(label: "Download your data")
                        Toggle(isOn: sampleBinding) {
                            row("Sample data", hasSample ? "Showing made-up notes, bills and assets" : "Fill every screen with made-up data")
                        }
                    }

                    Section("Display") {
                        Toggle("Hide amounts when the app opens", isOn: Binding(get: { p.hideOnOpen }, set: { p.hideOnOpen = $0; save() }))
                        NavigationLink("Display") { DisplayView(profile: p) }
                    }

                    Section {
                        NavigationLink("Report a problem") { ReportView() }
                        NavigationLink { AboutView() } label: { LabeledContent("About the app", value: Self.version) }
                    } header: {
                        Text("Help")
                    } footer: {
                        Text("No account, no server: everything you write stays on this phone.")
                            .padding(.top, Space.s8)
                    }
                }
            }
            .font(AppFont.main(16))
            .navigationTitle("Profile")
            .tint(Tokens.brand500)
        }
    }

    private var hasSample: Bool {
        entries.contains(where: \.sample) || assets.contains(where: \.sample) || bills.contains(where: \.sample)
    }

    /// One switch: on loads the made-up data, off removes it and leaves the user's own alone.
    private var sampleBinding: Binding<Bool> {
        Binding(get: { hasSample }, set: { on in
            let store = LocalStore(context: context)
            if on { store.loadSample() } else { store.clearSample() }
        })
    }

    private func row(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(sub).font(AppFont.main(13)).foregroundStyle(.secondary)
        }
    }

    private func save() { try? context.save() }
}

/// Two-letter circle for the name (there is no photo — no account).
struct Avatar: View {
    var name: String
    var size: CGFloat

    var body: some View {
        Text(String(name.prefix(2)).uppercased())
            .font(AppFont.main(size * 0.36, .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: 0xE5562A), in: .circle)
            .overlay(Circle().strokeBorder(Tokens.brand400, lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// Share sheet with everything as a JSON file.
struct ExportLink: View {
    var label: String
    @Environment(\.modelContext) private var context

    var body: some View {
        let file = ExportFile(store: LocalStore(context: context))
        let data = (try? file.data()) ?? Data()
        ShareLink(item: ExportDocument(data: data, fileName: "financial-note-\(Day.today()).json"),
                  preview: SharePreview("Financial Note data", image: Image(systemName: "doc.text"))) {
            Label(label, systemImage: "square.and.arrow.up")
        }
    }
}

// MARK: - Profile and name

private struct ProfileDetail: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @State private var editing = false
    @State private var name = ""

    var body: some View {
        let days = max(1, Int((Day.date(Day.today()).timeIntervalSince(Day.date(profile.joined)) / 86_400).rounded()) + 1)
        List {
            Section {
                VStack(spacing: Space.s8) {
                    Avatar(name: profile.name, size: 72)
                    Text(profile.name).font(AppFont.title(22, .bold))
                    Text("On this phone since \(DueText.ddmmyyyy(profile.joined)) · \(days) days")
                        .font(AppFont.main(13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
            Section {
                Button {
                    name = profile.name
                    editing = true
                } label: {
                    LabeledContent("Display name", value: profile.name)
                }
                .foregroundStyle(Tokens.text900)
            } header: {
                Text("Info")
            } footer: {
                Text("The app doesn't ask for your income, your job or your money goals — it doesn't need them to work.")
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("Profile")
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    Section {
                        TextField("Display name", text: $name)
                            .onChange(of: name) { _, v in if v.count > 40 { name = String(v.prefix(40)) } }
                    } footer: {
                        Text("This is the name in “Good morning, …”. It stays on this phone.")
                    }
                }
                .navigationTitle("Edit profile")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", systemImage: "checkmark") {
                            profile.name = name.trimmingCharacters(in: .whitespaces)
                            try? context.save()
                            editing = false
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Data & privacy

private struct YourDataView: View {
    @Query private var entries: [Entry]
    @Query private var assets: [Asset]
    @Query private var bills: [Bill]

    var body: some View {
        List {
            Section {
                intro("What the app keeps", "The full list. Nothing hidden.")
            }
            Section("On your phone") {
                LabeledContent("Spending notes", value: "\(entries.count) \(entries.count == 1 ? "line" : "lines")")
                LabeledContent("Assets", value: "\(assets.count)")
                LabeledContent("Bills", value: "\(bills.count)")
            }
            Section("Sent to a server") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing")
                    Text("Notes are read on this phone in this version").font(AppFont.main(13)).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Bank accounts")
                Text("Location")
                Text("Contacts")
            } header: {
                Text("Never collected")
            } footer: {
                Text("The app doesn't connect to a bank, so it can't spend money for you either.")
            }
            Section {
                ExportLink(label: "Download everything")
                NavigationLink { DeleteAllView() } label: {
                    Text("Delete everything").foregroundStyle(Tokens.text900)
                }
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("Your data")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct AIInfoView: View {
    var body: some View {
        List {
            Section { intro("The note reader does one thing", "The app still works if you type everything yourself.") }
            Section("On") {
                LabeledContent {
                    Text("On").foregroundStyle(Tokens.brand700)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reads your notes")
                        Text("Splits items, amounts and days").font(AppFont.main(13)).foregroundStyle(.secondary)
                    }
                }
                LabeledContent {
                    Text("Later").foregroundStyle(.secondary)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Answers when you ask")
                        Text("Comes later · it never speaks first").font(AppFont.main(13)).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Investment tips")
                    Text("Left out on purpose, not “not yet”").font(AppFont.main(13)).foregroundStyle(.secondary)
                }
                Text("Comments on how you spend")
                Text("Overspending alerts")
                Text("Spending or moving money")
            } header: {
                Text("Not in the app")
            } footer: {
                Text("These four were cut, not postponed: in our survey 38% refused investment tips, 31% refused being judged on their spending, and 63% didn't want an app touching their money.\n\nIn this version the note reader runs on your phone — no note leaves it.")
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("What the AI does")
        .toolbarTitleDisplayMode(.inline)
    }
}

/// Deleting everything is permanent, so it asks for DELETE to be typed first.
struct DeleteAllView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query private var assets: [Asset]
    @Query private var bills: [Bill]
    @State private var typed = ""
    @State private var done = false

    static func confirms(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).uppercased() == "DELETE"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Space.s6) {
                    Text("Deleting is permanent").font(AppFont.main(16, .semibold))
                    Text("\(entries.count) notes, \(assets.count) assets and \(bills.count) bills will be gone. There is no undo.")
                        .font(AppFont.main(14))
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                ExportLink(label: "Download a copy first")
            } footer: {
                Text("Saves a file you keep, before anything is removed.")
            }
            Section("Type DELETE to confirm") {
                TextField("DELETE", text: $typed)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }
            Section {
                Button("Delete everything", role: .destructive) {
                    LocalStore(context: context).clearAll()
                    done = true
                }
                .disabled(!Self.confirms(typed))
                Button("No, keep it") { dismiss() }
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("Delete data")
        .toolbarTitleDisplayMode(.inline)
        .alert("Everything is deleted", isPresented: $done) {
            Button("OK") { dismiss() }
        } message: {
            Text("This phone now starts clean. You can turn sample data back on in Profile.")
        }
    }
}

// MARK: - Display and help

private struct DisplayView: View {
    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section { intro("You choose when to look", "No number jumps out at you.") }
            Section("When the app opens") {
                Toggle(isOn: Binding(get: { profile.hideOnOpen }, set: { profile.hideOnOpen = $0; try? context.save() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide balances")
                        Text("Tap the eye to show them").font(AppFont.main(13)).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: Binding(get: { profile.hideAssets }, set: { profile.hideAssets = $0; try? context.save() })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide asset totals")
                        Text("Applies to Finance too").font(AppFont.main(13)).foregroundStyle(.secondary)
                    }
                }
            }
            Section("Numbers") { LabeledContent("Currency", value: "VND") }
        }
        .font(AppFont.main(16))
        .navigationTitle("Display")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct ReportView: View {
    static let topics = ["Misread my note", "Slow", "Wrong number", "Other"]
    @State private var topic = topics[0]
    @State private var text = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section { intro("What went wrong?", "Write it any way you like.") }
            Section("Topic") {
                Picker("Topic", selection: $topic) {
                    ForEach(Self.topics, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section {
                TextField("I typed “cà phê 24k” and it read 240k…", text: $text, axis: .vertical)
                    .lineLimit(5...10)
            } footer: {
                Text("Only the app version and your iOS version go with it. No amounts, no notes.")
            }
            Section {
                Button("Send by email", systemImage: "envelope") {
                    if let url = ReportView.mailURL(topic: topic, text: text) { openURL(url) }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("Report a problem")
        .toolbarTitleDisplayMode(.inline)
    }

    static func mailURL(topic: String, text: String) -> URL? {
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = ""
        c.queryItems = [
            URLQueryItem(name: "subject", value: "Financial Note: \(topic)"),
            URLQueryItem(name: "body", value: "\(topic)\n\n\(text)\n\n— Financial Note \(ProfileView.version), iOS \(UIDevice.current.systemVersion)"),
        ]
        return c.url
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.s6) {
                    Text("PRINCIPLE").font(AppFont.main(11, .semibold)).tracking(0.6).foregroundStyle(.white.opacity(0.7))
                    Text("A layer to look through, not a layer of control")
                        .font(AppFont.title(20, .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, Space.s8)
                .listRowBackground(Color(hex: 0x0D121C))
            }
            Section("This app does not") {
                sub("Hold or move your money", "63% don't want an app spending for them")
                sub("Suggest investments or products", "38% refused")
                sub("Comment on how you spend", "31% refused")
                sub("Read your bank account", "78% worry an app knows too much")
            }
            Section {
                LabeledContent("Version", value: ProfileView.version)
            } footer: {
                Text("WUD Design Challenge 2026 · Nin Nguyễn · Pham Nguyen Studio")
                    .frame(maxWidth: .infinity)
                    .padding(.top, Space.s16)
            }
        }
        .font(AppFont.main(16))
        .navigationTitle("About the app")
        .toolbarTitleDisplayMode(.inline)
    }

    private func sub(_ title: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(s).font(AppFont.main(13)).foregroundStyle(.secondary)
        }
    }
}

private func intro(_ title: String, _ sub: String) -> some View {
    VStack(alignment: .leading, spacing: Space.s4) {
        Text(title).font(AppFont.title(22, .bold, relativeTo: .title2)).foregroundStyle(Tokens.text900)
        Text(sub).font(AppFont.main(14)).foregroundStyle(.secondary)
    }
    .listRowBackground(Color.clear)
    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
}

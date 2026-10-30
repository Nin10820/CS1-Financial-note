import Combine
import SwiftData
import SwiftUI

/// The app: four tabs, the + menu, and the sheets they open.
struct RootView: View {
    @State private var app = AppState()
    @Query private var profiles: [Profile]
    @State private var didApplyPrefs = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.tab) {
            Tab("Today", systemImage: "calendar", value: AppState.TabID.today) {
                TodayView().toolbarVisibility(.hidden, for: .tabBar).modifier(BarRoom(show: true))
            }
            Tab("Due", systemImage: "doc.text.fill", value: AppState.TabID.due) {
                DueView().toolbarVisibility(.hidden, for: .tabBar).modifier(BarRoom(show: true))
            }
            Tab("Finance", systemImage: "chart.pie.fill", value: AppState.TabID.finance) {
                FinanceView().toolbarVisibility(.hidden, for: .tabBar).modifier(BarRoom(show: true))
            }
            Tab("AI", systemImage: "sparkles", value: AppState.TabID.ai) {
                AssistantView().toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .tint(Tokens.brand600)
        .overlay(alignment: .bottom) {
            // The AI tab has its own composer at the bottom; the bar steps aside while chatting.
            if app.tab != .ai || !app.aiChatting { AppTabBar() }
        }
        .overlay { ActionMenu() }
        .sheet(isPresented: $app.dayNoteOpen) { DayNoteEditor() }
        .sheet(isPresented: $app.templateOpen, onDismiss: { app.templatePrefill = nil }) {
            EntrySheet(entry: nil, prefill: app.templatePrefill)
        }
        .sheet(isPresented: $app.profileOpen) { ProfileView() }
        .fullScreenCover(isPresented: $app.scanOpen) { ScanView() }
        .fullScreenCover(item: $app.transfer) { TransferSheet(draft: $0) }
        .alert(sentTitle, isPresented: Binding(
            get: { app.sentToBank != nil && scenePhase == .active && app.transfer == nil },
            set: { if !$0 { app.sentToBank = nil } })
        ) {
            Button("Yes, save it") { saveSent() }
            Button("Not sent", role: .cancel) { app.sentToBank = nil }
        } message: {
            Text("The app can't see your bank. Saving adds it to your spending, marked as paid from \(app.sentToBank?.from?.name ?? "the bank").")
        }
        .onOpenURL { _ in }  // financialnote://paid — the bank app sending the user back.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, let d = app.handedOff {
                app.sentToBank = d
                app.handedOff = nil
            }
        }
        .environment(app)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            app.dayChanged()
        }
        .onChange(of: app.tab) { _, _ in
            app.actionsOpen = false
            app.barMinimized = false
        }
        .onAppear {
            guard !didApplyPrefs else { return }
            didApplyPrefs = true
            app.hidden = profiles.first?.hideOnOpen ?? false
            app.assetsHidden = app.hidden || (profiles.first?.hideAssets ?? false)
        }
    }

    private var sentTitle: String {
        guard let d = app.sentToBank else { return "" }
        return "Did you send \(Money.format(d.amount)) đ to \(d.payee)?"
    }

    /// The user says the transfer went through: it becomes a spending line, paid from that bank.
    private func saveSent() {
        guard let d = app.sentToBank else { return }
        app.sentToBank = nil
        let e = Entry(date: app.today, title: d.title, amount: d.amount, flow: .out, category: d.category,
                      noteId: UUID().uuidString,
                      source: "Scanned QR" + (d.bankName.map { " · \($0)" } ?? "") + (d.account.map { " \($0)" } ?? ""))
        e.paidFrom = d.from?.name
        if let t = Tags.suggest(title: d.title, category: d.category) { e.tags = [t] }
        LocalStore(context: context).addEntries([e])
    }
}

/// Navigation Bar (Figma 2026-10-30): Today, Due, Finance, AI in one glass capsule, and the
/// round green + beside it. The system tab bar can't hold a separate + on this iOS, so this is
/// built from the system Liquid Glass effect and given the system bar's behaviour back: a glass
/// lens that slides between tabs and can be dragged, the bar shrinking while you scroll down,
/// and the + morphing with the bar. It follows Reduce Transparency, Reduce Motion and dark mode.
private struct AppTabBar: View {
    @Environment(AppState.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    /// The tab under the finger while dragging along the bar.
    @State private var dragging: AppState.TabID?
    @State private var pressed = false

    private let tabs: [(AppState.TabID, String, String)] = [
        (.today, "Today", "calendar"),
        (.due, "Due", "doc.text.fill"),
        (.finance, "Finance", "chart.pie.fill"),
        (.ai, "AI", "sparkles"),
    ]

    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.72) }

    var body: some View {
        let small = app.barMinimized && !app.actionsOpen
        let lit = dragging ?? app.tab
        GlassEffectContainer(spacing: Space.s12) {
            HStack(spacing: Space.s12) {
                GeometryReader { g in
                    let w = g.size.width / CGFloat(tabs.count)
                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.0) { id, title, symbol in
                            let on = lit == id
                            VStack(spacing: 2) {
                                Image(systemName: symbol)
                                    .font(.system(size: 19, weight: .semibold))
                                    .symbolEffect(.bounce, value: app.tab == id)
                                if !small {
                                    Text(title).font(AppFont.main(11, .medium, relativeTo: .caption2))
                                }
                            }
                            .foregroundStyle(on ? Tokens.brand600 : Tokens.text900)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background {
                                if on {
                                    // The lens: its own piece of glass that slides to the picked tab.
                                    Capsule()
                                        .fill(.clear)
                                        .glassEffect(.regular.tint(Tokens.text900.opacity(0.06)).interactive(), in: .capsule)
                                        .matchedGeometryEffect(id: "lens", in: glass)
                                        .scaleEffect(pressed && !reduceMotion ? 1.12 : 1)
                                }
                            }
                            .contentShape(.capsule)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(title)
                            .accessibilityAddTraits(app.tab == id ? [.isSelected, .isButton] : .isButton)
                            .accessibilityAction { go(id) }
                        }
                    }
                    // Tap a tab, or drag along the bar: the lens follows the finger.
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let i = min(max(Int(v.location.x / w), 0), tabs.count - 1)
                                withAnimation(spring) {
                                    pressed = true
                                    dragging = tabs[i].0
                                }
                            }
                            .onEnded { v in
                                let i = min(max(Int(v.location.x / w), 0), tabs.count - 1)
                                withAnimation(spring) {
                                    pressed = false
                                    dragging = nil
                                }
                                go(tabs[i].0)
                            }
                    )
                }
                .frame(height: small ? 40 : 52)
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID("bar", in: glass)

                Button {
                    withAnimation(spring) { app.actionsOpen.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: small ? 18 : 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(app.actionsOpen ? 45 : 0))
                        .frame(width: small ? 48 : 60, height: small ? 48 : 60)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Tokens.writeButton).interactive(), in: .circle)
                .glassEffectID("plus", in: glass)
                .accessibilityLabel(app.actionsOpen ? "Close menu" : "Add")
                .accessibilityHint("Talk With AI, Template or Scan")
            }
        }
        .padding(.horizontal, small ? Space.s32 : Space.s20)
        .padding(.bottom, Space.s4)
        .animation(spring, value: small)
        .sensoryFeedback(.selection, trigger: lit)
    }

    private func go(_ id: AppState.TabID) {
        withAnimation(spring) {
            app.tab = id
            app.barMinimized = false
        }
    }
}

/// The three glass pills above the + (Figma Today 1073:18526).
private struct ActionMenu: View {
    @Environment(AppState.self) private var app

    var body: some View {
        if app.actionsOpen {
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture { animate { app.actionsOpen = false } }
                    .accessibilityLabel("Close menu")
                    .accessibilityAddTraits(.isButton)
                GlassEffectContainer(spacing: Space.s12) {
                    VStack(alignment: .trailing, spacing: Space.s12) {
                        ActionPill(title: "Talk With AI", systemImage: "sparkles") { app.openAssistant(voice: true) }
                        ActionPill(title: "Template", systemImage: "doc.text") {
                            app.actionsOpen = false
                            app.templateOpen = true
                        }
                        ActionPill(title: "Scan", systemImage: "qrcode.viewfinder") {
                            app.actionsOpen = false
                            app.scanOpen = true
                        }
                    }
                }
                .padding(.trailing, Space.s20)
                // Sits just above the tab bar (60 pt + its bottom gap).
                .padding(.bottom, 80)
            }
            .transition(.sheetLike)
        }
    }
}

struct ActionPill: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppFont.main(14, .semibold))
                .foregroundStyle(Tokens.brand800)
                .padding(.horizontal, Space.s16)
                .padding(.vertical, Space.s12)
        }
        .buttonStyle(.plain)
        // A near-white tint keeps the green label readable over whatever is behind the glass.
        .glassEffect(.regular.tint(Tokens.bgWhite.opacity(0.9)).interactive(), in: .capsule)
    }
}

/// Leaves room under a tab's content for the floating tab bar, so nothing ends up behind it.
private struct BarRoom: ViewModifier {
    var show: Bool

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: show ? 72 : 0)
        }
    }
}

/// Shrinks the tab bar while scrolling down, brings it back when scrolling up or at the top.
struct MinimizesTabBar: ViewModifier {
    @Environment(AppState.self) private var app

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { old, new in
            let down = new > old + 4 && new > 60
            let up = new < old - 4 || new < 30
            if down && !app.barMinimized { app.barMinimized = true }
            else if up && app.barMinimized { app.barMinimized = false }
        }
    }
}

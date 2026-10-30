import Combine
import SwiftData
import SwiftUI

/// The app: four tabs, the + menu, and the sheets they open.
struct RootView: View {
    @State private var app = AppState()
    @Query private var profiles: [Profile]
    @State private var didApplyPrefs = false

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
        .environment(app)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            app.dayChanged()
        }
        .onChange(of: app.tab) { _, _ in app.actionsOpen = false }
        .onAppear {
            guard !didApplyPrefs else { return }
            didApplyPrefs = true
            app.hidden = profiles.first?.hideOnOpen ?? false
            app.assetsHidden = app.hidden || (profiles.first?.hideAssets ?? false)
        }
    }
}

/// Navigation Bar (Figma 2026-10-30): Today, Due, Finance, AI in one glass capsule, and the
/// round green + beside it. The system tab bar can't hold a separate + on this iOS, so this is
/// drawn with the system Liquid Glass effect (glassEffect), which still follows Reduce
/// Transparency and the light / dark look.
private struct AppTabBar: View {
    @Environment(AppState.self) private var app

    private let tabs: [(AppState.TabID, String, String)] = [
        (.today, "Today", "calendar"),
        (.due, "Due", "doc.text.fill"),
        (.finance, "Finance", "chart.pie.fill"),
        (.ai, "AI", "sparkles"),
    ]

    var body: some View {
        GlassEffectContainer(spacing: Space.s12) {
            HStack(spacing: Space.s12) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.0) { id, title, symbol in
                        let on = app.tab == id
                        Button {
                            app.tab = id
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: symbol).font(.system(size: 19, weight: .semibold))
                                Text(title).font(AppFont.main(11, .semibold, relativeTo: .caption2))
                            }
                            .foregroundStyle(on ? Tokens.brand600 : Tokens.text900)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background { if on { Capsule().fill(Tokens.text900.opacity(0.08)) } }
                            .contentShape(.capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(title)
                        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(4)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button {
                    animate { app.actionsOpen.toggle() }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(app.actionsOpen ? 45 : 0))
                        .frame(width: 60, height: 60)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(Tokens.writeButton).interactive(), in: .circle)
                .accessibilityLabel(app.actionsOpen ? "Close menu" : "Add")
                .accessibilityHint("Talk With AI, Template or Scan")
            }
        }
        .padding(.horizontal, Space.s20)
        .padding(.bottom, Space.s4)
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
                        ActionPill(title: "Talk With AI", systemImage: "sparkles") { app.openAssistant() }
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
                .font(AppFont.main(15, .semibold))
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

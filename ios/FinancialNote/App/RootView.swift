import Combine
import SwiftData
import SwiftUI

/// The five tabs (Figma Navigation Bar Ver 2, 961:31747) as the system tab bar, so it gets real
/// Liquid Glass, minimises on scroll and follows Reduce Transparency by itself. The round green
/// write button floats above its right end.
struct RootView: View {
    @State private var app = AppState()
    @Query private var profiles: [Profile]
    @State private var didApplyPrefs = false

    var body: some View {
        TabView(selection: $app.tab) {
            Tab("Today", systemImage: "calendar", value: AppState.TabID.today) {
                TodayView()
            }
            Tab("Due", systemImage: "doc.text.fill", value: AppState.TabID.due) {
                DueView()
            }
            Tab("Scan", systemImage: "viewfinder", value: AppState.TabID.scan) {
                ScanView()
            }
            Tab("Finance", systemImage: "chart.pie.fill", value: AppState.TabID.finance) {
                FinanceView()
            }
            Tab("Profile", systemImage: "person.fill", value: AppState.TabID.profile) {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(Tokens.brand600)
        .overlay(alignment: .bottomTrailing) {
            WriteButton()
                .padding(.trailing, Space.s20)
                .padding(.bottom, 76)
        }
        .sheet(item: $app.assistant) { seed in
            AssistantSheet(seed: seed)
        }
        .sheet(isPresented: $app.dayNoteOpen) {
            DayNoteEditor()
        }
        .environment(app)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            app.dayChanged()
        }
        .onAppear {
            guard !didApplyPrefs else { return }
            didApplyPrefs = true
            app.hidden = profiles.first?.hideOnOpen ?? false
            app.assetsHidden = app.hidden || (profiles.first?.hideAssets ?? false)
        }
    }
}

/// The round green write button (Navigation Bar Ver 2). Tap: the Assistant. Hold: Notes of the day.
private struct WriteButton: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Menu {
            Button("Write with the Assistant", systemImage: "square.and.pencil") { app.openAssistant() }
            Button("Notes of the day", systemImage: "note.text") { app.dayNoteOpen = true }
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .glassEffect(.regular.tint(Tokens.writeButton).interactive(), in: .circle)
        } primaryAction: {
            app.openAssistant()
        }
        .accessibilityLabel("Write")
        .accessibilityHint("Opens the Assistant. Touch and hold for Notes of the day.")
    }
}

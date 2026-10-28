import Combine
import SwiftData
import SwiftUI

/// The five tabs (Figma Navigation Bar Ver 2, 961:31747) as the system tab bar, so it gets real
/// Liquid Glass, minimises on scroll and follows Reduce Transparency by itself. The quick-note
/// field and the write menu sit in the bar's bottom accessory.
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
        .tabViewBottomAccessory {
            QuickNoteAccessory()
        }
        .tint(Tokens.brand500)
        .overlay {
            if app.quick != nil {
                QuickNoteLayer()
                    .transition(.opacity)
            }
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

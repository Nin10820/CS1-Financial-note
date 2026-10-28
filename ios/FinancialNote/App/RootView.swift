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
                ComingLaterView(
                    title: "Due", systemImage: "doc.text",
                    text: "Bills and installments come in the next build. Your sample bills are already saved on this phone.")
            }
            Tab("Scan", systemImage: "viewfinder", value: AppState.TabID.scan) {
                ScanView()
            }
            Tab("Finance", systemImage: "chart.pie.fill", value: AppState.TabID.finance) {
                ComingLaterView(
                    title: "Finance", systemImage: "chart.pie",
                    text: "Assets, debt and “Taken care of” come in a later build.")
            }
            Tab("Profile", systemImage: "person.fill", value: AppState.TabID.profile) {
                ComingLaterView(
                    title: "Profile", systemImage: "person",
                    text: "Your name, your data and display settings come in a later build. Everything already stays on this phone.")
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
        }
    }
}

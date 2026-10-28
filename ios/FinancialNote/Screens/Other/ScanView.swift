import SwiftUI

/// Scan tab. Reading receipts with the camera isn't built, so it says so and offers typing.
struct ScanView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Scanning comes later", systemImage: "viewfinder")
                    .font(AppFont.heading(22))
            } description: {
                Text("Reading receipts with the camera isn't built yet. You can type what you spent instead — one line is enough.")
                    .font(AppFont.main(15))
            } actions: {
                Button("Type it instead") { app.openQuickNote() }
                    .font(AppFont.main(16, .semibold))
                    .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
            }
            .navigationTitle("Scan")
            .toolbarTitleDisplayMode(.inline)
        }
    }
}

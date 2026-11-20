import SwiftUI

/// The profile button at the top right of Today, Due and Finance.
struct ProfileButton: View {
    @Environment(AppState.self) private var app

    var body: some View {
        Button {
            app.profileOpen = true
        } label: {
            AppIcon(.user, size: 24)
                .foregroundStyle(Tokens.brand600)
        }
        .accessibilityLabel("Profile")
    }
}

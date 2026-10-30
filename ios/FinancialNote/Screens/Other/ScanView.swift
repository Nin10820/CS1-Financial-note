import SwiftUI

/// Scan — Figma 1077:21312: the camera frame with X, QR Code / Note and flip below.
/// Reading receipts and QR codes isn't built yet, so the frame says so plainly and offers
/// typing instead. The camera is never opened.
struct ScanView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .qr

    enum Mode: String, CaseIterable { case qr = "QR Code", note = "Note" }

    var body: some View {
        VStack(spacing: Space.s16) {
            ZStack {
                RoundedRectangle(cornerRadius: 28).fill(Color(hex: 0x0D121C))
                VStack(spacing: Space.s12) {
                    Image(systemName: mode == .qr ? "qrcode.viewfinder" : "doc.text.viewfinder")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(Tokens.onDarkMuted)
                    Text("Scanning comes later")
                        .font(AppFont.heading(20, .semibold))
                        .foregroundStyle(.white)
                    Text(mode == .qr
                         ? "Reading a payment QR code isn't built yet. The camera stays off."
                         : "Reading a receipt or a written note isn't built yet. The camera stays off.")
                        .font(AppFont.main(14))
                        .foregroundStyle(Tokens.onDark)
                        .multilineTextAlignment(.center)
                    Button("Type it instead") {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(400))
                            app.templateOpen = true
                        }
                    }
                    .font(AppFont.main(15, .semibold))
                    .buttonStyle(.glassProminent)
                    .tint(Tokens.action)
                    .padding(.top, Space.s8)
                }
                .padding(Space.s32)
            }
            .padding(.horizontal, Space.s12)

            HStack {
                Button("Close", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.text900)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
                Spacer()
                Picker("Scan", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
                Button {} label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Tokens.grey300)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: .circle)
                .disabled(true)
                .accessibilityLabel("Switch camera, comes later")
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s8)
        }
        .background(Tokens.bg3)
    }
}

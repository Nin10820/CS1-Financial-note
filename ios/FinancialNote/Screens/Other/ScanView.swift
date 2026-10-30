import AVFoundation
import SwiftUI

/// Scan — Figma 1077:21312: the camera with X, QR Code / Note and the shutter below.
/// QR Code reads a VietQR payment code and opens a filled-in line to check and save.
/// Note reads the words on a receipt or a written note and hands them to the AI tab, where
/// nothing is saved until Confirm. The camera runs only while this screen is open, everything
/// is read on the phone, and no photo is kept.
struct ScanView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .qr
    @State private var access = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var lines: [String] = []
    @State private var notPayment: String?

    enum Mode: String, CaseIterable { case qr = "QR Code", note = "Note" }

    var body: some View {
        VStack(spacing: Space.s16) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 28).fill(Color(hex: 0x0D121C))
                camera
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(.rect(cornerRadius: 28))
                if let notPayment {
                    banner(notPayment)
                } else if mode == .note && canScan {
                    banner(lines.isEmpty ? "Point at a receipt or a written note" : "\(lines.count) \(lines.count == 1 ? "line" : "lines") found")
                } else if mode == .qr && canScan {
                    banner("Point at a payment QR code")
                }
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
                Button(action: useText) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(mode == .note && !lines.isEmpty ? Tokens.action : Tokens.grey300, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(mode != .note || lines.isEmpty)
                .accessibilityLabel("Use this text")
            }
            .padding(.horizontal, Space.s20)
            .padding(.bottom, Space.s8)
        }
        .background(Tokens.bg3)
        .task {
            #if DEBUG
            // UI tests: feed a code as if the camera had read it.
            if let i = CommandLine.arguments.firstIndex(of: "-scanPayload"), i + 1 < CommandLine.arguments.count {
                try? await Task.sleep(for: .milliseconds(600))
                readCode(CommandLine.arguments[i + 1])
                return
            }
            #endif
            // Ask for the camera only on a device that has one, once this screen is fully open.
            guard CameraScanner.isSupported, access == .notDetermined else { return }
            try? await Task.sleep(for: .milliseconds(500))
            _ = await AVCaptureDevice.requestAccess(for: .video)
            access = AVCaptureDevice.authorizationStatus(for: .video)
        }
        .onChange(of: mode) { _, _ in
            lines = []
            notPayment = nil
        }
    }

    private var canScan: Bool { CameraScanner.isSupported && access == .authorized && CameraScanner.isAvailable }

    @ViewBuilder
    private var camera: some View {
        if !CameraScanner.isSupported {
            message("This needs the iPhone camera",
                    "Scanning works on an iPhone. This device (or the Simulator) has no camera it can use.")
        } else if access == .denied || access == .restricted {
            message("Camera is off for Financial Note",
                    "Turn it on in Settings › Financial Note › Camera. Nothing is recorded or sent.",
                    settings: true)
        } else if access == .authorized && CameraScanner.isAvailable {
            CameraScanner(
                mode: mode == .qr ? .qr : .text,
                onCode: readCode,
                onText: { lines = $0 })
                .id(mode)
        } else {
            ProgressView().tint(.white)
        }
    }

    private func message(_ title: String, _ text: String, settings: Bool = false) -> some View {
        VStack(spacing: Space.s12) {
            Image(systemName: mode == .qr ? "qrcode.viewfinder" : "doc.text.viewfinder")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Tokens.onDarkMuted)
            Text(title).font(AppFont.heading(20, .semibold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(text).font(AppFont.main(14)).foregroundStyle(Tokens.onDark).multilineTextAlignment(.center)
            if settings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                .font(AppFont.main(15, .semibold))
                .buttonStyle(.glass)
            }
            Button("Type it instead") { open { app.templateOpen = true } }
                .font(AppFont.main(15, .semibold))
                .buttonStyle(.glassProminent)
                .tint(Tokens.action)
                .padding(.top, Space.s8)
        }
        .padding(Space.s32)
    }

    private func banner(_ text: String) -> some View {
        Text(text)
            .font(AppFont.main(14, .medium))
            .foregroundStyle(Tokens.text900)
            .padding(.horizontal, Space.s16)
            .padding(.vertical, Space.s8)
            .glassEffect(.regular.tint(Tokens.bgWhite.opacity(0.9)), in: .capsule)
            .padding(.bottom, Space.s20)
            .accessibilityAddTraits(.updatesFrequently)
    }

    /// A payment code becomes a new line, filled in, to check and save.
    private func readCode(_ payload: String) {
        guard let qr = VietQR(payload: payload) else {
            notPayment = "That code isn't a payment QR"
            return
        }
        var e = EntryEdit()
        e.title = qr.title
        e.amount = qr.amount
        e.date = app.today
        e.paidFrom = "Transfer"
        e.source = "Scanned QR" + (qr.bankName.map { " · \($0)" } ?? "")
        if let t = Tags.suggest(title: e.title, category: e.category) { e.tags = [t] }
        open {
            app.templatePrefill = e
            app.templateOpen = true
        }
    }

    /// The words on screen go to the AI tab as a note, read into lines to confirm there.
    private func useText() {
        let found = lines
        guard !found.isEmpty else { return }
        open { app.openAssistant(date: app.today, noteLines: found) }
    }

    /// Closes the camera first, then opens the next screen.
    private func open(_ next: @escaping () -> Void) {
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            next()
        }
    }
}

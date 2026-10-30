import AVFoundation
import Speech
import SwiftUI

/// Talk With AI (from the owner's video): a full-screen moving gradient, "Tell me all the details
/// about your transaction", the words appearing as you speak, X to cancel and ✓ to send.
/// Speech is turned into text on the phone only — if this phone can't do that offline for the
/// chosen language, it says so instead of sending audio anywhere.
struct VoiceNoteView: View {
    var onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var listener = SpeechListener()
    @AppStorage("voiceLanguage") private var language = "vi-VN"

    var body: some View {
        ZStack {
            MovingGradient(still: reduceMotion)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            Text(shown)
                .font(AppFont.main(listener.text.isEmpty ? 30 : 26, .bold, relativeTo: .title))
                .foregroundStyle(.white.opacity(listener.text.isEmpty ? 0.55 : 1))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.s32)
                .contentTransition(.opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: listener.text)
                .accessibilityAddTraits(.updatesFrequently)

            VStack {
                HStack {
                    Spacer()
                    Button(action: switchLanguage) {
                        Text(language == "vi-VN" ? "🇻🇳" : "🇺🇸")
                            .font(.system(size: 22))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(language == "vi-VN" ? "Listening in Vietnamese. Switch to English" : "Listening in English. Switch to Vietnamese")
                }
                Spacer()
                HStack {
                    Button {
                        listener.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Tokens.text900)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Cancel")
                    Spacer()
                    Button(action: finish) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(Tokens.action).interactive(), in: .circle)
                    .disabled(listener.text.isEmpty)
                    .opacity(listener.text.isEmpty ? 0.6 : 1)
                    .accessibilityLabel("Send what you said")
                }
            }
            .padding(.horizontal, Space.s24)
            .padding(.vertical, Space.s16)
        }
        .task(id: language) { await listener.start(language: language) }
        .onDisappear { listener.stop() }
    }

    /// The prompt until words come in, then the words; or why it can't listen.
    private var shown: String {
        if let problem = listener.problem { return problem }
        return listener.text.isEmpty ? "Tell me all the details about your transaction" : listener.text
    }

    private func switchLanguage() {
        listener.stop()
        language = language == "vi-VN" ? "en-US" : "vi-VN"
    }

    private func finish() {
        let said = listener.text.trimmingCharacters(in: .whitespacesAndNewlines)
        listener.stop()
        dismiss()
        guard !said.isEmpty else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            onDone(said)
        }
    }
}

/// Soft brand colours drifting slowly behind the words; still when Reduce Motion is on.
private struct MovingGradient: View {
    var still: Bool

    var body: some View {
        TimelineView(.animation(paused: still)) { tl in
            let t = still ? 0 : tl.date.timeIntervalSinceReferenceDate
            let d = { (speed: Double, phase: Double) in Float(sin(t * speed + phase) * 0.18) }
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + d(0.6, 0), 0], [1, 0],
                    [0, 0.5 + d(0.5, 1)], [0.5 + d(0.7, 2), 0.5 + d(0.4, 3)], [1, 0.5 + d(0.55, 4)],
                    [0, 1], [0.5 + d(0.45, 5), 1], [1, 1],
                ],
                colors: [
                    Color(hex: 0x3B6922), Color(hex: 0x5FA82F), Color(hex: 0x83C853),
                    Color(hex: 0x4C8A26), Color(hex: 0x2C481F), Color(hex: 0x5FA82F),
                    Color(hex: 0x1C3314), Color(hex: 0x3B6922), Color(hex: 0x364152),
                ])
                .blur(radius: 30)
        }
    }
}

/// Live speech-to-text with the system recognizer, on the phone only.
@Observable
final class SpeechListener {
    var text = ""
    var problem: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?

    func start(language: String) async {
        text = ""
        problem = nil
        guard await Self.allowed() else {
            problem = "Microphone or Speech Recognition is off for Financial Note. Turn them on in Settings, or type instead."
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: language)), recognizer.isAvailable else {
            problem = "Voice isn't available right now. You can type instead."
            return
        }
        guard recognizer.supportsOnDeviceRecognition else {
            problem = language == "vi-VN"
                ? "This phone can't turn Vietnamese speech into text offline yet. Tap the flag for English, or type instead."
                : "This phone can't turn speech into text offline. You can type instead."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true // never leaves the phone
            request.addsPunctuation = true
            self.request = request

            Self.installTap(on: engine.inputNode, feeding: request)
            engine.prepare()
            try engine.start()

            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let words = result?.bestTranscription.formattedString
                let done = error != nil || (result?.isFinal ?? false)
                Task { @MainActor in
                    if let words { self?.text = words }
                    if done { self?.stop() }
                }
            }
        } catch {
            problem = "The microphone couldn't start. You can type instead."
            stop()
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// The audio tap runs on the audio thread, so it lives outside the main actor.
    private nonisolated static func installTap(on node: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
            request.append(buffer)
        }
    }

    private static func allowed() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in c.resume(returning: status == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

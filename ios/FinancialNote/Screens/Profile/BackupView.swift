import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Profile › Backup & restore: keep a copy of everything in a folder you pick in Files
/// (rewritten after each change), and put a copy back from that folder or any saved file.
struct BackupView: View {
    @Environment(\.modelContext) private var context
    @State private var backup = BackupFolder.shared
    @State private var picking: Pick?
    /// A file read and waiting for "Replace everything?".
    @State private var restoring: ExportFile?
    @State private var result: String?

    private enum Pick { case folder, file }

    var body: some View {
        List {
            Section {
                if let name = backup.folderName {
                    LabeledContent("Folder", value: name)
                    LabeledContent("Last saved", value: backup.lastSaved.map(Self.when) ?? "Not yet")
                }
                Button(backup.isOn ? "Change folder" : "Choose a folder", systemImage: "folder") { picking = .folder }
                if backup.isOn {
                    Button("Save now", systemImage: "arrow.clockwise") { backup.saveNow(container: context.container) }
                    Button("Stop backing up", systemImage: "xmark.circle") { backup.stop() }
                        .foregroundStyle(Tokens.text700)
                }
                if let problem = backup.problem {
                    Text(problem).font(AppFont.main(12)).foregroundStyle(Tokens.grey400)
                }
            } header: {
                Text("Back up to a folder")
            } footer: {
                Text("After each change, the app saves financial-note.json and spreadsheet files (CSV) to this folder. Pick a folder in iCloud Drive to keep a copy if you lose this phone. Your data never leaves this phone; the app only goes online to get today's exchange rates.")
            }
            .listRowBackground(Tokens.card)

            Section {
                if backup.isOn {
                    Button("Restore from the backup folder", systemImage: "clock.arrow.circlepath") { readFolder() }
                }
                Button("Restore from a file", systemImage: "doc") { picking = .file }
            } header: {
                Text("Restore")
            } footer: {
                Text("Puts back everything from a financial-note.json file. It replaces what's on this phone now.")
            }
            .listRowBackground(Tokens.card)
        }
        .appListSurface()
        .font(AppFont.main(14, .medium))
        .tint(Tokens.brand600)
        .navigationTitle("Backup & restore")
        .toolbarTitleDisplayMode(.inline)
        .fileImporter(isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
                      allowedContentTypes: picking == .folder ? [.folder] : [.json]) { picked in
            let kind = picking
            picking = nil
            guard case let .success(url) = picked else { return }
            if kind == .folder { backup.choose(url, container: context.container) } else { readFile(url) }
        }
        .confirmationDialog("Replace everything on this phone?", isPresented: Binding(
            get: { restoring != nil }, set: { if !$0 { restoring = nil } }), titleVisibility: .visible, presenting: restoring) { file in
            Button("Replace with this file", role: .destructive) { restore(file) }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("The file has \(file.summary), saved \(Self.when(file.exported)). What's on this phone now will be gone.")
        }
        .alert(result ?? "", isPresented: Binding(get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK") {}
        }
    }

    private func readFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            restoring = try ExportFile.decode(Data(contentsOf: url))
        } catch {
            result = "That file isn't a Financial Note backup."
        }
    }

    private func readFolder() {
        do {
            if let file = try backup.readBackup() { restoring = file } else { result = "There's no backup in the folder yet." }
        } catch {
            result = "Couldn't read the backup in \(backup.folderName ?? "the folder")."
        }
    }

    private func restore(_ file: ExportFile) {
        do {
            try LocalStore(context: context).restore(file)
            result = "Restored \(file.summary)."
        } catch {
            result = "Couldn't restore. Nothing was put back."
        }
    }

    /// "Today 16:40", "Yesterday 09:12", or "18 Nov 2026 09:12".
    static func when(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today \(time)" }
        if cal.isDateInYesterday(date) { return "Yesterday \(time)" }
        return date.formatted(.dateTime.day().month(.abbreviated).year()) + " " + time
    }
}

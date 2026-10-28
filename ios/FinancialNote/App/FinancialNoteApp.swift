import SwiftData
import SwiftUI

@main
struct FinancialNoteApp: App {
    let container: ModelContainer

    init() {
        // Everything lives in one SwiftData store on this phone. Nothing is synced or sent anywhere.
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: Schema(AppSchema.models), configurations: config)
        } catch {
            fatalError("Couldn't open the on-device store: \(error)")
        }
        LocalStore(context: container.mainContext).prepareOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            FoundationView()
        }
        .modelContainer(container)
    }
}

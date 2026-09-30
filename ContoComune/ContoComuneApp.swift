//
//  ContoComuneApp.swift
//  ContoComune
//
//  Created by Andrea Rizzi on 04/09/2026.
//

import SwiftUI
import SwiftData

@main
struct ContoComuneApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    let sharedModelContainer: ModelContainer = {
        // cloudKitDatabase: .none è OBBLIGATORIO: con l'entitlement iCloud
        // attivo SwiftData proverebbe a sincronizzare da solo (solo database
        // privato, niente condivisione) e rifiuterebbe lo schema. La sync la
        // fa il nostro SyncManager con CKSyncEngine.
        let modelConfiguration = ModelConfiguration(
            schema: AppSchema.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: AppSchema.schema, configurations: [modelConfiguration])
            // Le modifiche fatte dall'utente sono marcate come "locali": il
            // motore di sync le distingue da quelle arrivate da iCloud.
            container.mainContext.author = AppSchema.autoreLocale
            MigrazioneIdentificativi.sistemaDuplicati(in: container.mainContext)
            return container
        } catch {
            fatalError("Impossibile creare il ModelContainer: \(error)")
        }
    }()

    init() {
        // Non fa nulla finché la sync non è attivata in SyncConfig.
        SyncManager.shared.configura(container: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

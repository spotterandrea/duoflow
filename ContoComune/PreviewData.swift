import Foundation
import SwiftData

/// Container SwiftData in memoria con dati di esempio, usato SOLO dalle
/// #Preview di Xcode per vedere le schermate popolate senza toccare il
/// database reale. Non viene mai usato nell'app in esecuzione.
enum PreviewData {
    @MainActor
    static let container: ModelContainer = {
        let config = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try! ModelContainer(for: AppSchema.schema, configurations: [config])
        let ctx = container.mainContext

        let marco = Persona(nome: "Marco")
        let giulia = Persona(nome: "Giulia")
        ctx.insert(marco)
        ctx.insert(giulia)

        let mese = Date().startOfMonth
        ctx.insert(QuotaMensile(persona: marco, mese: mese, stipendio: 1600))
        ctx.insert(QuotaMensile(persona: giulia, mese: mese, stipendio: 1300))

        for (nome, cat, imp, giorno) in [
            ("Affitto", "Casa", 750.0, 5),
            ("Luce e gas (media)", "Utenze", 140.0, nil),
            ("Internet", "Casa", 29.99, nil),
            ("Spesa alimentare", "Alimentari", 400.0, nil)
        ] as [(String, String, Double, Int?)] {
            ctx.insert(SpesaRicorrente(nome: nome, categoria: cat, importoStimatoMensile: imp, giornoAddebito: giorno))
        }

        ctx.insert(Versamento(persona: marco, importo: 723.00, mese: mese))
        ctx.insert(Fattura(fornitore: "Luce", periodoRiferimento: "Ago–Set 2026", importo: 115, scadenza: Date().addingTimeInterval(86400 * 20)))
        ctx.insert(SpesaExtra(descrizione: "Riparazione lavatrice", importo: 85, categoria: "Manutenzione"))

        return container
    }()

    /// Container vuoto, per vedere l'onboarding del primo avvio.
    @MainActor
    static let containerVuoto: ModelContainer = {
        let config = ModelConfiguration(schema: AppSchema.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: AppSchema.schema, configurations: [config])
    }()
}

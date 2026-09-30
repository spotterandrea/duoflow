import Foundation
import SwiftData

/// Unico punto in cui è elencato lo schema SwiftData dell'app, così app,
/// anteprime e motore di sincronizzazione usano sempre lo stesso elenco di
/// modelli (prima era duplicato in ContoComuneApp e PreviewData).
enum AppSchema {
    static let schema = Schema([
        Persona.self,
        QuotaMensile.self,
        SpesaRicorrente.self,
        Fattura.self,
        Versamento.self,
        SpesaExtra.self
    ])

    /// Autore delle modifiche fatte dall'utente sul telefono. Le modifiche
    /// arrivate da iCloud usano invece `autoreSync`: così il motore di sync,
    /// leggendo la history, invia a CloudKit solo le modifiche locali e non
    /// rimanda indietro quelle appena ricevute (niente "eco").
    static let autoreLocale = "utente"
    static let autoreSync = "sync"
}

/// Tutti i modelli sincronizzabili espongono lo stesso identificativo stabile.
protocol RecordSincronizzabile: PersistentModel {
    var uuid: UUID { get set }
}

extension Persona: RecordSincronizzabile {}
extension QuotaMensile: RecordSincronizzabile {}
extension SpesaRicorrente: RecordSincronizzabile {}
extension Fattura: RecordSincronizzabile {}
extension Versamento: RecordSincronizzabile {}
extension SpesaExtra: RecordSincronizzabile {}

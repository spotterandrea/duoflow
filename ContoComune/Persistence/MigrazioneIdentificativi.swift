import Foundation
import SwiftData

/// Sistema una volta sola gli `uuid` dei record creati PRIMA che il campo
/// esistesse. Durante la migrazione leggera SwiftData riempie la nuova
/// colonna con un valore di default che può essere identico per tutte le
/// righe esistenti: qui ogni doppione riceve un UUID nuovo, così ogni record
/// ha un identificativo davvero univoco prima che la sync lo usi come nome
/// del record su CloudKit. Idempotente: se non ci sono doppioni non tocca nulla.
enum MigrazioneIdentificativi {

    @MainActor
    static func sistemaDuplicati(in context: ModelContext) {
        var modificato = false
        modificato = sistema(Persona.self, in: context) || modificato
        modificato = sistema(QuotaMensile.self, in: context) || modificato
        modificato = sistema(SpesaRicorrente.self, in: context) || modificato
        modificato = sistema(Fattura.self, in: context) || modificato
        modificato = sistema(Versamento.self, in: context) || modificato
        modificato = sistema(SpesaExtra.self, in: context) || modificato
        if modificato {
            try? context.save()
        }
    }

    /// Ritorna true se ha dovuto riassegnare almeno un uuid.
    @MainActor
    private static func sistema<T: RecordSincronizzabile>(_ tipo: T.Type, in context: ModelContext) -> Bool {
        guard let tutti = try? context.fetch(FetchDescriptor<T>()) else { return false }
        var visti = Set<UUID>()
        var modificato = false
        for record in tutti {
            if visti.contains(record.uuid) {
                record.uuid = UUID()
                modificato = true
            }
            visti.insert(record.uuid)
        }
        return modificato
    }
}

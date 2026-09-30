import Foundation
import SwiftData

/// Una spesa occasionale, non pianificata, ma pagata comunque dal conto
/// comune (es. una manutenzione imprevista, un acquisto per casa). A
/// differenza delle SpesaRicorrente, non ha un importo stimato mensile:
/// esiste solo come singolo movimento in uscita dal conto comune.
@Model
final class SpesaExtra {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var descrizione: String
    var importo: Double
    var categoria: String
    var data: Date
    var note: String?

    init(
        descrizione: String,
        importo: Double,
        categoria: String,
        data: Date = .now,
        note: String? = nil
    ) {
        self.descrizione = descrizione
        self.importo = importo
        self.categoria = categoria
        self.data = data
        self.note = note
    }
}

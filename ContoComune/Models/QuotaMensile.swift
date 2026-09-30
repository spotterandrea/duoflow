import Foundation
import SwiftData

/// Lo "stato economico" di una persona per un dato mese: lo stipendio di
/// quel mese e, facoltativamente, una percentuale scelta a mano invece del
/// calcolo automatico. È la schermata Impostazioni, in pratica.
///
/// Due modalità, che ricalcano il foglio originale:
/// - **Automatica** (percentualeManuale = nil): la quota è proporzionale allo
///   stipendio rispetto al totale degli stipendi del mese, e la somma delle
///   quote copre esattamente il totale delle spese ricorrenti.
/// - **Manuale** (percentualeManuale valorizzata): la quota è quella
///   percentuale del proprio stipendio, punto — come nel foglio (65% / 55%),
///   dove la somma può anche non coincidere esattamente con le spese
///   (generando un margine, positivo o negativo).
///
/// Un record per persona per mese: se per un mese non esiste ancora, la UI
/// può proporre come default l'ultimo valore noto, ma va comunque confermato
/// e salvato esplicitamente (per non far scattare in automatico i calcoli
/// futuri su una cifra mai confermata per quel mese).
@Model
final class QuotaMensile {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var persona: Persona?
    var mese: Date              // normalizzato al primo giorno del mese
    var stipendio: Double
    var percentualeManuale: Double?   // es. 0.65 = 65% dello stipendio; nil = calcolo automatico

    init(
        persona: Persona?,
        mese: Date,
        stipendio: Double,
        percentualeManuale: Double? = nil
    ) {
        self.persona = persona
        self.mese = mese
        self.stipendio = stipendio
        self.percentualeManuale = percentualeManuale
    }

    var usaCalcoloAutomatico: Bool { percentualeManuale == nil }
}

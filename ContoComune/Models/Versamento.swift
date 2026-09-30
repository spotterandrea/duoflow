import Foundation
import SwiftData

/// Un versamento mensile di una persona sul conto comune: la registrazione
/// concreta che "questo mese ho versato la mia quota". Serve a distinguere
/// la quota *dovuta* (calcolata dal BudgetEngine) dalla quota *effettivamente
/// versata* (questo record), così l'app può dirti se sei in pari o no.
@Model
final class Versamento {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var persona: Persona?
    var importo: Double
    var mese: Date              // normalizzato al primo giorno del mese di riferimento
    var dataVersamento: Date
    var note: String?

    init(
        persona: Persona?,
        importo: Double,
        mese: Date,
        dataVersamento: Date = .now,
        note: String? = nil
    ) {
        self.persona = persona
        self.importo = importo
        self.mese = mese
        self.dataVersamento = dataVersamento
        self.note = note
    }
}

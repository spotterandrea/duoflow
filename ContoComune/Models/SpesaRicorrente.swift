import Foundation
import SwiftData

enum PeriodicitaSpesa: String, Codable, CaseIterable {
    case mensile
    case bimestrale
    case annuale
}

/// Una voce fissa del budget della casa: mutuo, corrente, gas, acqua, TARI,
/// internet, spesa alimentare... L'importo è sempre il suo equivalente
/// MENSILE (come nel foglio: TARI e giardiniere sono spese annuali già
/// divise per 12), usato per calcolare quanto ciascuno deve versare ogni
/// mese. `periodicita` è solo informativa (utile in UI per ricordare che
/// la fattura reale non arriva ogni mese) e non entra nei calcoli.
@Model
final class SpesaRicorrente {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var nome: String            // es. "Mutuo", "Corrente ENEL", "TARI"
    var categoria: String       // es. "Casa", "Utenze", "Alimentari"
    var importoStimatoMensile: Double
    var periodicita: PeriodicitaSpesa   // informativa: quanto spesso arriva la fattura reale
    var attiva: Bool            // per disattivare una voce senza cancellare lo storico

    /// Giorno del mese (1...31) in cui la spesa viene addebitata, se noto
    /// (es. il mutuo il 27). `nil` = nessuna data fissa configurata: la voce
    /// entra comunque nel totale mensile, ma non compare tra i "prossimi
    /// addebiti" né nel saldo previsto, perché non sappiamo quando cade.
    /// Se il mese è più corto del giorno scelto (es. 31 a febbraio), viene
    /// usato l'ultimo giorno disponibile di quel mese; se cade di sabato o
    /// domenica, la data effettiva slitta al primo giorno feriale successivo
    /// (vedi `BudgetEngine.dataAddebito`), ma il giorno primario resta questo.
    var giornoAddebito: Int?

    /// Primo giorno dell'ultimo mese per cui l'addebito automatico è già
    /// stato registrato (come Fattura pagata). Serve a non registrarlo due
    /// volte, e a NON ricrearlo se l'utente elimina quel pagamento (es. il
    /// mese in cui il mutuo non è stato addebitato). Sincronizzato: così i
    /// due iPhone non lo registrano entrambi. Vedi `AddebitiAutomatici`.
    var ultimoMeseAddebitato: Date?

    @Relationship(deleteRule: .nullify, inverse: \Fattura.spesaRicorrente)
    var fatture: [Fattura] = []

    init(
        nome: String,
        categoria: String,
        importoStimatoMensile: Double,
        periodicita: PeriodicitaSpesa = .mensile,
        attiva: Bool = true,
        giornoAddebito: Int? = nil
    ) {
        self.nome = nome
        self.categoria = categoria
        self.importoStimatoMensile = importoStimatoMensile
        self.periodicita = periodicita
        self.attiva = attiva
        self.giornoAddebito = giornoAddebito
    }
}

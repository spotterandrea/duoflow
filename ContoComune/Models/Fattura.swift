import Foundation
import SwiftData

/// Una bolletta/fattura concreta, es. quella che arriva ogni due mesi da ENEL.
/// Digitalizza il foglio "Bollette utenze": fornitore, periodo coperto, importo,
/// scadenza, e se/quando è stata pagata. Collegata (facoltativamente) alla voce
/// ricorrente di riferimento, così sai a quale spesa fissa appartiene.
@Model
final class Fattura {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var fornitore: String              // es. "ENEL", "Simecom", "Uniacque"
    var periodoRiferimento: String     // es. "AGO. 2025 - SET. 2025"
    var importo: Double
    var scadenza: Date
    var pagata: Bool
    var dataPagamento: Date?

    var spesaRicorrente: SpesaRicorrente?

    init(
        fornitore: String,
        periodoRiferimento: String,
        importo: Double,
        scadenza: Date,
        pagata: Bool = false,
        dataPagamento: Date? = nil,
        spesaRicorrente: SpesaRicorrente? = nil
    ) {
        self.fornitore = fornitore
        self.periodoRiferimento = periodoRiferimento
        self.importo = importo
        self.scadenza = scadenza
        self.pagata = pagata
        self.dataPagamento = dataPagamento
        self.spesaRicorrente = spesaRicorrente
    }

    /// Segna la fattura come pagata dal conto comune, registrando quando.
    func segnaComePagata(data: Date = .now) {
        pagata = true
        dataPagamento = data
    }
}

import Foundation
import SwiftData
import CryptoKit

/// Registra da solo il pagamento delle spese fisse con giorno di addebito
/// (es. mutuo il 27): quando la data è arrivata crea una Fattura già pagata,
/// collegata alla voce, così il saldo attuale scende UNA volta, nel giorno
/// giusto. Il pagamento compare in Bollette → "Pagate di recente" e si può
/// modificare (importo reale diverso) o eliminare (addebito non avvenuto):
/// eliminato, non viene ricreato.
///
/// Prima questi addebiti comparivano solo nel "saldo previsto": passata la
/// data, il saldo attuale non scendeva mai.
enum AddebitiAutomatici {

    /// Da chiamare all'avvio e ogni volta che l'app torna in primo piano.
    /// Idempotente: se non c'è nulla da registrare non modifica niente.
    @MainActor
    static func registraScaduti(in context: ModelContext, oggi: Date = .now, calendar: Calendar = .current) {
        guard let voci = try? context.fetch(FetchDescriptor<SpesaRicorrente>()) else { return }
        let meseCorrente = calendar.startOfMonth(for: oggi)
        var modificato = false

        for voce in voci where voce.attiva && voce.giornoAddebito != nil {
            // Voce appena configurata: si parte da qui, senza arretrati.
            // Se l'addebito di questo mese è già passato lo si considera
            // gestito (non sappiamo se era stato registrato a mano).
            guard let ultimo = voce.ultimoMeseAddebitato else {
                let dataQuestoMese = BudgetEngine.dataAddebito(voce, mese: meseCorrente, calendar: calendar)
                let passato = dataQuestoMese.map { calendar.startOfDay(for: $0) <= calendar.startOfDay(for: oggi) } ?? false
                voce.ultimoMeseAddebitato = passato
                    ? meseCorrente
                    : calendar.date(byAdding: .month, value: -1, to: meseCorrente)
                modificato = true
                continue
            }

            // Dal mese successivo all'ultimo registrato fino a oggi (max 12
            // mesi di arretrati, se l'app non è stata aperta per molto).
            var mese = calendar.date(byAdding: .month, value: 1, to: calendar.startOfMonth(for: ultimo)) ?? meseCorrente
            var passi = 0
            while mese <= meseCorrente && passi < 12 {
                passi += 1
                guard let data = BudgetEngine.dataAddebito(voce, mese: mese, calendar: calendar),
                      calendar.startOfDay(for: data) <= calendar.startOfDay(for: oggi) else { break }

                let uuid = uuidDeterministico(voce: voce, mese: mese, calendar: calendar)
                let esiste = ((try? context.fetch(FetchDescriptor<Fattura>(predicate: #Predicate { $0.uuid == uuid }))) ?? []).isEmpty == false
                if !esiste {
                    let pagamento = Fattura(
                        fornitore: voce.nome,
                        periodoRiferimento: "Addebito automatico · \(Formatting.monthTitle(mese))",
                        importo: voce.importoStimatoMensile,
                        scadenza: data,
                        pagata: true,
                        dataPagamento: data,
                        spesaRicorrente: voce
                    )
                    pagamento.uuid = uuid
                    context.insert(pagamento)
                }
                voce.ultimoMeseAddebitato = mese
                modificato = true
                mese = calendar.date(byAdding: .month, value: 1, to: mese) ?? meseCorrente.addingTimeInterval(1)
            }
        }
        if modificato {
            try? context.save()
        }
    }

    /// Stesso uuid per la stessa voce nello stesso mese, su qualunque iPhone:
    /// se entrambi i telefoni registrano l'addebito prima di sincronizzarsi,
    /// finiscono sullo stesso record CloudKit invece di creare un doppione.
    static func uuidDeterministico(voce: SpesaRicorrente, mese: Date, calendar: Calendar = .current) -> UUID {
        let c = calendar.dateComponents([.year, .month], from: mese)
        let chiave = "addebito-\(voce.uuid.uuidString)-\(c.year ?? 0)-\(c.month ?? 0)"
        var byte = Array(SHA256.hash(data: Data(chiave.utf8)).prefix(16))
        byte[6] = (byte[6] & 0x0F) | 0x50   // versione 5 (basato su nome)
        byte[8] = (byte[8] & 0x3F) | 0x80   // variante RFC 4122
        return UUID(uuid: (byte[0], byte[1], byte[2], byte[3], byte[4], byte[5], byte[6], byte[7],
                           byte[8], byte[9], byte[10], byte[11], byte[12], byte[13], byte[14], byte[15]))
    }
}

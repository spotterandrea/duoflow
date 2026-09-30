import Foundation
import SwiftData

/// Riproduce, in codice, le formule del foglio "Budget casa - convivenza":
/// quota mensile dovuta da ciascuno (proporzionale allo stipendio), stato dei
/// versamenti, e saldo del conto comune. Nessuno stato qui dentro: prende in
/// input i dati letti da SwiftData e restituisce numeri pronti per la UI.
enum BudgetEngine {

    // MARK: - Quote mensili

    /// Totale mensile delle spese ricorrenti attive (equivalente a C13 nel foglio).
    /// `importoStimatoMensile` è sempre il valore già ricondotto al mese (come TARI
    /// o giardiniere nel foglio, spese annuali divise per 12): la `periodicita` è
    /// solo informativa su quanto spesso arriva la fattura reale, non filtra qui.
    static func totaleSpeseRicorrentiMensili(_ speseRicorrenti: [SpesaRicorrente]) -> Double {
        speseRicorrenti
            .filter(\.attiva)
            .reduce(0) { $0 + $1.importoStimatoMensile }
    }

    /// Quota dovuta da ciascuna persona per il mese a cui appartengono le
    /// `QuotaMensile` passate (equivalente a C28/C29 nel foglio). Per chi è in
    /// modalità automatica, la quota è proporzionale al proprio stipendio
    /// rispetto al totale degli stipendi di quel mese; per chi ha impostato una
    /// percentuale manuale, la quota è quella percentuale del proprio stipendio,
    /// indipendentemente dal totale delle spese (può creare un margine, come
    /// il 65%/55% del foglio originale che lasciava +6,24€ di eccedenza).
    ///
    /// Nota: il totale degli stipendi usato per la modalità automatica include
    /// comunque tutte le persone del mese, anche quelle in modalità manuale —
    /// così il calcolo resta coerente se in futuro una sola persona passa a
    /// percentuale fissa e l'altra resta automatica.
    static func quoteMensili(_ quoteMese: [QuotaMensile], speseRicorrenti: [SpesaRicorrente]) -> [PersonaID: Double] {
        let totaleSpese = totaleSpeseRicorrentiMensili(speseRicorrenti)
        let totaleStipendi = quoteMese.reduce(0) { $0 + $1.stipendio }

        var risultato: [PersonaID: Double] = [:]
        for quota in quoteMese {
            guard let persona = quota.persona else { continue }
            if let percentualeManuale = quota.percentualeManuale {
                risultato[PersonaID(persona)] = quota.stipendio * percentualeManuale
            } else if totaleStipendi > 0 {
                risultato[PersonaID(persona)] = totaleSpese * (quota.stipendio / totaleStipendi)
            } else {
                risultato[PersonaID(persona)] = 0
            }
        }
        return risultato
    }

    /// Differenza tra la somma di tutte le quote del mese e il totale delle
    /// spese ricorrenti: positiva se si versa più del necessario (margine),
    /// negativa se non basta a coprirle. Equivalente alla cella C31 del foglio
    /// ("TOTALE INSERITO - TOTALE SPESE MENSILI RICORRENTI").
    static func margineRispettoAlleSpese(quoteMese: [QuotaMensile], speseRicorrenti: [SpesaRicorrente]) -> Double {
        let totaleQuote = quoteMensili(quoteMese, speseRicorrenti: speseRicorrenti).values.reduce(0, +)
        return totaleQuote - totaleSpeseRicorrentiMensili(speseRicorrenti)
    }

    // MARK: - Stato dei versamenti

    /// Quanto una persona ha effettivamente versato in un dato mese.
    static func versatoNelMese(_ persona: Persona, mese: Date, versamenti: [Versamento]) -> Double {
        let calendar = Calendar.current
        return versamenti
            .filter { $0.persona === persona && calendar.isDate($0.mese, equalTo: mese, toGranularity: .month) }
            .reduce(0) { $0 + $1.importo }
    }

    /// Se la persona è in pari con la propria quota per il mese dato.
    /// Una piccola tolleranza (1 centesimo) evita falsi negativi da arrotondamenti.
    static func inPari(_ persona: Persona, mese: Date, quotaAttesa: Double, versamenti: [Versamento]) -> Bool {
        versatoNelMese(persona, mese: mese, versamenti: versamenti) >= quotaAttesa - 0.01
    }

    // MARK: - Saldo conto comune

    /// Saldo attuale del conto comune: tutto ciò che è stato versato, meno tutto
    /// ciò che è stato effettivamente pagato (fatture pagate + spese extra).
    /// Le SpesaRicorrente da sole NON impattano il saldo: contano solo quando
    /// diventano una Fattura pagata, così il saldo riflette i movimenti reali,
    /// non quelli pianificati.
    static func saldoContoComune(versamenti: [Versamento], fatture: [Fattura], speseExtra: [SpesaExtra]) -> Double {
        let totaleVersato = versamenti.reduce(0) { $0 + $1.importo }
        let totaleFatturePagate = fatture.filter(\.pagata).reduce(0) { $0 + $1.importo }
        let totaleSpeseExtra = speseExtra.reduce(0) { $0 + $1.importo }
        return totaleVersato - totaleFatturePagate - totaleSpeseExtra
    }

    /// Fatture ancora da pagare, ordinate per scadenza più vicina prima:
    /// è il "cosa resta da pagare" richiesto per la dashboard.
    static func fattureDaPagare(_ fatture: [Fattura]) -> [Fattura] {
        fatture
            .filter { !$0.pagata }
            .sorted { $0.scadenza < $1.scadenza }
    }

    // MARK: - Ricorrenze con data fissa e saldo previsto

    /// Data effettiva in cui una spesa ricorrente con giorno fisso viene
    /// addebitata in un dato mese: il `giornoAddebito` configurato, clampato
    /// all'ultimo giorno disponibile se il mese è più corto (es. 31 a
    /// febbraio), e spostato al primo giorno feriale successivo se cade di
    /// sabato o domenica — il giorno "primario" salvato sulla voce non
    /// cambia mai, qui si calcola solo quando escono davvero i soldi.
    /// Ritorna `nil` se la voce non ha un giorno fisso configurato.
    static func dataAddebito(_ spesa: SpesaRicorrente, mese: Date, calendar: Calendar = .current) -> Date? {
        guard let giorno = spesa.giornoAddebito else { return nil }
        var comps = calendar.dateComponents([.year, .month], from: mese)
        let giorniNelMese = calendar.range(of: .day, in: .month, for: mese)?.count ?? 28
        comps.day = min(max(giorno, 1), giorniNelMese)
        guard var data = calendar.date(from: comps) else { return nil }
        while calendar.isDateInWeekend(data) {
            data = calendar.date(byAdding: .day, value: 1, to: data) ?? data
        }
        return data
    }

    /// true se l'addebito di quel mese è già stato registrato come pagamento
    /// reale: allora è già nel saldo attuale e non va ricontato nelle previsioni.
    static func addebitoGiaRegistrato(_ spesa: SpesaRicorrente, mese: Date, calendar: Calendar = .current) -> Bool {
        guard let ultimo = spesa.ultimoMeseAddebitato else { return false }
        return calendar.startOfMonth(for: mese) <= calendar.startOfMonth(for: ultimo)
    }

    /// I prossimi addebiti (voci ricorrenti attive con giorno fisso) da oggi
    /// fino a `finoAGiorni` giorni nel futuro, ordinati per data più vicina.
    /// Guarda il mese corrente e i due successivi, cosi una voce con
    /// scadenza già passata questo mese mostra comunque la prossima.
    ///
    /// `soloIlProssimoPerVoce` (default true): per ogni voce mostra solo la
    /// prossima data utile. Prima, con una finestra di 45 giorni, il mutuo
    /// del 27 compariva due volte (fine settembre e fine ottobre) e sembrava
    /// venisse scalato due volte.
    static func prossimiAddebiti(
        _ speseRicorrenti: [SpesaRicorrente],
        oggi: Date = .now,
        finoAGiorni: Int = 60,
        soloIlProssimoPerVoce: Bool = true,
        calendar: Calendar = .current
    ) -> [(spesa: SpesaRicorrente, data: Date)] {
        let inizioOggi = calendar.startOfDay(for: oggi)
        let limite = calendar.date(byAdding: .day, value: finoAGiorni, to: inizioOggi) ?? inizioOggi

        var risultati: [(spesa: SpesaRicorrente, data: Date)] = []
        for spesa in speseRicorrenti where spesa.attiva && spesa.giornoAddebito != nil {
            for offset in 0...2 {
                guard let mese = calendar.date(byAdding: .month, value: offset, to: oggi),
                      !addebitoGiaRegistrato(spesa, mese: mese, calendar: calendar),
                      let data = dataAddebito(spesa, mese: mese, calendar: calendar) else { continue }
                if data >= inizioOggi && data <= limite {
                    risultati.append((spesa: spesa, data: data))
                    if soloIlProssimoPerVoce { break }   // i mesi sono in ordine: la prima è la prossima
                }
            }
        }
        return risultati.sorted { $0.data < $1.data }
    }

    /// Saldo previsto del conto comune a una certa data futura: parte dal
    /// saldo attuale e sottrae le voci ricorrenti con data fissa che, tra
    /// oggi e quella data, avranno il loro addebito — così il saldo mostrato
    /// riflette quello che succederà davvero (es. il saldo scende quando
    /// arriva il giorno del mutuo), non solo i movimenti già avvenuti.
    ///
    /// Filtra direttamente per data (non passando da un conteggio di giorni
    /// come `prossimiAddebiti`): calcolare prima "quanti giorni mancano" da
    /// `oggi` (che ha un orario, es. le 14:45) a `dataObiettivo` (sempre
    /// mezzanotte) e poi ririfiltrare per quel numero di giorni arrotondava
    /// per difetto ed escludeva l'addebito del giorno esatto — il saldo
    /// previsto restava a 0 invece di scendere.
    static func saldoPrevisto(
        al dataObiettivo: Date,
        oggi: Date = .now,
        versamenti: [Versamento],
        fatture: [Fattura],
        speseExtra: [SpesaExtra],
        speseRicorrenti: [SpesaRicorrente],
        calendar: Calendar = .current
    ) -> Double {
        let saldoAttuale = saldoContoComune(versamenti: versamenti, fatture: fatture, speseExtra: speseExtra)
        let inizioOggi = calendar.startOfDay(for: oggi)

        var totaleAddebiti: Double = 0
        for spesa in speseRicorrenti where spesa.attiva && spesa.giornoAddebito != nil {
            for offset in 0...2 {
                guard let mese = calendar.date(byAdding: .month, value: offset, to: oggi),
                      !addebitoGiaRegistrato(spesa, mese: mese, calendar: calendar),
                      let data = dataAddebito(spesa, mese: mese, calendar: calendar) else { continue }
                if data >= inizioOggi && data <= dataObiettivo {
                    totaleAddebiti += spesa.importoStimatoMensile
                }
            }
        }
        return saldoAttuale - totaleAddebiti
    }
}

/// SwiftData @Model non è Hashable in modo comodo da usare come chiave di
/// dizionario tra istanze diverse; questo wrapper leggero risolve senza
/// toccare il modello. persistentModelID è stabile anche prima del salvataggio.
struct PersonaID: Hashable {
    let id: PersistentIdentifier
    let nome: String

    init(_ persona: Persona) {
        self.id = persona.persistentModelID
        self.nome = persona.nome
    }
}

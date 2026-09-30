import Foundation

/// Testi della guida in-app, tutti in un unico posto: quando cambia una
/// funzione dell'app, si aggiorna solo questo file.
///
/// Regole di scrittura: risposte brevi (2-4 frasi), tono diretto, nessun
/// termine tecnico che l'utente non vede nell'app.
enum ContenutiGuida {

    struct Domanda: Identifiable, Hashable {
        /// Identificativo stabile, usato per aprire direttamente una domanda
        /// dai pulsanti "?" sparsi nell'app (vedi `ArgomentoGuida`).
        let id: String
        let domanda: String
        let risposta: String
    }

    struct Sezione: Identifiable {
        let id: String
        let titolo: String
        let icona: String
        let domande: [Domanda]
    }

    static let sezioni: [Sezione] = [
        Sezione(id: "base", titolo: "Come funziona", icona: "book.fill", domande: [
            Domanda(
                id: "cos-e",
                domanda: "A cosa serve DuoFlow?",
                risposta: "È il registro del vostro conto comune. Sapete ogni mese quanto deve versare ciascuno, cosa è già stato versato, quali bollette e spese sono state pagate e quanto resta sul conto."
            ),
            Domanda(
                id: "saldo",
                domanda: "Come viene calcolato il saldo attuale?",
                risposta: "È la somma di tutti i versamenti registrati, meno le bollette segnate come pagate (compresi gli addebiti automatici) e le spese extra. Si calcola dall'inizio: non si azzera a fine mese e nessun dato viene cancellato da solo."
            ),
            Domanda(
                id: "saldo-iniziale",
                domanda: "Sul conto c'erano già dei soldi: come li inserisco?",
                risposta: "Il saldo parte da zero. Se il conto aveva già dei soldi, registra un versamento con quell'importo (per esempio con la nota \"Saldo iniziale\")."
            ),
            Domanda(
                id: "questo-iphone",
                domanda: "A cosa serve \"Chi usa questo iPhone\"?",
                risposta: "Quando registri un versamento, l'app propone già il tuo nome e la tua quota. Vale solo per questo telefono e si cambia in Impostazioni."
            ),
        ]),

        Sezione(id: "quote", titolo: "Quote mensili", icona: "chart.pie.fill", domande: [
            Domanda(
                id: "quota-automatica",
                domanda: "Come viene calcolata la quota di ciascuno?",
                risposta: "Con il calcolo automatico, il totale delle spese fisse del mese viene diviso in proporzione agli stipendi. Esempio: con 1.500 € e 1.000 € di stipendio, il primo copre il 60% delle spese e il secondo il 40%. Se nessuno inserisce lo stipendio, la quota resta a zero."
            ),
            Domanda(
                id: "percentuale-manuale",
                domanda: "Cos'è la percentuale manuale?",
                risposta: "Invece del calcolo automatico, la quota diventa una percentuale fissa del proprio stipendio (per esempio il 50%). Si attiva per ciascuna persona in Impostazioni. La somma delle due quote può così essere diversa dal totale delle spese."
            ),
            Domanda(
                id: "margine",
                domanda: "Perché la somma delle quote non è uguale alle spese?",
                risposta: "Succede quando almeno uno dei due usa la percentuale manuale: la quota dipende dallo stipendio, non dalle spese. Se versate di più, la differenza resta sul conto; se versate di meno, il conto scende."
            ),
            Domanda(
                id: "stipendi-mesi",
                domanda: "Se cambio lo stipendio, cambiano anche i mesi passati?",
                risposta: "No. Lo stipendio che modifichi vale per il mese corrente: i mesi precedenti restano calcolati con gli stipendi di allora."
            ),
            Domanda(
                id: "in-pari",
                domanda: "Cosa vuol dire \"In pari\" e \"Da versare\"?",
                risposta: "\"In pari\" significa che i versamenti di quella persona per il mese corrente coprono la sua quota. \"Da versare\" significa che manca ancora qualcosa: l'importo esatto è nella scheda Versamenti."
            ),
        ]),

        Sezione(id: "versamenti", titolo: "Versamenti", icona: "arrow.up.arrow.down.circle.fill", domande: [
            Domanda(
                id: "mese-riferimento",
                domanda: "Cos'è il mese di riferimento di un versamento?",
                risposta: "È la quota che quel versamento copre. Esempio: un bonifico del 2 ottobre per la quota di settembre va registrato con mese di riferimento settembre, così settembre risulta in pari."
            ),
            Domanda(
                id: "modifica-versamento",
                domanda: "Ho sbagliato un versamento: come lo correggo?",
                risposta: "In Versamenti tocca la riga per modificare tutto (persona, importo, mese, data, note). Tenendo premuto si apre il menu con Modifica ed Elimina."
            ),
        ]),

        Sezione(id: "spese", titolo: "Spese fisse e addebiti", icona: "calendar", domande: [
            Domanda(
                id: "spese-fisse",
                domanda: "Cosa sono le spese fisse?",
                risposta: "Le voci che pagate ogni mese dal conto comune: affitto o mutuo, utenze, internet, spesa. Il loro totale mensile è la base per calcolare le quote. Si gestiscono in Impostazioni → Voci di spesa ricorrenti."
            ),
            Domanda(
                id: "importo-mensile",
                domanda: "Come inserisco una spesa annuale o bimestrale?",
                risposta: "Inserisci l'importo equivalente al mese: una tassa annuale da 150 € diventa 12,50 € al mese. Così la quota mensile accantona la cifra giusta. La bolletta reale la registri poi in Bollette quando arriva."
            ),
            Domanda(
                id: "disattiva-voce",
                domanda: "Che differenza c'è tra disattivare ed eliminare una voce?",
                risposta: "Una voce disattivata non entra più nelle quote, ma resta collegata alle bollette già registrate. Eliminarla la toglie del tutto. Se una spesa finisce, di solito conviene disattivarla."
            ),
            Domanda(
                id: "addebito-automatico",
                domanda: "Cos'è l'addebito automatico?",
                risposta: "Se una spesa fissa ha un giorno di addebito (per esempio il mutuo il 27), quel giorno l'app registra da sola il pagamento e il saldo scende. Lo trovi in Bollette → Pagate di recente, con la dicitura \"Addebito automatico\". Viene registrato all'apertura dell'app."
            ),
            Domanda(
                id: "addebito-diverso",
                domanda: "L'importo addebitato è diverso, oppure quel mese non c'è stato: cosa faccio?",
                risposta: "In Bollette tocca il pagamento automatico e correggi l'importo. Se l'addebito non è avvenuto, eliminalo: non verrà ricreato."
            ),
            Domanda(
                id: "weekend",
                domanda: "Cosa succede se il giorno di addebito cade nel weekend?",
                risposta: "Come fanno le banche, l'addebito slitta al primo giorno feriale successivo. Se il mese è più corto (per esempio il 31 a febbraio), si usa l'ultimo giorno del mese."
            ),
            Domanda(
                id: "saldo-previsto",
                domanda: "Cos'è il saldo previsto?",
                risposta: "È il saldo che avrete dopo il prossimo addebito fisso: il saldo attuale meno le spese con giorno di addebito in arrivo. Serve a capire in anticipo se sul conto ci sarà abbastanza."
            ),
        ]),

        Sezione(id: "bollette", titolo: "Bollette ed extra", icona: "doc.text.fill", domande: [
            Domanda(
                id: "bollette",
                domanda: "Come funzionano le bollette?",
                risposta: "Registra ogni bolletta con importo e scadenza: resta in \"Da pagare\" (in rosso se scaduta) finché non la tocchi per segnarla come pagata. Solo allora viene sottratta dal saldo."
            ),
            Domanda(
                id: "bolletta-vs-extra",
                domanda: "Che differenza c'è tra bolletta, spesa fissa ed extra?",
                risposta: "La spesa fissa è la previsione mensile che decide le quote. La bolletta è il pagamento reale, e può essere collegata alla sua spesa fissa. L'extra è una spesa occasionale non prevista, per esempio una riparazione, pagata dal conto comune."
            ),
            Domanda(
                id: "modifica-bolletta",
                domanda: "Come modifico o elimino una bolletta o un extra?",
                risposta: "Tocca la riga per modificarla; tenendo premuto si apre il menu con Modifica ed Elimina. Tutti i campi, importo compreso, si possono sempre correggere."
            ),
        ]),

        Sezione(id: "condivisione", titolo: "Condivisione con il partner", icona: "person.2.fill", domande: [
            Domanda(
                id: "invita",
                domanda: "Come invito il mio partner?",
                risposta: "Impostazioni → Condivisione → Invita il partner, poi manda il link con Messaggi, WhatsApp o Mail. Il partner deve avere DuoFlow installato e aprire il link dal suo iPhone. Servono due account iCloud, uno a testa."
            ),
            Domanda(
                id: "partner-dati",
                domanda: "Il mio partner aveva già inserito dei dati: che fine fanno?",
                risposta: "Quando accetta l'invito, l'app lo avvisa: i dati inseriti fino a quel momento sul suo iPhone vengono sostituiti da quelli del conto condiviso. Conviene quindi che sia uno solo dei due a configurare l'app all'inizio."
            ),
            Domanda(
                id: "sincronizzazione",
                domanda: "Quanto ci mettono le modifiche ad arrivare sull'altro iPhone?",
                risposta: "Di solito pochi secondi, se entrambi siete connessi a internet. Senza connessione l'app funziona lo stesso: le modifiche partono appena torna la rete. Se serve, in Impostazioni c'è \"Sincronizza ora\"."
            ),
            Domanda(
                id: "stessa-modifica",
                domanda: "Cosa succede se modifichiamo la stessa cosa nello stesso momento?",
                risposta: "Resta l'ultima modifica arrivata su iCloud. Per le cose importanti, come l'importo di un versamento, conviene che se ne occupi uno dei due alla volta."
            ),
            Domanda(
                id: "interrompi",
                domanda: "Cosa succede se la condivisione viene interrotta?",
                risposta: "Il partner vede un avviso: i dati restano sul suo iPhone, ma non si aggiornano più. Chi ha creato il conto comune continua a usarlo normalmente."
            ),
            Domanda(
                id: "ripristino",
                domanda: "Come ricomincio da capo?",
                risposta: "Impostazioni → Ripristino → Ripristina l'app, con doppia conferma. Se il conto l'hai creato tu, i dati vengono eliminati anche da iCloud e la condivisione termina. Se sei stato invitato, esci dal conto condiviso e i dati del partner restano intatti. Con iCloud attivo serve la connessione a internet: senza, non viene eliminato nulla."
            ),
            Domanda(
                id: "senza-icloud",
                domanda: "Posso usare DuoFlow senza iCloud?",
                risposta: "Sì, ma i dati restano solo su quel telefono e non si possono condividere. Senza iCloud, inoltre, non c'è una copia di sicurezza: se perdi il telefono, perdi i dati."
            ),
        ]),

        Sezione(id: "privacy", titolo: "Privacy e dati", icona: "lock.fill", domande: [
            Domanda(
                id: "dove-dati",
                domanda: "Dove sono salvati i miei dati?",
                risposta: "Sul vostro iPhone e nel vostro iCloud. DuoFlow non ha server propri: i dati non passano da nessun altro."
            ),
            Domanda(
                id: "chi-legge",
                domanda: "Chi può vedere i miei dati?",
                risposta: "Solo tu e la persona che hai invitato. Su iCloud i dati (importi, stipendi, nomi, note) sono cifrati: nemmeno lo sviluppatore dell'app può leggerli."
            ),
            Domanda(
                id: "pubblicita",
                domanda: "L'app contiene pubblicità o tracciamenti?",
                risposta: "No: niente pubblicità, niente tracciamento, niente statistiche di utilizzo."
            ),
        ]),
    ]

    /// Tutte le domande in un unico elenco, per la ricerca.
    static var tutte: [(sezione: Sezione, domanda: Domanda)] {
        sezioni.flatMap { sezione in sezione.domande.map { (sezione, $0) } }
    }
}

import Foundation
import CloudKit
import SwiftData

/// Conversione tra i modelli SwiftData e i record CloudKit.
///
/// - Il nome di ogni record è "<Tipo>.<uuid>", così dal solo CKRecord.ID si
///   sa sia il tipo sia quale oggetto locale cercare.
/// - Tutti i campi dell'utente vanno in `encryptedValues`: sono cifrati da
///   iCloud (end-to-end con la Protezione avanzata dei dati) e nemmeno lo
///   sviluppatore li può leggere dalla dashboard CloudKit.
/// - Le relazioni (es. Versamento → Persona) sono salvate come uuid testuale
///   e ricollegate all'arrivo; se l'oggetto collegato non è ancora arrivato,
///   il collegamento resta "pendente" e viene ritentato al lotto successivo.
enum MappaturaRecord {

    enum Tipo: String, CaseIterable {
        case persona = "Persona"
        case quotaMensile = "QuotaMensile"
        case spesaRicorrente = "SpesaRicorrente"
        case fattura = "Fattura"
        case versamento = "Versamento"
        case spesaExtra = "SpesaExtra"

        /// Ordine in cui applicare i record ricevuti: prima quelli a cui gli
        /// altri fanno riferimento.
        var ordineApplicazione: Int {
            switch self {
            case .persona: return 0
            case .spesaRicorrente: return 1
            default: return 2
            }
        }
    }

    // MARK: - Identificativi

    static func nomeRecord(tipo: Tipo, uuid: UUID) -> String {
        "\(tipo.rawValue).\(uuid.uuidString)"
    }

    static func scomponi(_ nomeRecord: String) -> (tipo: Tipo, uuid: UUID)? {
        let parti = nomeRecord.split(separator: ".", maxSplits: 1).map(String.init)
        guard parti.count == 2, let tipo = Tipo(rawValue: parti[0]), let uuid = UUID(uuidString: parti[1]) else { return nil }
        return (tipo, uuid)
    }

    static func tipo(di modello: any PersistentModel) -> Tipo? {
        switch modello {
        case is Persona: return .persona
        case is QuotaMensile: return .quotaMensile
        case is SpesaRicorrente: return .spesaRicorrente
        case is Fattura: return .fattura
        case is Versamento: return .versamento
        case is SpesaExtra: return .spesaExtra
        default: return nil
        }
    }

    // MARK: - Locale → CloudKit

    /// Scrive i campi del modello dentro `record` (nuovo o con i campi di
    /// sistema già noti, per non generare conflitti inutili).
    static func riempi(_ record: CKRecord, da modello: any PersistentModel) {
        let v = record.encryptedValues
        switch modello {
        case let p as Persona:
            v["nome"] = p.nome
        case let q as QuotaMensile:
            v["persona"] = q.persona?.uuid.uuidString
            v["mese"] = q.mese
            v["stipendio"] = q.stipendio
            v["percentualeManuale"] = q.percentualeManuale
        case let s as SpesaRicorrente:
            v["nome"] = s.nome
            v["categoria"] = s.categoria
            v["importoStimatoMensile"] = s.importoStimatoMensile
            v["periodicita"] = s.periodicita.rawValue
            v["attiva"] = s.attiva
            v["giornoAddebito"] = s.giornoAddebito
            v["ultimoMeseAddebitato"] = s.ultimoMeseAddebitato
        case let f as Fattura:
            v["fornitore"] = f.fornitore
            v["periodoRiferimento"] = f.periodoRiferimento
            v["importo"] = f.importo
            v["scadenza"] = f.scadenza
            v["pagata"] = f.pagata
            v["dataPagamento"] = f.dataPagamento
            v["spesaRicorrente"] = f.spesaRicorrente?.uuid.uuidString
        case let ve as Versamento:
            v["persona"] = ve.persona?.uuid.uuidString
            v["importo"] = ve.importo
            v["mese"] = ve.mese
            v["dataVersamento"] = ve.dataVersamento
            v["note"] = ve.note
        case let e as SpesaExtra:
            v["descrizione"] = e.descrizione
            v["importo"] = e.importo
            v["categoria"] = e.categoria
            v["data"] = e.data
            v["note"] = e.note
        default:
            break
        }
    }

    // MARK: - CloudKit → locale

    /// Riferimenti che non è stato possibile ricollegare subito:
    /// campo → uuid dell'oggetto collegato.
    typealias Riferimenti = [String: String]

    /// Crea o aggiorna l'oggetto locale corrispondente a `record`.
    /// Ritorna i riferimenti rimasti in sospeso (vuoto se tutto collegato).
    @discardableResult
    static func applica(_ record: CKRecord, in context: ModelContext, indice: IndiceLocale) -> Riferimenti {
        guard case let (tipo, uuid)? = scomponi(record.recordID.recordName) else { return [:] }
        let v = record.encryptedValues
        var pendenti: Riferimenti = [:]

        // Tipo di ritorno esplicito: fa scegliere il subscript generico
        // tipizzato di CloudKit invece di quello Objective-C.
        func stringa(_ k: String) -> String? { v[k] }
        func numero(_ k: String) -> Double? { v[k] }
        func data(_ k: String) -> Date? { v[k] }
        func booleano(_ k: String) -> Bool? { v[k] }
        func intero(_ k: String) -> Int? { v[k] }

        switch tipo {
        case .persona:
            let p = indice.trova(Persona.self, uuid) ?? indice.nuovo(Persona(nome: ""), uuid: uuid, in: context)
            p.nome = stringa("nome") ?? p.nome

        case .quotaMensile:
            let q = indice.trova(QuotaMensile.self, uuid)
                ?? indice.nuovo(QuotaMensile(persona: nil, mese: .now, stipendio: 0), uuid: uuid, in: context)
            q.mese = data("mese") ?? q.mese
            q.stipendio = numero("stipendio") ?? 0
            q.percentualeManuale = numero("percentualeManuale")
            q.persona = collega(Persona.self, campo: "persona", valore: stringa("persona"), indice: indice, pendenti: &pendenti)

        case .spesaRicorrente:
            let s = indice.trova(SpesaRicorrente.self, uuid)
                ?? indice.nuovo(SpesaRicorrente(nome: "", categoria: "", importoStimatoMensile: 0), uuid: uuid, in: context)
            s.nome = stringa("nome") ?? s.nome
            s.categoria = stringa("categoria") ?? s.categoria
            s.importoStimatoMensile = numero("importoStimatoMensile") ?? 0
            s.periodicita = stringa("periodicita").flatMap(PeriodicitaSpesa.init(rawValue:)) ?? .mensile
            s.attiva = booleano("attiva") ?? true
            s.giornoAddebito = intero("giornoAddebito")
            s.ultimoMeseAddebitato = data("ultimoMeseAddebitato")

        case .fattura:
            let f = indice.trova(Fattura.self, uuid)
                ?? indice.nuovo(Fattura(fornitore: "", periodoRiferimento: "", importo: 0, scadenza: .now), uuid: uuid, in: context)
            f.fornitore = stringa("fornitore") ?? f.fornitore
            f.periodoRiferimento = stringa("periodoRiferimento") ?? f.periodoRiferimento
            f.importo = numero("importo") ?? 0
            f.scadenza = data("scadenza") ?? f.scadenza
            f.pagata = booleano("pagata") ?? false
            f.dataPagamento = data("dataPagamento")
            f.spesaRicorrente = collega(SpesaRicorrente.self, campo: "spesaRicorrente", valore: stringa("spesaRicorrente"), indice: indice, pendenti: &pendenti)

        case .versamento:
            let ve = indice.trova(Versamento.self, uuid)
                ?? indice.nuovo(Versamento(persona: nil, importo: 0, mese: .now), uuid: uuid, in: context)
            ve.importo = numero("importo") ?? 0
            ve.mese = data("mese") ?? ve.mese
            ve.dataVersamento = data("dataVersamento") ?? ve.dataVersamento
            ve.note = stringa("note")
            ve.persona = collega(Persona.self, campo: "persona", valore: stringa("persona"), indice: indice, pendenti: &pendenti)

        case .spesaExtra:
            let e = indice.trova(SpesaExtra.self, uuid)
                ?? indice.nuovo(SpesaExtra(descrizione: "", importo: 0, categoria: ""), uuid: uuid, in: context)
            e.descrizione = stringa("descrizione") ?? e.descrizione
            e.importo = numero("importo") ?? 0
            e.categoria = stringa("categoria") ?? e.categoria
            e.data = data("data") ?? e.data
            e.note = stringa("note")
        }
        return pendenti
    }

    /// Risolve un riferimento per uuid. Se l'oggetto collegato non esiste
    /// ancora in locale, annota il riferimento tra i pendenti.
    private static func collega<T: RecordSincronizzabile>(
        _ tipo: T.Type, campo: String, valore: String?, indice: IndiceLocale, pendenti: inout Riferimenti
    ) -> T? {
        guard let valore, let uuid = UUID(uuidString: valore) else { return nil }
        if let trovato = indice.trova(tipo, uuid) { return trovato }
        pendenti[campo] = valore
        return nil
    }

    /// Ricollega i riferimenti rimasti in sospeso. Ritorna quelli ancora
    /// irrisolti (vuoto = tutto a posto).
    static func risolviPendenti(nomeRecord: String, _ riferimenti: Riferimenti, indice: IndiceLocale) -> Riferimenti {
        guard case let (tipo, uuid)? = scomponi(nomeRecord) else { return [:] }
        var ancoraPendenti: Riferimenti = [:]
        for (campo, valore) in riferimenti {
            guard let uuidCollegato = UUID(uuidString: valore) else { continue }
            switch (tipo, campo) {
            case (.quotaMensile, "persona"):
                if let p = indice.trova(Persona.self, uuidCollegato) { indice.trova(QuotaMensile.self, uuid)?.persona = p } else { ancoraPendenti[campo] = valore }
            case (.versamento, "persona"):
                if let p = indice.trova(Persona.self, uuidCollegato) { indice.trova(Versamento.self, uuid)?.persona = p } else { ancoraPendenti[campo] = valore }
            case (.fattura, "spesaRicorrente"):
                if let s = indice.trova(SpesaRicorrente.self, uuidCollegato) { indice.trova(Fattura.self, uuid)?.spesaRicorrente = s } else { ancoraPendenti[campo] = valore }
            default:
                break
            }
        }
        return ancoraPendenti
    }

    /// Elimina l'oggetto locale corrispondente a un record cancellato altrove.
    static func elimina(nomeRecord: String, in context: ModelContext, indice: IndiceLocale) {
        guard case let (tipo, uuid)? = scomponi(nomeRecord) else { return }
        let oggetto: (any PersistentModel)? = {
            switch tipo {
            case .persona: return indice.trova(Persona.self, uuid)
            case .quotaMensile: return indice.trova(QuotaMensile.self, uuid)
            case .spesaRicorrente: return indice.trova(SpesaRicorrente.self, uuid)
            case .fattura: return indice.trova(Fattura.self, uuid)
            case .versamento: return indice.trova(Versamento.self, uuid)
            case .spesaExtra: return indice.trova(SpesaExtra.self, uuid)
            }
        }()
        if let oggetto {
            context.delete(oggetto)
            indice.rimuovi(nomeRecord: nomeRecord)
        }
    }
}

/// Indice in memoria "nome record → oggetto" su un ModelContext, costruito
/// una volta per lotto di modifiche: evita un fetch per ogni record e
/// non usa #Predicate su proprietà di protocollo (non supportato da SwiftData).
final class IndiceLocale {
    private var oggetti: [String: any PersistentModel] = [:]

    init(context: ModelContext) {
        carica(Persona.self, .persona, context)
        carica(QuotaMensile.self, .quotaMensile, context)
        carica(SpesaRicorrente.self, .spesaRicorrente, context)
        carica(Fattura.self, .fattura, context)
        carica(Versamento.self, .versamento, context)
        carica(SpesaExtra.self, .spesaExtra, context)
    }

    private func carica<T: RecordSincronizzabile>(_ t: T.Type, _ tipo: MappaturaRecord.Tipo, _ context: ModelContext) {
        for o in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
            oggetti[MappaturaRecord.nomeRecord(tipo: tipo, uuid: o.uuid)] = o
        }
    }

    func trova<T: RecordSincronizzabile>(_ t: T.Type, _ uuid: UUID) -> T? {
        guard let tipo = MappaturaRecord.Tipo(rawValue: String(describing: T.self)) else { return nil }
        return oggetti[MappaturaRecord.nomeRecord(tipo: tipo, uuid: uuid)] as? T
    }

    func trova(nomeRecord: String) -> (any PersistentModel)? {
        oggetti[nomeRecord]
    }

    func nuovo<T: RecordSincronizzabile>(_ oggetto: T, uuid: UUID, in context: ModelContext) -> T {
        oggetto.uuid = uuid
        context.insert(oggetto)
        if let tipo = MappaturaRecord.Tipo(rawValue: String(describing: T.self)) {
            oggetti[MappaturaRecord.nomeRecord(tipo: tipo, uuid: uuid)] = oggetto
        }
        return oggetto
    }

    func rimuovi(nomeRecord: String) {
        oggetti[nomeRecord] = nil
    }

    var tuttiINomi: [String] { Array(oggetti.keys) }
}

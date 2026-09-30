import Foundation
import CloudKit
import SwiftData
import Observation

/// Motore di sincronizzazione iCloud tra i due iPhone della coppia.
///
/// Architettura (vedi `Documentazione/Sync-iCloud.md`):
/// - SwiftData resta l'archivio locale: l'app funziona identica anche offline
///   o senza iCloud.
/// - CKSyncEngine gestisce invio/ricezione, notifiche push e nuovi tentativi.
/// - Tutti i dati di una coppia stanno in UNA zona CloudKit ("ContoComune")
///   nel database privato di chi ha creato il conto; il partner la riceve
///   tramite uno share di zona e ci lavora dal proprio database condiviso.
///   Ogni coppia è quindi isolata per costruzione.
/// - Le modifiche locali si scoprono leggendo la history di SwiftData
///   (autore "utente"); quelle scaricate da iCloud sono scritte con autore
///   "sync" e ignorate, così non tornano indietro.
@Observable
final class SyncManager {

    static let shared = SyncManager()

    enum StatoAccount: Equatable {
        case sconosciuto, disponibile, assente, limitato
    }

    private(set) var ruolo: RuoloSync
    private(set) var statoAccount: StatoAccount = .sconosciuto
    private(set) var ultimaSincronizzazione: Date?
    private(set) var inCorso = false
    var ultimoErrore: String?
    /// Invito ricevuto che richiede conferma (su questo iPhone ci sono già
    /// dati che verrebbero sostituiti da quelli del partner).
    var invitoInAttesa: CKShare.Metadata?
    /// Messaggio informativo da mostrare una volta (es. condivisione terminata).
    var avviso: String?

    @ObservationIgnored private var metadati: MetadatiSync
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var modelContainer: ModelContainer?
    @ObservationIgnored private var osservatoreSalvataggi: NSObjectProtocol?

    private init() {
        metadati = MetadatiSync.carica()
        ruolo = metadati.ruolo
    }

    // MARK: - Avvio

    /// Da chiamare una volta all'avvio dell'app. Non fa nulla se la sync è
    /// disattivata in `SyncConfig`.
    func configura(container: ModelContainer) {
        guard SyncConfig.abilitata, modelContainer == nil else { return }
        modelContainer = container
        osservatoreSalvataggi = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: container.mainContext,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.registraModificheLocali() }
        }
        Task { await avvia() }
    }

    private func avvia() async {
        guard let ckContainer = SyncConfig.container else { return }
        statoAccount = await Self.verificaAccount(ckContainer)
        guard statoAccount == .disponibile, engine == nil else { return }

        if ruolo == .nessuno {
            // Senza dati non c'è niente da caricare: si aspetta la fine
            // dell'onboarding (diventa proprietario) o un invito (partecipante).
            guard haDatiLocali else { return }
            impostaRuolo(.proprietario)
        }
        avviaEngine(ckContainer)
    }

    private func avviaEngine(_ ckContainer: CKContainer) {
        let database: CKDatabase
        switch ruolo {
        case .nessuno: return
        case .proprietario: database = ckContainer.privateCloudDatabase
        case .partecipante: database = ckContainer.sharedCloudDatabase
        }

        let configurazione = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: metadati.statoEngine,
            delegate: self
        )
        let nuovoEngine = CKSyncEngine(configurazione)
        engine = nuovoEngine

        if ruolo == .proprietario && !metadati.caricamentoInizialeFatto {
            accodaCaricamentoIniziale(su: nuovoEngine)
        } else {
            registraModificheLocali()
        }
    }

    /// Primo caricamento del proprietario: crea la zona e mette in coda
    /// tutti i record già presenti (es. i dati inseriti prima della sync).
    private func accodaCaricamentoIniziale(su engine: CKSyncEngine) {
        guard let context = modelContainer?.mainContext else { return }
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncConfig.zonaPropria))])
        let indice = IndiceLocale(context: context)
        let modifiche = indice.tuttiINomi.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(CKRecord.ID(recordName: $0, zoneID: SyncConfig.zonaPropria))
        }
        engine.state.add(pendingRecordZoneChanges: modifiche)
        metadati.tokenHistory = ultimoTokenHistory(context)
        metadati.caricamentoInizialeFatto = true
        metadati.salva()
    }

    // MARK: - Stato

    var zonaCorrente: CKRecordZone.ID? {
        switch ruolo {
        case .nessuno: return nil
        case .proprietario: return SyncConfig.zonaPropria
        case .partecipante(let proprietario):
            return CKRecordZone.ID(zoneName: SyncConfig.nomeZona, ownerName: proprietario)
        }
    }

    private var haDatiLocali: Bool {
        guard let context = modelContainer?.mainContext else { return false }
        return ((try? context.fetchCount(FetchDescriptor<Persona>())) ?? 0) > 0
    }

    private func impostaRuolo(_ nuovo: RuoloSync) {
        ruolo = nuovo
        metadati.ruolo = nuovo
        metadati.salva()
    }

    /// Dimentica tutto lo stato di sync (i dati locali restano intatti).
    private func azzeraStatoSync(ruolo nuovoRuolo: RuoloSync = .nessuno) {
        engine = nil
        metadati = MetadatiSync()
        impostaRuolo(nuovoRuolo)
    }

    private static func verificaAccount(_ container: CKContainer) async -> StatoAccount {
        switch try? await container.accountStatus() {
        case .available: return .disponibile
        case .noAccount: return .assente
        case .restricted: return .limitato
        default: return .sconosciuto
        }
    }

    /// Forza un giro completo di sync (pulsante "Sincronizza ora").
    func sincronizzaOra() async {
        guard let engine else { await avvia(); return }
        inCorso = true
        defer { inCorso = false }
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
            ultimaSincronizzazione = .now
        } catch {
            ultimoErrore = error.localizedDescription
        }
    }

    // MARK: - Modifiche locali → coda di invio

    /// Legge la history di SwiftData dall'ultimo token e mette in coda su
    /// CKSyncEngine ogni inserimento/modifica/eliminazione fatta dall'utente.
    func registraModificheLocali() {
        guard let context = modelContainer?.mainContext else { return }
        guard let engine, let zona = zonaCorrente else {
            if ruolo == .nessuno { Task { await avvia() } }
            return
        }

        var descrittore = HistoryDescriptor<DefaultHistoryTransaction>()
        if let token = metadati.tokenHistory {
            descrittore.predicate = #Predicate { $0.token > token }
        }
        guard let transazioni = try? context.fetchHistory(descrittore), !transazioni.isEmpty else { return }

        var modifiche: [CKSyncEngine.PendingRecordZoneChange] = []
        for transazione in transazioni where transazione.author == AppSchema.autoreLocale {
            for cambiamento in transazione.changes {
                switch cambiamento {
                case .insert(let c):
                    if let nome = nomeRecord(per: c.changedPersistentIdentifier, in: context) {
                        modifiche.append(.saveRecord(CKRecord.ID(recordName: nome, zoneID: zona)))
                    }
                case .update(let c):
                    if let nome = nomeRecord(per: c.changedPersistentIdentifier, in: context) {
                        modifiche.append(.saveRecord(CKRecord.ID(recordName: nome, zoneID: zona)))
                    }
                case .delete(let c):
                    if let nome = Self.nomeRecordEliminato(c) {
                        modifiche.append(.deleteRecord(CKRecord.ID(recordName: nome, zoneID: zona)))
                        metadati.riferimentiPendenti[nome] = nil
                    }
                @unknown default:
                    break
                }
            }
        }
        metadati.tokenHistory = transazioni.last?.token ?? metadati.tokenHistory
        metadati.salva()
        if !modifiche.isEmpty {
            engine.state.add(pendingRecordZoneChanges: modifiche)
        }
    }

    private func ultimoTokenHistory(_ context: ModelContext) -> DefaultHistoryToken? {
        (try? context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()))?.last?.token
    }

    /// Nome record CloudKit di un oggetto ancora esistente. Fetch concreto per
    /// tipo: #Predicate non supporta proprietà di protocollo in modo generico.
    private func nomeRecord(per id: PersistentIdentifier, in context: ModelContext) -> String? {
        switch id.entityName {
        case "Persona":
            return (try? context.fetch(FetchDescriptor<Persona>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .persona, uuid: $0.uuid) }
        case "QuotaMensile":
            return (try? context.fetch(FetchDescriptor<QuotaMensile>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .quotaMensile, uuid: $0.uuid) }
        case "SpesaRicorrente":
            return (try? context.fetch(FetchDescriptor<SpesaRicorrente>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .spesaRicorrente, uuid: $0.uuid) }
        case "Fattura":
            return (try? context.fetch(FetchDescriptor<Fattura>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .fattura, uuid: $0.uuid) }
        case "Versamento":
            return (try? context.fetch(FetchDescriptor<Versamento>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .versamento, uuid: $0.uuid) }
        case "SpesaExtra":
            return (try? context.fetch(FetchDescriptor<SpesaExtra>(predicate: #Predicate { $0.persistentModelID == id })))?.first
                .map { MappaturaRecord.nomeRecord(tipo: .spesaExtra, uuid: $0.uuid) }
        default:
            return nil
        }
    }

    /// Nome record di un oggetto eliminato, letto dal tombstone della history
    /// (possibile grazie a `@Attribute(.preserveValueOnDeletion)` su uuid).
    private static func nomeRecordEliminato(_ eliminazione: any HistoryDelete) -> String? {
        if let d = eliminazione as? DefaultHistoryDelete<Persona>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .persona, uuid: u)
        }
        if let d = eliminazione as? DefaultHistoryDelete<QuotaMensile>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .quotaMensile, uuid: u)
        }
        if let d = eliminazione as? DefaultHistoryDelete<SpesaRicorrente>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .spesaRicorrente, uuid: u)
        }
        if let d = eliminazione as? DefaultHistoryDelete<Fattura>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .fattura, uuid: u)
        }
        if let d = eliminazione as? DefaultHistoryDelete<Versamento>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .versamento, uuid: u)
        }
        if let d = eliminazione as? DefaultHistoryDelete<SpesaExtra>, let u = d.tombstone[\.uuid] as? UUID {
            return MappaturaRecord.nomeRecord(tipo: .spesaExtra, uuid: u)
        }
        return nil
    }

    // MARK: - Condivisione con il partner

    /// Lo share di zona già esistente (nil se non ancora creato).
    func condivisioneEsistente() async throws -> CKShare? {
        guard let ckContainer = SyncConfig.container, let zona = zonaCorrente else { return nil }
        let database = ruolo == .proprietario ? ckContainer.privateCloudDatabase : ckContainer.sharedCloudDatabase
        let id = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zona)
        do {
            return try await database.record(for: id) as? CKShare
        } catch let errore as CKError where errore.code == .unknownItem || errore.code == .zoneNotFound {
            // Nessuno share ancora creato, o la zona non esiste ancora su iCloud.
            return nil
        }
    }

    /// Crea (se serve) lo share di zona del proprietario, pronto da inviare.
    func preparaCondivisione() async throws -> CKShare {
        guard let ckContainer = SyncConfig.container, ruolo == .proprietario else {
            throw ErroreSync.condivisioneNonDisponibile
        }
        if let esistente = try await condivisioneEsistente() { return esistente }

        // La zona deve esistere su iCloud prima di poterla condividere: la
        // creiamo esplicitamente (operazione idempotente) invece di fidarci
        // che CKSyncEngine l'abbia già inviata, poi carichiamo i record in coda.
        _ = try await ckContainer.privateCloudDatabase.modifyRecordZones(
            saving: [CKRecordZone(zoneID: SyncConfig.zonaPropria)],
            deleting: []
        )
        try await engine?.sendChanges()

        let share = CKShare(recordZoneID: SyncConfig.zonaPropria)
        share[CKShare.SystemFieldKey.title] = ProfiloLocale.nomeApp
        share.publicPermission = .none
        let risultato = try await ckContainer.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
        guard let salvato = try risultato.saveResults[share.recordID]?.get() as? CKShare else {
            throw ErroreSync.condivisioneNonDisponibile
        }
        return salvato
    }

    /// Il proprietario ha interrotto la condivisione dal pannello di sistema.
    func condivisioneInterrotta() {
        avviso = "Condivisione interrotta: il partner non vede più i vostri dati aggiornati."
    }

    // MARK: - Invito ricevuto (lato partner)

    /// Chiamato dal SceneDelegate quando si apre un link d'invito.
    func riceviInvito(_ metadata: CKShare.Metadata) {
        guard SyncConfig.abilitata else { return }
        if case .partecipante(let proprietario) = ruolo,
           proprietario == metadata.share.recordID.zoneID.ownerName {
            return // già dentro questa condivisione
        }
        if haDatiLocali {
            invitoInAttesa = metadata // serve conferma: i dati locali verranno sostituiti
        } else {
            Task { await accetta(metadata) }
        }
    }

    func rifiutaInvito() {
        invitoInAttesa = nil
    }

    /// Accetta l'invito: da qui in poi questo iPhone lavora sui dati del
    /// partner. Gli eventuali dati locali vengono sostituiti (senza toccare
    /// iCloud: la cancellazione avviene con autore "sync").
    func accetta(_ metadata: CKShare.Metadata) async {
        invitoInAttesa = nil
        guard let ckContainer = SyncConfig.container else { return }
        inCorso = true
        defer { inCorso = false }
        do {
            _ = try await ckContainer.accept(metadata)

            let eraProprietario = ruolo == .proprietario
            engine = nil
            if eraProprietario {
                // I dati propri su iCloud non servono più: il conto comune
                // ora è quello del partner.
                _ = try? await ckContainer.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [SyncConfig.zonaPropria])
            }
            svuotaDatiLocali()

            azzeraStatoSync(ruolo: .partecipante(nomeProprietarioZona: metadata.share.recordID.zoneID.ownerName))
            if let context = modelContainer?.mainContext {
                metadati.tokenHistory = ultimoTokenHistory(context)
            }
            metadati.caricamentoInizialeFatto = true
            metadati.salva()

            avviaEngine(ckContainer)
            try await engine?.fetchChanges()
            ultimaSincronizzazione = .now
        } catch {
            ultimoErrore = "Impossibile accettare l'invito: \(error.localizedDescription)"
        }
    }

    private func svuotaDatiLocali() {
        guard let context = modelContainer?.mainContext else { return }
        Self.eliminaTuttiIDati(in: context)
    }

    /// Elimina oggetto per oggetto sul context principale (così le schermate
    /// si aggiornano subito), con autore "sync": queste eliminazioni non
    /// devono mai essere inviate a iCloud come modifiche dell'utente.
    private static func eliminaTuttiIDati(in context: ModelContext) {
        let autorePrecedente = context.author
        context.author = AppSchema.autoreSync
        defer { context.author = autorePrecedente }
        func elimina<T: PersistentModel>(_ tipo: T.Type) {
            for oggetto in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
                context.delete(oggetto)
            }
        }
        elimina(Versamento.self)
        elimina(QuotaMensile.self)
        elimina(Fattura.self)
        elimina(SpesaExtra.self)
        elimina(SpesaRicorrente.self)
        elimina(Persona.self)
        try? context.save()
    }

    // MARK: - Ripristino dell'app

    /// Riporta l'app come appena installata (Impostazioni → Ripristina).
    /// - Proprietario: cancella anche la zona su iCloud (il partner vedrà
    ///   "condivisione terminata").
    /// - Partecipante: esce dalla condivisione SENZA toccare i dati del
    ///   partner (eliminare la zona dal database condiviso = uscire dallo share).
    /// La parte iCloud avviene PRIMA di cancellare i dati locali: se fallisce
    /// (es. niente internet) non si tocca nulla, altrimenti i vecchi dati
    /// rimasti su iCloud si mescolerebbero con quelli del nuovo conto.
    func ripristinaTutto(context: ModelContext) async throws {
        if let ckContainer = SyncConfig.container, let zona = zonaCorrente {
            let database: CKDatabase = ruolo == .proprietario
                ? ckContainer.privateCloudDatabase
                : ckContainer.sharedCloudDatabase
            do {
                let risultato = try await database.modifyRecordZones(saving: [], deleting: [zona])
                if case .failure(let errore)? = risultato.deleteResults[zona] {
                    throw errore
                }
            } catch let errore as CKError where errore.code == .zoneNotFound || errore.code == .unknownItem {
                // Già assente su iCloud: va bene così.
            } catch {
                throw ErroreSync.ripristinoNonRiuscito(error.localizedDescription)
            }
        }

        engine = nil
        Self.eliminaTuttiIDati(in: context)
        azzeraStatoSync()
        ultimoErrore = nil
        avviso = nil
        invitoInAttesa = nil
        ultimaSincronizzazione = nil
        UserDefaults.standard.removeObject(forKey: ProfiloLocale.chiavePersonaCorrente)
    }

    // MARK: - Modifiche remote → archivio locale

    private func applicaModificheRemote(
        modifiche: [CKRecord],
        eliminazioni: [CKRecord.ID]
    ) {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        context.author = AppSchema.autoreSync
        context.autosaveEnabled = false
        let indice = IndiceLocale(context: context)

        let ordinati = modifiche.sorted {
            let a = MappaturaRecord.scomponi($0.recordID.recordName)?.tipo.ordineApplicazione ?? 9
            let b = MappaturaRecord.scomponi($1.recordID.recordName)?.tipo.ordineApplicazione ?? 9
            return a < b
        }
        for record in ordinati {
            metadati.memorizzaCampiSistema(di: record)
            let pendenti = MappaturaRecord.applica(record, in: context, indice: indice)
            metadati.riferimentiPendenti[record.recordID.recordName] = pendenti.isEmpty ? nil : pendenti
        }
        for id in eliminazioni {
            MappaturaRecord.elimina(nomeRecord: id.recordName, in: context, indice: indice)
            metadati.campiSistema[id.recordName] = nil
            metadati.riferimentiPendenti[id.recordName] = nil
        }
        for (nome, riferimenti) in metadati.riferimentiPendenti {
            let rimasti = MappaturaRecord.risolviPendenti(nomeRecord: nome, riferimenti, indice: indice)
            metadati.riferimentiPendenti[nome] = rimasti.isEmpty ? nil : rimasti
        }

        do {
            try context.save()
        } catch {
            ultimoErrore = "Errore nel salvare i dati ricevuti: \(error.localizedDescription)"
        }
        metadati.salva()
    }

    /// Costruisce il CKRecord da inviare per un oggetto locale. nil (e
    /// rimozione dalla coda) se nel frattempo l'oggetto è stato eliminato.
    private func costruisciRecord(_ id: CKRecord.ID, indice: IndiceLocale) -> CKRecord? {
        guard case let (tipo, _)? = MappaturaRecord.scomponi(id.recordName),
              let oggetto = indice.trova(nomeRecord: id.recordName) else {
            engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(id)])
            return nil
        }
        let record = metadati.recordBase(id: id, tipo: tipo.rawValue)
        MappaturaRecord.riempi(record, da: oggetto)
        return record
    }
}

enum ErroreSync: LocalizedError {
    case condivisioneNonDisponibile
    case ripristinoNonRiuscito(String)

    var errorDescription: String? {
        switch self {
        case .condivisioneNonDisponibile:
            return "La condivisione non è disponibile: controlla di aver effettuato l'accesso a iCloud."
        case .ripristinoNonRiuscito:
            return "Non è stato possibile cancellare i dati da iCloud, quindi non è stato eliminato nulla. Controlla la connessione a internet e riprova."
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension SyncManager: CKSyncEngineDelegate {

    // I metodi del protocollo sono nonisolated (CKSyncEngine li chiama dal
    // proprio thread) e rimandano subito al MainActor, dove vivono ModelContext
    // e stato osservato dalla UI.
    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await gestisciEvento(event)
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await prossimoLotto(context, syncEngine: syncEngine)
    }

    private func gestisciEvento(_ event: CKSyncEngine.Event) async {
        switch event {
        case .stateUpdate(let e):
            metadati.statoEngine = e.stateSerialization
            metadati.salva()

        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                statoAccount = .disponibile
            case .signOut, .switchAccounts:
                // Account iCloud cambiato: lo stato di sync non vale più.
                // I dati locali restano sul telefono.
                statoAccount = .assente
                azzeraStatoSync()
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let e):
            for eliminazione in e.deletions where eliminazione.zoneID.zoneName == SyncConfig.nomeZona {
                gestisciZonaEliminata(eliminazione.zoneID)
            }

        case .fetchedRecordZoneChanges(let e):
            applicaModificheRemote(
                modifiche: e.modifications.map(\.record),
                eliminazioni: e.deletions.map(\.recordID)
            )

        case .sentRecordZoneChanges(let e):
            gestisciInvio(e)

        case .sentDatabaseChanges(let e):
            // Prima non veniva controllato: se la creazione della zona falliva,
            // nessuno se ne accorgeva e l'invito poi trovava "Zone does not exist".
            for fallita in e.failedZoneSaves {
                ultimoErrore = "Impossibile creare lo spazio su iCloud: \(fallita.error.localizedDescription)"
                engine?.state.add(pendingDatabaseChanges: [.saveZone(fallita.zone)])
            }

        case .willFetchChanges, .willSendChanges:
            inCorso = true

        case .didFetchChanges, .didSendChanges:
            inCorso = false
            ultimaSincronizzazione = .now

        default:
            break
        }
    }

    private func prossimoLotto(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let ambito = context.options.scope
        let modifiche = syncEngine.state.pendingRecordZoneChanges.filter { ambito.contains($0) }
        guard !modifiche.isEmpty, let modelContext = modelContainer?.mainContext else { return nil }
        let indice = IndiceLocale(context: modelContext)
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: modifiche) { id in
            await self.costruisciRecord(id, indice: indice)
        }
    }

    private func gestisciInvio(_ e: CKSyncEngine.Event.SentRecordZoneChanges) {
        var daRiaccodare: [CKSyncEngine.PendingRecordZoneChange] = []
        var zonaMancante = false

        for record in e.savedRecords {
            metadati.memorizzaCampiSistema(di: record)
        }
        for fallito in e.failedRecordSaves {
            let id = fallito.record.recordID
            switch fallito.error.code {
            case .serverRecordChanged:
                // Qualcun altro ha modificato il record: si prende la versione
                // del server come base e si rimanda la nostra (vince l'ultima modifica).
                if let server = fallito.error.serverRecord {
                    metadati.memorizzaCampiSistema(di: server)
                }
                daRiaccodare.append(.saveRecord(id))
            case .zoneNotFound:
                zonaMancante = true
                metadati.campiSistema[id.recordName] = nil
                daRiaccodare.append(.saveRecord(id))
            case .unknownItem:
                metadati.campiSistema[id.recordName] = nil
                daRiaccodare.append(.saveRecord(id))
            case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                 .notAuthenticated, .operationCancelled, .requestRateLimited:
                break // CKSyncEngine ritenta da solo
            default:
                ultimoErrore = fallito.error.localizedDescription
            }
        }
        for id in e.deletedRecordIDs {
            metadati.campiSistema[id.recordName] = nil
        }

        if zonaMancante, ruolo == .proprietario {
            engine?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: SyncConfig.zonaPropria))])
        }
        if !daRiaccodare.isEmpty {
            engine?.state.add(pendingRecordZoneChanges: daRiaccodare)
        }
        metadati.salva()
    }

    private func gestisciZonaEliminata(_ zona: CKRecordZone.ID) {
        switch ruolo {
        case .partecipante:
            // Il partner ha interrotto la condivisione (o ci ha rimosso):
            // i dati restano su questo iPhone come copia non più aggiornata.
            azzeraStatoSync()
            avviso = "La condivisione del conto comune è terminata. I dati restano su questo iPhone ma non si aggiornano più."
        case .proprietario:
            // Zona cancellata (es. dati iCloud reimpostati): si ricarica tutto.
            metadati.campiSistema = [:]
            metadati.caricamentoInizialeFatto = false
            metadati.salva()
            if let engine { accodaCaricamentoIniziale(su: engine) }
        case .nessuno:
            break
        }
    }
}

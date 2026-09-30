import Foundation
import CloudKit
import SwiftData

/// Tutto ciò che il motore di sync deve ricordare tra un avvio e l'altro,
/// salvato in un file JSON in Application Support (fuori da SwiftData, così
/// non finisce nella history e non viene a sua volta sincronizzato).
struct MetadatiSync: Codable {
    var ruolo: RuoloSync = .nessuno
    /// Stato interno di CKSyncEngine (cosa ha già scaricato, cosa resta da inviare).
    var statoEngine: CKSyncEngine.State.Serialization?
    /// Fin dove è già stata letta la history di SwiftData.
    var tokenHistory: DefaultHistoryToken?
    /// Campi di sistema CloudKit (change tag) per nome record: servono a
    /// inviare le modifiche senza generare conflitti a ogni salvataggio.
    var campiSistema: [String: Data] = [:]
    /// Relazioni arrivate prima dell'oggetto a cui puntano: nomeRecord → (campo → uuid).
    var riferimentiPendenti: [String: [String: String]] = [:]
    /// Il proprietario ha già caricato su iCloud i dati esistenti.
    var caricamentoInizialeFatto = false

    // MARK: - Persistenza su file

    private static var url: URL {
        let cartella = URL.applicationSupportDirectory.appending(path: "Sync", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: cartella, withIntermediateDirectories: true)
        return cartella.appending(path: "metadati.json")
    }

    static func carica() -> MetadatiSync {
        guard let data = try? Data(contentsOf: url),
              let metadati = try? JSONDecoder().decode(MetadatiSync.self, from: data) else {
            return MetadatiSync()
        }
        return metadati
    }

    func salva() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.url, options: [.atomic, .completeFileProtection])
    }

    // MARK: - Campi di sistema

    mutating func memorizzaCampiSistema(di record: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        campiSistema[record.recordID.recordName] = coder.encodedData
    }

    /// Un CKRecord "vuoto" con i campi di sistema già noti, o nuovo se non ce ne sono.
    func recordBase(id: CKRecord.ID, tipo: String) -> CKRecord {
        if let data = campiSistema[id.recordName],
           let decoder = try? NSKeyedUnarchiver(forReadingFrom: data) {
            decoder.requiresSecureCoding = true
            defer { decoder.finishDecoding() }
            if let record = CKRecord(coder: decoder), record.recordID == id {
                return record
            }
        }
        return CKRecord(recordType: tipo, recordID: id)
    }
}

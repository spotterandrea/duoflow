import Foundation
import CloudKit

/// Configurazione della sincronizzazione iCloud.
///
/// ⚠️ La sync resta SPENTA finché `containerIdentifier` è nil. Prima di
/// accenderla vanno fissati bundle id e container iCloud definitivi (un
/// container CloudKit non si può rinominare né eliminare), poi in Xcode:
/// Signing & Capabilities → + iCloud (spunta CloudKit, aggiungi il
/// container) e + Background Modes (spunta Remote notifications). Vedi
/// `Documentazione/Sync-iCloud.md`.
enum SyncConfig {
    /// Da impostare a "iCloud.com.andrearizzi.duoflow" (bundle id definitivo
    /// com.andrearizzi.duoflow) dopo aver creato il container in Xcode.
    /// nil = sync disattivata.
    static let containerIdentifier: String? = "iCloud.com.andrearizzi.duoflow"

    static var abilitata: Bool { containerIdentifier != nil }

    static var container: CKContainer? {
        containerIdentifier.map { CKContainer(identifier: $0) }
    }

    /// Nome della zona CloudKit che contiene TUTTI i dati di una coppia.
    /// Il proprietario la crea nel proprio database privato e la condivide
    /// per intero (share di zona) con il partner.
    static let nomeZona = "ContoComune"

    static var zonaPropria: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: nomeZona, ownerName: CKCurrentUserDefaultName)
    }
}

/// Ruolo di QUESTO iPhone rispetto ai dati sincronizzati.
enum RuoloSync: Codable, Equatable {
    /// Nessuna sync attiva (iCloud assente, sync spenta o non ancora partita).
    case nessuno
    /// I dati stanno nel database privato di questo utente (chi ha creato il
    /// conto comune). Vale anche senza partner: fa da backup su iCloud.
    case proprietario
    /// I dati appartengono al partner e arrivano dal database condiviso.
    /// `nomeProprietarioZona` identifica la zona del partner.
    case partecipante(nomeProprietarioZona: String)
}

import UIKit
import CloudKit

/// Mostra il pannello di sistema di condivisione iCloud (invita via
/// Messaggi/Mail/WhatsApp, vedi partecipanti, interrompi condivisione).
/// Presentato direttamente da UIKit: dentro un .sheet di SwiftUI il
/// UICloudSharingController si comporta in modo inaffidabile.
enum PresentatoreCondivisione {

    static func presenta(share: CKShare, container: CKContainer) {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = DelegatoCondivisione.shared
        controllerInCima()?.present(controller, animated: true)
    }

    private static func controllerInCima() -> UIViewController? {
        let scena = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var cima = scena?.keyWindow?.rootViewController
        while let presentato = cima?.presentedViewController {
            cima = presentato
        }
        return cima
    }
}

final class DelegatoCondivisione: NSObject, UICloudSharingControllerDelegate {
    static let shared = DelegatoCondivisione()

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        SyncManager.shared.ultimoErrore = "Condivisione non riuscita: \(error.localizedDescription)"
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        ProfiloLocale.nomeApp
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        SyncManager.shared.condivisioneInterrotta()
    }
}

import UIKit
import CloudKit

/// Serve solo per due cose che SwiftUI da solo non espone:
/// 1. registrarsi alle notifiche push silenziose (CKSyncEngine le usa per
///    sapere quando il partner ha modificato qualcosa);
/// 2. ricevere il link d'invito CloudKit quando il partner lo apre.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if SyncConfig.abilitata {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configurazione = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configurazione.delegateClass = SceneDelegate.self
        return configurazione
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// App chiusa: l'invito arriva insieme all'apertura della scena.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            SyncManager.shared.riceviInvito(metadata)
        }
    }

    /// App già aperta o in background.
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        SyncManager.shared.riceviInvito(cloudKitShareMetadata)
    }
}

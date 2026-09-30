import SwiftUI
import UIKit

/// Chiude la tastiera in tutta l'app: swipe verso il basso (via il
/// modifier SwiftUI nativo, sicuro) e tap in un punto qualsiasi dello
/// schermo (via un gesture installato UNA SOLA VOLTA sulla finestra, non
/// sui singoli Form/ScrollView).
///
/// Perché non un `.onTapGesture` su ogni Form: un tap gesture SwiftUI
/// aggiunto direttamente su un Form/List intercetta anche i tocchi
/// destinati ai suoi controlli interattivi (Picker, Toggle, Stepper) — è
/// il bug per cui il menu di scelta della Persona nel form "Nuovo
/// versamento" aveva smesso di aprirsi. Il gesture qui sotto è impostato
/// con `cancelsTouchesInView = false` e un delegate che permette il
/// riconoscimento simultaneo con qualunque altro gesture: chiude la
/// tastiera ma lascia sempre passare il tocco al controllo sotto.
enum KeyboardDismissGlobale {
    @MainActor private static var installato = false

    @MainActor
    static func installaSeNecessario() {
        guard !installato else { return }
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
            let window = windowScene.windows.first(where: \.isKeyWindow) ?? windowScene.windows.first
        else { return }

        let tap = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
        tap.cancelsTouchesInView = false
        tap.delegate = Delegate.shared
        window.addGestureRecognizer(tap)
        installato = true
    }

    private final class Delegate: NSObject, UIGestureRecognizerDelegate {
        static let shared = Delegate()
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

extension View {
    /// Attiva lo swipe-down nativo di SwiftUI per chiudere la tastiera su
    /// questo Form/ScrollView. Il tap-fuori-dal-campo è gestito a parte,
    /// una sola volta per l'intera app (vedi `KeyboardDismissGlobale`).
    func dismissTastieraAlloSwipe() -> some View {
        self.scrollDismissesKeyboard(.immediately)
    }
}

import SwiftUI
import SwiftData

/// Impostazioni → Ripristino: riporta l'app come appena installata.
/// Doppia conferma, con testi diversi a seconda che il conto sia proprio,
/// del partner o solo locale. Al termine, senza dati, ContentView mostra
/// di nuovo l'onboarding.
struct RipristinoCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sync = SyncManager.shared

    @State private var primaConferma = false
    @State private var secondaConferma = false
    @State private var inCorso = false
    @State private var errore: String?

    private var cosaSuccede: String {
        switch sync.ruolo {
        case .proprietario:
            return "Verranno eliminati tutti i dati da questo iPhone e da iCloud: persone, stipendi, versamenti, bollette, spese fisse ed extra. Se hai invitato il partner, il conto condiviso terminerà anche per lui."
        case .partecipante:
            return "Uscirai dal conto condiviso e i dati verranno eliminati da questo iPhone. I dati del tuo partner restano intatti sul suo iPhone."
        case .nessuno:
            return "Verranno eliminati tutti i dati su questo iPhone: persone, stipendi, versamenti, bollette, spese fisse ed extra."
        }
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Elimina tutti i dati e riporta DuoFlow come appena installata, con la configurazione iniziale.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                Button {
                    primaConferma = true
                } label: {
                    HStack {
                        Label("Ripristina l'app", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        if inCorso { ProgressView() }
                    }
                    .foregroundStyle(AppTheme.danger)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(inCorso)
            }
        }
        // 1ª conferma: spiega cosa verrà eliminato.
        .alert("Ripristinare l'app?", isPresented: $primaConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Continua", role: .destructive) {
                // Piccolo ritardo: SwiftUI non mostra un alert mentre
                // il precedente si sta ancora chiudendo.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { secondaConferma = true }
            }
        } message: {
            Text(cosaSuccede)
        }
        // 2ª conferma: ultima possibilità.
        .alert("Sei proprio sicuro?", isPresented: $secondaConferma) {
            Button("Annulla", role: .cancel) {}
            Button("Elimina tutto", role: .destructive) { ripristina() }
        } message: {
            Text("L'operazione non si può annullare e i dati non potranno essere recuperati.")
        }
        .alert(
            "Ripristino non riuscito",
            isPresented: Binding(get: { errore != nil }, set: { if !$0 { errore = nil } })
        ) {
            Button("OK", role: .cancel) { errore = nil }
        } message: {
            Text(errore ?? "")
        }
    }

    private func ripristina() {
        inCorso = true
        Task {
            defer { inCorso = false }
            do {
                try await sync.ripristinaTutto(context: modelContext)
            } catch {
                errore = error.localizedDescription
            }
        }
    }
}

import SwiftUI
import CloudKit

/// Sezione "Condivisione" delle Impostazioni: stato di iCloud, invito del
/// partner e sincronizzazione manuale.
struct CondivisioneCard: View {
    @State private var sync = SyncManager.shared
    @State private var preparazioneInCorso = false

    var body: some View {
        CardView {
            if !SyncConfig.abilitata {
                riga(
                    icona: "icloud.slash",
                    titolo: "Sincronizzazione non ancora attiva",
                    sottotitolo: "In questa versione i dati restano solo su questo iPhone."
                )
            } else {
                switch sync.statoAccount {
                case .assente, .limitato:
                    riga(
                        icona: "exclamationmark.icloud",
                        titolo: "iCloud non disponibile",
                        sottotitolo: "Accedi a iCloud nelle Impostazioni dell'iPhone per condividere i dati con il partner."
                    )
                default:
                    contenutoAttivo
                }
            }
        }
    }

    @ViewBuilder
    private var contenutoAttivo: some View {
        switch sync.ruolo {
        case .partecipante:
            riga(icona: "person.2.fill", titolo: "Conto condiviso dal partner", sottotitolo: statoSync)
            RowDivider()
            pulsante("Gestisci condivisione", icona: "person.crop.circle.badge.checkmark") { apriCondivisione() }
        case .proprietario:
            riga(icona: "checkmark.icloud.fill", titolo: "Salvato su iCloud", sottotitolo: statoSync)
            RowDivider()
            pulsante("Invita il partner", icona: "person.badge.plus") { apriCondivisione() }
        case .nessuno:
            riga(icona: "icloud", titolo: "In attesa di iCloud", sottotitolo: "La sincronizzazione parte da sola appena possibile.")
        }
        if sync.ruolo != .nessuno {
            RowDivider()
            pulsante("Sincronizza ora", icona: "arrow.triangle.2.circlepath") {
                Task { await sync.sincronizzaOra() }
            }
        }
        if let errore = sync.ultimoErrore {
            Text(errore)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.danger)
                .padding(.bottom, 10)
        }
    }

    private var statoSync: String {
        if sync.inCorso || preparazioneInCorso { return "Sincronizzazione in corso…" }
        if let data = sync.ultimaSincronizzazione {
            return "Ultima sincronizzazione: \(data.formatted(date: .omitted, time: .shortened))"
        }
        return "Sincronizzazione automatica"
    }

    private func apriCondivisione() {
        guard let container = SyncConfig.container else { return }
        preparazioneInCorso = true
        Task {
            defer { preparazioneInCorso = false }
            do {
                let share: CKShare?
                if sync.ruolo == .proprietario {
                    share = try await sync.preparaCondivisione()
                } else {
                    share = try await sync.condivisioneEsistente()
                }
                if let share {
                    PresentatoreCondivisione.presenta(share: share, container: container)
                }
            } catch {
                sync.ultimoErrore = error.localizedDescription
            }
        }
    }

    private func riga(icona: String, titolo: String, sottotitolo: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icona)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(titolo).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                Text(sottotitolo).font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func pulsante(_ titolo: String, icona: String, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            HStack {
                Label(titolo, systemImage: icona)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                if preparazioneInCorso && titolo != "Sincronizza ora" {
                    ProgressView()
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(preparazioneInCorso)
    }
}

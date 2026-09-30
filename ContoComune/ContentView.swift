//
//  ContentView.swift
//  ContoComune
//
//  Created by Andrea Rizzi on 04/09/2026.
//

import SwiftUI
import SwiftData

/// Punto d'ingresso: se sul telefono non c'è ancora nessuna persona mostra
/// l'onboarding, altrimenti le 5 schermate principali. Lo stato è ricavato
/// dai dati, non da un flag: quando il partner accetta l'invito e la sync
/// scarica le persone della coppia, l'onboarding sparisce da solo.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Persona.nome) private var persone: [Persona]
    @AppStorage(ProfiloLocale.chiavePersonaCorrente) private var uuidPersonaCorrente: String = ""
    @State private var sync = SyncManager.shared

    /// Chiede "chi sei?" una sola volta se questo iPhone non lo sa ancora
    /// (es. il partner appena entrato dall'invito, o installazioni precedenti
    /// all'onboarding).
    private var serveSceltaPersona: Bool {
        !persone.isEmpty && !persone.contains { $0.uuid.uuidString == uuidPersonaCorrente }
    }

    var body: some View {
        Group {
            if persone.isEmpty {
                OnboardingView()
            } else {
                RootTabView()
            }
        }
        .onAppear {
            KeyboardDismissGlobale.installaSeNecessario()
            AddebitiAutomatici.registraScaduti(in: modelContext)
        }
        .onChange(of: scenePhase) { _, fase in
            // Es. app lasciata aperta in background fino al giorno del mutuo.
            if fase == .active {
                AddebitiAutomatici.registraScaduti(in: modelContext)
            }
        }
        .sheet(isPresented: .constant(serveSceltaPersona && sync.invitoInAttesa == nil)) {
            SceltaPersonaSheet(persone: persone) { persona in
                uuidPersonaCorrente = persona.uuid.uuidString
            }
            .interactiveDismissDisabled()
        }
        .confirmationDialog(
            "Unirti al conto comune del partner?",
            isPresented: Binding(
                get: { sync.invitoInAttesa != nil },
                set: { if !$0 { sync.rifiutaInvito() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unisciti e sostituisci i dati", role: .destructive) {
                if let invito = sync.invitoInAttesa {
                    Task { await sync.accetta(invito) }
                }
            }
            Button("Annulla", role: .cancel) { sync.rifiutaInvito() }
        } message: {
            Text("I dati inseriti finora su questo iPhone verranno sostituiti da quelli del conto condiviso.")
        }
        .alert(
            "Condivisione",
            isPresented: Binding(get: { sync.avviso != nil }, set: { if !$0 { sync.avviso = nil } })
        ) {
            Button("OK", role: .cancel) { sync.avviso = nil }
        } message: {
            Text(sync.avviso ?? "")
        }
    }
}

/// "Chi sei tu tra i due?" — salvato solo su questo iPhone.
private struct SceltaPersonaSheet: View {
    let persone: [Persona]
    let scelta: (Persona) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chi usa questo iPhone?")
                .font(AppTheme.titleFont(26))
                .foregroundStyle(AppTheme.ink)
            Text("Servirà a proporti come default quando registri un versamento. Puoi cambiarlo in Impostazioni.")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.inkMuted)
            ForEach(persone) { persona in
                Button { scelta(persona) } label: {
                    HStack(spacing: 12) {
                        AvatarView(iniziali: String(persona.nome.prefix(2)).uppercased(), size: 38)
                        Text(persona.nome)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.ink)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(AppTheme.inkFaint)
                    }
                    .padding(14)
                    .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(24)
        .background(AppTheme.appBackground)
        .presentationDetents([.medium])
    }
}

#Preview("Con dati") {
    ContentView()
        .modelContainer(PreviewData.container)
}

#Preview("Primo avvio") {
    ContentView()
        .modelContainer(PreviewData.containerVuoto)
}

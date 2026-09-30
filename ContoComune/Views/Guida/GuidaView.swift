import SwiftUI

/// Guida e domande frequenti (Impostazioni → Guida). Domande raggruppate
/// per sezione, che si aprono con un tocco, più una ricerca. Può aprirsi
/// direttamente su una domanda (`domandaIniziale`) quando la si raggiunge
/// da un pulsante "?" nell'app.
struct GuidaView: View {
    var domandaIniziale: String? = nil

    @State private var ricerca = ""
    @State private var aperte: Set<String> = []

    private var risultati: [(sezione: ContenutiGuida.Sezione, domanda: ContenutiGuida.Domanda)] {
        let testo = ricerca.trimmingCharacters(in: .whitespaces)
        guard !testo.isEmpty else { return [] }
        return ContenutiGuida.tutte.filter {
            $0.domanda.domanda.localizedStandardContains(testo) || $0.domanda.risposta.localizedStandardContains(testo)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "Domande frequenti", title: "Guida")

                    campoRicerca

                    if ricerca.trimmingCharacters(in: .whitespaces).isEmpty {
                        ForEach(ContenutiGuida.sezioni) { sezione in
                            SectionLabel(text: sezione.titolo)
                            CardView {
                                ForEach(Array(sezione.domande.enumerated()), id: \.element.id) { indice, domanda in
                                    if indice > 0 { RowDivider() }
                                    rigaDomanda(domanda, icona: sezione.icona)
                                        .id(domanda.id)
                                }
                            }
                        }
                    } else if risultati.isEmpty {
                        CardView {
                            EmptyStateView(systemImage: "magnifyingglass", text: "Nessuna risposta per \"\(ricerca)\".")
                        }
                    } else {
                        SectionLabel(text: "\(risultati.count) risultati")
                        CardView {
                            ForEach(Array(risultati.enumerated()), id: \.element.domanda.id) { indice, elemento in
                                if indice > 0 { RowDivider() }
                                rigaDomanda(elemento.domanda, icona: elemento.sezione.icona)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.appBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let id = domandaIniziale else { return }
                aperte.insert(id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    private var campoRicerca: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.inkFaint)
            TextField("Cerca una domanda", text: $ricerca)
                .autocorrectionDisabled()
                .font(.system(size: 15))
            if !ricerca.isEmpty {
                Button { ricerca = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppTheme.inkFaint)
                }
                .accessibilityLabel("Cancella ricerca")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
    }

    private func rigaDomanda(_ domanda: ContenutiGuida.Domanda, icona: String) -> some View {
        let aperta = aperte.contains(domanda.id)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if aperta { aperte.remove(domanda.id) } else { aperte.insert(domanda.id) }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Text(domanda.domanda)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.inkFaint)
                        .rotationEffect(.degrees(aperta ? 180 : 0))
                        .padding(.top, 3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(aperta ? "Chiudi la risposta" : "Mostra la risposta")

            if aperta {
                Text(domanda.risposta)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 13)
    }
}

/// Piccolo "?" da mettere accanto a un concetto: apre la guida sulla
/// domanda giusta in un foglio.
struct AiutoButton: View {
    let domanda: String
    /// Grandezza dell'icona, da abbinare al testo accanto (12 per le
    /// etichette di sezione, 13 per i testi delle righe).
    var dimensione: CGFloat = 13
    @State private var presentato = false

    var body: some View {
        Button { presentato = true } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: dimensione, weight: .medium))
                .foregroundStyle(AppTheme.inkFaint)
                // Area di tocco più grande dell'icona SENZA occupare spazio
                // nel layout: prima un riquadro fisso da 28 pt spingeva il "?"
                // in alto e lontano dal testo.
                .padding(10)
                .contentShape(Rectangle())
                .padding(-10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Aiuto")
        .sheet(isPresented: $presentato) {
            NavigationStack {
                GuidaView(domandaIniziale: domanda)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Chiudi") { presentato = false }
                        }
                    }
            }
        }
    }
}

#Preview {
    NavigationStack { GuidaView(domandaIniziale: "addebito-automatico") }
}

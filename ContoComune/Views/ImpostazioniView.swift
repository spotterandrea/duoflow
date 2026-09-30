import SwiftUI
import SwiftData

/// Quinta tab: stipendio del mese e modalità di calcolo (automatica o
/// percentuale manuale) per ciascuna persona, più l'elenco delle voci di spesa ricorrente (aggiungi, modifica,
/// disattiva o elimina in SpeseRicorrentiListView).
struct ImpostazioniView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Persona.nome) private var persone: [Persona]
    @Query private var quoteMensili: [QuotaMensile]
    @Query(sort: \SpesaRicorrente.nome) private var speseRicorrenti: [SpesaRicorrente]
    @AppStorage(ProfiloLocale.chiavePersonaCorrente) private var uuidPersonaCorrente: String = ""

    private var meseCorrente: Date { Date().startOfMonth }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: Formatting.monthTitle(meseCorrente), title: "Impostazioni")

                    SectionLabel(text: "Persone e stipendi del mese")
                    Text("Si aggiornano solo per il mese selezionato: quelli passati restano come confermati.")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.inkMuted)
                        .padding(.horizontal, 2)

                    if persone.isEmpty {
                        CardView {
                            EmptyStateView(systemImage: "person.2", text: "Nessuna persona ancora configurata.")
                        }
                    } else {
                        ForEach(persone) { persona in
                            if let quota = quoteMensili.first(where: { $0.persona === persona && $0.mese.isSameMonth(as: meseCorrente) }) {
                                PersonaImpostazioniCard(persona: persona, quota: quota)
                            }
                        }
                    }

                    if !persone.isEmpty {
                        SectionLabel(text: "Questo iPhone")
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Chi lo usa").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                                    Text("Proposto come default nei nuovi versamenti").font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                                }
                                Spacer()
                                Picker("Chi lo usa", selection: $uuidPersonaCorrente) {
                                    Text("Non indicato").tag("")
                                    ForEach(persone) { persona in
                                        Text(persona.nome).tag(persona.uuid.uuidString)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppTheme.accent)
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    SectionLabel(text: "Condivisione", aiuto: "invita")
                    CondivisioneCard()

                    SectionLabel(text: "Voci di spesa ricorrenti")
                    NavigationLink {
                        SpeseRicorrentiListView()
                    } label: {
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(speseRicorrenti.filter(\.attiva).count) voci attive")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text(speseRicorrenti.map(\.nome).joined(separator: ", "))
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(AppTheme.inkFaint)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.inkFaint)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .buttonStyle(.plain)

                    SectionLabel(text: "Aiuto")
                    NavigationLink {
                        GuidaView()
                    } label: {
                        CardView {
                            HStack(spacing: 12) {
                                Image(systemName: "book.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 34, height: 34)
                                    .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Guida e domande frequenti")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("Quote, versamenti, addebiti, condivisione, privacy")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(AppTheme.inkFaint)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.inkFaint)
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    .buttonStyle(.plain)

                    SectionLabel(text: "Ripristino", aiuto: "ripristino")
                    RipristinoCard()
                }
                .padding(16)
            }
            .dismissTastieraAlloSwipe()
            .background(AppTheme.appBackground)
            .navigationBarHidden(true)
            .onAppear { assicuraQuoteMensili() }
        }
    }

    /// Crea, se manca, la QuotaMensile del mese corrente per ogni persona
    /// (partendo dall'ultimo stipendio noto), così ognuna ha subito una card
    /// modificabile in Impostazioni. Chiamata solo da `onAppear`, mai dal
    /// corpo della view, per non mutare lo store durante il render.
    private func assicuraQuoteMensili() {
        for persona in persone {
            let esiste = quoteMensili.contains { $0.persona === persona && $0.mese.isSameMonth(as: meseCorrente) }
            guard !esiste else { continue }
            let ultimaNota = quoteMensili
                .filter { $0.persona === persona }
                .sorted { $0.mese > $1.mese }
                .first
            modelContext.insert(QuotaMensile(persona: persona, mese: meseCorrente, stipendio: ultimaNota?.stipendio ?? 0))
        }
    }

}

/// Card espandibile per una persona: stipendio del mese e, se attivata, la
/// percentuale manuale al posto del calcolo automatico proporzionale.
private struct PersonaImpostazioniCard: View {
    @Bindable var persona: Persona
    @Bindable var quota: QuotaMensile

    @State private var espansa = false
    @State private var percentualeManualeAttiva: Bool = false
    @State private var percentualeTesto: String = ""
    @State private var stipendioTesto: String = ""

    var body: some View {
        CardView {
            DisclosureGroup(isExpanded: $espansa) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Nome").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                        Spacer()
                        TextField("Nome", text: $persona.nome)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(.system(size: 15))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(minWidth: 84, maxWidth: 170)
                            .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.vertical, 12)

                    RowDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Stipendio netto").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                            Text("Usato per calcolare la quota").font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                        }
                        Spacer()
                        // Campo di testo con aggiornamento a ogni cifra: prima usava
                        // `value:format:`, che salva solo quando si preme Invio — e il
                        // tastierino numerico non ha Invio, quindi lo stipendio
                        // restava quello vecchio e le quote non si ricalcolavano.
                        TextField("0", text: $stipendioTesto)
                            .keyboardType(.decimalPad)
                            .onChange(of: stipendioTesto) { _, testo in
                                let nuovo = Importo.leggi(testo) ?? 0
                                // Scrive solo se cambia davvero: evita modifiche "vuote"
                                // che la sync invierebbe a iCloud a ogni apertura.
                                if nuovo != quota.stipendio { quota.stipendio = nuovo }
                            }
                            .multilineTextAlignment(.trailing)
                            .font(AppTheme.numberFont())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(minWidth: 84)
                            .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(.vertical, 12)

                    RowDivider()

                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("Percentuale manuale").font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                                AiutoButton(domanda: "percentuale-manuale")
                            }
                            Text("Invece del calcolo automatico").font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                        }
                        Spacer()
                        Toggle("", isOn: $percentualeManualeAttiva)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                            .scaleEffect(0.82)
                            .frame(width: 70 * 0.82, height: 31 * 0.82)
                    }
                    .padding(.vertical, 12)
                    .onChange(of: percentualeManualeAttiva) { _, attiva in
                        if attiva {
                            let percentualeIniziale = quota.percentualeManuale ?? 0.5
                            percentualeTesto = String(format: "%.0f", percentualeIniziale * 100)
                            quota.percentualeManuale = percentualeIniziale
                        } else {
                            quota.percentualeManuale = nil
                        }
                    }

                    if percentualeManualeAttiva {
                        RowDivider()
                        HStack {
                            Text("Percentuale dello stipendio")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.inkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .layoutPriority(0)
                            Spacer(minLength: 8)
                            HStack(spacing: 2) {
                                TextField("50", text: $percentualeTesto)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(AppTheme.numberFont())
                                    .frame(width: 32)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onChange(of: percentualeTesto) { _, testo in
                                        // Solo cifre, massimo 3 (0-100): evita che un valore
                                        // troppo lungo faccia sbordare il campo dal layout.
                                        let filtrato = String(testo.filter(\.isNumber).prefix(3))
                                        if filtrato != testo { percentualeTesto = filtrato }
                                        if let valore = Double(filtrato) {
                                            let clampato = min(max(valore, 0), 100)
                                            quota.percentualeManuale = clampato / 100
                                        }
                                    }
                                Text("%").font(AppTheme.numberFont()).foregroundStyle(AppTheme.inkMuted)
                            }
                            // Stesso trattamento (riquadro con sfondo, non testo "nudo") dello
                            // stipendio netto qui sopra: prima il numero stava a ridosso del
                            // bordo della card, senza margine proprio, e sembrava sbordare.
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .layoutPriority(1)
                        }
                        .padding(.vertical, 10)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    AvatarView(iniziali: String(persona.nome.prefix(2)).uppercased(), size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(persona.nome).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                        Text(quota.usaCalcoloAutomatico ? "Calcolo automatico" : "Percentuale manuale")
                            .font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                    }
                }
                .padding(.vertical, 6)
            }
            .tint(AppTheme.ink)
        }
        .onAppear {
            stipendioTesto = Self.testoStipendio(quota.stipendio)
            percentualeManualeAttiva = quota.percentualeManuale != nil
            if let percentuale = quota.percentualeManuale {
                percentualeTesto = String(format: "%.0f", percentuale * 100)
            }
        }
    }

    /// "1400" oppure "1250,50": niente decimali inutili, virgola italiana.
    private static func testoStipendio(_ valore: Double) -> String {
        guard valore != 0 else { return "" }
        if valore == valore.rounded() { return String(format: "%.0f", valore) }
        return String(format: "%.2f", valore).replacingOccurrences(of: ".", with: ",")
    }
}

#Preview {
    ImpostazioniView()
        .modelContainer(PreviewData.container)
}

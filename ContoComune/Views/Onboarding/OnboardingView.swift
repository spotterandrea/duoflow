import SwiftUI
import SwiftData

/// Configurazione al primo avvio, al posto del vecchio seed fisso con due
/// nomi e due stipendi scritti nel codice. Quattro passi brevi:
/// benvenuto → nomi della coppia → stipendi (facoltativi) → voci di partenza.
/// Tutto ciò che si inserisce qui resta modificabile in Impostazioni.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(ProfiloLocale.chiavePersonaCorrente) private var uuidPersonaCorrente: String = ""

    private enum Passo: Int, CaseIterable {
        case benvenuto, nomi, stipendi, voci
    }

    @State private var passo: Passo = .benvenuto
    @State private var mostraInvito = false

    @State private var nomeTuo = ""
    @State private var nomePartner = ""
    @State private var stipendioTuoTesto = ""
    @State private var stipendioPartnerTesto = ""
    @State private var voci: [VoceProposta] = VoceProposta.predefinite

    private var nomiValidi: Bool {
        !nomeTuo.pulito.isEmpty && !nomePartner.pulito.isEmpty
            && nomeTuo.pulito.lowercased() != nomePartner.pulito.lowercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            if passo != .benvenuto {
                indicatorePassi
                    .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch passo {
                    case .benvenuto: benvenuto
                    case .nomi: nomi
                    case .stipendi: stipendi
                    case .voci: vociDiPartenza
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            pulsantiInBasso
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(AppTheme.appBackground)
        .animation(.easeInOut(duration: 0.2), value: passo)
        .sheet(isPresented: $mostraInvito) {
            InvitoRicevutoSheet()
        }
    }

    // MARK: - Passi

    private var benvenuto: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 40)
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.accentInk)
                .frame(width: 72, height: 72)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text(ProfiloLocale.nomeApp)
                .font(AppTheme.titleFont(34))
                .foregroundStyle(AppTheme.ink)

            Text("Il libretto digitale del conto comune di coppia.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.inkMuted)

            VStack(alignment: .leading, spacing: 14) {
                puntoElenco("chart.pie.fill", "Calcola quanto deve versare ciascuno, in proporzione allo stipendio o con la percentuale che scegliete voi.")
                puntoElenco("doc.text.fill", "Tiene traccia di bollette, spese fisse ed extra pagate dal conto comune.")
                puntoElenco("person.2.fill", "Si condivide con il partner via iCloud: ognuno inserisce i dati dal proprio iPhone.")
            }
            .padding(.top, 8)
        }
    }

    private var nomi: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(eyebrow: "Passo 1 di 3", title: "Chi siete?")
            Text("Servono solo per distinguere le quote. Potrete cambiarli quando volete.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkMuted)

            CardView {
                campoTesto("Il tuo nome", testo: $nomeTuo, placeholder: "Es. Marco")
                RowDivider()
                campoTesto("Nome del partner", testo: $nomePartner, placeholder: "Es. Giulia")
            }

            if !nomeTuo.pulito.isEmpty && nomeTuo.pulito.lowercased() == nomePartner.pulito.lowercased() {
                Text("Usate due nomi diversi, altrimenti le quote sarebbero indistinguibili.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.danger)
            }
        }
    }

    private var stipendi: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(eyebrow: "Passo 2 di 3", title: "Stipendi netti")
            Text("Facoltativi. Con gli stipendi l'app divide le spese in proporzione; senza, potete impostare una percentuale a mano in Impostazioni.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkMuted)

            CardView {
                campoImporto(nomeTuo.pulito, testo: $stipendioTuoTesto)
                RowDivider()
                campoImporto(nomePartner.pulito, testo: $stipendioPartnerTesto)
            }

            Text("Gli stipendi restano solo nei vostri dispositivi e nel vostro iCloud: nessun server esterno li vede.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.inkFaint)
        }
    }

    private var vociDiPartenza: some View {
        VStack(alignment: .leading, spacing: 14) {
            ScreenHeader(eyebrow: "Passo 3 di 3", title: "Spese fisse")
            Text("Scegli le spese che pagate dal conto comune e indica quanto costano in media al mese. Puoi saltare e aggiungerle dopo.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkMuted)

            CardView {
                ForEach($voci) { $voce in
                    if voce.id != voci.first?.id { RowDivider() }
                    HStack(spacing: 10) {
                        Toggle("", isOn: $voce.selezionata)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                            .scaleEffect(0.82)
                            .frame(width: 51 * 0.82, height: 31 * 0.82)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(voce.nome).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                            Text(voce.categoria).font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                        }
                        Spacer(minLength: 8)
                        if voce.selezionata {
                            HStack(spacing: 3) {
                                Text("€").font(AppTheme.numberFont(13)).foregroundStyle(AppTheme.inkMuted)
                                TextField("0", text: $voce.importoTesto)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(AppTheme.numberFont())
                                    .frame(width: 70)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    // MARK: - Navigazione

    private var indicatorePassi: some View {
        HStack(spacing: 6) {
            ForEach([Passo.nomi, .stipendi, .voci], id: \.self) { p in
                Capsule()
                    .fill(p.rawValue <= passo.rawValue ? AppTheme.accent : AppTheme.hairline)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var pulsantiInBasso: some View {
        switch passo {
        case .benvenuto:
            VStack(spacing: 10) {
                PrimaryButton(title: "Iniziamo", systemImage: "arrow.right") { passo = .nomi }
                Button("Ho ricevuto un invito dal mio partner") { mostraInvito = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.vertical, 6)
            }
        case .nomi:
            barraNavigazione(indietro: .benvenuto, avanti: .stipendi, abilitato: nomiValidi)
        case .stipendi:
            barraNavigazione(indietro: .nomi, avanti: .voci, abilitato: true)
        case .voci:
            HStack(spacing: 10) {
                pulsanteIndietro(.stipendi)
                PrimaryButton(title: "Crea il conto comune", systemImage: "checkmark") { completa() }
            }
        }
    }

    private func barraNavigazione(indietro: Passo, avanti: Passo, abilitato: Bool) -> some View {
        HStack(spacing: 10) {
            pulsanteIndietro(indietro)
            PrimaryButton(title: "Avanti", systemImage: "arrow.right") { passo = avanti }
                .disabled(!abilitato)
                .opacity(abilitato ? 1 : 0.45)
        }
    }

    private func pulsanteIndietro(_ destinazione: Passo) -> some View {
        Button { passo = destinazione } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 48, height: 46)
                .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Indietro")
    }

    // MARK: - Salvataggio

    /// Crea le due persone, la loro quota del mese corrente e le voci scelte.
    /// Appena esiste almeno una Persona, ContentView passa alle schermate
    /// principali da sola.
    private func completa() {
        let tu = Persona(nome: nomeTuo.pulito)
        let partner = Persona(nome: nomePartner.pulito)
        modelContext.insert(tu)
        modelContext.insert(partner)

        let mese = Date().startOfMonth
        modelContext.insert(QuotaMensile(persona: tu, mese: mese, stipendio: Importo.leggi(stipendioTuoTesto) ?? 0))
        modelContext.insert(QuotaMensile(persona: partner, mese: mese, stipendio: Importo.leggi(stipendioPartnerTesto) ?? 0))

        for voce in voci where voce.selezionata {
            modelContext.insert(SpesaRicorrente(
                nome: voce.nome,
                categoria: voce.categoria,
                importoStimatoMensile: Importo.leggi(voce.importoTesto) ?? 0,
                periodicita: voce.periodicita
            ))
        }

        uuidPersonaCorrente = tu.uuid.uuidString
        try? modelContext.save()
    }

    // MARK: - Componenti

    private func puntoElenco(_ icona: String, _ testo: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icona)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)
            Text(testo)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func campoTesto(_ etichetta: String, testo: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(etichetta).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
            Spacer(minLength: 12)
            TextField(placeholder, text: testo)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(size: 15))
        }
        .padding(.vertical, 14)
    }

    private func campoImporto(_ nome: String, testo: Binding<String>) -> some View {
        HStack {
            AvatarView(iniziali: String(nome.prefix(2)).uppercased())
            Text(nome).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
            Spacer(minLength: 12)
            HStack(spacing: 3) {
                Text("€").font(AppTheme.numberFont(13)).foregroundStyle(AppTheme.inkMuted)
                TextField("0", text: testo)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(AppTheme.numberFont())
                    .frame(width: 84)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.vertical, 12)
    }
}

/// Una voce di spesa suggerita durante l'onboarding.
struct VoceProposta: Identifiable {
    let id = UUID()
    let nome: String
    let categoria: String
    var periodicita: PeriodicitaSpesa = .mensile
    var selezionata = false
    var importoTesto = ""

    static let predefinite: [VoceProposta] = [
        VoceProposta(nome: "Affitto o mutuo", categoria: "Casa"),
        VoceProposta(nome: "Condominio", categoria: "Casa"),
        VoceProposta(nome: "Luce", categoria: "Utenze", periodicita: .bimestrale),
        VoceProposta(nome: "Gas", categoria: "Utenze", periodicita: .bimestrale),
        VoceProposta(nome: "Acqua", categoria: "Utenze", periodicita: .bimestrale),
        VoceProposta(nome: "Internet", categoria: "Casa"),
        VoceProposta(nome: "Rifiuti (TARI)", categoria: "Casa", periodicita: .annuale),
        VoceProposta(nome: "Spesa alimentare", categoria: "Alimentari")
    ]
}

/// Spiega al partner invitato cosa fare: l'app si configura da sola appena
/// si apre il link d'invito ricevuto, scaricando i dati della coppia.
struct InvitoRicevutoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "envelope.open.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
                Text("Apri il link d'invito")
                    .font(AppTheme.titleFont(26))
                    .foregroundStyle(AppTheme.ink)
                Text("Il tuo partner ti ha mandato un link (via Messaggi, WhatsApp o Mail). Aprilo da questo iPhone: \(ProfiloLocale.nomeApp) si aprirà e scaricherà da iCloud i dati del vostro conto comune. Non serve configurare nulla qui.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.inkMuted)
                Text("Serve essere collegati a iCloud nelle Impostazioni dell'iPhone.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.inkFaint)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.appBackground)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ho capito") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private extension String {
    var pulito: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    OnboardingView()
        .modelContainer(PreviewData.containerVuoto)
}

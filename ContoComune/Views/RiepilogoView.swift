import SwiftUI
import SwiftData

/// Prima tab: saldo del conto comune, quota del mese per ciascuno (con stato
/// versato/da versare) e l'elenco delle spese ricorrenti che quella quota copre.
/// Rispecchia la sezione "DASHBOARD" del mockup approvato.
struct RiepilogoView: View {
    @Query(sort: \Persona.nome) private var persone: [Persona]
    @Query private var quoteMensili: [QuotaMensile]
    @Query private var versamenti: [Versamento]
    @Query private var fatture: [Fattura]
    @Query private var speseExtra: [SpesaExtra]
    @Query(filter: #Predicate<SpesaRicorrente> { $0.attiva }) private var speseRicorrenti: [SpesaRicorrente]

    private var meseCorrente: Date { Date().startOfMonth }

    private var quoteDelMese: [QuotaMensile] {
        quoteMensili.filter { $0.mese.isSameMonth(as: meseCorrente) }
    }

    private var quoteCalcolate: [PersonaID: Double] {
        BudgetEngine.quoteMensili(quoteDelMese, speseRicorrenti: speseRicorrenti)
    }

    private var totaleSpese: Double {
        BudgetEngine.totaleSpeseRicorrentiMensili(speseRicorrenti)
    }

    private var saldo: Double {
        BudgetEngine.saldoContoComune(versamenti: versamenti, fatture: fatture, speseExtra: speseExtra)
    }

    /// I prossimi addebiti a data fissa (es. il mutuo il 27), nei prossimi 45
    /// giorni: prima non c'era modo di vedere quando il saldo sarebbe sceso.
    private var prossimiAddebiti: [(spesa: SpesaRicorrente, data: Date)] {
        BudgetEngine.prossimiAddebiti(speseRicorrenti, finoAGiorni: 45)
    }

    /// Saldo previsto subito dopo il prossimo addebito programmato.
    private var saldoPrevistoDopoProssimo: Double? {
        guard let prossimo = prossimiAddebiti.first else { return nil }
        return BudgetEngine.saldoPrevisto(
            al: prossimo.data,
            versamenti: versamenti,
            fatture: fatture,
            speseExtra: speseExtra,
            speseRicorrenti: speseRicorrenti
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: Formatting.monthTitle(meseCorrente), title: ProfiloLocale.nomeApp)

                    BalanceCardView(
                        saldo: saldo,
                        meta: "Versato finora meno quanto già pagato"
                    )

                    if persone.isEmpty {
                        SectionLabel(text: "Quote del mese")
                        CardView {
                            EmptyStateView(systemImage: "person.2", text: "Aggiungi le persone dalle Impostazioni per iniziare.")
                        }
                    } else {
                        SectionLabel(text: "Quote di \(Formatting.monthTitle(meseCorrente))", aiuto: "quota-automatica")
                        CardView {
                            ForEach(Array(persone.enumerated()), id: \.element.persistentModelID) { index, persona in
                                if index > 0 { RowDivider() }
                                quotaRow(for: persona)
                            }
                            if persone.count == 2 {
                                SplitBarView(
                                    quotaA: quoteCalcolate[PersonaID(persone[0])] ?? 0,
                                    quotaB: quoteCalcolate[PersonaID(persone[1])] ?? 0
                                )
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                            }
                        }
                    }

                    SectionLabel(text: "Spese ricorrenti coperte · \(Formatting.currency(totaleSpese)) / mese")
                    CardView {
                        if speseRicorrenti.isEmpty {
                            EmptyStateView(systemImage: "list.bullet.rectangle", text: "Nessuna spesa ricorrente configurata.")
                        } else {
                            ForEach(Array(speseRicorrenti.enumerated()), id: \.element.persistentModelID) { index, spesa in
                                if index > 0 { RowDivider() }
                                ListRowView(
                                    systemImage: icona(per: spesa.categoria),
                                    title: spesa.nome,
                                    subtitle: spesa.categoria,
                                    amount: Formatting.currency(spesa.importoStimatoMensile)
                                )
                            }
                        }
                    }

                    if !prossimiAddebiti.isEmpty {
                        SectionLabel(text: "Prossimi addebiti")
                        CardView {
                            ForEach(Array(prossimiAddebiti.enumerated()), id: \.offset) { index, elemento in
                                if index > 0 { RowDivider() }
                                ListRowView(
                                    systemImage: "calendar",
                                    title: elemento.spesa.nome,
                                    subtitle: "Addebito il \(Formatting.dateShort.string(from: elemento.data))",
                                    amount: Formatting.currency(elemento.spesa.importoStimatoMensile)
                                )
                            }
                        }

                        if let prossimo = prossimiAddebiti.first, let saldoPrevisto = saldoPrevistoDopoProssimo {
                            SectionLabel(text: "Saldo previsto al \(Formatting.dateShort.string(from: prossimo.data))", aiuto: "saldo-previsto")
                            CardView {
                                HStack {
                                    // Il nome della voce è passato qui dall'etichetta di
                                    // sezione, che così resta su una riga su ogni iPhone.
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Saldo stimato")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(AppTheme.ink)
                                        Text("Dopo \(elementoNome(prossimo))")
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(AppTheme.inkFaint)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(Formatting.currency(saldoPrevisto))
                                        .font(AppTheme.numberFont())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.appBackground)
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder
    private func quotaRow(for persona: Persona) -> some View {
        let quota = quoteCalcolate[PersonaID(persona)] ?? 0
        let percentuale = totaleSpese > 0 ? quota / totaleSpese : 0
        let inPari = BudgetEngine.inPari(persona, mese: meseCorrente, quotaAttesa: quota, versamenti: versamenti)

        HStack {
            HStack(spacing: 10) {
                AvatarView(iniziali: iniziali(persona.nome))
                VStack(alignment: .leading, spacing: 1) {
                    Text(persona.nome).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                    Text(Formatting.percent(percentuale)).font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatting.currency(quota)).font(AppTheme.numberFont())
                PillView(text: inPari ? "In pari" : "Da versare", stato: inPari ? .ok : .warn)
            }
        }
        .padding(.vertical, 12)
    }

    private func iniziali(_ nome: String) -> String {
        String(nome.prefix(2)).uppercased()
    }

    private func elementoNome(_ elemento: (spesa: SpesaRicorrente, data: Date)) -> String {
        elemento.spesa.nome
    }

    private func icona(per categoria: String) -> String {
        switch categoria {
        case "Casa": return "house.fill"
        case "Utenze": return "bolt.fill"
        case "Alimentari": return "cart.fill"
        default: return "tag.fill"
        }
    }
}

#Preview {
    RiepilogoView()
        .modelContainer(PreviewData.container)
}

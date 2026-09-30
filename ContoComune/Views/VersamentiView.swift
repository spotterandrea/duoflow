import SwiftUI
import SwiftData

/// Terza tab: storico dei versamenti sul conto comune, e per ciascuna persona
/// quanto manca per essere in pari con la quota del mese corrente. Tocca un
/// versamento per modificarlo, tieni premuto per Modifica/Elimina.
struct VersamentiView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Persona.nome) private var persone: [Persona]
    @Query private var quoteMensili: [QuotaMensile]
    @Query(sort: \Versamento.dataVersamento, order: .reverse) private var versamenti: [Versamento]
    @Query(filter: #Predicate<SpesaRicorrente> { $0.attiva }) private var speseRicorrenti: [SpesaRicorrente]

    @State private var nuovoVersamentoPresentato = false
    @State private var versamentoInModifica: Versamento?

    private var meseCorrente: Date { Date().startOfMonth }

    private var quoteDelMese: [QuotaMensile] {
        quoteMensili.filter { $0.mese.isSameMonth(as: meseCorrente) }
    }

    private var quoteCalcolate: [PersonaID: Double] {
        BudgetEngine.quoteMensili(quoteDelMese, speseRicorrenti: speseRicorrenti)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "Quota calcolata su stipendio", title: "Versamenti")

                    SectionLabel(text: "Storico")
                    CardView {
                        if versamenti.isEmpty {
                            EmptyStateView(systemImage: "arrow.up.arrow.down.circle", text: "Nessun versamento ancora registrato.")
                        } else {
                            ForEach(Array(versamenti.enumerated()), id: \.element.persistentModelID) { index, versamento in
                                if index > 0 { RowDivider() }
                                // Tocca per modificare, tieni premuto per Modifica/Elimina
                                // (stesso comportamento delle bollette).
                                Button {
                                    versamentoInModifica = versamento
                                } label: {
                                    ListRowView(
                                        systemImage: "person.fill",
                                        title: versamento.persona?.nome ?? "—",
                                        subtitle: "\(Formatting.dateShort.string(from: versamento.dataVersamento)) · quota di \(Formatting.monthTitle(versamento.mese).lowercased())",
                                        amount: Formatting.currency(versamento.importo)
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        versamentoInModifica = versamento
                                    } label: {
                                        Label("Modifica", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(versamento)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    ForEach(persone) { persona in
                        let quota = quoteCalcolate[PersonaID(persona)] ?? 0
                        let versato = BudgetEngine.versatoNelMese(persona, mese: meseCorrente, versamenti: versamenti)
                        let residuo = max(quota - versato, 0)

                        SectionLabel(text: "\(persona.nome) · \(Formatting.monthTitle(meseCorrente))")
                        CardView {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(residuo > 0.01 ? "Ancora da versare" : "Quota coperta")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(AppTheme.ink)
                                    Text("Quota attesa \(Formatting.currency(quota))")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(AppTheme.inkFaint)
                                }
                                Spacer()
                                Text(Formatting.currency(residuo))
                                    .font(AppTheme.numberFont())
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PrimaryButton(title: "Registra versamento") {
                        nuovoVersamentoPresentato = true
                    }
                }
                .padding(16)
            }
            .background(AppTheme.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $nuovoVersamentoPresentato) {
                NuovoVersamentoSheet()
            }
            .sheet(item: $versamentoInModifica) { versamento in
                NuovoVersamentoSheet(versamentoDaModificare: versamento)
            }
        }
    }
}

#Preview {
    VersamentiView()
        .modelContainer(PreviewData.container)
}

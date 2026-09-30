import SwiftUI
import SwiftData

/// Seconda tab: bollette da pagare (con scadenza, in rosso se già passata) e
/// le ultime pagate. Tocca una riga da pagare per segnarla come pagata,
/// tocca una pagata per modificarla; su entrambe, tenendo premuto, si apre
/// il menu con "Modifica" (tutti i campi, importo compreso, sono sempre
/// correggibili) ed "Elimina".
struct BolletteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fattura.scadenza) private var fatture: [Fattura]
    @State private var nuovaFatturaPresentata = false
    @State private var fatturaInModifica: Fattura?

    private var daPagare: [Fattura] { BudgetEngine.fattureDaPagare(fatture) }
    private var pagateRecenti: [Fattura] {
        fatture
            .filter(\.pagata)
            .sorted { ($0.dataPagamento ?? .distantPast) > ($1.dataPagamento ?? .distantPast) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "\(fatture.count) fatture registrate", title: "Bollette")

                    SectionLabel(text: "Da pagare")
                    CardView {
                        if daPagare.isEmpty {
                            EmptyStateView(systemImage: "checkmark.circle", text: "Nessuna bolletta in sospeso.")
                        } else {
                            ForEach(Array(daPagare.enumerated()), id: \.element.persistentModelID) { index, fattura in
                                if index > 0 { RowDivider() }
                                Button {
                                    fattura.segnaComePagata()
                                } label: {
                                    ListRowView(
                                        systemImage: "bolt.fill",
                                        title: "\(fattura.fornitore)",
                                        subtitle: fattura.periodoRiferimento,
                                        amount: Formatting.currency(fattura.importo),
                                        badge: (scaduta(fattura) ? "Scaduta" : "Scad. \(Formatting.dateShort.string(from: fattura.scadenza))",
                                                scaduta(fattura) ? .danger : .warn)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        fatturaInModifica = fattura
                                    } label: {
                                        Label("Modifica", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(fattura)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel(text: "Pagate di recente")
                    CardView {
                        if pagateRecenti.isEmpty {
                            EmptyStateView(systemImage: "tray", text: "Ancora nessuna bolletta pagata.")
                        } else {
                            ForEach(Array(pagateRecenti.enumerated()), id: \.element.persistentModelID) { index, fattura in
                                if index > 0 { RowDivider() }
                                Button {
                                    fatturaInModifica = fattura
                                } label: {
                                    ListRowView(
                                        systemImage: "bolt.fill",
                                        title: fattura.fornitore,
                                        subtitle: fattura.periodoRiferimento,
                                        amount: Formatting.currency(fattura.importo),
                                        badge: ("Pagata", .ok)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        fatturaInModifica = fattura
                                    } label: {
                                        Label("Modifica", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(fattura)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    PrimaryButton(title: "Aggiungi fattura") {
                        nuovaFatturaPresentata = true
                    }
                }
                .padding(16)
            }
            .dismissTastieraAlloSwipe()
            .background(AppTheme.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $nuovaFatturaPresentata) {
                NuovaFatturaSheet()
            }
            .sheet(item: $fatturaInModifica) { fattura in
                NuovaFatturaSheet(fatturaDaModificare: fattura)
            }
        }
    }

    private func scaduta(_ fattura: Fattura) -> Bool {
        fattura.scadenza < Date()
    }
}

#Preview {
    BolletteView()
        .modelContainer(PreviewData.container)
}

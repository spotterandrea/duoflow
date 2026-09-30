import SwiftUI
import SwiftData

/// Quarta tab: spese occasionali pagate dal conto comune, fuori dal budget
/// ricorrente fisso (es. una riparazione imprevista). Ogni riga si può
/// toccare per modificarla (tutti i campi sono correggibili) o tenere
/// premuta per eliminarla, se inserita per errore.
struct ExtraView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpesaExtra.data, order: .reverse) private var speseExtra: [SpesaExtra]
    @State private var nuovaSpesaPresentata = false
    @State private var spesaInModifica: SpesaExtra?

    private var meseCorrente: Date { Date().startOfMonth }

    private var speseDelMese: [SpesaExtra] {
        speseExtra.filter { $0.data.isSameMonth(as: meseCorrente) }
    }

    private var totaleMese: Double {
        speseDelMese.reduce(0) { $0 + $1.importo }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScreenHeader(eyebrow: "Fuori dal budget fisso", title: "Spese Extra")

                    SectionLabel(text: "Tutte le spese del mese")
                    CardView {
                        if speseExtra.isEmpty {
                            EmptyStateView(systemImage: "cart", text: "Nessuna spesa extra ancora registrata.")
                        } else {
                            ForEach(Array(speseExtra.enumerated()), id: \.element.persistentModelID) { index, spesa in
                                if index > 0 { RowDivider() }
                                Button {
                                    spesaInModifica = spesa
                                } label: {
                                    ListRowView(
                                        systemImage: "cart.fill",
                                        title: spesa.descrizione,
                                        subtitle: "\(Formatting.dateShort.string(from: spesa.data)) · \(spesa.categoria)",
                                        amount: Formatting.currency(spesa.importo)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        spesaInModifica = spesa
                                    } label: {
                                        Label("Modifica", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(spesa)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    SectionLabel(text: "Totale spese extra · \(Formatting.monthTitle(meseCorrente))")
                    CardView {
                        HStack {
                            Text("Uscito dal conto comune")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            Text(Formatting.currency(totaleMese))
                                .font(AppTheme.numberFont())
                        }
                        .padding(.vertical, 4)
                    }

                    PrimaryButton(title: "Aggiungi spesa extra") {
                        nuovaSpesaPresentata = true
                    }
                }
                .padding(16)
            }
            .dismissTastieraAlloSwipe()
            .background(AppTheme.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $nuovaSpesaPresentata) {
                NuovaSpesaExtraSheet()
            }
            .sheet(item: $spesaInModifica) { spesa in
                NuovaSpesaExtraSheet(spesaDaModificare: spesa)
            }
        }
    }
}

#Preview {
    ExtraView()
        .modelContainer(PreviewData.container)
}

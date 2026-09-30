import SwiftUI
import SwiftData

/// Form per registrare o modificare una bolletta (fornitore, periodo,
/// importo, scadenza, collegamento facoltativo alla voce di spesa
/// ricorrente). Stesso form per "nuova" e "modifica": se `fatturaDaModificare`
/// è valorizzata, precompila e aggiorna quella invece di crearne una nuova —
/// prima un importo sbagliato (es. una bolletta ENEL da 180 € digitata come
/// 180.000 €) non era correggibile in nessun modo dopo il salvataggio.
struct NuovaFatturaSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SpesaRicorrente.nome) private var speseRicorrenti: [SpesaRicorrente]

    var fatturaDaModificare: Fattura? = nil

    @State private var fornitore = ""
    @State private var periodoRiferimento = ""
    @State private var importoTesto = ""
    @State private var scadenza = Date()
    @State private var spesaCollegata: SpesaRicorrente?
    @State private var giaPagata = false

    private var importo: Double? {
        Double(importoTesto.replacingOccurrences(of: ",", with: "."))
    }

    private var valida: Bool {
        !fornitore.trimmingCharacters(in: .whitespaces).isEmpty && (importo ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Fornitore") {
                    TextField("es. ENEL, Simecom, Uniacque", text: $fornitore)
                    TextField("Periodo, es. Ago–Set 2026", text: $periodoRiferimento)
                }
                Section("Importo e scadenza") {
                    TextField("Importo", text: $importoTesto)
                        .keyboardType(.decimalPad)
                    DatePicker("Scadenza", selection: $scadenza, displayedComponents: .date)
                    Toggle("Già pagata", isOn: $giaPagata)
                }
                Section("Voce di spesa collegata") {
                    Picker("Voce", selection: $spesaCollegata) {
                        Text("Nessuna").tag(SpesaRicorrente?.none)
                        ForEach(speseRicorrenti) { spesa in
                            Text(spesa.nome).tag(SpesaRicorrente?.some(spesa))
                        }
                    }
                }
            }
            .dismissTastieraAlloSwipe()
            .navigationTitle(fatturaDaModificare == nil ? "Nuova fattura" : "Modifica fattura")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salva() }.disabled(!valida)
                }
            }
            .onAppear { precompila() }
        }
    }

    private func precompila() {
        guard let fattura = fatturaDaModificare else { return }
        fornitore = fattura.fornitore
        periodoRiferimento = fattura.periodoRiferimento
        importoTesto = String(format: "%.2f", fattura.importo)
        scadenza = fattura.scadenza
        spesaCollegata = fattura.spesaRicorrente
        giaPagata = fattura.pagata
    }

    private func salva() {
        guard let importo else { return }

        if let fattura = fatturaDaModificare {
            fattura.fornitore = fornitore
            fattura.periodoRiferimento = periodoRiferimento
            fattura.importo = importo
            fattura.scadenza = scadenza
            fattura.spesaRicorrente = spesaCollegata
            if giaPagata && !fattura.pagata {
                fattura.segnaComePagata()
            } else if !giaPagata {
                fattura.pagata = false
                fattura.dataPagamento = nil
            }
        } else {
            let fattura = Fattura(
                fornitore: fornitore,
                periodoRiferimento: periodoRiferimento,
                importo: importo,
                scadenza: scadenza,
                pagata: giaPagata,
                dataPagamento: giaPagata ? .now : nil,
                spesaRicorrente: spesaCollegata
            )
            modelContext.insert(fattura)
        }
        dismiss()
    }
}

#Preview {
    NuovaFatturaSheet()
        .modelContainer(PreviewData.container)
}

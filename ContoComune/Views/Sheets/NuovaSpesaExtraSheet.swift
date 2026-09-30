import SwiftUI
import SwiftData

/// Form per registrare o modificare una spesa extra occasionale pagata dal
/// conto comune. Stesso form per "nuova" e "modifica": se `spesaDaModificare`
/// è valorizzata, precompila tutti i campi e aggiorna quella invece di
/// crearne una nuova — prima non era possibile correggere nulla dopo il
/// salvataggio (es. un importo digitato per errore come 180.000 € invece di
/// 180 € restava sbagliato per sempre).
struct NuovaSpesaExtraSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var spesaDaModificare: SpesaExtra? = nil

    @State private var descrizione = ""
    @State private var importoTesto = ""
    @State private var categoria = ""
    @State private var data = Date()
    @State private var note = ""

    private var importo: Double? {
        Double(importoTesto.replacingOccurrences(of: ",", with: "."))
    }

    private var valida: Bool {
        !descrizione.trimmingCharacters(in: .whitespaces).isEmpty && (importo ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Spesa") {
                    TextField("Descrizione, es. Riparazione cancello", text: $descrizione)
                    TextField("Categoria, es. Manutenzione", text: $categoria)
                }
                Section("Importo e data") {
                    TextField("Importo", text: $importoTesto)
                        .keyboardType(.decimalPad)
                    DatePicker("Data", selection: $data, displayedComponents: .date)
                    TextField("Note (facoltative)", text: $note)
                }
            }
            .dismissTastieraAlloSwipe()
            .navigationTitle(spesaDaModificare == nil ? "Nuova spesa extra" : "Modifica spesa extra")
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
        guard let spesa = spesaDaModificare else { return }
        descrizione = spesa.descrizione
        importoTesto = String(format: "%.2f", spesa.importo)
        categoria = spesa.categoria
        data = spesa.data
        note = spesa.note ?? ""
    }

    private func salva() {
        guard let importo else { return }
        let categoriaFinale = categoria.isEmpty ? "Varie" : categoria
        let noteFinali = note.isEmpty ? nil : note

        if let spesa = spesaDaModificare {
            spesa.descrizione = descrizione
            spesa.importo = importo
            spesa.categoria = categoriaFinale
            spesa.data = data
            spesa.note = noteFinali
        } else {
            let spesa = SpesaExtra(
                descrizione: descrizione,
                importo: importo,
                categoria: categoriaFinale,
                data: data,
                note: noteFinali
            )
            modelContext.insert(spesa)
        }
        dismiss()
    }
}

#Preview {
    NuovaSpesaExtraSheet()
        .modelContainer(PreviewData.container)
}

import SwiftUI
import SwiftData

/// Form per registrare o modificare un versamento: persona, importo
/// (pre-compilato con la quota attesa del mese se nuovo), mese di
/// riferimento, data e note facoltative. Stesso form per "nuovo" e
/// "modifica", come per le bollette: se `versamentoDaModificare` è
/// valorizzato, precompila e aggiorna quello invece di crearne uno nuovo —
/// prima un versamento sbagliato si poteva solo lasciare così com'era.
struct NuovoVersamentoSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Persona.nome) private var persone: [Persona]
    @Query private var quoteMensili: [QuotaMensile]
    @Query(filter: #Predicate<SpesaRicorrente> { $0.attiva }) private var speseRicorrenti: [SpesaRicorrente]

    var versamentoDaModificare: Versamento? = nil

    @State private var personaSelezionata: Persona?
    @AppStorage(ProfiloLocale.chiavePersonaCorrente) private var uuidPersonaCorrente: String = ""
    @State private var importoTesto = ""
    @State private var meseRiferimento = Date().startOfMonth
    @State private var data = Date()
    @State private var note = ""
    @State private var precompilato = false
    @State private var confermaEliminazione = false

    private var quoteCalcolate: [PersonaID: Double] {
        let quoteDelMese = quoteMensili.filter { $0.mese.isSameMonth(as: meseRiferimento) }
        return BudgetEngine.quoteMensili(quoteDelMese, speseRicorrenti: speseRicorrenti)
    }

    private var importo: Double? { Importo.leggi(importoTesto) }

    private var valida: Bool {
        personaSelezionata != nil && (importo ?? 0) > 0
    }

    /// Mesi selezionabili: gli ultimi 12 e il prossimo, più quello del
    /// versamento in modifica se fosse più vecchio.
    private var mesiDisponibili: [Date] {
        let calendario = Calendar.current
        let corrente = Date().startOfMonth
        var mesi = (-12...1).compactMap { calendario.date(byAdding: .month, value: $0, to: corrente) }
        if let mese = versamentoDaModificare?.mese.startOfMonth, !mesi.contains(where: { $0.isSameMonth(as: mese) }) {
            mesi.insert(mese, at: 0)
        }
        return mesi.reversed()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chi ha versato") {
                    Picker("Persona", selection: $personaSelezionata) {
                        Text("Seleziona").tag(Persona?.none)
                        ForEach(persone) { persona in
                            Text(persona.nome).tag(Persona?.some(persona))
                        }
                    }
                    .onChange(of: personaSelezionata) { _, nuovaPersona in
                        // Proposta automatica della quota solo per i nuovi versamenti.
                        guard versamentoDaModificare == nil, let nuovaPersona, importoTesto.isEmpty else { return }
                        if let quota = quoteCalcolate[PersonaID(nuovaPersona)] {
                            importoTesto = Self.testoImporto(quota)
                        }
                    }
                }
                Section {
                    TextField("Importo", text: $importoTesto)
                        .keyboardType(.decimalPad)
                    Picker("Mese di riferimento", selection: $meseRiferimento) {
                        ForEach(mesiDisponibili, id: \.self) { mese in
                            Text(Formatting.monthTitle(mese)).tag(mese)
                        }
                    }
                    DatePicker("Data del versamento", selection: $data, displayedComponents: .date)
                    TextField("Note (facoltative)", text: $note)
                } header: {
                    Text("Importo e data")
                } footer: {
                    Text("Il mese di riferimento decide quale quota mensile copre il versamento.")
                }

                if versamentoDaModificare != nil {
                    Section {
                        Button("Elimina versamento", role: .destructive) {
                            confermaEliminazione = true
                        }
                    }
                }
            }
            .dismissTastieraAlloSwipe()
            .onAppear(perform: precompila)
            .navigationTitle(versamentoDaModificare == nil ? "Nuovo versamento" : "Modifica versamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salva() }.disabled(!valida)
                }
            }
            .confirmationDialog("Eliminare questo versamento?", isPresented: $confermaEliminazione, titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    if let versamento = versamentoDaModificare {
                        modelContext.delete(versamento)
                    }
                    dismiss()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Il saldo del conto comune verrà ricalcolato.")
            }
        }
    }

    private func precompila() {
        guard !precompilato else { return }
        precompilato = true
        if let versamento = versamentoDaModificare {
            personaSelezionata = versamento.persona
            importoTesto = Self.testoImporto(versamento.importo)
            meseRiferimento = versamento.mese.startOfMonth
            data = versamento.dataVersamento
            note = versamento.note ?? ""
        } else if personaSelezionata == nil {
            // Propone chi usa questo iPhone (scelto in Impostazioni).
            personaSelezionata = persone.first { $0.uuid.uuidString == uuidPersonaCorrente }
        }
    }

    private func salva() {
        guard let importo, let personaSelezionata else { return }
        let noteFinali = note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        if let versamento = versamentoDaModificare {
            versamento.persona = personaSelezionata
            versamento.importo = importo
            versamento.mese = meseRiferimento
            versamento.dataVersamento = data
            versamento.note = noteFinali
        } else {
            modelContext.insert(Versamento(
                persona: personaSelezionata,
                importo: importo,
                mese: meseRiferimento,
                dataVersamento: data,
                note: noteFinali
            ))
        }
        dismiss()
    }

    /// "840,00" con la virgola, come si scrive in italiano.
    private static func testoImporto(_ valore: Double) -> String {
        String(format: "%.2f", valore).replacingOccurrences(of: ".", with: ",")
    }
}

#Preview {
    NuovoVersamentoSheet()
        .modelContainer(PreviewData.container)
}

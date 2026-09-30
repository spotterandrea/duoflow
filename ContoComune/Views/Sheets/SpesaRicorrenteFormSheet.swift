import SwiftUI
import SwiftData

/// Form per creare o modificare una voce di spesa ricorrente (nome,
/// categoria, importo mensile equivalente, periodicità reale, giorno fisso
/// di addebito, attiva/non attiva). Stesso form per "nuova" e "modifica": se
/// `voceDaModificare` è valorizzata, precompila e aggiorna quella invece di
/// crearne una nuova.
struct SpesaRicorrenteFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var voceDaModificare: SpesaRicorrente? = nil

    @State private var nome = ""
    @State private var categoria = ""
    @State private var importoTesto = ""
    @State private var periodicita: PeriodicitaSpesa = .mensile
    @State private var attiva = true
    @State private var haGiornoFisso = false
    @State private var giornoAddebito = 1

    private var importo: Double? {
        Double(importoTesto.replacingOccurrences(of: ",", with: "."))
    }

    private var valida: Bool {
        !nome.trimmingCharacters(in: .whitespaces).isEmpty && (importo ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Voce") {
                    TextField("Nome, es. Mutuo", text: $nome)
                    TextField("Categoria, es. Casa", text: $categoria)
                }
                Section {
                    TextField("Importo", text: $importoTesto)
                        .keyboardType(.decimalPad)
                    Picker("Periodicità reale della fattura", selection: $periodicita) {
                        Text("Mensile").tag(PeriodicitaSpesa.mensile)
                        Text("Bimestrale").tag(PeriodicitaSpesa.bimestrale)
                        Text("Annuale").tag(PeriodicitaSpesa.annuale)
                    }
                } header: {
                    Text("Importo mensile equivalente")
                } footer: {
                    Text("Se la spesa reale non arriva ogni mese (es. TARI annuale), inserisci comunque qui il suo equivalente mensile: è quello che entra nel calcolo delle quote.")
                }
                Section {
                    Toggle("Ha un giorno fisso di addebito", isOn: $haGiornoFisso)
                    if haGiornoFisso {
                        Stepper("Giorno \(giornoAddebito) del mese", value: $giornoAddebito, in: 1...31)
                    }
                } footer: {
                    Text(haGiornoFisso
                        ? "Se il mese ha meno giorni (es. 31 a febbraio) o il giorno cade di sabato/domenica, l'addebito si sposta automaticamente ai giorni feriali più vicini: il giorno primario resta comunque questo."
                        : "Impostalo per vedere questa voce tra i \"prossimi addebiti\" e nel saldo previsto del Riepilogo (es. il saldo che scenderà quando arriverà il mutuo).")
                }
                Section {
                    Toggle("Voce attiva", isOn: $attiva)
                } footer: {
                    Text("Disattivala se avete chiuso questa spesa (es. mutuo estinto): resta nello storico collegata alle fatture passate, ma non entra più nel calcolo delle quote future.")
                }
            }
            .dismissTastieraAlloSwipe()
            .navigationTitle(voceDaModificare == nil ? "Nuova voce" : "Modifica voce")
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
        guard let voce = voceDaModificare else { return }
        nome = voce.nome
        categoria = voce.categoria
        importoTesto = String(format: "%.2f", voce.importoStimatoMensile)
        periodicita = voce.periodicita
        attiva = voce.attiva
        if let giorno = voce.giornoAddebito {
            haGiornoFisso = true
            giornoAddebito = giorno
        }
    }

    private func salva() {
        guard let importo else { return }
        let categoriaFinale = categoria.trimmingCharacters(in: .whitespaces).isEmpty ? "Altro" : categoria
        let giornoFinale = haGiornoFisso ? giornoAddebito : nil

        if let voce = voceDaModificare {
            voce.nome = nome
            voce.categoria = categoriaFinale
            voce.importoStimatoMensile = importo
            voce.periodicita = periodicita
            voce.attiva = attiva
            voce.giornoAddebito = giornoFinale
        } else {
            let nuova = SpesaRicorrente(
                nome: nome,
                categoria: categoriaFinale,
                importoStimatoMensile: importo,
                periodicita: periodicita,
                attiva: attiva,
                giornoAddebito: giornoFinale
            )
            modelContext.insert(nuova)
        }
        dismiss()
    }
}

#Preview {
    SpesaRicorrenteFormSheet()
        .modelContainer(PreviewData.container)
}

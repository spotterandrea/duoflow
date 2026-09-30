import SwiftUI
import SwiftData

/// Elenco delle voci di spesa ricorrente, modificabile: si può aggiungere
/// una nuova voce, toccarne una per modificarla, disattivarla (resta nello
/// storico ma esce dal calcolo delle quote — utile se es. si estingue il
/// mutuo) o eliminarla del tutto con lo swipe. Stile riallineato al resto
/// dell'app (sfondo, colori e titolo coerenti con le altre schermate: prima
/// questa era l'unica a usare l'aspetto di sistema di default).
struct SpeseRicorrentiListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SpesaRicorrente.nome) private var speseRicorrenti: [SpesaRicorrente]

    @State private var nuovaVocePresentata = false
    @State private var voceInModifica: SpesaRicorrente?

    var body: some View {
        List {
            if speseRicorrenti.isEmpty {
                Text("Nessuna voce ricorrente ancora configurata.")
                    .foregroundStyle(AppTheme.inkMuted)
                    .listRowBackground(Color.clear)
            }
            ForEach(speseRicorrenti) { spesa in
                Button {
                    voceInModifica = spesa
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(spesa.nome)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(spesa.attiva ? AppTheme.ink : AppTheme.inkFaint)
                            Text(sottotitolo(per: spesa))
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.inkFaint)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatting.currency(spesa.importoStimatoMensile))
                                .font(AppTheme.numberFont())
                                .foregroundStyle(spesa.attiva ? AppTheme.ink : AppTheme.inkFaint)
                            if !spesa.attiva {
                                Text("Non attiva")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(AppTheme.inkFaint)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(AppTheme.surface)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        modelContext.delete(spesa)
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                    Button {
                        spesa.attiva.toggle()
                    } label: {
                        Label(spesa.attiva ? "Disattiva" : "Riattiva", systemImage: spesa.attiva ? "pause.circle" : "play.circle")
                    }
                    .tint(AppTheme.warn)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(AppTheme.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Voci ricorrenti")
                    .font(AppTheme.titleFont(17))
                    .foregroundStyle(AppTheme.ink)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    nuovaVocePresentata = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $nuovaVocePresentata) {
            SpesaRicorrenteFormSheet()
        }
        .sheet(item: $voceInModifica) { spesa in
            SpesaRicorrenteFormSheet(voceDaModificare: spesa)
        }
    }

    private func sottotitolo(per spesa: SpesaRicorrente) -> String {
        guard let giorno = spesa.giornoAddebito else { return spesa.categoria }
        return "\(spesa.categoria) · addebito il \(giorno)"
    }
}

#Preview {
    NavigationStack {
        SpeseRicorrentiListView()
    }
    .modelContainer(PreviewData.container)
}

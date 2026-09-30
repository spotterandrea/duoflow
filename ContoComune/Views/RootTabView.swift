import SwiftUI
import SwiftData

/// Le 5 schermate principali dell'app, come nel mockup approvato: Riepilogo,
/// Bollette, Versamenti, Extra, Impostazioni.
struct RootTabView: View {
    var body: some View {
        TabView {
            RiepilogoView()
                .tabItem { Label("Riepilogo", systemImage: "chart.bar.fill") }

            BolletteView()
                .tabItem { Label("Bollette", systemImage: "doc.text.fill") }

            VersamentiView()
                .tabItem { Label("Versamenti", systemImage: "arrow.up.arrow.down.circle") }

            ExtraView()
                .tabItem { Label("Extra", systemImage: "plus.circle") }

            ImpostazioniView()
                .tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    RootTabView()
        .modelContainer(PreviewData.container)
}

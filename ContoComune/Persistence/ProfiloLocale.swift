import Foundation

/// Impostazioni che valgono solo per QUESTO iPhone (non sincronizzate):
/// quale Persona della coppia sta usando il telefono. Serve per proporre
/// "te stesso" come default nei form (es. chi ha fatto il versamento).
enum ProfiloLocale {
    /// Nome mostrato nell'interfaccia (deve coincidere con CFBundleDisplayName
    /// nelle impostazioni del target).
    static let nomeApp = "DuoFlow"

    static let chiavePersonaCorrente = "uuidPersonaCorrente"
}

/// Lettura di importi scritti a mano, con virgola o punto decimale
/// ("1.234,56", "1234.56", "12,5"). Ritorna nil se non è un numero.
enum Importo {
    static func leggi(_ testo: String) -> Double? {
        var t = testo.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "€", with: "")
        t = t.replacingOccurrences(of: " ", with: "")
        guard !t.isEmpty else { return nil }
        if t.contains(",") {
            // Formato italiano: il punto è separatore delle migliaia.
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return Double(t)
    }
}

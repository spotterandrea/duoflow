import SwiftUI

/// Palette e font di DuoFlow: titoli serif, numeri monospaziati tabulari,
/// superfici chiare con il blu dell'icona come accento. Ogni colore ha una variante dark coerente,
/// così l'app segue automaticamente il tema di sistema.
enum AppTheme {

    // MARK: - Colori
    // Palette DuoFlow, ricavata dall'icona: blu del portafoglio come accento,
    // arancio dei punti del grafico per gli avvisi, neutri blu-ardesia.
    // Contrasti verificati (WCAG): testo principale > 14:1, secondario > 6:1.

    static let appBackground = Color(light: "F3F7FB", dark: "0D1522")
    static let surface = Color(light: "FFFFFF", dark: "152033")
    static let surfaceSunken = Color(light: "E8EFF6", dark: "0A111C")
    static let ink = Color(light: "14243A", dark: "E8EEF6")
    static let inkMuted = Color(light: "4F6178", dark: "A2B1C4")
    static let inkFaint = Color(light: "8392A5", dark: "6F7F94")
    static let hairline = Color(light: "D9E2EC", dark: "243248")

    static let accent = Color(light: "2E69B2", dark: "5A9BDD")
    /// Tono più profondo dell'accento, per il gradiente della card saldo
    /// (come il fronte del portafoglio nell'icona).
    static let accentDeep = Color(light: "25548F", dark: "4C8AD0")
    static let accentInk = Color(light: "FFFFFF", dark: "06121F")
    static let accentSoft = Color(light: "DCE8F6", dark: "1A3354")
    static let accentSoftInk = Color(light: "1F4C86", dark: "9CC8F5")

    /// Arancio dell'icona (F2A548), scurito in chiaro per restare leggibile.
    static let warn = Color(light: "94540C", dark: "F2A548")
    static let warnSoft = Color(light: "FCE9CF", dark: "3D2B12")

    static let danger = Color(light: "B03A32", dark: "E88A80")
    static let dangerSoft = Color(light: "F7DEDB", dark: "3D2220")

    // MARK: - Font

    /// Titoli di schermata (equivalente a Source Serif 4 nel mockup).
    static func titleFont(_ size: CGFloat = 23) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Eyebrow / etichette in maiuscolo (equivalente a IBM Plex Mono nel mockup).
    static func eyebrowFont(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    /// Numeri ed importi, sempre con cifre tabulari.
    static func numberFont(_ size: CGFloat = 15, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    /// Colore dinamico chiaro/scuro definito via componente hex RGB (senza #).
    init(light: String, dark: String) {
        self.init(uiColor: UIColor(
            light: UIColor(hex: light),
            dark: UIColor(hex: dark)
        ))
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    convenience init(light: UIColor, dark: UIColor) {
        self.init(dynamicProvider: { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

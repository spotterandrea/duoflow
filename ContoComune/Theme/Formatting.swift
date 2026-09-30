import Foundation

/// Helper di formattazione condivisi: valuta in euro coerente col mockup
/// ("€ 1.371,26"), date brevi, e normalizzazione al primo giorno del mese
/// (usata ovunque un modello salva `mese` per confrontare periodi).
enum Formatting {

    /// Formatter decimale (non currency) così il simbolo "€ " resta sempre
    /// un prefisso fisso, indipendentemente da come la locale it_IT
    /// posizionerebbe normalmente il simbolo di valuta.
    private static let decimalFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "it_IT")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func currency(_ value: Double) -> String {
        let numero = decimalFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        return "€ \(numero)"
    }

    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    static let dateShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "dd/MM/yy"
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    static func monthTitle(_ date: Date) -> String {
        monthYear.string(from: date).capitalized
    }
}

extension Calendar {
    /// Normalizza una data al primo giorno del suo mese, a mezzanotte: è così
    /// che `mese` viene salvato su QuotaMensile e Versamento, per confrontare
    /// periodi in modo affidabile indipendentemente dal giorno scelto in UI.
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}

extension Date {
    var startOfMonth: Date {
        Calendar.current.startOfMonth(for: self)
    }

    func isSameMonth(as other: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: other, toGranularity: .month)
    }
}

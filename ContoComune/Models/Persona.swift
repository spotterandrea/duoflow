import Foundation
import SwiftData

/// Uno dei due partner della coppia. Non porta lo stipendio: quello varia
/// mese per mese e viene registrato in QuotaMensile, per non alterare
/// retroattivamente i calcoli dei mesi già chiusi quando cambia.
@Model
final class Persona {
    /// Identificativo stabile e univoco del record, uguale su tutti i
    /// dispositivi della coppia: è il nome del record su CloudKit. Viene
    /// conservato anche dopo l'eliminazione (history tombstone), così la
    /// sync sa quale record cancellare sull'altro iPhone.
    @Attribute(.preserveValueOnDeletion) var uuid: UUID = UUID()

    var nome: String

    init(nome: String) {
        self.nome = nome
    }
}

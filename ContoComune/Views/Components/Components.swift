import SwiftUI

/// Stato semantico per pill/pallini (in pari, da versare, scaduto), riusato
/// in Bollette, Versamenti e Riepilogo. Mappa 1:1 il legend del mockup.
enum StatoBadge {
    case ok, warn, danger

    var color: Color {
        switch self {
        case .ok: return AppTheme.accentSoftInk
        case .warn: return AppTheme.warn
        case .danger: return AppTheme.danger
        }
    }

    var softColor: Color {
        switch self {
        case .ok: return AppTheme.accentSoft
        case .warn: return AppTheme.warnSoft
        case .danger: return AppTheme.dangerSoft
        }
    }
}

/// Etichetta arrotondata con pallino colorato, es. "In pari" / "Scad. 24/10".
struct PillView: View {
    let text: String
    let stato: StatoBadge

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(stato.color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(stato.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(stato.softColor, in: Capsule())
    }
}

/// Contenitore a scheda con bordo sottile, usato per raggruppare righe.
struct CardView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }
}

/// Titolo di sezione in maiuscolo/monospazio, come "QUOTE DI SETTEMBRE".
/// Se `aiuto` è valorizzato, subito dopo il testo compare un piccolo "?"
/// allineato alla stessa riga, che apre la guida su quella domanda.
struct SectionLabel: View {
    let text: String
    var aiuto: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(text.uppercased())
                .font(AppTheme.eyebrowFont())
                .foregroundStyle(AppTheme.inkFaint)
            if let aiuto {
                AiutoButton(domanda: aiuto, dimensione: 12)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
    }
}

/// Eyebrow + titolo serif in cima a ogni schermata (es. "Settembre 2026" / "Bollette").
struct ScreenHeader: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow.uppercased())
                .font(AppTheme.eyebrowFont(10.5))
                .foregroundStyle(AppTheme.inkFaint)
            Text(title)
                .font(AppTheme.titleFont())
                .foregroundStyle(AppTheme.ink)
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La grande card blu con il saldo del conto comune in cima al Riepilogo.
struct BalanceCardView: View {
    let saldo: Double
    let meta: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SALDO ATTUALE")
                .font(AppTheme.eyebrowFont())
                .opacity(0.85)
            Text(Formatting.currency(saldo))
                .font(AppTheme.numberFont(34, weight: .semibold))
            Text(meta)
                .font(.system(size: 12.5))
                .opacity(0.85)
        }
        .foregroundStyle(AppTheme.accentInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

/// Cerchietto con iniziali, per rappresentare una Persona senza foto profilo.
struct AvatarView: View {
    let iniziali: String
    var size: CGFloat = 32

    var body: some View {
        Text(iniziali)
            .font(.system(size: size * 0.4, weight: .semibold, design: .monospaced))
            .foregroundStyle(AppTheme.inkMuted)
            .frame(width: size, height: size)
            .background(AppTheme.surfaceSunken, in: Circle())
    }
}

/// Riga generica di lista: icona, titolo + sottotitolo, importo (+ badge facoltativo).
struct ListRowView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let amount: String
    var badge: (text: String, stato: StatoBadge)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.inkMuted)
                .frame(width: 34, height: 34)
                .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(AppTheme.ink)
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(AppTheme.inkFaint)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount).font(AppTheme.numberFont(14)).foregroundStyle(AppTheme.ink)
                if let badge {
                    PillView(text: badge.text, stato: badge.stato)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

/// Divisore sottile tra righe di lista dentro una CardView.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(AppTheme.hairline).frame(height: 1)
    }
}

/// Stato vuoto per liste senza dati ("Nessuna fattura ancora").
struct EmptyStateView: View {
    let systemImage: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(AppTheme.inkFaint)
                .frame(width: 44, height: 44)
                .background(AppTheme.surfaceSunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

/// Pulsante pieno color accento, larghezza intera (es. "+ Registra versamento").
struct PrimaryButton: View {
    let title: String
    var systemImage: String = "plus"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.accentInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Barra a due segmenti che mostra la ripartizione percentuale tra due persone.
struct SplitBarView: View {
    let quotaA: Double
    let quotaB: Double

    var body: some View {
        GeometryReader { geo in
            let totale = max(quotaA + quotaB, 0.0001)
            HStack(spacing: 0) {
                Rectangle().fill(AppTheme.accent).frame(width: geo.size.width * quotaA / totale)
                Rectangle().fill(AppTheme.hairline)
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }
}

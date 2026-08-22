import SwiftUI
import WidgetKit


// Die vier Zuschnitte einer Komplikation.
//
// Sie liegen in `WatchGeteilt/` und nicht beim Widget-Ziel, weil auch die
// Uhr-App sie zeichnen können muss — sonst liesse sich am Simulator nie
// nachsehen, wie eine Komplikation wirklich aussieht, und die Antwort auf
// «passt das?» käme erst vom Gerät eines Käufers.
//
// Alle vier zeigen dieselbe Auskunft — das drängendste Fenster —, nur
// verschieden knapp. Was auf der kleinsten Fläche wegfällt, ist die Herkunft;
// was nie wegfällt, ist das Alter der Zahl. Eine Zahl ohne ihr Alter ist auf
// einem Zifferblatt keine Auskunft, sondern eine Behauptung.

struct UhrEintrag: TimelineEntry {
    let date: Date
    let urteil: Urteil
    let stand: Date?

    static let beispiel = UhrEintrag(
        date: .now,
        urteil: Urteil(lage: .knapp, quelle: "Claude", fenster: "7 Tage",
                       fensterKurz: "1W", prozent: 81.7, anbieter: .claude,
                       zuruecksetzung: nil),
        stand: .now.addingTimeInterval(-142))
}

/// Rund — der Ring, wie ihn die Menüleiste auf dem Mac zeigt.
struct RundeUhrAnsicht: View {
    let eintrag: UhrEintrag
    @Environment(\.colorScheme) private var schema

    var body: some View {
        if let prozent = eintrag.urteil.prozent {
            // Die Verhältnisse sind auf die 58 Punkte gerechnet, die eine runde
            // Zubehörkachel innen hat — dieselbe Rechnung wie beim iPhone.
            UsageRing(percent: prozent,
                      provider: eintrag.urteil.anbieter,
                      label: .none,
                      lineWidthRatio: 5.0 / 58.0,
                      paddingRatio: 1.5 / 58.0)
                .overlay { mitte(prozent) }
                .widgetAccentable()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(eintrag.urteil.quelle ?? "AI Cockpit")
                .accessibilityValue(Format.percent(prozent))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "hourglass")
            }
            .accessibilityLabel("Noch keine Zahlen")
        }
    }

    private func mitte(_ prozent: Double) -> some View {
        VStack(spacing: -1) {
            Text(Format.percentDigits(prozent))
                .font(.system(size: 19, weight: .semibold))
            Text(kurzesAlter)
                .font(.system(size: 9))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 2)
    }

    private var kurzesAlter: String {
        guard let stand = eintrag.stand else { return "—" }
        let minuten = Int(Date().timeIntervalSince(stand) / 60)
        if minuten < 1 { return "jetzt" }
        if minuten < 60 { return "\(minuten) m" }
        return "\(minuten / 60) h"
    }
}

/// Ecke — Ringsegment aussen, Zahl innen.
struct EckAnsicht: View {
    let eintrag: UhrEintrag

    var body: some View {
        if let prozent = eintrag.urteil.prozent {
            Text(Format.percentDigits(prozent))
                .font(.title3)
                .widgetLabel {
                    Gauge(value: min(max(prozent / 100, 0), 1)) {
                        Text(eintrag.urteil.fensterKurz ?? eintrag.urteil.quelle ?? "")
                    }
                    .tint(farbe)
                }
                .widgetAccentable()
        } else {
            Image(systemName: "hourglass")
        }
    }

    private var farbe: Color {
        // Die Ecke hat keine Umgebung, aus der sich ein Farbschema ableiten
        // liesse — sie wird ohnehin fast immer getönt gezeichnet. Die dunkle
        // Palette ist hier die richtige Vorgabe.
        eintrag.urteil.stufe.color(in: Theme.dark,
                                   accent: Theme.dark.color(for: eintrag.urteil.anbieter))
    }
}

/// Rechteckig — drei Zeilen: wer, wie voll, wie alt.
struct RechteckigeUhrAnsicht: View {
    let eintrag: UhrEintrag
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let palette = Theme.palette(schema)
        let urteil = eintrag.urteil
        let farbe = urteil.stufe.color(in: palette, accent: palette.color(for: urteil.anbieter))

        VStack(alignment: .leading, spacing: 1) {
            Text(urteil.lage.satz)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let prozent = urteil.prozent {
                HStack(spacing: 4) {
                    if let symbol = urteil.stufe.symbol {
                        Image(systemName: symbol).widgetAccentedRenderingMode(.fullColor)
                    }
                    Text(beschriftung).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 2)
                    Text(Format.percent(prozent)).monospacedDigit().fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(farbe)
            }

            if let stand = eintrag.stand {
                Text(Theme.ago(stand)).font(.caption2).foregroundStyle(palette.faint)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Auf 160 Punkten steht neben dem Namen noch der Prozentwert. Deshalb
    /// hier die Kurzform des Fensters («1W» statt «7 Tage») — sie kommt aus der
    /// Dauer und ist in beiden Sprachen dieselbe.
    private var beschriftung: String {
        let urteil = eintrag.urteil
        guard let quelle = urteil.quelle else { return "" }
        guard let fenster = urteil.fensterKurz ?? urteil.fenster else { return quelle }
        return "\(quelle) · \(fenster)"
    }
}

/// Einzeilig — über der Uhrzeit. Hier passt genau ein Gedanke hin.
struct EinzeiligeAnsicht: View {
    let eintrag: UhrEintrag

    var body: some View {
        if let prozent = eintrag.urteil.prozent {
            Label {
                Text("\(eintrag.urteil.quelle ?? "AI Cockpit") \(Format.percent(prozent))")
            } icon: {
                Image(systemName: eintrag.urteil.stufe.symbol ?? "circle.dashed")
            }
        } else {
            Text("AI Cockpit")
        }
    }
}

#if DEBUG
/// Die vier Zuschnitte nebeneinander, in echter Grösse — nur für den Blick am
/// Simulator. Eine Komplikation auf ein Zifferblatt zu legen, lässt sich von
/// aussen nicht steuern; ohne diesen Umweg bliebe «sieht es richtig aus?» bis
/// zum ersten Käufer offen.
struct KomplikationsSchau: View {
    let eintrag: UhrEintrag

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                RechteckigeUhrAnsicht(eintrag: eintrag).frame(width: 150, height: 45)
                EinzeiligeAnsicht(eintrag: eintrag).frame(width: 150, height: 20)
                RundeUhrAnsicht(eintrag: eintrag).frame(width: 58, height: 58)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
#endif

import SwiftUI

// Der oberste Bildschirm: ein Satz, dann die Zahl, die ihn belegt.
//
// Die Reihenfolge ist die ganze Entscheidung. Eine Liste von Prozentwerten
// verlangt, die eigenen Schwellen im Kopf zu haben; auf einem Handgelenk ist
// das eine Zumutung. Der Satz nimmt sie ab — und die Zeile darunter macht ihn
// überprüfbar, damit niemand ihm glauben muss.

struct AntwortAnsicht: View {
    @Environment(UhrBruecke.self) private var brücke
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let palette = Theme.palette(schema)
        let urteil = brücke.urteil

        VStack(alignment: .leading, spacing: 8) {
                Text(urteil.lage.satz)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                    .foregroundStyle(palette.primary)

                if let prozent = urteil.prozent {
                    massgebendeZeile(urteil, prozent: prozent, palette: palette)
                }

                if urteil.lage == .keineZahlen {
                    Text("Auf dem iPhone einrichten")
                        .font(.footnote)
                        .foregroundStyle(palette.secondary)
                }

            if let stand = brücke.stand {
                HStack(spacing: 4) {
                    // Ein durchgestrichenes Funkzeichen statt einer
                    // Fehlermeldung: Dass gerade nichts durchkommt, ändert
                    // nichts an der Zahl von vorhin — es ändert nur, wie sehr
                    // man ihr trauen soll.
                    if brücke.stumm {
                        Image(systemName: "iphone.slash").font(.caption2)
                    }
                    Text(Theme.ago(stand))
                        .font(.caption2)
                }
                .foregroundStyle(palette.faint)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func massgebendeZeile(_ urteil: Urteil,
                                  prozent: Double,
                                  palette: Theme.Palette) -> some View {
        let farbe = urteil.stufe.color(in: palette, accent: palette.color(for: urteil.anbieter))

        // Der Balken trägt dieselbe Aussage wie der Satz, nur als Länge. Auf
        // einem gedimmten Always-On-Bildschirm ist das die Fassung, die
        // überlebt — Farbe allein tut es dort nicht.
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.secondary.opacity(0.22))
                Capsule().fill(farbe)
                    .frame(width: proxy.size.width * min(max(prozent / 100, 0), 1))
            }
        }
        .frame(height: 5)

        // Die Kopfzeile trägt **wer** und **wie voll** — mehr passt auf 40
        // Millimeter nicht nebeneinander, ohne dass etwas abschneidet. Ein
        // abgeschnittenes «7 d…» sagt weniger als gar nichts und sieht dabei
        // nach einem Fehler aus.
        HStack(spacing: 5) {
            if let quelle = urteil.quelle {
                AnbieterZeichen(name: quelle, anbieter: urteil.anbieter, groesse: 15)
                Text(quelle)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(palette.secondary)
            }
            Spacer(minLength: 4)
            if let symbol = urteil.stufe.symbol {
                Image(systemName: symbol).font(.caption2).foregroundStyle(farbe)
            }
            Text(Format.percent(prozent))
                .font(.caption)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(farbe)
        }

        // Welches Fenster und wann es zurückkommt, in einer Zeile darunter.
        // Die beiden gehören zusammen: «7 Tage» allein ist eine Beschriftung,
        // «7 Tage, zurück Dienstag 14:20» ist eine Auskunft.
        if urteil.fenster != nil || urteil.zuruecksetzung != nil {
            Text(nebenzeile(urteil))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(palette.faint)
        }
    }

    private func nebenzeile(_ urteil: Urteil) -> String {
        var teile: [String] = []
        if let fenster = urteil.fenster { teile.append(fenster) }
        if let zurueck = urteil.zuruecksetzung {
            teile.append(String(localized: "zurück \(Theme.absolute(zurueck))"))
        }
        return teile.joined(separator: " · ")
    }
}

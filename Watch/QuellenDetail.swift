import SwiftUI

// Eine Quelle in voller Breite — der dritte Bildschirm.
//
// Hier steht der Ring aus der Mac-Menüleiste so gross, wie das Handgelenk es
// zulässt. Auf Armlänge ist das die Darstellung, die man ohne Zielen liest;
// als Startbildschirm wäre sie falsch gewesen, weil man vier Kronendrehungen
// bräuchte, um alles zu sehen.

struct QuellenDetail: View {
    let quelle: WidgetZustand.Quelle
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let palette = Theme.palette(schema)

        Group {
            if quelle.fenster.isEmpty {
                // Geldkarten führen kein Kontingent. Was sie haben, ist die
                // Zeile, die auch die eingeklappte Karte auf dem iPhone zeigt —
                // an zwei Stellen verschieden zu formulieren hiesse, zwei
                // Fassungen zu pflegen.
                VStack(spacing: 8) {
                    Text(quelle.wert)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.primary)
                    Text(Theme.ago(quelle.stand))
                        .font(.caption2)
                        .foregroundStyle(palette.faint)
                }
                .frame(maxWidth: .infinity)
            } else {
                // **Ein Fenster je Seite, geblättert mit der Krone.**
                // Untereinander gescrollt schnitt der Bildschirm den zweiten
                // Ring mitten durch die Zahl — auf einem Handgelenk sieht das
                // nicht nach «da kommt noch etwas» aus, sondern nach einem
                // Zeichenfehler. Geblättert steht jede Seite ganz da, und die
                // Punkte am Rand sagen, wie viele es sind.
                TabView {
                    ForEach(Array(quelle.fenster.enumerated()), id: \.offset) { _, fenster in
                        fensterBlock(fenster, palette: palette)
                    }
                }
                .tabViewStyle(.verticalPage)
            }
        }
        .navigationTitle(quelle.name)
        .containerBackground(palette.background, for: .navigation)
    }

    private func fensterBlock(_ fenster: WidgetZustand.Fenster,
                              palette: Theme.Palette) -> some View {
        VStack(spacing: 6) {
            UsageRing(percent: fenster.prozent,
                      provider: quelle.alsAnbieter,
                      label: .percent,
                      accessibilityTitle: "\(quelle.name) \(fenster.name)")
                .frame(width: 96, height: 96)

            Text(fenster.name)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(palette.secondary)

            if let zurueck = fenster.zuruecksetzung {
                Text("zurück \(Theme.absolute(zurueck))")
                    .font(.caption2)
                    .foregroundStyle(palette.faint)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

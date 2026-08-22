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

        ScrollView {
            VStack(spacing: 10) {
                if quelle.fenster.isEmpty {
                    // Geldkarten führen kein Kontingent. Was sie haben, ist die
                    // Zeile, die auch die eingeklappte Karte auf dem iPhone
                    // zeigt — an zwei Stellen verschieden zu formulieren hiesse,
                    // zwei Fassungen zu pflegen.
                    Text(quelle.wert)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.primary)
                        .padding(.top, 6)
                } else {
                    ForEach(Array(quelle.fenster.enumerated()), id: \.offset) { _, fenster in
                        fensterBlock(fenster, palette: palette)
                    }
                }

                Text(Theme.ago(quelle.stand))
                    .font(.caption2)
                    .foregroundStyle(palette.faint)
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(quelle.name)
        .containerBackground(palette.background, for: .navigation)
    }

    private func fensterBlock(_ fenster: WidgetZustand.Fenster,
                              palette: Theme.Palette) -> some View {
        VStack(spacing: 2) {
            UsageRing(percent: fenster.prozent,
                      provider: quelle.alsAnbieter,
                      label: .percent,
                      accessibilityTitle: "\(quelle.name) \(fenster.name)")
                .frame(width: 84, height: 84)

            Text(fenster.name)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(palette.secondary)

            if let zurueck = fenster.zuruecksetzung {
                Text("zurück \(Theme.absolute(zurueck))")
                    .font(.caption2)
                    .foregroundStyle(palette.faint)
            }
        }
        .padding(.bottom, 4)
    }
}

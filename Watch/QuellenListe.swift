import SwiftUI

// Die Quellen, eine Zeile je Stück — der zweite Bildschirm.
//
// Er steht **unter** der Antwort und nicht neben ihr. Wer die Krone dreht,
// hat den Satz schon gelesen und will jetzt wissen, wie es sich verteilt.
// Zwei gleichrangige Reiter hätten daraus eine Wahl gemacht, die niemand
// treffen will, während er den Arm hebt.

struct QuellenListe: View {
    let quellen: [WidgetZustand.Quelle]
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let palette = Theme.palette(schema)
        VStack(spacing: 6) {
            ForEach(Array(quellen.enumerated()), id: \.offset) { _, quelle in
                NavigationLink {
                    QuellenDetail(quelle: quelle)
                } label: {
                    QuellenZeile(quelle: quelle, palette: palette)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct QuellenZeile: View {
    let quelle: WidgetZustand.Quelle
    let palette: Theme.Palette

    var body: some View {
        // Der drängendste Wert der Quelle, nicht der erste: Ein
        // Fünfstundenfenster bei 12 % neben einem Wochenfenster bei 96 % —
        // welches davon in die Zeile gehört, ist keine Frage.
        let prozent = quelle.fenster.map(\.prozent).filter(\.isFinite).max() ?? quelle.prozent
        let stufe = prozent.map { LimitThresholds.standard.level($0) } ?? .normal
        let farbe = stufe.color(in: palette, accent: palette.color(for: quelle.alsAnbieter))

        VStack(spacing: 3) {
            HStack(spacing: 6) {
                AnbieterZeichen(name: quelle.name, anbieter: quelle.alsAnbieter, groesse: 18)
                Text(quelle.name)
                    .font(.footnote)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(palette.primary)
                Spacer(minLength: 2)
                if let symbol = stufe.symbol {
                    Image(systemName: symbol).font(.caption2).foregroundStyle(farbe)
                }
                Text(prozent.map(Format.percent) ?? quelle.kurz)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(prozent == nil ? palette.secondary : farbe)
            }

            // Kein Balken bei den Geldkarten. Ein Balken ohne Obergrenze zeigt
            // eine Auslastung an, die es nicht gibt — und wäre damit die
            // erfundene Zahl, die `WidgetZustand` überall vermeidet.
            if let prozent {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.secondary.opacity(0.22))
                        Capsule().fill(farbe)
                            .frame(width: proxy.size.width * min(max(prozent / 100, 0), 1))
                    }
                }
                .frame(height: 3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

// Die zwei sichtbaren Teile des Demomodus: der Weg hinein und das Band, das
// sagt, dass man drin ist.
//
// Beide sind offen und beschriftet. Kein Geheimcode, keine versteckte Geste,
// kein siebenmal auf die Versionsnummer tippen — so etwas ist im App Store
// nicht bloss unhöflich, sondern selbst ein Ablehnungsgrund (2.3.1: verborgene
// Funktionen). Und ein Nutzer, der nicht merkt, dass er Beispielzahlen
// anschaut, ist das eigentliche Problem, das dieses Band löst: Er hielte 63 %
// für seinen Verbrauch.

// MARK: - Das Band

/// Steht über der Kartenliste, solange die Demo läuft — und verschwindet von
/// selbst, sobald sie aus ist.
///
/// Dass es sich selbst ein- und ausblendet, ist Absicht: Der Aufrufer soll
/// keine Bedingung schreiben müssen, die er beim nächsten Umbau vergisst. Wer
/// es einhängt, hängt es einmal ein.
struct DemoBand: View {

    /// Wird nach dem Verlassen gerufen — der Aufrufer soll dann die echten
    /// Daten holen. Das Band tut das nicht selbst: Es weiss nichts von
    /// `Cockpit` und soll auch nichts davon wissen.
    var beimVerlassen: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if DemoModus.geteilt.laeuft {
            inhalt(Theme.palette(scheme))
        }
    }

    private func inhalt(_ palette: Theme.Palette) -> some View {
        // Bei sehr grosser Schrift untereinander: Nebeneinander bliebe dem Text
        // neben dem Knopf sonst eine Spalte von zwei Zentimetern.
        let anordnung = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))

        return anordnung {
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Demodaten")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.primary)
                    Text("Beispielzahlen — keine echten Konten.")
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                // Zeichen **und** Text. Im eingetönten Widget wie bei
                // Farbenblindheit trägt die Farbe hier nichts allein.
                Image(systemName: "theatermasks.fill")
                    .foregroundStyle(palette.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                DemoModus.geteilt.beende()
                beimVerlassen()
            } label: {
                Text("Demo verlassen")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .accessibilityHint(Text("Zeigt wieder die Zahlen der eigenen Konten."))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(palette.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(palette.cardBorder).frame(height: 0.5)
        }
    }
}

// MARK: - Der Weg hinein

/// Der Knopf «Demo ansehen» für die Anmeldeseite.
///
/// Er schliesst die Seite gleich mit: Wer die Demo anschauen will, will nicht
/// anschliessend noch eine Anmeldemaske wegräumen, die er gerade nicht
/// beantwortet hat.
struct DemoStarterKnopf: View {
    @Environment(\.dismiss) private var schliesse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                DemoModus.geteilt.starte()
                schliesse()
            } label: {
                Text("Demo ansehen").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Text("Zeigt die App mit Beispieldaten — ohne Anmeldung und ohne Schlüssel. Verlassen lässt sie sich jederzeit über das Band am oberen Rand.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

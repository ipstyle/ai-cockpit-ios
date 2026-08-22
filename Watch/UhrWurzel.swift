import SwiftUI

// Die drei Ebenen der Uhr-Fassung, in einer Rolle.
//
// Antwort, Liste und Detail sitzen absichtlich in **einem** Bildlauf und nicht
// in Reitern: Die Krone ist die natürliche Bewegung am Handgelenk, und was
// weiter unten steht, ist auch weiter hinten in der Frage. Eine Reiterleiste
// wäre eine Wahl, die niemand treffen will, während er den Arm hebt.
//
// Was hier **nicht** steht, ist ebenso Absicht: keine Einstellungen, keine
// Anmeldung, kein Konto. Eingerichtet wird auf dem iPhone — die Uhr hat weder
// Tastatur noch Anmeldefenster, und die Zugangsdaten haben hier nichts
// verloren.

struct UhrWurzel: View {
    @Environment(UhrBruecke.self) private var brücke
    @Environment(\.colorScheme) private var schema

    var body: some View {
        let palette = Theme.palette(schema)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    AntwortAnsicht()

                    if let quellen = brücke.zustand?.quellen, !quellen.isEmpty {
                        Divider()
                        QuellenListe(quellen: quellen)
                    }

                    Button {
                        Task { await brücke.aktualisiere() }
                    } label: {
                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(brücke.laeuft)
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .containerBackground(palette.background, for: .navigation)
            // **Kein Titel auf dem ersten Bildschirm.** Der grosse Name kostet
            // auf einer 40-Millimeter-Uhr rund vierzig von 197 Punkten — ein
            // Fünftel der Fläche für eine Auskunft, die schon auf dem
            // Zifferblatt und im Dock steht. Die Unterseiten tragen ihren
            // Titel, weil er dort sagt, wo man ist.
        }
        // Beim Erscheinen einmal nachfragen — wer die App öffnet, will die
        // Zahl von jetzt und nicht die vom letzten Griff zum Telefon. Bleibt
        // die Antwort aus, steht weiterhin da, was daliegt.
        .task { await brücke.aktualisiere() }
    }
}

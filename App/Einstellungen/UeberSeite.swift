import SwiftUI
import AgentDeckCore

// Über — Fassung, Datenschutz, Abgrenzung, und der eine Knopf, der alles
// wegräumt.
//
// Die Abgrenzung steht hier nicht aus Höflichkeit: AI Cockpit zeigt Zahlen von
// Anthropic, OpenAI und Moonshot und trägt deren Namen auf sechs Karten. Wer
// das sieht, könnte annehmen, die App komme von dort. Sie kommt nicht von dort,
// und das gehört an die Stelle, an der man nachsieht, wem ein Programm gehört.

struct UeberSeite: View {
    let einstellungen: Einstellungen
    let cockpit: Cockpit

    @State private var fragtNachLoeschen = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)

        EinstellungsForm(titel: String(localized: "Über")) {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Cockpit")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primary)
                    Text("developed by ipstyle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Version \(AppKennung.version)")
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section {
                Text("Diese App spricht mit keinem Server, der ihr gehört: Es gibt keinen. Sie fragt ausschliesslich die Dienste ab, für die du selbst einen Zugang hinterlegt hast, und zeigt deren Antwort an. Es gibt kein Konto bei AI Cockpit, keine Anmeldung bei uns, keine Analyse, keine Werbekennung und keine Weitergabe an Dritte.")
                Text("Zugangsdaten liegen im Schlüsselbund dieses Geräts. Alles Übrige — Darstellung, Schwellen, welche Karten eingeklappt sind — steht in den Benutzervorgaben der App. Inhalte deiner Unterhaltungen liest die App nie; sie holt Kontingente und Beträge, mehr nicht.")
            } header: {
                Text("Datenschutz")
            }

            Section {
                Text("AI Cockpit ist ein eigenständiges Werkzeug und **nicht** mit Anthropic, OpenAI oder Moonshot AI verbunden — weder betrieben noch beauftragt noch gebilligt. Die Namen stehen auf den Karten, weil dort deren Zahlen stehen.")
            } header: {
                Text("Abgrenzung")
            }

            Section {
                Button(role: .destructive) {
                    fragtNachLoeschen = true
                } label: {
                    Label(String(localized: "Abmelden und alle lokalen Daten löschen"),
                          systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        // `role: .destructive` färbt nur die Schrift; das
                        // Zeichen bliebe in der Akzentfarbe der Seite stehen.
                        // Ein blauer Papierkorb neben rotem Text sagt zwei
                        // verschiedene Dinge über denselben Knopf.
                        .foregroundStyle(.red)
                }
                .confirmationDialog(Text("Wirklich alles löschen?"),
                                    isPresented: $fragtNachLoeschen,
                                    titleVisibility: .visible) {
                    Button("Abmelden und alles löschen", role: .destructive) { raeumeAuf() }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Entfernt die Claude-Anmeldung und alle drei API-Schlüssel aus dem Schlüsselbund, setzt Darstellung und Schwellen zurück und löscht den Stand, den das Widget zeigt. Bei den Diensten selbst ändert sich nichts — die Schlüssel bleiben dort gültig und müssten dort widerrufen werden.")
                }
            } footer: {
                Text("Danach ist die App wieder so, wie sie beim ersten Start war. Rückgängig machen lässt sich das nicht.")
            }
        }
    }

    /// Räumt auf — und sorgt dafür, dass die Karten das sofort zeigen.
    ///
    /// Ohne den zweiten Teil bliebe die Liste mit Zahlen stehen, deren Grundlage
    /// gerade gelöscht wurde. Das wäre die unangenehmste Art, an dieser Stelle
    /// Vertrauen zu verlieren: Man drückt «alles löschen» und sieht weiter alles.
    private func raeumeAuf() {
        einstellungen.loescheAlles()
        cockpit.eingeklappteKarten = ""
        Task { await cockpit.aktualisiere() }
    }
}

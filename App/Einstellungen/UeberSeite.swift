import SwiftUI
import AgentDeckCore

// Über — Fassung, Datenschutz, Abgrenzung, Verweise.
//
// Die ausführliche Auskunft über Netzziele, Ablage und Prüfstand steht auf der
// eigenen Seite «Datenschutz und Sicherheit»; hier bleibt die Kurzfassung mit
// dem Weg dorthin.
//
// Der Knopf zum Zurücksetzen stand einmal hier unten. Er steht jetzt direkt in
// der Einstellungsliste: Wer die App zurücksetzen will, sucht das unter
// «Einstellungen» und nicht unter «Über» — und hat ihn dort prompt nicht
// gefunden.
//
// Die Abgrenzung steht hier nicht aus Höflichkeit: AI Cockpit zeigt Zahlen von
// Anthropic, OpenAI und Moonshot und trägt deren Namen auf fünf Karten. Wer
// das sieht, könnte annehmen, die App komme von dort. Sie kommt nicht von dort,
// und das gehört an die Stelle, an der man nachsieht, wem ein Programm gehört.

struct UeberSeite: View {
    let einstellungen: Einstellungen

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)

        EinstellungsForm(titel: String(localized: "Über")) {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Cockpit")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primary)
                    Text("Developed by Albert Frick / ipstyle")
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

                // Der Verweis statt der langen Fassung: Die vollständige Liste
                // der Netzziele gehört auf eine eigene Seite, sonst schiebt sie
                // hier den Löschknopf so weit nach unten, dass ihn niemand mehr
                // findet. Beides ist wichtig, aber nicht gleichzeitig.
                NavigationLink {
                    DatenschutzSeite()
                } label: {
                    Label(String(localized: "Alle Netzwerkziele, Ablage und Prüfstand"),
                          systemImage: "lock.shield")
                        .frame(minHeight: 44)
                }
            } header: {
                Text("Datenschutz")
            }

            Section {
                Text("AI Cockpit ist ein eigenständiges Werkzeug und **nicht** mit Anthropic, OpenAI oder Moonshot AI verbunden — weder betrieben noch beauftragt noch gebilligt. Die Namen stehen auf den Karten, weil dort deren Zahlen stehen.")
            } header: {
                Text("Abgrenzung")
            }

            // Verweise öffnen im Browser des Geräts, nicht in einem eingebauten
            // Fenster: Wer eine Seite über Datenschutz aufruft, soll sie in
            // seinem eigenen Browser sehen, mit dessen Einstellungen — und
            // nicht in einer Ansicht, die diese App kontrolliert.
            Section {
                Link(destination: URL(string: "https://aicockpit.info/de/")!) {
                    verweis(titel: String(localized: "Projektseite"),
                            adresse: "aicockpit.info",
                            symbol: "safari")
                }
                Link(destination: URL(string: "https://apps.apple.com/app/id6802014255")!) {
                    verweis(titel: String(localized: "AI Cockpit für macOS"),
                            adresse: String(localized: "Mac App Store"),
                            symbol: "macbook")
                }
            } header: {
                Text("Verweise")
            } footer: {
                // Steht da, weil es stimmt und sonst enttäuscht: Auf der
                // Projektseite ist von dieser Fassung heute nichts zu finden.
                Text("Die Projektseite beschreibt zurzeit die Mac-Fassung; ein Teil für diese App entsteht noch. Die macOS-Fassung ist kostenpflichtig und teilt sich mit dieser App den Quellcode, wird aber getrennt gezählt.")
            }

        }
    }

    /// Eine Verweiszeile: Name links, Ziel rechts, Zeichen davor.
    ///
    /// Das Ziel steht dabei, weil ein Verweis ohne Ziel eine Zumutung ist —
    /// man soll vor dem Tippen sehen, wo man landet, und nicht erst danach.
    private func verweis(titel: String, adresse: String, symbol: String) -> some View {
        Label {
            HStack(alignment: .firstTextBaseline) {
                Text(titel)
                Spacer(minLength: 8)
                Text(adresse)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.up.forward.square")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

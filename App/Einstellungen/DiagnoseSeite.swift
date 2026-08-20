import SwiftUI
import UIKit
import AgentDeckCore

// Die Seite, die im Fehlerfall zwei Tage spart.
//
// Sie beantwortet die drei Fragen, die man sonst nur durch Ausprobieren klärt:
//
// 1. **Ist die App Group erreichbar?** Steht ihre Kennung nicht buchstabengleich
//    in beiden Berechtigungsdateien, gibt `UserDefaults(suiteName:)` still `nil`
//    zurück — kein Fehler, kein Absturz, nur ein Widget, das leer bleibt.
// 2. **Was sagt der Schlüsselbund zu jedem Eintrag?** «Fehlt» und «verweigert»
//    sehen von aussen gleich aus und haben nichts miteinander zu tun: Das eine
//    behebt der Nutzer in einer Minute, das andere kann er gar nicht beheben.
// 3. **Wie alt sind die Zahlen?** Eine Karte mit einem Wert von vor drei
//    Stunden ist etwas anderes als eine Karte, die nie etwas bekommen hat.
//
// Und sie beantwortet sie **zum Weitergeben**: ein Knopf, ein Text in der
// Zwischenablage. Ohne den tippt jemand einen Statuscode ab und vertippt sich.

struct DiagnoseSeite: View {
    let einstellungen: Einstellungen
    let cockpit: Cockpit

    @State private var kopiert = false
    @Environment(\.colorScheme) private var scheme

    private var text: String {
        einstellungen.diagnoseText(zuletztAktualisiert: cockpit.zuletztAktualisiert)
    }

    var body: some View {
        let palette = Theme.palette(scheme)

        EinstellungsForm(titel: String(localized: "Diagnose")) {
            Section {
                // Fester Zeichenabstand, damit die Spalten stehen — der Text
                // ist zum Lesen **und** zum Verschicken gedacht.
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } footer: {
                Text("Der Text enthält keine Schlüssel und keine Token — nur Zustände und die letzten vier Zeichen, die auch oben stehen. Er lässt sich bedenkenlos weitergeben.")
            }

            Section {
                Button {
                    kopiere()
                } label: {
                    Label(kopiert ? String(localized: "In die Zwischenablage gelegt")
                                  : String(localized: "In die Zwischenablage"),
                          systemImage: kopiert ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }

                Button {
                    Task { await cockpit.aktualisiere() }
                } label: {
                    Label(String(localized: "Jetzt neu abfragen"), systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(cockpit.wirdAktualisiert)
            }
        }
        // Der Schlüsselbund kann sich geändert haben, während diese Seite nicht
        // zu sehen war — etwa weil auf der Kontenseite ein Schlüssel dazukam.
        .onAppear { einstellungen.aktualisiereStand() }
    }

    private func kopiere() {
        UIPasteboard.general.string = text
        kopiert = true
        // Die Bestätigung geht von selbst wieder weg. Ein Knopf, der dauerhaft
        // «kopiert» heisst, sagt beim zweiten Blick nicht mehr, ob das eben war
        // oder vorhin.
        Task {
            try? await Task.sleep(for: .seconds(2))
            kopiert = false
        }
    }
}

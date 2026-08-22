import SwiftUI

// Der Einstieg der Uhr-Fassung.
//
// **Die Uhr zeigt, sie holt nicht.** Sie hält kein einziges Geheimnis: Für
// Claude und ChatGPT gilt, dass ein Refresh-Token an genau einer Stelle
// eingelöst werden darf (`Cockpit.swift`, `WidgetSchluesselbund.swift`). Das
// Widget hält sich schon daran; eine Uhr als dritte Instanz im Rennen würde
// irgendwann verlieren, eine 401 für ein abgelaufenes Recht halten und den
// Nutzer abmelden. Was hier steht, kommt deshalb ausnahmslos vom iPhone.

@main
struct UhrApp: App {
    @State private var brücke = UhrBruecke()

    var body: some Scene {
        WindowGroup {
            UhrWurzel()
                .environment(brücke)
        }
    }
}

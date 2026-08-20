import SwiftUI
import AgentDeckCore

/// Einstiegspunkt der iPhone- und iPad-Fassung.
@main
struct AICockpitMobileApp: App {
    /// Der Zustand lebt hier und nicht in der Ansicht: Die Kartenliste wird bei
    /// jeder Drehung und jedem Schriftgradwechsel neu gebaut, die Zahlen darin
    /// sollen das nicht mitmachen.
    @State private var cockpit = Cockpit()

    var body: some Scene {
        WindowGroup { WurzelAnsicht(cockpit: cockpit) }
    }
}

/// Die Kartenliste, verbunden mit dem Zustand.
///
/// Sie hält nur zusammen, was `CardsView` an Rückrufen verlangt — entschieden
/// wird hier nichts: Was ein Knopf auslöst, sagt `Cockpit.aktion(fuer:)`, damit
/// die Antwort an derselben Stelle steht wie der Zustand, aus dem sie folgt.
struct WurzelAnsicht: View {
    @Bindable var cockpit: Cockpit

    @State private var zeigtAnmeldung = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        CardsView(cards: cockpit.karten,
                  lastUpdated: cockpit.zuletztAktualisiert,
                  isRefreshing: cockpit.wirdAktualisiert,
                  thresholds: cockpit.schwellen,
                  collapsedCards: $cockpit.eingeklappteKarten,
                  refresh: { await cockpit.aktualisiere() },
                  // Das Zahnrad öffnet heute das Einzige, was sich einstellen
                  // lässt: die Anmeldung. Die drei API-Schlüssel brauchen ein
                  // eigenes Fenster — solange es das nicht gibt, laden ihre
                  // Karten im Text ein statt mit einem Knopf ins Leere.
                  openSettings: { zeigtAnmeldung = true },
                  cardAction: fuehreAus)
            .task { await cockpit.aktualisiere() }
            .sheet(isPresented: $zeigtAnmeldung) {
                // Nach dem Zumachen gleich nachfassen: Wer sich eben angemeldet
                // hat, will die Zahlen sehen und nicht noch einen Knopf suchen.
                Task { await cockpit.aktualisiere() }
            } content: {
                AnmeldeAnsicht()
            }
            .onChange(of: phase) { _, neu in
                // Zurück aus dem Hintergrund. Die Schwelle verhindert, dass
                // zehn kurze Blicke am Tag zehn volle Kostenläufe auslösen.
                guard neu == .active else { return }
                Task { await cockpit.aktualisiereFallsAelterAls(120) }
            }
    }

    private func fuehreAus(_ karte: CardLayout.Card) {
        switch cockpit.aktion(fuer: karte) {
        case .anmelden:
            zeigtAnmeldung = true
        case .erneutVersuchen(let quelle):
            Task { await cockpit.versucheErneut(quelle) }
        case nil:
            break
        }
    }
}

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

    @State private var zeigtEinstellungen = false
    /// Getrennt vom Einstellungs-Sheet: Wer auf der Claude-Karte «Anmelden»
    /// tippt, will sich anmelden — nicht erst durch die Einstellungen suchen.
    @State private var zeigtAnmeldung = false
    @State private var zeigtChatGPTAnmeldung = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        CardsView(cards: cockpit.karten,
                  laufend: cockpit.laufendeNamen,
                  thresholds: cockpit.schwellen,
                  collapsedCards: $cockpit.eingeklappteKarten,
                  // Der Knopf und das Herunterziehen holen **alles**, auch
                  // die Kostenkarten, die sonst eine Viertelstunde Ruhe haben.
                  refresh: { await cockpit.aktualisiere(erzwingen: true) },
                  openSettings: { zeigtEinstellungen = true },
                  cardAction: fuehreAus)
            .task { await cockpit.aktualisiere() }
            // Das Erscheinungsbild gehört an die Wurzel, nicht in die
            // Einstellungen: Dort gesetzt, färbte es nur sich selbst.
            .preferredColorScheme(cockpit.erscheinungsbild)
            .safeAreaInset(edge: .top) {
                // Sagt, dass die Zahlen erfunden sind, und bietet den Ausweg.
                // Blendet sich selbst aus, wenn die Demo nicht läuft. Ein
                // Prüfer, der nicht merkt, dass er Demodaten sieht, ist
                // genauso ein Problem wie gar keine Daten.
                DemoBand { Task { await cockpit.aktualisiere() } }
            }
            .sheet(isPresented: $zeigtEinstellungen) {
                // Nach dem Zumachen gleich nachfassen: Wer eben einen Schlüssel
                // eingetragen hat, will die Zahlen sehen und nicht noch einen
                // Knopf suchen.
                Task { await cockpit.aktualisiere() }
            } content: {
                EinstellungenAnsicht(cockpit: cockpit)
            }
            .sheet(isPresented: $zeigtAnmeldung) {
                Task { await cockpit.aktualisiere() }
            } content: {
                AnmeldeAnsicht()
            }
            .sheet(isPresented: $zeigtChatGPTAnmeldung) {
                Task { await cockpit.aktualisiere() }
            } content: {
                CodexAnmeldeAnsicht()
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
        case .beiChatGPTAnmelden:
            zeigtChatGPTAnmeldung = true
        case .einrichten:
            zeigtEinstellungen = true
        case .erneutVersuchen(let quelle):
            Task { await cockpit.versucheErneut(quelle) }
        case nil:
            break
        }
    }
}

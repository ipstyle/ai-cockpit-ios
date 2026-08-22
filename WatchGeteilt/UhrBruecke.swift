import Foundation
import Observation
import WatchConnectivity
import WidgetKit

// Die Brücke zum iPhone — die Uhr-Seite.
//
// **Warum es die App Group hier nicht tut.** App Groups und
// Schlüsselbund-Zugriffsgruppen sind gerätegebunden. Sie verbinden Prozesse auf
// *einem* Gerät: auf dem iPhone die App mit ihrem Widget, auf der Uhr die App
// mit ihrer Komplikation. Über die Kopplung tragen sie nicht — der Container
// auf der Uhr ist ein anderer, und er ist einfach leer. Ohne Fehlermeldung.
// Wer das übersieht, sucht den Fehler tagelang im falschen Stockwerk.
//
// Übertragen wird `WidgetZustand`, unverändert. Das ist kein Zufall: Der Typ
// wurde für genau dieses Problem gebaut — fertige Anzeigewerte statt
// Rohantworten, eine Fassungsnummer, Nachsicht gegenüber älteren Ständen. Er
// löst es nur bisher für einen anderen Prozess auf demselben Gerät. Die
// Komplikation auf der Uhr liest ihn deshalb mit demselben `lies()` wie das
// Widget auf dem iPhone.

@MainActor
@Observable
final class UhrBruecke: NSObject {

    private(set) var zustand: WidgetZustand?
    private(set) var laeuft = false
    /// Der letzte Versuch ging ins Leere — kein iPhone in Reichweite oder keine
    /// Antwort innerhalb der Frist. Bewusst **kein** Fehlertext: Die Zahlen von
    /// vorhin stehen weiter da, und ihr Alter sagt bereits alles Nötige.
    private(set) var stumm = false

    var urteil: Urteil { Urteil.aus(zustand) }

    var stand: Date? { zustand?.erhoben }

    override init() {
        super.init()
        // Zuerst das, was schon daliegt — die Uhr soll nicht auf ein Funkgerät
        // warten, bevor sie etwas zeigt.
        zustand = WidgetZustand.lies()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Bittet das iPhone um frische Zahlen.
    ///
    /// Zehn Sekunden, dann ist es gut. Länger zu warten hiesse, einen leeren
    /// Bildschirm zu zeigen, wo eine Zahl von vorhin gestanden hätte — und eine
    /// Zahl mit Alter ist mehr wert als eine Sanduhr.
    func aktualisiere() async {
        guard !laeuft else { return }
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            stumm = true
            return
        }
        laeuft = true
        defer { laeuft = false }

        let antwort = await Frist.hoechstens(10) {
            await withCheckedContinuation { fortsetzung in
                WCSession.default.sendMessage([UhrNachricht.bitteAktualisieren: true]) { antwort in
                    fortsetzung.resume(returning: antwort[UhrNachricht.nutzlast] as? Data)
                } errorHandler: { _ in
                    fortsetzung.resume(returning: nil)
                }
            }
        }

        guard let daten = antwort ?? nil else { stumm = true; return }
        uebernimm(daten)
    }

    /// Legt den Stand in der App Group **der Uhr** ab und stösst die
    /// Komplikation an — aber nur, wenn sich etwas geändert hat.
    ///
    /// `WidgetZustand.schreib(nach:)` erledigt beides und kennt die Regel
    /// bereits: Schreiben kostet nichts, Neuladen kommt aus einem knappen
    /// Vorrat. Deshalb hier kein eigener Weg.
    private func uebernimm(_ daten: Data) {
        let dekodierer = JSONDecoder()
        dekodierer.dateDecodingStrategy = .iso8601
        guard let neu = try? dekodierer.decode(WidgetZustand.self, from: daten),
              neu.version <= WidgetZustand.aktuelleVersion
        else { return }

        stumm = false
        zustand = neu
        neu.schreib()
    }
}

// MARK: - WCSessionDelegate

extension UhrBruecke: WCSessionDelegate {

    // Die Rückrufe kommen aus einer fremden Warteschlange. Alles, was den
    // beobachtbaren Zustand anfasst, muss deshalb auf den Hauptakteur — sonst
    // zeichnet SwiftUI aus dem falschen Faden.
    /// **Hier liegt die Falle.** `didReceiveApplicationContext` feuert nur für
    /// einen Kontext, der *nach* der Aktivierung eintrifft. Was das iPhone
    /// geschickt hat, während die Uhr-App nicht lief — also fast immer —, liegt
    /// beim Start bereits in `receivedApplicationContext` und wird sonst nie
    /// gelesen. Die Uhr zeigte damit «Keine Zahlen», obwohl die Zahlen längst
    /// da waren. Am gekoppelten Simulatorpaar gesehen, nicht ausgedacht.
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: (any Error)?) {
        guard state == .activated,
              let daten = session.receivedApplicationContext[UhrNachricht.nutzlast] as? Data
        else { return }
        Task { @MainActor in self.uebernimm(daten) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let daten = context[UhrNachricht.nutzlast] as? Data else { return }
        Task { @MainActor in self.uebernimm(daten) }
    }

    /// Kommt von `transferCurrentComplicationUserInfo` — der Weg, der die Uhr
    /// auch dann weckt, wenn niemand die App geöffnet hat. Genau dafür ist er
    /// da, und genau darum wird er sparsam benutzt: Der Vorrat liegt bei rund
    /// fünfzig am Tag.
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard let daten = userInfo[UhrNachricht.nutzlast] as? Data else { return }
        Task { @MainActor in self.uebernimm(daten) }
    }
}

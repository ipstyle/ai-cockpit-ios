import Foundation
import WatchConnectivity

// Die Brücke zur Uhr — die iPhone-Seite.
//
// **Die Uhr holt nicht, sie bekommt.** Für Claude und ChatGPT gilt, dass ein
// Refresh-Token an genau einer Stelle eingelöst werden darf; das Widget hält
// sich schon daran (`WidgetSchluesselbund.swift`). Eine Uhr als dritte Instanz
// im Rennen verlöre irgendwann, hielte die 401 für ein abgelaufenes Recht und
// meldete den Nutzer ab. Deshalb geht von hier aus **kein Geheimnis** über die
// Kopplung — nur fertige Anzeigewerte.
//
// Zwei Wege, mit verschiedenem Preis:
//
// * `updateApplicationContext` kostet praktisch nichts und ersetzt jedes Mal
//   den vorigen Stand. Der Weg für «immer, wenn sich etwas geändert hat».
// * `transferCurrentComplicationUserInfo` **weckt die Uhr**, auch wenn niemand
//   die App geöffnet hat — und kommt aus einem Vorrat von rund fünfzig am Tag.
//   Der Weg für «die Auskunft ist eine andere geworden».
//
// Die zweite Zeile ist der Grund, warum `Urteil` in `Shared/` liegt: Ob sich
// die Auskunft geändert hat, muss hier nach derselben Regel entschieden werden
// wie drüben angezeigt.

@MainActor
final class UhrVersorgung: NSObject {

    static let geteilt = UhrVersorgung()

    /// Was das iPhone tut, wenn die Uhr um frische Zahlen bittet. Wird beim
    /// Start gesetzt — hier steht keine Abruflogik, sonst hätte diese Klasse
    /// zwei Aufgaben.
    var aufAnfrage: (@MainActor () async -> WidgetZustand?)?

    private var zuletztGeweckt: Date?
    private var zuletztGemeldet: Urteil?
    /// Der letzte Stand, auch wenn er nicht abgeschickt werden konnte.
    ///
    /// **Warum das nötig ist.** `WCSession.activate()` ist asynchron. Beim
    /// Programmstart läuft der erste Abruf längst, während die Sitzung noch
    /// `.notActivated` meldet — der erste Schub fiele damit ersatzlos aus, und
    /// der nächste käme erst beim nächsten Abruf. Im Demomodus, der genau
    /// einmal beim Start schreibt, käme überhaupt keiner: Die Uhr sagte «Keine
    /// Zahlen», während auf dem iPhone fünf Karten standen. Am gekoppelten
    /// Simulatorpaar gesehen, nicht ausgedacht.
    private var wartend: WidgetZustand?

    /// Unter dieser Grenze wird nicht mehr geweckt. Der Rest des Vorrats gehört
    /// dem Fall, der ihn wirklich braucht: ein Fenster, das kippt.
    private static let reserve = 8
    /// Auch bei unveränderter Stufe darf die Zahl nicht beliebig alt werden.
    private static let spaetestensNach: TimeInterval = 30 * 60

    private var sitzung: WCSession? {
        guard WCSession.isSupported() else { return nil }
        return WCSession.default
    }

    /// **Der einzige Weg, auf dem die iPhone-Fassung einen Widget-Zustand
    /// veröffentlicht.**
    ///
    /// Ablegen und Schieben gehören zusammen, und zwar unter einem Namen. Sonst
    /// entsteht genau der Fehler, den niemand bemerkt: Der Demomodus schrieb
    /// seinen Stand direkt (`DemoDaten.widgetZustand().schreib()`), das Widget
    /// zeigte Demozahlen, die Uhr zeigte weiter die von gestern — und nichts
    /// wurde rot. Am Simulator gesehen, nicht ausgedacht.
    static func veroeffentliche(_ zustand: WidgetZustand) {
        zustand.schreib()
        geteilt.schiebe(zustand)
    }

    /// Schiebt, was gerade in der App Group liegt — für die Wege, die den
    /// Zustand roh schreiben statt ihn zu bauen.
    ///
    /// Liegt dort nichts, geht ein **leerer** Stand hinüber und nicht gar
    /// nichts. Der Unterschied ist der ganze Punkt: Nichts zu senden liesse die
    /// Uhr auf ihren alten Zahlen sitzen, und nach dem Verlassen des Demomodus
    /// wären das erfundene.
    static func schiebeAktuellen() {
        geteilt.schiebe(WidgetZustand.lies()
                        ?? WidgetZustand(erhoben: Date(), fenster: [], quellen: []))
    }

    /// Schickt nach, was liegengeblieben ist.
    private func holeNach() {
        guard let zustand = wartend else { return }
        schiebe(zustand)
    }

    func starte() {
        guard let sitzung else { return }
        sitzung.delegate = self
        sitzung.activate()
    }

    /// Schiebt den Stand zur Uhr — wenn es überhaupt eine gibt.
    ///
    /// Die drei Bedingungen sind nicht Zierde: Ohne gekoppelte Uhr wirft
    /// `updateApplicationContext` einen Fehler, und ohne installierte Uhr-App
    /// verpufft alles. Beides bei jedem Abruf zu versuchen, füllt nur das
    /// Protokoll.
    func schiebe(_ zustand: WidgetZustand) {
        wartend = zustand
        guard let sitzung, sitzung.activationState == .activated,
              sitzung.isPaired, sitzung.isWatchAppInstalled
        else { return }
        wartend = nil

        let kodierer = JSONEncoder()
        kodierer.dateEncodingStrategy = .iso8601
        guard let daten = try? kodierer.encode(zustand) else { return }
        let nutzlast: [String: Any] = [UhrNachricht.nutzlast: daten]

        // Immer: Der laufende Stand. Ein Fehler hier ist keiner, der jemanden
        // etwas angeht — beim nächsten Abruf wird es wieder versucht.
        try? sitzung.updateApplicationContext(nutzlast)

        guard sitzung.isComplicationEnabled else { return }
        guard sitzung.remainingComplicationUserInfoTransfers > Self.reserve else { return }

        let urteil = Urteil.aus(zustand)
        let ueberfaellig = zuletztGeweckt.map { Date().timeIntervalSince($0) > Self.spaetestensNach } ?? true
        guard !urteil.sagtDasselbeWie(zuletztGemeldet) || ueberfaellig else { return }

        sitzung.transferCurrentComplicationUserInfo(nutzlast)
        zuletztGeweckt = Date()
        zuletztGemeldet = urteil
    }
}

// MARK: - WCSessionDelegate

extension UhrVersorgung: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: (any Error)?) {
        guard state == .activated else { return }
        Task { @MainActor in self.holeNach() }
    }

    /// Die Uhr wurde gekoppelt, die App dort installiert oder wieder entfernt.
    /// Jedes Mal ändert sich die Antwort auf «lohnt sich das Schieben» — und
    /// beim ersten Ja soll nicht erst der nächste Abruf abgewartet werden.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.holeNach() }
    }

    /// Auf dem iPhone kann die aktive Uhr wechseln. Danach muss die Sitzung neu
    /// aktiviert werden, sonst geht ab hier alles ins Leere — und zwar
    /// stillschweigend.
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Die Uhr bittet um frische Zahlen. Das iPhone wird dafür geweckt — es
    /// muss also zügig antworten und darf nicht auf einen Kostenlauf warten,
    /// der eine Viertelstunde dauert.
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[UhrNachricht.bitteAktualisieren] != nil else {
            replyHandler([:])
            return
        }
        // WatchConnectivity stammt aus Objective-C und gibt den Rückrufblock
        // ohne `Sendable` heraus. Ihn über eine Aufgabengrenze zu reichen, hält
        // Swift 6 deshalb für ein Wettrennen. Es ist keins: Der Block wird
        // **genau einmal** aufgerufen, aus genau dieser Aufgabe. Die Kiste sagt
        // das dem Übersetzer — und zwar so eng gefasst, dass sie nichts anderes
        // durchlässt.
        let rueckruf = NurEinmal(replyHandler)
        Task { @MainActor in
            let zustand = await self.aufAnfrage?() ?? WidgetZustand.lies()
            let kodierer = JSONEncoder()
            kodierer.dateEncodingStrategy = .iso8601
            guard let zustand, let daten = try? kodierer.encode(zustand) else {
                rueckruf.wert([:])
                return
            }
            rueckruf.wert([UhrNachricht.nutzlast: daten])
        }
    }
}

/// Ein Wert, der über eine Aufgabengrenze darf, weil der Aufrufer dafür
/// geradesteht.
///
/// Bewusst `private` und bewusst namenlos allgemein: Wer das anderswo braucht,
/// soll dort begründen, warum es sicher ist, statt hier ein Werkzeug zu finden,
/// mit dem sich jede Warnung wegdrücken lässt.
private struct NurEinmal<Wert>: @unchecked Sendable {
    let wert: Wert
    init(_ wert: Wert) { self.wert = wert }
}

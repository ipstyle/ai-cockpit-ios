import Foundation
import Observation

// Die zwei Schalter — und wo sie liegen.
//
// Sie stehen bewusst **nicht** in `Einstellungen`, obwohl sie dort hingehören
// würden: Diese Ablage hier ist der ganze Zustand, den die Mitteilungen
// brauchen, und der Dienst muss sie auch lesen können, wenn keine
// Einstellungsansicht offen ist. Wer die zwei Eigenschaften später nach
// `Einstellungen` zieht, muss nur die Schlüsselnamen mitnehmen — die Werte
// liegen dann schon richtig.
//
// Schreibweise wie im Bestand: englische Schlüssel in lowerCamelCase, gleich
// wie `warnThreshold`, `criticalThreshold`, `appearanceMode`. `notifyEnabled`
// ist buchstabengleich zur Mac-Fassung und meint dort dasselbe — den Hinweis,
// wenn ein Kontingent eine Schwelle reisst. `notifyWindowReset` gibt es auf dem
// Mac noch nicht; dort ist der Rücksetz-Hinweis an denselben Schalter gehängt.

/// Ob gemeldet werden soll — und was.
@MainActor
@Observable
final class MitteilungenVorgaben {

    /// Die Schlüsselnamen. Öffentlich, weil `Mitteilungen` sie ohne Umweg über
    /// eine Instanz liest: Der Dienst läuft auch dann, wenn niemand die
    /// Einstellungen offen hat.
    enum Schluessel {
        /// Hinweis, wenn ein Fenster die Warn- oder die kritische Schwelle reisst.
        static let beiLimit = "notifyEnabled"
        /// Hinweis, wenn ein Fünf-Stunden-Fenster neu beginnt.
        static let beiNeuemFenster = "notifyWindowReset"

        static let alle = [beiLimit, beiNeuemFenster]
    }

    var beiLimit: Bool {
        didSet { vorgaben.set(beiLimit, forKey: Schluessel.beiLimit) }
    }

    var beiNeuemFenster: Bool {
        didSet { vorgaben.set(beiNeuemFenster, forKey: Schluessel.beiNeuemFenster) }
    }

    /// Wahr, solange keiner der beiden Schalter an ist. Dann gibt es nichts
    /// mehr abzuräumen — und nichts mehr zu planen.
    var allesAus: Bool { !beiLimit && !beiNeuemFenster }

    /// Einer für die ganze App.
    ///
    /// Nicht aus Bequemlichkeit: «Alle Daten löschen» muss die Schalter auch
    /// dann umlegen, wenn die Einstellungsansicht gerade offen ist. Eine
    /// zweite Instanz zeigte danach weiter «an», während in den Vorgaben nichts
    /// mehr steht — und das ist der Zustand, in dem niemand mehr weiss, was
    /// gilt.
    static let geteilt = MitteilungenVorgaben()

    /// Beides aus — für «Alle Daten löschen».
    ///
    /// Erst die Werte, dann räumt der Aufrufer die Schlüssel weg. In dieser
    /// Reihenfolge bleibt nichts stehen: Die Beobachter schreiben beim Zuweisen
    /// zurück, und was danach entfernt wird, ist wirklich weg.
    func setzeZurueck() {
        beiLimit = false
        beiNeuemFenster = false
    }

    private let vorgaben: UserDefaults

    /// **Vorgabe ist aus**, anders als auf dem Mac.
    ///
    /// Nicht aus Zurückhaltung, sondern weil sonst gar nichts käme: Die
    /// Erlaubnis wird erst erfragt, wenn jemand den Schalter umlegt. Stünde er
    /// von Anfang an auf «an», hätte niemand je die Frage beantwortet, und die
    /// App wäre eingeschaltet und stumm zugleich — der schlechteste der drei
    /// möglichen Zustände.
    init(vorgaben: UserDefaults = .standard) {
        self.vorgaben = vorgaben
        beiLimit = vorgaben.bool(forKey: Schluessel.beiLimit)
        beiNeuemFenster = vorgaben.bool(forKey: Schluessel.beiNeuemFenster)
    }

    /// Für den Dienst: der Stand, ohne eine Instanz und ohne Hauptakteur.
    nonisolated static func istAn(_ schluessel: String,
                                  in vorgaben: UserDefaults = .standard) -> Bool {
        vorgaben.bool(forKey: schluessel)
    }
}

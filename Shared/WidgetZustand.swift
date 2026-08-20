import Foundation
import WidgetKit

// Was die App dem Widget hinlegt.
//
// Das Widget kann nichts abfragen: Es läuft in einem eigenen Prozess, zu einem
// Zeitpunkt, den das System bestimmt, und hat weder die Claude-Token noch die
// Zeit für einen Netzabruf. Es liest, was hier steht — mehr nicht.
//
// Deshalb stehen hier **fertige Anzeigewerte** und keine Rohantworten: ein
// Name, ein Prozentwert, eine Zurücksetzung. Wer die Auswertung ins Widget
// verlegte, hätte sie zweimal, und die zweite altert.
//
// **Diese Datei gehört später nach `Shared/`.** `project.yml` gibt dem
// Widget-Ziel nur `Widget/` und `Shared/` als Quellen; solange sie unter
// `App/Model/` liegt, kann nur die App sie sehen. Das Schreiben stimmt schon,
// das Lesen im Widget kommt in Etappe E3 — dann wandert die Datei mit.

/// Der Stand, den das Widget zeigt.
struct WidgetZustand: Codable, Sendable, Equatable {

    /// Wird bei jeder Formänderung erhöht. Ein älteres Widget, das eine neuere
    /// Fassung findet, zeigt lieber nichts als etwas Falsches — dieselbe Regel
    /// wie bei `MacZustand`.
    static let aktuelleVersion = 1

    /// Steht in der App Group, nicht in den Benutzervorgaben der App: Nur die
    /// Gruppe sehen beide Prozesse.
    static let schluessel = "widget-zustand-v1"

    /// Ein Nutzungsfenster, so wie es angezeigt wird.
    struct Fenster: Codable, Sendable, Equatable {
        /// Die Beschriftung, die die Quelle mitgeliefert hat — «5 Stunden»,
        /// «7 Tage», «Fable 5». Nicht die Kennung: Das Widget schreibt sie hin,
        /// es entscheidet nichts daran.
        let name: String
        /// 0…100.
        let prozent: Double
        let zuruecksetzung: Date?

        init(name: String, prozent: Double, zuruecksetzung: Date?) {
            self.name = name
            self.prozent = prozent
            self.zuruecksetzung = zuruecksetzung
        }
    }

    let version: Int
    /// Wann die Zahlen **erhoben** wurden — nicht, wann sie hier abgelegt
    /// wurden. Der Unterschied ist genau das, was auf dem Widget stehen muss:
    /// Ein Wert von vor drei Stunden ist eine andere Aussage als einer von
    /// eben, und die App darf ihn nicht durchs Hinschreiben verjüngen.
    let erhoben: Date
    let fenster: [Fenster]

    init(erhoben: Date, fenster: [Fenster]) {
        self.version = Self.aktuelleVersion
        self.erhoben = erhoben
        self.fenster = fenster
    }

    // MARK: - Lesen und Schreiben

    private static var kodierer: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var dekodierer: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func lies(aus vorgaben: UserDefaults? = AppGruppe.vorgaben) -> WidgetZustand? {
        guard let daten = vorgaben?.data(forKey: schluessel),
              let zustand = try? dekodierer.decode(WidgetZustand.self, from: daten),
              zustand.version <= aktuelleVersion
        else { return nil }
        return zustand
    }

    /// Legt den Stand ab und stösst das Widget an — **letzteres nur, wenn sich
    /// die angezeigten Werte geändert haben.**
    ///
    /// Die beiden Schritte sind absichtlich verschieden teuer. Schreiben kostet
    /// nichts, es geht in eine lokale Datei; deshalb wird immer geschrieben,
    /// damit `erhoben` stimmt. Ein Neuladen dagegen kommt aus einem knappen
    /// Vorrat — das System gibt einem Widget grob 40 bis 70 am Tag. Wer bei
    /// jedem Abruf neu lädt, hat den Vorrat vor Mittag verbraucht und steht den
    /// Rest des Tages mit veralteten Zahlen da.
    ///
    /// - Returns: ob das Widget angestossen wurde.
    @discardableResult
    func schreib(nach vorgaben: UserDefaults? = AppGruppe.vorgaben) -> Bool {
        schreib(nach: vorgaben, stossAn: true)
    }

    /// Dasselbe, ohne das Widget anzustossen.
    ///
    /// Ruft das Widget selbst ab und legt das Ergebnis hier ab, wäre ein
    /// Anstoss ein Kreis: Neuladen führte zum Abruf, der Abruf zum Neuladen.
    /// Deshalb dieser Weg — und **nicht** ein zweiter Kodierer auf der
    /// Widget-Seite. Zwei Kodierer heisst zwei Datumsschreibweisen, die im
    /// Gleichschritt bleiben müssen, und der Tag, an dem eine davon nachzieht,
    /// fällt niemandem auf: Der Zustand liesse sich schreiben und nicht mehr
    /// lesen, das Widget bliebe einfach leer.
    @discardableResult
    func legAbOhneNeuladen(nach vorgaben: UserDefaults? = AppGruppe.vorgaben) -> Bool {
        schreib(nach: vorgaben, stossAn: false)
    }

    @discardableResult
    private func schreib(nach vorgaben: UserDefaults?, stossAn: Bool) -> Bool {
        guard let vorgaben, let daten = try? Self.kodierer.encode(self) else { return false }
        let vorher = Self.lies(aus: vorgaben)
        vorgaben.set(daten, forKey: Self.schluessel)

        guard stossAn, vorher?.fenster != fenster else { return false }
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }
}

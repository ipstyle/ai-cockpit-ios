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

    /// Eine Karte in einer Zeile — das, was das Widget als Liste zeigt.
    ///
    /// Lange stand hier nur `fenster`, und das waren ausschliesslich die
    /// Claude-Fenster: Das Widget zeigte Claude und sonst nichts, obwohl in der
    /// App fünf Karten standen. Diese Liste ist die Antwort darauf — **eine
    /// Zeile je eingeblendeter Karte, die wirklich Zahlen hat.**
    ///
    /// Der Text kommt aus derselben Kurzfassung, die die eingeklappte Karte in
    /// der App zeigt. Das ist kein Zufall, sondern der Punkt: Sie ist bereits
    /// darauf gebaut, in eine Zeile zu passen, und sie an zwei Stellen
    /// verschieden zu formulieren hiesse, zwei Fassungen zu pflegen.
    struct Quelle: Codable, Sendable, Equatable {
        /// «Claude», «ChatGPT», «OpenAI-API» — wie auf der Karte.
        let name: String
        /// Der Rohwert von `Theme.Provider`.
        ///
        /// Ohne ihn kann die Kachel die Anbieterfarbe nicht kennen, und genau
        /// das war zu sehen: Die ganze grosse Kachel stand in Claudes Orange,
        /// ChatGPT und Kimi eingeschlossen. In der App erkennt man die Quelle an
        /// ihrer Farbe, bevor man den Namen liest — das gehört aufs Widget.
        let anbieter: String
        /// Die Fenster **dieser** Quelle.
        ///
        /// Vorher lagen alle Fenster flach auf oberster Ebene und stammten
        /// sämtlich von Claude. Auf der grossen Kachel stand darum unter der
        /// Quellenliste ein Balkenblock, der zu nichts Sichtbarem gehörte.
        let fenster: [Fenster]
        /// «5 h: 64 % · 7 d: 57 %», «Heute US$ 0.00 · Monat US$ 3.05».
        let wert: String
        /// Dasselbe auf **eine** Angabe eingedampft — für die kleine Kachel und
        /// den Sperrbildschirm, wo der volle Wert abgeschnitten würde. Und ein
        /// abgeschnittener Betrag («US$ 0…») ist keine Auskunft, sondern eine
        /// Falle.
        let kurz: String
        /// Für die Ampel. `nil` bei Karten, die kein Kontingent führen, sondern
        /// Geld — dort gibt es keinen Prozentsatz, und einen zu erfinden wäre
        /// schlimmer als keiner.
        let prozent: Double?
        let warnung: Bool
        /// Wann **diese** Zahlen erhoben wurden. Je Quelle und nicht global:
        /// Das Widget erneuert von sich aus nur Claude, die übrigen Zeilen sind
        /// so alt wie der letzte Lauf der App.
        let stand: Date

        init(name: String, anbieter: String = "neutral", wert: String, kurz: String? = nil,
             fenster: [Fenster] = [], prozent: Double?, warnung: Bool, stand: Date) {
            self.name = name
            self.anbieter = anbieter
            self.fenster = fenster
            self.wert = wert
            self.kurz = kurz ?? wert
            self.prozent = prozent
            self.warnung = warnung
            self.stand = stand
        }

        /// Der Anbieter als Aufzählung.
        ///
        /// **Mit Reparatur für Zeilen aus einer älteren Fassung.** Die trugen
        /// noch keinen Anbieter, und das Widget nimmt beim eigenen Nachladen
        /// nur die Claude-Zeile neu auf — die übrigen wandern unverändert mit.
        /// Ohne diese Zuordnung standen ChatGPT und Kimi so lange in einer
        /// fremden Farbe, bis die App das nächste Mal lief. Am Gerät gesehen,
        /// nicht ausgedacht.
        ///
        /// Der Name taugt dafür, weil er aus unseren eigenen Kartentiteln
        /// kommt und nicht aus einer Netzantwort.
        var alsAnbieter: Theme.Provider {
            if let bekannt = Theme.Provider(rawValue: anbieter), bekannt != .neutral { return bekannt }
            switch name {
            case "Claude": return .claude
            case "ChatGPT": return .chatGPT
            case let n where n.hasPrefix("Kimi"): return .kimi
            case let n where n.hasPrefix("OpenAI"): return .openAI
            // Die Anthropic-Karte trägt in der App Claudes Farbe: derselbe
            // Anbieter, zwei Zugänge.
            case let n where n.hasPrefix("Anthropic"): return .claude
            default: return .neutral
            }
        }

        /// Ältere Stände kennen `kurz` nicht — dort gilt der volle Wert.
        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            name = try c.decode(String.self, forKey: .name)
            // Ältere Stände kennen weder Anbieter noch eigene Fenster. Sie
            // deswegen zu verwerfen hiesse: leeres Widget bis zum nächsten
            // Start der App.
            anbieter = try c.decodeIfPresent(String.self, forKey: .anbieter) ?? "neutral"
            fenster = try c.decodeIfPresent([Fenster].self, forKey: .fenster) ?? []
            wert = try c.decode(String.self, forKey: .wert)
            kurz = try c.decodeIfPresent(String.self, forKey: .kurz) ?? wert
            prozent = try c.decodeIfPresent(Double.self, forKey: .prozent)
            warnung = try c.decode(Bool.self, forKey: .warnung)
            stand = try c.decode(Date.self, forKey: .stand)
        }
    }

    let version: Int
    /// Wann die Zahlen **erhoben** wurden — nicht, wann sie hier abgelegt
    /// wurden. Der Unterschied ist genau das, was auf dem Widget stehen muss:
    /// Ein Wert von vor drei Stunden ist eine andere Aussage als einer von
    /// eben, und die App darf ihn nicht durchs Hinschreiben verjüngen.
    let erhoben: Date
    /// Die Claude-Fenster — sie tragen den Ring und die Balken.
    let fenster: [Fenster]
    /// Eine Zeile je eingeblendeter Karte mit Zahlen. Leer bei einem Stand aus
    /// einer älteren Fassung; dann zeigt das Widget wie früher nur `fenster`.
    let quellen: [Quelle]

    init(erhoben: Date, fenster: [Fenster], quellen: [Quelle] = []) {
        self.version = Self.aktuelleVersion
        self.erhoben = erhoben
        self.fenster = fenster
        self.quellen = quellen
    }

    /// Ein Stand aus einer älteren Fassung kennt `quellen` nicht. Ihn deswegen
    /// zu verwerfen hiesse: leeres Widget bis zum nächsten Start der App.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        erhoben = try c.decode(Date.self, forKey: .erhoben)
        fenster = try c.decode([Fenster].self, forKey: .fenster)
        quellen = try c.decodeIfPresent([Quelle].self, forKey: .quellen) ?? []
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

        guard stossAn, vorher?.fenster != fenster || vorher?.quellen != quellen else { return false }
        WidgetCenter.shared.reloadAllTimelines()
        return true
    }
}

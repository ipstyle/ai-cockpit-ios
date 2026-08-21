import Foundation
import CryptoKit
import AgentDeckCore

// Was einmal geholt wurde, wird nie wieder geholt.
//
// **Das Problem.** Die OpenAI-Karte zeigt drei Zahlen: heute, laufender Monat,
// gesamt. «Gesamt» heisst gesamt — die Schnittstelle liefert dafür Tages-Eimer,
// höchstens 180 je Seite, und drei Jahre sind rund 1100 Tage. Das sind sieben
// Seitenabrufe nacheinander, jeder mit eigener Wartezeit und zweitem Anlauf.
// Am Gerät gemessen: über eine Minute, im schlechten Fall gar nicht fertig.
//
// **Die Einsicht dahinter ist banal:** Der 14. März 2024 kostet heute genau so
// viel wie gestern. Vergangene Tage sind fertig. Nur der heutige Tag ändert
// sich noch — und der steht in einem einzigen Eimer.
//
// Also wird alles bis **gestern** hier abgelegt und beim nächsten Mal nur noch
// nachgeholt, was seither dazugekommen ist. Aus sieben Seiten wird eine.
//
// **Was das nicht ist:** ein Zwischenspeicher für die Anzeige. Den gibt es
// schon (`Zwischenspeicher`), er hält die *fertigen Zahlen* über einen
// Neustart. Hier liegen die *Rohtage*, aus denen die Zahlen entstehen — die
// Ersparnis liegt im Abruf, nicht in der Darstellung.
//
// **Was hier nicht hineingehört:** der Admin-Schlüssel. Gespeichert wird nur
// seine Prüfsumme, und die dient einem einzigen Zweck — zu merken, dass jemand
// den Schlüssel gewechselt hat, damit die Tage eines fremden Kontos nicht
// weitergerechnet werden.
struct OpenAIVerlauf: Codable, Sendable {

    /// Ein abgeschlossener Tag.
    struct Tag: Codable, Sendable {
        let beginn: Date
        let betrag: Decimal
        let waehrung: String

        init(_ eimer: OpenAIUsageClient.CostBucket) {
            beginn = eimer.start
            betrag = eimer.amount
            waehrung = eimer.currency
        }

        var alsEimer: OpenAIUsageClient.CostBucket {
            .init(start: beginn, amount: betrag, currency: waehrung)
        }
    }

    static let aktuelleVersion = 1
    static let schluessel = "openai-verlauf-v1"

    /// **Wie weit zurück ein Nachschlag reicht.**
    ///
    /// Nicht nur bis zum letzten gespeicherten Tag: Die Kosten-Schnittstelle
    /// bucht nach, und ein Eimer, der beim Abruf um 00:05 UTC noch leer war,
    /// kann Stunden später einen Betrag tragen. Zwei Tage Überlappung kosten
    /// nichts — sie liegen in derselben Seite — und ersparen einen Fehler, den
    /// niemand je bemerken würde, weil er nur die Gesamtsumme leise verkürzt.
    static let ueberlappung: TimeInterval = 2 * 86_400

    var version = Self.aktuelleVersion
    /// Prüfsumme des Admin-Schlüssels, **nicht** der Schlüssel.
    var kennung: String = ""
    var tage: [Tag] = []

    // MARK: - Der Nachschlag

    /// Ab wann nachgeholt werden muss.
    ///
    /// Ohne gespeicherte Tage: drei Jahre zurück, dieselbe Spanne wie im Kern —
    /// «gesamt» soll auf beiden Geräten dasselbe heissen.
    func abWann(jetzt: Date) -> Date {
        let kalender = Calendar.current
        let ganzZurueck = kalender.date(byAdding: .year, value: -3, to: jetzt) ?? jetzt
        guard let juengster = tage.map(\.beginn).max() else { return ganzZurueck }
        return max(ganzZurueck, juengster.addingTimeInterval(-Self.ueberlappung))
    }

    /// Gespeicherte Tage plus frisch geholte, ohne Doppelzählung.
    ///
    /// Die Überlappung ist der Grund, warum hier gesiebt statt angehängt wird:
    /// Die letzten zwei Tage kommen aus beiden Quellen, und der frische Wert
    /// ist der richtige.
    func verschmolzen(mit frisch: [OpenAIUsageClient.CostBucket], ab: Date) -> [OpenAIUsageClient.CostBucket] {
        tage.filter { $0.beginn < ab }.map(\.alsEimer) + frisch
    }

    /// Merkt sich alles, was **vor heute** liegt.
    ///
    /// Der heutige Eimer wird bewusst nicht abgelegt: Er wächst noch. Läge er
    /// hier, zeigte die Karte morgen den Vormittagsstand von heute.
    mutating func merke(_ eimer: [OpenAIUsageClient.CostBucket], jetzt: Date) {
        // UTC, nicht Ortszeit: Die Schnittstelle legt ihre Tages-Eimer an
        // UTC-Mitternachten an. Westlich von UTC fiele mit der lokalen
        // Mitternacht der heutige Eimer in «vergangen» — und würde eingefroren.
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let heute = kalender.startOfDay(for: jetzt)
        tage = eimer.filter { $0.start < heute }.map(Tag.init)
    }

    // MARK: - Schlüsselwechsel

    /// Prüfsumme statt Schlüssel. Kurz gehalten: Sie muss zwei Schlüssel
    /// unterscheiden, nicht einen rekonstruieren.
    static func kennung(fuer adminSchluessel: String) -> String {
        let summe = SHA256.hash(data: Data(adminSchluessel.utf8))
        return summe.prefix(8).map { String(format: "%02x", $0) }.joined()
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

    /// Liest den Verlauf — aber nur, wenn er zum selben Schlüssel gehört.
    ///
    /// Passt die Kennung nicht, kommt ein leerer Verlauf zurück. Der nächste
    /// Abruf holt dann wieder drei Jahre. Einmal, und danach nie wieder.
    static func lies(fuer adminSchluessel: String,
                     aus vorgaben: UserDefaults = .standard) -> OpenAIVerlauf {
        let erwartet = kennung(fuer: adminSchluessel)
        guard let daten = vorgaben.data(forKey: schluessel),
              let verlauf = try? dekodierer.decode(OpenAIVerlauf.self, from: daten),
              verlauf.version <= aktuelleVersion,
              verlauf.kennung == erwartet
        else { return OpenAIVerlauf(kennung: erwartet) }
        return verlauf
    }

    func schreib(nach vorgaben: UserDefaults = .standard) {
        guard let daten = try? Self.kodierer.encode(self) else { return }
        vorgaben.set(daten, forKey: Self.schluessel)
    }

    static func loesche(aus vorgaben: UserDefaults = .standard) {
        vorgaben.removeObject(forKey: schluessel)
    }
}

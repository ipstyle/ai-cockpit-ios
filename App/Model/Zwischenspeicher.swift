import Foundation
import AgentDeckCore

// Was die App vom letzten Mal behält.
//
// Ohne diese Datei fing jeder Start bei null an: Alle fünf Quellen standen auf
// «wird geholt …», und weil der OpenAI-Abruf der langsamste ist, sah man dort
// am längsten nichts. Für den Nutzer ist das nicht «lädt gerade» — es ist eine
// leere Karte, und eine leere Karte sieht kaputt aus.
//
// Das Widget war darin immer weiter als die App: Es legt seinen Stand ab und
// zeigt ihn mit Altersangabe, bis etwas Frischeres kommt. Genau das macht die
// App jetzt auch.
//
// **Gespeichert werden die Werte, nicht die fertigen Karten.** Der Unterschied
// entscheidet, wie viel Code das kostet: Aus wiederhergestellten Werten entsteht
// die Karte auf dem gewohnten Weg — Kurzfassung, Ampel, Balken, Widget-Zeile und
// Zeitstempel stimmen von selbst. Ein Speicher fertiger Karten müsste jede
// dieser Ableitungen ein zweites Mal führen, und die zweite altert.
//
// **Was hier nicht hineingehört:** irgendetwas, das Zugriff auf ein fremdes
// Konto gibt. Was drinsteht, sind Prozentwerte und Geldbeträge — dieselbe Art
// Daten, die das Widget längst in der App Group ablegt. Schlüssel und Token
// bleiben im Schlüsselbund, ausnahmslos.

/// Der letzte erfolgreiche Stand aller Quellen.
struct Zwischenspeicher: Codable, Sendable, Equatable {

    /// Wird bei jeder Formänderung erhöht. Ein älterer Stand, den eine neuere
    /// Fassung nicht mehr deuten kann, wird verworfen statt falsch gezeigt.
    static let aktuelleVersion = 1
    static let schluessel = "letzterStand-v1"

    // MARK: - Die gespeicherten Formen

    /// Ein Nutzungsfenster, wie `LimitWindow` es führt.
    struct Fenster: Codable, Sendable, Equatable {
        let name: String
        let prozent: Double
        let zuruecksetzung: Date?
        let minuten: Int?

        init(_ w: LimitWindow) {
            name = w.label
            prozent = w.usedPercent
            zuruecksetzung = w.resetsAt
            minuten = w.windowMinutes
        }

        var zuKern: LimitWindow {
            LimitWindow(label: name, usedPercent: prozent,
                        resetsAt: zuruecksetzung, windowMinutes: minuten)
        }
    }

    struct ClaudeStand: Codable, Sendable, Equatable {
        let fuenfStunden: Fenster?
        let woche: Fenster?
        let modelle: [Fenster]
        let erhoben: Date

        init(_ l: ClaudeLimits) {
            fuenfStunden = l.fiveHour.map(Fenster.init)
            woche = l.weekly.map(Fenster.init)
            modelle = l.weeklyScoped.map(Fenster.init)
            erhoben = l.fetchedAt
        }

        var zuKern: ClaudeLimits {
            ClaudeLimits(fiveHour: fuenfStunden?.zuKern,
                         weekly: woche?.zuKern,
                         weeklyScoped: modelle.map(\.zuKern),
                         fetchedAt: erhoben)
        }
    }

    struct CodexStand: Codable, Sendable, Equatable {
        let fuenfStunden: Fenster?
        let woche: Fenster?
        let abo: String?
        let guthaben: String?
        let erhoben: Date

        init(_ l: CodexLimits) {
            fuenfStunden = l.fiveHour.map(Fenster.init)
            woche = l.weekly.map(Fenster.init)
            abo = l.planType
            guthaben = l.creditBalance
            erhoben = l.observedAt
        }

        /// `.appServer` als Quelle, weil die Zahlen von dort kamen. Der Kern
        /// unterscheidet damit «live geholt» von «aus alten Protokolldateien
        /// gelesen» — und gelesen wurden sie nie.
        var zuKern: CodexLimits {
            CodexLimits(fiveHour: fuenfStunden?.zuKern, weekly: woche?.zuKern,
                        planType: abo, creditBalance: guthaben,
                        observedAt: erhoben, source: .appServer)
        }
    }

    /// Für OpenAI und die Anthropic-Schnittstelle — beide führen dieselben vier
    /// Beträge.
    struct KostenStand: Codable, Sendable, Equatable {
        let heute: Decimal
        let monat: Decimal
        let gesamt: Decimal
        let seit: Date?
        let waehrung: String
        let erhoben: Date

        init(_ k: OpenAICosts) {
            heute = k.today; monat = k.month; gesamt = k.total
            seit = k.since; waehrung = k.currency; erhoben = k.fetchedAt
        }

        init(_ k: AnthropicCosts) {
            heute = k.today; monat = k.month; gesamt = k.total
            seit = k.since; waehrung = k.currency; erhoben = k.fetchedAt
        }

        var alsOpenAI: OpenAICosts {
            OpenAICosts(today: heute, month: monat, total: gesamt, since: seit,
                        currency: waehrung, fetchedAt: erhoben)
        }

        /// Kostenzeilen und Tagesreihe bleiben leer: Die iOS-Karte zeigt beides
        /// nicht, und was nicht gezeigt wird, muss auch nicht aufbewahrt werden.
        var alsAnthropic: AnthropicCosts {
            AnthropicCosts(today: heute, month: monat, total: gesamt, since: seit,
                           currency: waehrung, fetchedAt: erhoben, lines: [], daily: [])
        }
    }

    struct KimiStand: Codable, Sendable, Equatable {
        let verfuegbar: Decimal
        let gutscheine: Decimal
        let bargeld: Decimal
        let erhoben: Date

        init(_ b: KimiClient.Balance) {
            verfuegbar = b.available; gutscheine = b.voucher
            bargeld = b.cash; erhoben = b.fetchedAt
        }

        var zuKern: KimiClient.Balance {
            KimiClient.Balance(available: verfuegbar, voucher: gutscheine,
                               cash: bargeld, fetchedAt: erhoben)
        }
    }

    // MARK: - Der Stand

    var version = Self.aktuelleVersion
    var claude: ClaudeStand?
    var codex: CodexStand?
    var openAI: KostenStand?
    var anthropic: KostenStand?
    var kimi: KimiStand?
    /// Wann zuletzt ein vollständiger Durchgang durch war. Ohne diesen Wert
    /// stünde nach einem Neustart «noch keine Daten» über Zahlen, die dastehen.
    var zuletztAktualisiert: Date?

    var istLeer: Bool {
        claude == nil && codex == nil && openAI == nil && anthropic == nil && kimi == nil
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

    /// Liegt in den Vorgaben der App, **nicht** in der App Group: Das Widget hat
    /// seinen eigenen Stand. Zwei Ablagen für dieselbe Aussage wären eine zu
    /// viel — und die, die niemand pflegt, wird die falsche.
    static func lies(aus vorgaben: UserDefaults = .standard) -> Zwischenspeicher {
        guard let daten = vorgaben.data(forKey: schluessel),
              let stand = try? dekodierer.decode(Zwischenspeicher.self, from: daten),
              stand.version <= aktuelleVersion
        else { return Zwischenspeicher() }
        return stand
    }

    func schreib(nach vorgaben: UserDefaults = .standard) {
        guard let daten = try? Self.kodierer.encode(self) else { return }
        vorgaben.set(daten, forKey: Self.schluessel)
    }

    static func loesche(aus vorgaben: UserDefaults = .standard) {
        vorgaben.removeObject(forKey: schluessel)
    }
}

import Foundation
import UserNotifications
import AgentDeckCore

// Lokale Hinweise — zwei Anlässe, kein Server.
//
// Es gibt keinen Push und keinen Dienst dahinter: Was hier entsteht, ist eine
// `UNNotificationRequest` auf demselben Gerät. Kein Konto, keine Anmeldung,
// nichts, was das Telefon verlässt.
//
// Drei Regeln tragen diese Datei. Fällt eine davon weg, wird aus einer
// nützlichen Meldung eine Belästigung:
//
// 1. **Gemeldet wird der Übergang, nicht der Zustand.** Wer bei jedem Abruf
//    meldet, dass 92 % erreicht sind, meldet beim zehnten Blick zum zehnten
//    Mal dasselbe. Je Fenster steht deshalb die zuletzt erreichte Stufe fest;
//    gemeldet wird nur, wenn sie steigt. Fällt sie wieder, ist der Hinweis
//    wieder scharf.
// 2. **Der Merkzettel überlebt den Neustart.** Er liegt in den
//    Benutzervorgaben, nicht im Speicher. Sonst wäre nach jedem Start jede
//    Stufe wieder «normal» — und der erste Abruf begrüsste den Nutzer mit der
//    Warnung von gestern.
// 3. **Kein Hinweis ohne Anlass.** Sieht der Dienst ein Fenster zum ersten Mal,
//    merkt er sich den Stand und meldet nichts. «Überschritten» setzt einen
//    Vorher-Wert voraus; ohne ihn ist jede Meldung geraten.
//
// Was diese Datei **nicht** kann: melden, während die App nicht läuft. Ein
// iPhone hält keinen Prozess im Hintergrund, der alle paar Minuten Kontingente
// abfragt — die Schwellen-Hinweise entstehen deshalb beim Abruf, also während
// die App vorn ist oder gerade nach vorn kommt. Einzige Ausnahme ist der
// Hinweis auf ein neues Fenster: Dessen Zeitpunkt steht im Voraus fest, und
// eine Meldung, die für später eingeplant ist, stellt iOS auch bei geschlossener
// App zu.

@MainActor
final class Mitteilungen {

    /// Einer für die ganze App. Der Merkzettel liegt zwar in den
    /// Benutzervorgaben und wäre auch doppelt tragfähig — aber zwei Instanzen,
    /// die im selben Durchgang dasselbe Fenster prüfen, meldeten es zweimal.
    static let geteilt = Mitteilungen()

    /// Die Stufe, die ein Fenster zuletzt erreicht hatte.
    private enum Stufe: Int, Comparable {
        case normal = 0
        case warnung = 1
        case kritisch = 2

        static func < (links: Stufe, rechts: Stufe) -> Bool { links.rawValue < rechts.rawValue }
    }

    /// Die Schlüssel des Merkzettels. Eigene Namen, damit sie beim Aufräumen in
    /// `Einstellungen.loescheAlles()` als Gruppe erkennbar sind.
    private enum Ablage {
        /// Fenster → zuletzt erreichte Stufe (Rohwert von `Stufe`).
        static let stufen = "notifyLevelState"
        /// Fenster → zuletzt gesehener Rücksetzzeitpunkt.
        static let zuruecksetzungen = "notifyResetState"
        /// Fenster → Rücksetzzeitpunkt, für den der Hinweis schon erledigt ist
        /// (gesendet oder eingeplant).
        static let erledigteZyklen = "notifyResetDone"

        static let alle = [stufen, zuruecksetzungen, erledigteZyklen]
    }

    private let vorgaben: UserDefaults
    private let zentrale = UNUserNotificationCenter.current()

    init(vorgaben: UserDefaults = .standard) {
        self.vorgaben = vorgaben
    }

    // MARK: - Der eine Eingang

    /// Prüft alles, was ein Durchgang hergibt.
    ///
    /// Absichtlich **eine** Methode mit den fertigen Werten statt vieler
    /// Einzelaufrufe: Der Anschluss im Cockpit soll eine Zeile sein, und was
    /// gemeldet wird, soll an einer Stelle stehen und nicht über den Aufrufer
    /// verteilt.
    ///
    /// - Parameters:
    ///   - claude: Die Claude-Kontingente, oder `nil`, wenn der Abruf nichts
    ///     geliefert hat. Ein Fehlschlag ist kein Anlass — er sagt nichts über
    ///     den Verbrauch, nur über das Netz.
    ///   - chatgpt: Dasselbe für ChatGPT.
    ///   - schwellen: Die eingestellten Prozentwerte.
    func melde(claude: ClaudeLimits?, chatgpt: CodexLimits?, schwellen: LimitThresholds) async {
        if let claude {
            if let fenster = claude.fiveHour {
                await pruefe("claude-5h", titel: "Claude · 5 Stunden",
                             fenster: fenster, schwellen: schwellen, fuenfStunden: true)
            }
            if let fenster = claude.weekly {
                await pruefe("claude-7d", titel: "Claude · 7 Tage",
                             fenster: fenster, schwellen: schwellen, fuenfStunden: false)
            }
            // Die modellbezogenen Wochenfenster zählen wie die festen: Ein
            // volles Opus-Kontingent trifft einen genauso hart.
            for fenster in claude.weeklyScoped {
                await pruefe("claude-7d-\(fenster.label)",
                             titel: String(localized: "Claude · 7 Tage · \(fenster.label)"),
                             fenster: fenster, schwellen: schwellen, fuenfStunden: false)
            }
        }

        if let chatgpt {
            if let fenster = chatgpt.fiveHour {
                await pruefe("chatgpt-5h", titel: "ChatGPT · 5 Stunden",
                             fenster: fenster, schwellen: schwellen, fuenfStunden: true)
            }
            if let fenster = chatgpt.weekly {
                await pruefe("chatgpt-7d", titel: "ChatGPT · 7 Tage",
                             fenster: fenster, schwellen: schwellen, fuenfStunden: false)
            }
        }
    }

    /// Ein Fenster, beide Anlässe.
    ///
    /// - Parameter fuenfStunden: Ob der Hinweis auf ein neues Fenster gilt. Beim
    ///   Wochenfenster wäre er keine Nachricht: Sieben Tage lang passiert
    ///   nichts, und dass am Montag wieder alles offen ist, weiss man auch so.
    private func pruefe(_ schluessel: String,
                        titel: String,
                        fenster: LimitWindow,
                        schwellen: LimitThresholds,
                        fuenfStunden: Bool) async {
        await pruefeSchwelle(schluessel, titel: titel, fenster: fenster, schwellen: schwellen)
        guard fuenfStunden else { return }
        await pruefeNeuesFenster(schluessel, titel: titel, fenster: fenster)
    }

    // MARK: - Schwelle überschritten

    /// Meldet, wenn ein Fenster die Warn- oder die kritische Schwelle **reisst**.
    ///
    /// Nicht bei jedem Wert darüber: Der Vergleich läuft gegen die zuletzt
    /// erreichte Stufe. Von «normal» auf «kritisch» ist ein Sprung und eine
    /// Meldung; von «kritisch» auf «kritisch» ist nichts passiert.
    private func pruefeSchwelle(_ schluessel: String,
                                titel: String,
                                fenster: LimitWindow,
                                schwellen: LimitThresholds) async {
        guard MitteilungenVorgaben.istAn(MitteilungenVorgaben.Schluessel.beiLimit, in: vorgaben) else { return }

        let prozent = Self.geklemmt(fenster.usedPercent)
        let stufe: Stufe = prozent >= schwellen.critical ? .kritisch
                         : prozent >= schwellen.warn ? .warnung
                         : .normal

        var merkzettel = stufen
        let vorher = merkzettel[schluessel].flatMap(Stufe.init(rawValue:))
        merkzettel[schluessel] = stufe.rawValue
        stufen = merkzettel

        // Erstes Sehen: nur merken. Es gibt keinen Vorher-Wert, also ist auch
        // nichts überschritten worden — höchstens war es schon vorher so.
        guard let vorher else { return }
        guard stufe > vorher else { return }
        guard await darfMelden() else { return }

        let anteil = Int(prozent.rounded())
        if stufe == .kritisch {
            await sende(titel: String(localized: "\(titel) fast aufgebraucht"),
                        text: String(localized: "Das Kontingent ist zu \(anteil) % ausgeschöpft."))
        } else {
            await sende(titel: String(localized: "\(titel) bei \(anteil) %"),
                        text: String(localized: "Noch \(100 - anteil) % übrig."))
        }
    }

    // MARK: - Neues Fenster

    /// Meldet, dass ein Fünf-Stunden-Fenster neu begonnen hat.
    ///
    /// Erkannt wird das am Rücksetzzeitpunkt: Rückt er nach vorn, ist das alte
    /// Fenster abgelaufen und ein neues offen. Der Verbrauch allein taugt nicht
    /// als Merkmal — er fällt auch, wenn eine Abfrage danebengeht und eine
    /// halbe Antwort zurückkommt.
    ///
    /// Zwei Wege führen zur Meldung, und sie schliessen einander aus:
    ///
    /// - **Eingeplant.** Steht der Rücksetzzeitpunkt in der Zukunft, wird die
    ///   Meldung für genau diesen Moment vorgemerkt. Das ist der eigentliche
    ///   Nutzen: Sie kommt an, während die App zu ist — sonst müsste man
    ///   hinsehen, um zu erfahren, dass man nicht mehr hinsehen muss.
    /// - **Nachgereicht.** War nichts eingeplant — weil die Erlaubnis damals
    ///   fehlte oder die App den Zeitpunkt nie gesehen hat —, meldet der erste
    ///   Abruf nach dem Wechsel.
    ///
    /// Wofür eingeplant wurde, gilt als erledigt. Sonst käme beides.
    private func pruefeNeuesFenster(_ schluessel: String, titel: String, fenster: LimitWindow) async {
        guard MitteilungenVorgaben.istAn(MitteilungenVorgaben.Schluessel.beiNeuemFenster, in: vorgaben) else { return }
        guard let zuruecksetzung = fenster.resetsAt else { return }

        var gesehen = zuruecksetzungen
        let vorher = gesehen[schluessel]
        gesehen[schluessel] = zuruecksetzung
        zuruecksetzungen = gesehen

        // Ohne Vorher-Wert wird nur gemerkt: Ob dieses Fenster gerade begonnen
        // hat oder seit vier Stunden läuft, ist von hier aus nicht zu
        // unterscheiden — und geraten wird nicht.
        if let vorher, zuruecksetzung > vorher {
            // Das Fenster hat gewechselt. Gemeldet wird nur, wenn für den
            // vergangenen Zyklus nichts eingeplant war — sonst ist die Meldung
            // längst zugestellt.
            if erledigteZyklen[schluessel] != vorher {
                merkeErledigt(schluessel, zyklus: vorher)
                if await darfMelden() {
                    await sende(
                        titel: String(localized: "\(titel) zurückgesetzt"),
                        text: String(localized: "Das Kontingent steht wieder bei \(Int(Self.geklemmt(fenster.usedPercent).rounded())) %."))
                }
            }
        }

        await planeEin(schluessel, titel: titel, zuruecksetzung: zuruecksetzung)
    }

    /// Merkt die Meldung für den Moment des Zurücksetzens vor.
    ///
    /// Dieselbe Kennung bei jedem Durchgang: iOS ersetzt damit die vorgemerkte
    /// Meldung, statt eine zweite danebenzulegen. Verschiebt die Gegenstelle den
    /// Zeitpunkt, zieht die Vormerkung mit.
    private func planeEin(_ schluessel: String, titel: String, zuruecksetzung: Date) async {
        // Unter einer Minute lohnt die Vormerkung nicht — bis sie steht, ist der
        // Zeitpunkt vorbei, und `UNTimeIntervalNotificationTrigger` verlangt
        // ohnehin eine Spanne grösser als null.
        let abstand = zuruecksetzung.timeIntervalSinceNow
        guard abstand > 60 else { return }
        guard erledigteZyklen[schluessel] != zuruecksetzung else { return }
        guard await darfMelden() else { return }

        let inhalt = UNMutableNotificationContent()
        inhalt.title = String(localized: "\(titel) zurückgesetzt")
        inhalt.body = String(localized: "Das Fenster ist abgelaufen — das Kontingent steht wieder offen.")
        inhalt.sound = .default

        // `add` wirft, wenn iOS die Vormerkung nicht annimmt — etwa weil das
        // Kontingent von 64 offenen Meldungen voll ist. Das ist kein Fall, den
        // ein Nutzer beheben könnte, und keiner, der die App stören darf:
        // Kommt die Meldung nicht zustande, bleibt es still.
        try? await zentrale.add(UNNotificationRequest(
            identifier: "\(Self.vormerkung)\(schluessel)",
            content: inhalt,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: abstand, repeats: false)))

        merkeErledigt(schluessel, zyklus: zuruecksetzung)
    }

    /// Räumt alle Vormerkungen ab.
    ///
    /// Gehört an den Schalter: Wer die Hinweise abschaltet, hat auch die
    /// eingeplante Meldung von heute Nachmittag nicht mehr bestellt. Ohne dies
    /// käme sie trotzdem — und das wäre der eine Fehler, den niemand verzeiht.
    func entferneVormerkungen() {
        // Die Kennungen aus dem Merkzettel **und** die zwei festen: Ist der
        // Merkzettel schon weg, hinge die Vormerkung sonst ohne Besitzer im
        // System und käme trotzdem.
        var offen = Set(erledigteZyklen.keys.map { "\(Self.vormerkung)\($0)" })
        offen.formUnion(Self.geplanteFenster.map { "\(Self.vormerkung)\($0)" })
        zentrale.removePendingNotificationRequests(withIdentifiers: Array(offen))
        // Der Merkzettel der Zyklen wird mitgelöscht: Was nicht mehr eingeplant
        // ist, darf beim nächsten Einschalten wieder eingeplant werden.
        vorgaben.removeObject(forKey: Ablage.erledigteZyklen)
    }

    /// Setzt alles zurück — für «Alle Daten löschen».
    ///
    /// Die zwei Schalter gehören dazu: Wer alles löscht, hat auch die Erlaubnis
    /// nicht mehr erteilt, an die er sich nicht mehr erinnert. Die
    /// Systemerlaubnis selbst bleibt, wo sie ist — die vergibt iOS, nicht diese
    /// App, und sie zurückzunehmen wäre hier gar nicht möglich.
    func vergissAlles() {
        MitteilungenVorgaben.geteilt.setzeZurueck()
        entferneVormerkungen()
        for schluessel in Ablage.alle { vorgaben.removeObject(forKey: schluessel) }
    }

    private static let vormerkung = "fenster-neu-"
    /// Die Fenster, für die überhaupt vorgemerkt wird — beide
    /// Fünf-Stunden-Fenster. Steht hier, damit das Abräumen sie auch dann
    /// findet, wenn der Merkzettel leer ist.
    private static let geplanteFenster = ["claude-5h", "chatgpt-5h"]

    // MARK: - Senden

    private func sende(titel: String, text: String) async {
        let inhalt = UNMutableNotificationContent()
        inhalt.title = titel
        inhalt.body = text
        inhalt.sound = .default
        // Ohne Auslöser heisst: sofort. Ein Fehlschlag bleibt still — siehe
        // `planeEin`: Eine Meldung ist eine Nebensache, kein Vorgang, dessen
        // Scheitern jemanden beschäftigen soll.
        try? await zentrale.add(UNNotificationRequest(identifier: UUID().uuidString, content: inhalt, trigger: nil))
    }

    /// Ob gemeldet werden darf — **ohne** zu fragen.
    ///
    /// Der Dialog gehört an den Schalter in den Einstellungen und nirgendwo
    /// sonst hin. Hier wird nur nachgesehen; fehlt die Erlaubnis, bleibt es
    /// still. Ein Berechtigungsdialog, der beim Aktualisieren aufspringt, ist
    /// genau die Überrumpelung, die zum Nein führt.
    private func darfMelden() async -> Bool {
        let erlaubnis = MitteilungenErlaubnis()
        await erlaubnis.lade()
        return erlaubnis.zustand == .erlaubt
    }

    // MARK: - Merkzettel

    /// Klemmt eine Prozentangabe auf 0…100, bevor sie in ein `Int` läuft.
    ///
    /// `Int(_:)` **beendet den Prozess**, wenn der Wert keine Zahl oder
    /// unendlich ist oder ausserhalb von `Int64` liegt — abfangen lässt sich das
    /// nicht. `LimitWindow.init` klemmt heute bereits, aber darauf soll sich
    /// diese Datei nicht verlassen: Eine Meldung darf die App unter keinen
    /// Umständen beenden. Gleiche Klemme wie in der Mac-Fassung: keine Zahl gilt
    /// als 0, unendlich als 100.
    static func geklemmt(_ wert: Double) -> Double {
        guard wert.isFinite else { return wert == .infinity ? 100 : 0 }
        return min(max(wert, 0), 100)
    }

    private var stufen: [String: Int] {
        get { (vorgaben.dictionary(forKey: Ablage.stufen) ?? [:]).compactMapValues { $0 as? Int } }
        set { vorgaben.set(newValue, forKey: Ablage.stufen) }
    }

    private var zuruecksetzungen: [String: Date] {
        get { (vorgaben.dictionary(forKey: Ablage.zuruecksetzungen) ?? [:]).compactMapValues { $0 as? Date } }
        set { vorgaben.set(newValue, forKey: Ablage.zuruecksetzungen) }
    }

    private var erledigteZyklen: [String: Date] {
        get { (vorgaben.dictionary(forKey: Ablage.erledigteZyklen) ?? [:]).compactMapValues { $0 as? Date } }
        set { vorgaben.set(newValue, forKey: Ablage.erledigteZyklen) }
    }

    private func merkeErledigt(_ schluessel: String, zyklus: Date) {
        var erledigt = erledigteZyklen
        erledigt[schluessel] = zyklus
        erledigteZyklen = erledigt
    }
}

// MARK: - Kleiner Griff für den Anschluss

extension Quellenstand {
    /// Die Werte, falls es welche gibt.
    ///
    /// Steht hier und nicht in `Cockpit.swift`, damit der Anschluss dort eine
    /// Zeile bleibt: `mitteilungen.melde(claude: claude.wert, …)`. Ein
    /// Fehlschlag oder ein leerer Zugang liefert `nil` — und `nil` ist kein
    /// Anlass für eine Meldung.
    var wert: Wert? {
        if case .daten(let werte) = self { return werte }
        return nil
    }
}

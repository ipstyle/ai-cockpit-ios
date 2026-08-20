import Foundation
import Observation
import SwiftUI
import AgentDeckCore

// Der Zustand der iOS-Fassung — das Stück zwischen dem Kern und `CardsView`.
//
// Vorlage ist `AgentDeck/AppStore.swift` der Mac-Fassung, aber deutlich
// abgespeckt. Was hier fehlt und warum:
//
// - **Keine sechs Zeitgeber.** Ein iPhone hat kein Fenster, das im Hintergrund
//   offen bleibt. Aktualisiert wird, wenn die App nach vorn kommt, wenn man
//   den Knopf drückt oder die Liste herunterzieht — alles andere wäre Strom
//   für eine Anzeige, die niemand ansieht.
// - **Kein Zurückweichen mit wachsendem Abstand** (`SourceHealth`). Das war
//   die Antwort auf einen Takt von 30 Sekunden. Ohne Takt gibt es nichts, was
//   sich bremsen liesse; wer hier drückt, will es jetzt wissen.
// - **Kein Verlauf, keine Hochrechnung, keine Sparklines.** Beides braucht
//   `[UsageSample]` über Stunden — und damit einen Prozess, der läuft, während
//   niemand hinsieht. Den gibt es hier nicht. Die Hochrechnungszeile bleibt
//   deshalb leer, statt aus zwei Messwerten eine Zahl zu erfinden.
//
// Was **gleich** bleibt, ist das Wichtigste: Jede Quelle hat ihren eigenen
// Zeitstempel und ihren eigenen Fehlerzustand, und ein Fehler in einer Quelle
// lässt die übrigen unberührt.

/// Wie es einer Datenquelle geht.
///
/// Vier Fälle statt eines `Result`, weil «noch nichts» und «nicht eingerichtet»
/// eben **keine** Fehler sind. Auf dem Mac zeigte die App dafür lange dieselbe
/// Meldung — und wer nie einen OpenAI-Schlüssel hinterlegt hatte, sah in seiner
/// Karte einen Fehler, den es gar nicht gab.
enum Quellenstand<Wert> {
    case laedt
    /// Kein Schlüssel, keine Anmeldung. Kein Fehler — eine Einladung.
    case nichtEingerichtet
    case daten(Wert)
    case fehler(String)
}

@MainActor
@Observable
final class Cockpit {

    // MARK: - Was die Ansicht sieht

    private(set) var karten: [CockpitCard] = []
    /// Ende des letzten vollständigen Durchgangs. Die einzelnen Karten tragen
    /// ihren eigenen, genaueren Zeitstempel — dieser hier steht in der
    /// Kopfzeile und beantwortet «wann habe ich zuletzt gefragt».
    private(set) var zuletztAktualisiert: Date?

    /// Welche Quellen gerade unterwegs sind.
    ///
    /// Früher stand hier ein einzelnes `wirdAktualisiert`, und daran hingen
    /// gleich drei Fehler: Ein zweiter Aufruf während eines laufenden Durchgangs
    /// wurde **stillschweigend verworfen** — wer einen Schlüssel eintrug,
    /// während der Startlauf noch lief, sah seine Karte bis zum nächsten
    /// App-Start leer. Und die Kopfzeile behauptete eine Minute lang, die ganze
    /// App arbeite, obwohl vier von fünf Karten längst dastanden.
    ///
    /// Der ursprüngliche Grund für die Sperre bleibt gewahrt: Zwei gleichzeitige
    /// Läufe **derselben** Quelle würden denselben Refresh-Token doppelt
    /// einlösen. Genau das ist gesperrt — nicht mehr.
    private(set) var laufendeQuellen: Set<CardLayout.Card> = []

    /// Läuft überhaupt noch etwas? Für den Kreisel im Aktualisieren-Knopf.
    var wirdAktualisiert: Bool { laufendeQuellen.isEmpty == false }

    /// Namen der Quellen, die noch unterwegs sind — in der Reihenfolge der
    /// Karten, damit die Kopfzeile nicht bei jedem Durchgang anders sortiert.
    var laufendeNamen: [String] {
        Self.quellen.filter { laufendeQuellen.contains($0) }.map(Self.name(fuer:))
    }

    /// Die fünf Quellen, die diese Fassung abfragt. Die Sitzungskarte gehört
    /// nicht dazu — sie hat auf einem iPhone keine Quelle.
    private static let quellen: [CardLayout.Card] = [.claude, .chatgpt, .openai, .anthropic, .kimi]

    /// Kennungen der eingeklappten Karten, mit Komma getrennt — dasselbe
    /// Format wie `AppSettings.collapsedCards` auf dem Mac. Zerlegt wird es von
    /// `CardLayout` im Kern; hier wird es nur gehalten und gesichert.
    var eingeklappteKarten: String {
        didSet {
            guard eingeklappteKarten != oldValue else { return }
            UserDefaults.standard.set(eingeklappteKarten, forKey: Self.schluesselEingeklappt)
        }
    }

    /// Kennungen der ausgeblendeten Karten, mit Komma getrennt.
    ///
    /// Sie liegt **hier** und nicht als `@AppStorage` in der Einstellungsseite:
    /// Eine Ansicht, die in die Vorgaben schreibt, sagt niemandem Bescheid — die
    /// Kartenliste erfuhr von der Änderung erst beim nächsten vollständigen
    /// Durchgang, also frühestens nach dem langsamsten Netzabruf und in der
    /// Praxis oft erst nach einem Neustart. Über `didSet` greift ein Schalter
    /// sofort, ganz ohne Netz.
    var versteckteKarten: String {
        didSet {
            guard versteckteKarten != oldValue else { return }
            UserDefaults.standard.set(versteckteKarten, forKey: Self.schluesselVersteckt)
            baueKarten()
        }
    }

    /// Aus den Benutzervorgaben, unter denselben Schlüsselnamen wie auf dem
    /// Mac. Fehlt ein Wert, gelten dessen Vorgaben (75 / 90) — der Nutzer hat
    /// dann schlicht noch nichts eingestellt, und das ist kein Fehlerfall.
    var schwellen: LimitThresholds {
        let vorgaben = UserDefaults.standard
        let warnung = vorgaben.object(forKey: "warnThreshold") as? Double
        let kritisch = vorgaben.object(forKey: "criticalThreshold") as? Double
        var werte = LimitThresholds.standard
        if let warnung { werte.warn = warnung }
        if let kritisch { werte.critical = kritisch }
        return werte
    }

    /// Hell, dunkel oder wie das System — `nil` heisst «wie das System».
    /// Gehört an die Wurzel der Ansichten; in den Einstellungen gesetzt, färbte
    /// es nur diese selbst.
    var erscheinungsbild: ColorScheme? {
        switch UserDefaults.standard.string(forKey: "appearanceMode") {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// Die Abostufe zum angemeldeten Konto — steht als Etikett neben «Claude».
    private(set) var claudeAbo: String?

    // MARK: - Zustand je Quelle

    private var claude: Quellenstand<ClaudeLimits> = .laedt
    private var codex: Quellenstand<CodexLimits> = .laedt
    private var openAI: Quellenstand<OpenAICosts> = .laedt
    private var anthropic: Quellenstand<AnthropicCosts> = .laedt
    private var kimi: Quellenstand<KimiClient.Balance> = .laedt

    private static let schluesselEingeklappt = "collapsedCards"
    private static let schluesselVersteckt = "hiddenCards"

    init() {
        eingeklappteKarten = UserDefaults.standard.string(forKey: Self.schluesselEingeklappt) ?? ""
        versteckteKarten = UserDefaults.standard.string(forKey: Self.schluesselVersteckt) ?? ""

        // **Der letzte bekannte Stand, bevor irgendetwas geholt wird.** Vorher
        // stand hier fünfmal «wird geholt …», und weil der OpenAI-Abruf der
        // langsamste ist, sah man dort am längsten nichts — was aussieht wie
        // eine kaputte Karte und nicht wie eine ladende.
        //
        // Die Zahlen tragen ihr Alter mit («Aktualisiert vor 2 Std.»), und die
        // Karten, die gerade nachgeladen werden, tragen den Kreisel. Damit ist
        // gesagt, was der Fall ist: alte Zahlen, neue unterwegs.
        let letzter = Zwischenspeicher.lies()
        if let w = letzter.claude { claude = .daten(w.zuKern) }
        if let w = letzter.codex { codex = .daten(w.zuKern) }
        if let w = letzter.openAI { openAI = .daten(w.alsOpenAI) }
        if let w = letzter.anthropic { anthropic = .daten(w.alsAnthropic) }
        if let w = letzter.kimi { kimi = .daten(w.zuKern) }
        zuletztAktualisiert = letzter.zuletztAktualisiert
        claudeAbo = letzter.claude == nil ? nil : Self.abostufe()

        baueKarten()
    }

    // MARK: - Aktualisieren

    /// Holt alle vier Quellen **gleichzeitig**.
    ///
    /// Nacheinander wäre es unbrauchbar: Die OpenAI-Abfrage blättert drei Jahre
    /// Kosten durch und fragt danach jedes Projekt einzeln. Bis zu einer halben
    /// Minute lang stünde die Claude-Karte leer da, obwohl ihre Antwort nach
    /// einer Sekunde vorlag. Jede Quelle schreibt ohnehin nur in ihr eigenes
    /// Feld — sie können sich nicht in die Quere kommen.
    /// Wie frisch eine Quelle sein muss, damit ein selbsttätiger Durchgang sie
    /// in Ruhe lässt.
    ///
    /// **Kosten ändern sich langsam, Kontingente schnell.** Der OpenAI-Abruf
    /// blättert drei Jahre Tagesbeträge durch — sieben Anfragen nacheinander,
    /// rund eine Minute. Den bei jedem Blick in die App neu zu starten, kostet
    /// Akku und Netz für eine Zahl, die sich in der Zwischenzeit um Rappen
    /// bewegt hat. Ein Fünfstundenfenster kann derweil um zwanzig Prozent
    /// gestiegen sein.
    ///
    /// **Der Knopf gilt trotzdem.** Wer «Aktualisieren» drückt oder die Liste
    /// herunterzieht, bekommt alles neu — dafür ist er da.
    private static func mindestalter(_ quelle: CardLayout.Card) -> TimeInterval {
        switch quelle {
        case .openai, .anthropic: return 15 * 60
        default: return 0
        }
    }

    /// Wann die Zahlen dieser Quelle erhoben wurden.
    private func stand(_ quelle: CardLayout.Card) -> Date? {
        switch quelle {
        case .claude: if case .daten(let w) = claude { return w.fetchedAt }
        case .chatgpt: if case .daten(let w) = codex { return w.observedAt }
        case .openai: if case .daten(let w) = openAI { return w.fetchedAt }
        case .anthropic: if case .daten(let w) = anthropic { return w.fetchedAt }
        case .kimi: if case .daten(let w) = kimi { return w.fetchedAt }
        case .sitzungen: return nil
        }
        return nil
    }

    /// - Parameter erzwingen: Auch holen, was noch frisch genug wäre. Der
    ///   Aktualisieren-Knopf und das Herunterziehen setzen das; der Weg zurück
    ///   in den Vordergrund nicht.
    func aktualisiere(erzwingen: Bool = false) async {
        // Im Demomodus wird nichts abgefragt — kein Netz, kein Schlüsselbund.
        // Die Prüfung steht vor allem anderen: Ein Abruf, der schon läuft,
        // liesse sich nicht mehr zurückholen.
        guard !DemoModus.laeuft else { return uebernehmeDemodaten() }

        // **Nur das anstossen, was nicht schon unterwegs ist.** Früher wurde der
        // ganze Durchgang verworfen, sobald irgendetwas lief — und damit fiel
        // das Nachfassen nach dem Eintragen eines Schlüssels ersatzlos weg.
        let jetzt = Date()
        let offen = Self.quellen.filter { quelle in
            guard laufendeQuellen.contains(quelle) == false else { return false }
            guard !erzwingen, let erhoben = stand(quelle) else { return true }
            return jetzt.timeIntervalSince(erhoben) >= Self.mindestalter(quelle)
        }
        guard !offen.isEmpty else { return }
        laufendeQuellen.formUnion(offen)

        claudeAbo = Self.abostufe()
        let region = Self.kimiRegion()

        // **Jede Quelle zeigt ihr Ergebnis, sobald sie es hat.**
        //
        // Vorher wurden alle fünf zusammen abgewartet, und damit hing die ganze
        // Anzeige an der langsamsten. Das ist keine theoretische Sorge: Der
        // OpenAI-Kostenabruf geht über bis zu zwölf Seiten mal mehrere
        // Endpunkte, und bis der durch war, stand auf **allen** Karten «wird
        // geholt …» — auch auf Claude, dessen Zahlen längst da waren.
        //
        // Die Karten werden nach jeder eintreffenden Quelle neu gebaut. Das ist
        // ein paarmal mehr Arbeit für die Ansicht und der Grund, warum man
        // überhaupt etwas sieht, während der Rest noch läuft.
        await withTaskGroup(of: Void.self) { gruppe in
            for quelle in offen {
                gruppe.addTask { [weak self] in await self?.hole(quelle, region: region) }
            }
        }
        // Sicherungsnetz: `hole` streicht jede Quelle selbst, sobald sie da ist.
        // Wird ein Auftrag abgebrochen, käme er dort nicht mehr an — und eine
        // Quelle, die für immer als «läuft» gilt, liesse sich nie wieder
        // anstossen.
        laufendeQuellen.subtract(offen)

        baueKarten()
        schreibeWidgetZustand()
        schreibeZwischenspeicher()
        // Zuletzt und nicht zuerst: Die Karten sollen stehen, bevor eine
        // Meldung auf sie zeigt. Was gemeldet wird, entscheidet `Mitteilungen`
        // — hier wird nur gesagt, was es Neues gibt.
        await Mitteilungen.geteilt.melde(claude: claude.wert, chatgpt: codex.wert,
                                         schwellen: schwellen)
    }

    /// Holt **eine** Quelle und zeichnet sie ein.
    ///
    /// Die Quelle wird gestrichen, bevor neu gebaut wird — so verschwindet ihr
    /// Name aus der Kopfzeile im selben Zug, in dem ihre Zahlen erscheinen.
    private func hole(_ quelle: CardLayout.Card, region: KimiClient.Region) async {
        switch quelle {
        case .claude:    claude = await Abruf.claude()
        case .chatgpt:   codex = await Abruf.codex()
        case .openai:    openAI = await Abruf.openAI()
        case .anthropic: anthropic = await Abruf.anthropic()
        case .kimi:      kimi = await Abruf.kimi(region: region)
        case .sitzungen:
            // Die einzige Karte, die tatsächlich am Mac hängt: Die laufenden
            // Sitzungen stehen in Dateien, für die es keinen Netz-Endpunkt gibt.
            break
        }
        laufendeQuellen.remove(quelle)
        // **Der Zeitstempel gehört hierhin, nicht ans Ende eines Durchgangs.**
        // Sonst kann ein zweiter, kurzer Lauf über die schnellen Quellen
        // «Aktualisiert vor 40 s» melden, während der erste OpenAI-Abruf noch
        // gar nie durchgekommen ist. «Aktualisiert vor x» heisst: seither hat
        // keine Quelle mehr etwas Neues gebracht.
        if laufendeQuellen.isEmpty { zuletztAktualisiert = Date() }
        baueKarten()
    }

    /// Aktualisiert nur, wenn die Zahlen alt genug sind.
    ///
    /// Für den Weg zurück in den Vordergrund: Wer die App zehnmal am Tag kurz
    /// aufmacht, soll nicht zehn volle Kostenläufe auslösen — sehen will er
    /// trotzdem etwas Frisches.
    func aktualisiereFallsAelterAls(_ dauer: TimeInterval) async {
        // Läuft schon etwas, ist die Frage beantwortet: frischer geht es
        // gerade nicht. Ohne diese Zeile stiess der Wechsel in den Vordergrund
        // beim Start einen zweiten Lauf an, während der erste noch unterwegs
        // war — und der holte die schnellen Quellen ein zweites Mal.
        guard laufendeQuellen.isEmpty else { return }
        guard let zuletztAktualisiert else { return await aktualisiere() }
        guard Date().timeIntervalSince(zuletztAktualisiert) >= dauer else { return }
        await aktualisiere()
    }

    /// Eine einzelne Quelle noch einmal versuchen — der Knopf an der
    /// Fehlermeldung. Die übrigen Karten bleiben unangetastet stehen, samt
    /// ihren Zahlen; sie haben mit dem Fehlschlag nichts zu tun.
    func versucheErneut(_ karte: CardLayout.Card) async {
        guard !DemoModus.laeuft else { return }
        // Nur diese eine Quelle sperren. Dass eine andere gerade läuft, geht
        // diesen Knopf nichts an — jede Quelle schreibt nur in ihr eigenes Feld.
        guard Self.quellen.contains(karte), laufendeQuellen.contains(karte) == false else { return }
        laufendeQuellen.insert(karte)

        if karte == .claude { claudeAbo = Self.abostufe() }
        await hole(karte, region: Self.kimiRegion())
        // Der Zeitstempel der Kopfzeile bleibt unangetastet: «Aktualisiert vor
        // x» meint den Abschluss eines ganzen Durchgangs, nicht den einer
        // einzelnen Quelle.
        schreibeWidgetZustand()
        schreibeZwischenspeicher()
        // Zuletzt und nicht zuerst: Die Karten sollen stehen, bevor eine
        // Meldung auf sie zeigt. Was gemeldet wird, entscheidet `Mitteilungen`
        // — hier wird nur gesagt, was es Neues gibt.
        await Mitteilungen.geteilt.melde(claude: claude.wert, chatgpt: codex.wert,
                                         schwellen: schwellen)
    }

    // MARK: - Knöpfe an den Karten

    /// Was der Knopf einer Karte auslösen soll.
    ///
    /// Was ein Knopf auf einer Karte auslöst.
    ///
    /// Die drei Schlüssel-Karten hatten lange keinen, weil es kein Ziel gab —
    /// ein Knopf ins Leere ist schlimmer als keiner. Seit es die Einstellungen
    /// gibt, führt «Eintragen» dorthin.
    enum Kartenaktion: Equatable, Sendable {
        case anmelden
        case beiChatGPTAnmelden
        /// Führt in die Einstellungen, wo der Schlüssel eingetragen wird.
        case einrichten
        case erneutVersuchen(CardLayout.Card)
    }

    func aktion(fuer karte: CardLayout.Card) -> Kartenaktion? {
        switch karte {
        case .claude:
            if case .nichtEingerichtet = claude { return .anmelden }
            if case .fehler = claude { return .erneutVersuchen(.claude) }
        case .openai:
            if case .nichtEingerichtet = openAI { return .einrichten }
            if case .fehler = openAI { return .erneutVersuchen(.openai) }
        case .anthropic:
            if case .nichtEingerichtet = anthropic { return .einrichten }
            if case .fehler = anthropic { return .erneutVersuchen(.anthropic) }
        case .kimi:
            if case .nichtEingerichtet = kimi { return .einrichten }
            if case .fehler = kimi { return .erneutVersuchen(.kimi) }
        case .chatgpt:
            if case .nichtEingerichtet = codex { return .beiChatGPTAnmelden }
            if case .fehler = codex { return .erneutVersuchen(.chatgpt) }
        case .sitzungen:
            // Die Karte gibt es hier nicht mehr; der Fall bleibt stehen, weil
            // der Kern das Layout kennt und die Aufzählung teilt.
            return nil
        }
        return nil
    }

    // MARK: - Karten bauen

    /// Der Demomodus: fertige Karten statt vier Abfragen.
    ///
    /// `zuletztAktualisiert` wird trotzdem gesetzt — die Kopfzeile soll «vor
    /// wenigen Sekunden» sagen und nicht «noch keine Daten». Auch das gehört
    /// zu dem Bild, das die Demo zeigt.
    private func uebernehmeDemodaten() {
        karten = DemoDaten.karten()
        zuletztAktualisiert = Date()
        DemoDaten.widgetZustand().schreib()
    }

    /// Die Kennungen der ausgeblendeten Karten, zerlegt.
    ///
    /// Dasselbe Format wie bei den eingeklappten Karten und der Reihenfolge:
    /// eine Liste von Kennungen. Ausblenden ist etwas anderes als Einklappen —
    /// eine eingeklappte Karte wird weiter abgerufen und zeigt ihre
    /// Kurzfassung, eine ausgeblendete gibt es nicht mehr.
    var versteckteKennungen: Set<String> {
        Set(versteckteKarten.split(separator: ",").map(String.init).filter { $0.isEmpty == false })
    }

    private func baueKarten() {
        let versteckt = versteckteKennungen
        karten = [
            claudeKarte(),
            chatgptKarte(),
            openAIKarte(),
            anthropicKarte(),
            kimiKarte()
            // Keine Sitzungskarte: Die laufenden Claude-Code-Sitzungen stehen
            // in Dateien auf dem Rechner, und dafür gibt es keinen
            // Netz-Endpunkt. Sie über eine iCloud-Brücke vom Mac zu holen wäre
            // machbar gewesen — für **eine** Karte hätte das die Mac-App
            // iCloud-Rechte gekostet und damit eine neue Prüfrunde bei Apple.
            // Bewusster Entscheid vom 20.08.2026.
        ]
        // Erst bauen, dann aussieben: Eine ausgeblendete Karte soll trotzdem
        // abgerufen worden sein — wer sie wieder einblendet, will nicht auf den
        // nächsten Durchgang warten.
        .filter { versteckt.contains($0.id.rawValue) == false }
        // An einer Stelle statt in fünf Kartenbauern: Ob eine Quelle läuft,
        // steht hier und geht die Karte selbst nichts an.
        //
        // **Nicht beim allerersten Abruf.** Dann steht der Ladehinweis samt
        // eigenem Kreisel schon in der Karte; ein zweiter oben rechts wäre
        // dieselbe Auskunft zweimal. Der Kreisel im Kopf gehört dem anderen
        // Fall: Die Karte zeigt ihre letzten Zahlen, und daneben soll stehen,
        // dass gerade neue unterwegs sind.
        .map { karte in
            var mit = karte
            let zeigtSchonLadehinweis: Bool
            if case .loading = karte.status { zeigtSchonLadehinweis = true } else { zeigtSchonLadehinweis = false }
            mit.wirdGeholt = laufendeQuellen.contains(karte.id) && !zeigtSchonLadehinweis
            return mit
        }
    }

    // MARK: Claude

    private func claudeKarte() -> CockpitCard {
        var badge: String?
        var updated: Date?
        var summary: CardSummary?
        var limits: [CockpitLimit] = []
        var status: CardStatus?
        var knopf: String?

        switch claude {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            status = .loading(String(localized: "Kontingente werden geholt …"))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht angemeldet"))
            status = .missing(String(localized: "Noch nicht bei Claude angemeldet."))
            knopf = String(localized: "Anmelden")
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let werte):
            badge = claudeAbo
            updated = werte.fetchedAt
            if let fenster = werte.fiveHour {
                limits.append(CockpitLimit(title: String(localized: "5-Stunden-Fenster"), window: fenster))
            }
            if let fenster = werte.weekly {
                limits.append(CockpitLimit(title: String(localized: "7-Tage-Fenster"), window: fenster))
            }
            // Modellbezogene Wochenfenster — was das Abo zusätzlich führt
            // (Fable 5, Sonnet, Opus). Gleichwertig zu den zwei festen Zeilen:
            // Ein volles Fable-Kontingent ist kein Nebenwert.
            for fenster in werte.weeklyScoped {
                limits.append(CockpitLimit(title: String(localized: "7 Tage · \(fenster.label)"), window: fenster))
            }
            summary = claudeKurzfassung(werte)
        }

        return CockpitCard(id: .claude, title: "Claude", provider: .claude,
                           badge: badge, updated: updated, summary: summary,
                           limits: limits, status: status, actionTitle: knopf)
    }

    /// «5 h 42 % · 7 d 88 %» — und die Modellfenster nur, wenn sie drücken.
    ///
    /// Bei drei Modellen wäre die Zeile sonst länger als die eingeklappte Karte
    /// breit ist, und das Einklappen damit entwertet.
    private func claudeKurzfassung(_ werte: ClaudeLimits) -> CardSummary? {
        var teile: [String] = []
        var warnung = false
        if let fenster = werte.fiveHour {
            teile.append("5 h: \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        if let fenster = werte.weekly {
            teile.append("7 d: \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        for fenster in werte.weeklyScoped where warnt(fenster) {
            teile.append("\(fenster.label): \(Format.percent(fenster.usedPercent))")
            warnung = true
        }
        guard !teile.isEmpty else { return nil }
        // Untereinander statt nebeneinander: Zwei Zeilen mit je einem Zeitraum
        // und einem Wert lassen sich mit einem Blick vergleichen, eine lange
        // Zeile nicht. Und es passt in jeder Schriftgrösse, ohne zu schrumpfen.
        return CardSummary(text: teile.joined(separator: "\n"), warning: warnung)
    }

    private func warnt(_ fenster: LimitWindow) -> Bool {
        fenster.usedPercent >= schwellen.warn
    }

    // MARK: OpenAI

    private func openAIKarte() -> CockpitCard {
        var updated: Date?
        var summary: CardSummary?
        var kurzFuerWidget: String?
        var geld: [CockpitMoney] = []
        var status: CardStatus?
        var knopf: String?

        switch openAI {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            // Als einzige Karte mit Begründung: Auch der schlanke Abruf muss
            // die Kostenseiten durchblättern. Das sind Sekunden, nicht mehr die
            // Minute von früher — aber ohne den Satz sieht auch das nach einem
            // Hänger aus.
            status = .loading(String(localized: "Kosten werden geholt … OpenAI gibt sie nur seitenweise heraus, das dauert ein paar Sekunden."))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht eingerichtet"))
            status = .missing(String(localized: "Kein Admin-Schlüssel hinterlegt. Diese Karte bleibt leer, bis einer da ist — sie ist keine Voraussetzung für die übrigen."))
            knopf = String(localized: "Eintragen")
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let kosten):
            updated = kosten.fetchedAt
            geld = [
                CockpitMoney(title: String(localized: "Heute"), value: kosten.today, currency: kosten.currency),
                CockpitMoney(title: String(localized: "Laufender Monat"), value: kosten.month, currency: kosten.currency),
                CockpitMoney(title: String(localized: "Gesamt"), value: kosten.total, currency: kosten.currency,
                             emphasised: true)
            ]
            summary = CardSummary(text: String(localized: "Heute \(Format.money(kosten.today, kosten.currency))\nMonat \(Format.money(kosten.month, kosten.currency))"))
            kurzFuerWidget = Format.money(kosten.month, kosten.currency)
        }

        return CockpitCard(id: .openai, title: "OpenAI-API", provider: .openAI,
                           updated: updated, summary: summary,
                           widgetKurz: kurzFuerWidget,
                           money: geld, status: status, actionTitle: knopf)
    }

    // MARK: Anthropic-API

    /// Die Kosten der Anthropic-API — etwas anderes als das Abo darüber. Wer
    /// beides zahlt, will beides sehen; deshalb trägt die Karte die Farbe von
    /// Claude, aber einen eigenen Titel.
    private func anthropicKarte() -> CockpitCard {
        var updated: Date?
        var summary: CardSummary?
        var kurzFuerWidget: String?
        var geld: [CockpitMoney] = []
        var status: CardStatus?
        var knopf: String?

        switch anthropic {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            status = .loading(String(localized: "Kosten werden geholt …"))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht eingerichtet"))
            status = .missing(String(localized: "Kein Admin-Schlüssel hinterlegt. Zeigt die Kosten der Anthropic-API — nicht das Abo darüber."))
            knopf = String(localized: "Eintragen")
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let werte):
            updated = werte.fetchedAt
            geld = [
                CockpitMoney(title: String(localized: "Heute"), value: werte.today, currency: werte.currency),
                CockpitMoney(title: String(localized: "Laufender Monat"), value: werte.month, currency: werte.currency),
                CockpitMoney(title: String(localized: "Gesamt"), value: werte.total, currency: werte.currency,
                             emphasised: true)
            ]
            summary = CardSummary(text: String(localized: "Heute \(Format.money(werte.today, werte.currency))\nMonat \(Format.money(werte.month, werte.currency))"))
            kurzFuerWidget = Format.money(werte.month, werte.currency)
        }

        return CockpitCard(id: .anthropic, title: "Anthropic-API", provider: .claude,
                           updated: updated, summary: summary,
                           widgetKurz: kurzFuerWidget,
                           money: geld, status: status, actionTitle: knopf)
    }

    // MARK: Kimi

    /// Kimi kennt nur den Kontostand. Einen Endpunkt für Tages-, Monats- oder
    /// Gesamtverbrauch gibt es nicht — das steht so in der Dokumentation, und
    /// die Karte sagt es dem Nutzer, statt ihn suchen zu lassen.
    private func kimiKarte() -> CockpitCard {
        var badge: String?
        var updated: Date?
        var summary: CardSummary?
        var kurzFuerWidget: String?
        var geld: [CockpitMoney] = []
        var status: CardStatus?
        var knopf: String?

        switch kimi {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            status = .loading(String(localized: "Kontostand wird geholt …"))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht eingerichtet"))
            status = .missing(String(localized: "Kein Schlüssel hinterlegt. Diese Karte bleibt leer, bis einer da ist."))
            knopf = String(localized: "Eintragen")
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let werte):
            // Die Währung liefert die Schnittstelle nicht mit; die Plattform
            // rechnet in Dollar, und die Mac-Fassung schreibt aus demselben
            // Grund «USD» hin.
            let waehrung = "USD"
            badge = werte.available > 0 ? String(localized: "aktiv") : String(localized: "leer")
            updated = werte.fetchedAt
            geld = [
                CockpitMoney(title: String(localized: "Verfügbares Guthaben"), value: werte.available,
                             currency: waehrung, emphasised: true),
                CockpitMoney(title: String(localized: "davon Gutscheine"), value: werte.voucher, currency: waehrung),
                CockpitMoney(title: String(localized: "davon Bargeld"), value: werte.cash, currency: waehrung)
            ]
            summary = CardSummary(text: String(localized: "\(Format.money(werte.available, waehrung)) verfügbar"),
                                  warning: werte.available <= 0)
            kurzFuerWidget = Format.money(werte.available, waehrung)
        }

        return CockpitCard(id: .kimi, title: "Kimi K3", provider: .kimi,
                           badge: badge,
                           note: String(localized: "kein Verbrauch über die Schnittstelle"),
                           updated: updated, summary: summary,
                           widgetKurz: kurzFuerWidget,
                           money: geld, status: status, actionTitle: knopf)
    }

    // MARK: Die zwei, die vom Mac kommen

    /// ChatGPT/Codex und die Sitzungen haben auf einem iPhone keine Quelle —
    /// nicht «noch nicht», sondern grundsätzlich: Das eine gibt der Codex-Dienst
    /// nur einem lokalen Programm heraus, das andere steht in Dateien unter
    /// `~/.claude/projects`.
    ///
    /// Die Karte sagt genau das. Sie zeigt keinen Ladekreisel und keinen Text,
    /// der so tut, als käme gleich etwas: Ohne laufenden Mac kommt hier nie
    /// etwas, und das ist eine Auskunft, keine Entschuldigung.
    ///
    /// - Parameter stand: Wann der Mac zuletzt geschrieben hat. Bleibt `nil`,
    ///   bis die Gegenseite in Etappe E4 steht — die Karte trägt den Wert dann
    ///   in der Kopfzeile als Alter, ohne dass hier etwas zu ändern wäre.
    // MARK: ChatGPT

    /// Die ChatGPT-Karte holt ihre Zahlen selbst.
    ///
    /// Lange stand hier, das ginge nicht: Der Codex-Dienst gebe die
    /// Kontingente nur einem Programm auf demselben Rechner heraus. Das war
    /// ein Irrtum — es gibt einen Netz-Endpunkt, siehe `CodexUsageClient`.
    private func chatgptKarte() -> CockpitCard {
        var updated: Date?
        var limits: [CockpitLimit] = []
        var status: CardStatus?
        var knopf: String?
        var badge: String?
        var summary: CardSummary?

        switch codex {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            status = .loading(String(localized: "Kontingente werden geholt …"))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht angemeldet"))
            status = .missing(String(localized: "Noch nicht bei ChatGPT angemeldet. Die Anmeldung läuft über OpenAI selbst — diese App sieht dein Passwort nie."))
            knopf = String(localized: "Anmelden")
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let werte):
            updated = werte.observedAt
            badge = werte.planType
            if let f = werte.fiveHour { limits.append(CockpitLimit(title: f.label, window: f)) }
            if let w = werte.weekly { limits.append(CockpitLimit(title: w.label, window: w)) }
            // Kein Fenster in der Antwort heisst nicht «kein Verbrauch»,
            // sondern «nichts zu sagen» — das gehört unterschieden.
            if limits.isEmpty {
                summary = CardSummary(text: String(localized: "keine Kontingente"))
                status = .missing(String(localized: "ChatGPT nennt derzeit keine Kontingente für dieses Konto."))
            } else {
                summary = chatgptKurzfassung(werte)
            }
        }

        return CockpitCard(id: .chatgpt, title: "ChatGPT", provider: .chatGPT,
                           badge: badge, updated: updated, summary: summary,
                           limits: limits, status: status, actionTitle: knopf)
    }

    /// Was von der Karte übrig bleibt, wenn sie zugeklappt ist.
    ///
    /// Ohne diese Kurzfassung lässt sich die Karte gar nicht zuklappen — die
    /// Ansicht zeigt den Pfeil nur, wenn es etwas zu zeigen gibt. Genau daran
    /// hat die ChatGPT-Karte eine Zeit lang gefehlt.
    private func chatgptKurzfassung(_ werte: CodexLimits) -> CardSummary? {
        var teile: [String] = []
        var warnung = false
        if let fenster = werte.fiveHour {
            teile.append("5 h: \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        if let fenster = werte.weekly {
            teile.append("7 d: \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        guard !teile.isEmpty else { return nil }
        return CardSummary(text: teile.joined(separator: "\n"), warning: warnung)
    }

    private func brueckenKarte(_ id: CardLayout.Card,
                               titel: String,
                               provider: Theme.Provider,
                               erklaerung: String,
                               stand: Date? = nil) -> CockpitCard {
        CockpitCard(id: id, title: titel, provider: provider,
                    updated: stand,
                    summary: CardSummary(text: String(localized: "braucht einen laufenden Mac")),
                    status: .missing(erklaerung))
    }

    // MARK: - Widget versorgen

    /// Legt in die App Group, was das Widget zeigt.
    ///
    /// Zweierlei: die Claude-Fenster für Ring und Balken, und **eine Zeile je
    /// eingeblendeter Karte mit Zahlen**. Letzteres fehlte lange — das Widget
    /// zeigte Claude und sonst nichts, obwohl in der App fünf Karten standen.
    ///
    /// Geschrieben wird nur, was gemessen wurde. Eine Karte ohne Schlüssel oder
    /// mitten im Abruf trägt einen Statushinweis; die gehört nicht aufs Widget,
    /// wo für «nicht eingerichtet» weder Platz noch Anlass ist.
    /// Legt den letzten erfolgreichen Stand ab.
    ///
    /// **Nur Erfolge.** Ein Fehlschlag darf den letzten guten Stand nicht
    /// wegwischen — dieselbe Regel wie beim Widget-Zustand darunter. Wer sich
    /// hier den `.fehler`-Fall mitspeichert, hat nach einem Netzaussetzer eine
    /// App, die beim nächsten Start leer startet.
    private func schreibeZwischenspeicher() {
        var stand = Zwischenspeicher()
        if case .daten(let w) = claude { stand.claude = .init(w) }
        if case .daten(let w) = codex { stand.codex = .init(w) }
        if case .daten(let w) = openAI { stand.openAI = .init(w) }
        if case .daten(let w) = anthropic { stand.anthropic = .init(w) }
        if case .daten(let w) = kimi { stand.kimi = .init(w) }
        stand.zuletztAktualisiert = zuletztAktualisiert
        guard !stand.istLeer else { return }
        stand.schreib()
    }

    private func schreibeWidgetZustand() {
        // Eine Zeile je eingeblendeter Karte, die Zahlen zeigt — gebaut vom
        // selben Initialisierer, den auch der Demomodus benutzt.
        let quellen = karten.compactMap(WidgetZustand.Quelle.init(karte:))

        guard case .daten(let werte) = claude else {
            // Ohne Claude gibt es keine Fenster für den Ring — die Liste der
            // übrigen Quellen aber schon, und die soll nicht mit verschwinden.
            guard !quellen.isEmpty else { return }
            WidgetZustand(erhoben: quellen.map(\.stand).min() ?? Date(),
                          fenster: [], quellen: quellen).schreib()
            return
        }

        var fenster: [WidgetZustand.Fenster] = []
        if let f = werte.fiveHour {
            fenster.append(.init(name: f.label, prozent: f.usedPercent, zuruecksetzung: f.resetsAt))
        }
        if let f = werte.weekly {
            fenster.append(.init(name: f.label, prozent: f.usedPercent, zuruecksetzung: f.resetsAt))
        }
        for f in werte.weeklyScoped {
            fenster.append(.init(name: f.label, prozent: f.usedPercent, zuruecksetzung: f.resetsAt))
        }

        // **Der älteste Stand zählt.** Er steht als «vor x» auf der Kachel, und
        // die Aussage muss für alles gelten, was dort steht — nicht nur für die
        // Zeile, die zufällig zuletzt geholt wurde.
        let aeltester = ([werte.fetchedAt] + quellen.map(\.stand)).min() ?? werte.fetchedAt
        WidgetZustand(erhoben: aeltester, fenster: fenster, quellen: quellen).schreib()
    }

    // MARK: - Kleinkram

    /// Lange Meldungen passen nicht in eine Kopfzeile; aufgeklappt stehen sie
    /// vollständig da. Dieselbe Grenze wie auf dem Mac.
    private func kurz(_ meldung: String) -> CardSummary {
        CardSummary(text: meldung.count > 40 ? String(localized: "Fehler") : meldung, warning: true)
    }

    /// «Max 5×», «Pro». Der Kern liest die Stufe eigentlich aus
    /// `~/.claude.json` — die Datei gibt es auf einem iPhone nicht, also greift
    /// dort der Rückfall auf den Token und liefert denselben lesbaren Namen.
    private static func abostufe() -> String? {
        ClaudeAccount.subscription(fallback: Zugaenge().liesToken()?.subscriptionType)
    }

    /// Wie eine Quelle in der Kopfzeile heisst, solange sie noch läuft.
    ///
    /// Dieselben Namen wie auf den Karten — ein zweiter Satz Bezeichnungen wäre
    /// für den Leser eine zweite Liste zum Zuordnen.
    private static func name(fuer karte: CardLayout.Card) -> String {
        switch karte {
        case .claude: return "Claude"
        case .chatgpt: return "ChatGPT"
        case .openai: return String(localized: "OpenAI-API")
        case .anthropic: return String(localized: "Anthropic-API")
        case .kimi: return "Kimi K3"
        case .sitzungen: return String(localized: "Sitzungen")
        }
    }

    /// Aus den Benutzervorgaben, unter demselben Schlüsselnamen wie auf dem
    /// Mac. Ohne Angabe gilt die internationale Plattform — die chinesische
    /// hängt an einem anderen Server, das ist keine Kleinigkeit zum Raten.
    private static func kimiRegion() -> KimiClient.Region {
        let roh = UserDefaults.standard.string(forKey: "kimiRegion") ?? ""
        return KimiClient.Region(rawValue: roh) ?? .international
    }
}

// MARK: - Die Abrufe

/// Die vier Netzabrufe, bewusst **ausserhalb** von `Cockpit`.
///
/// Sie brauchen nichts vom Hauptakteur und sollen ihn auch nicht besetzen: Was
/// hier läuft, sind Sekunden am Netz, und die gehören nicht auf den Strang, der
/// die Oberfläche zeichnet. Jede Funktion gibt einen Zustand zurück statt zu
/// werfen — so kann keine von ihnen die anderen mitreissen.
private enum Abruf {

    // MARK: Claude

    static func claude() async -> Quellenstand<ClaudeLimits> {
        let zugaenge = Zugaenge()
        var token: OAuthTokens

        switch zugaenge.pruefeToken() {
        case .fehlt:
            return .nichtEingerichtet
        case .verweigert(let status):
            // Auf iOS gibt es keinen Zustimmungsdialog wie auf dem Mac. Wenn
            // der Schlüsselbund hier abweist, passen Zugriffsgruppe und
            // Provisioning-Profil nicht zusammen — das ist ein Fehler im Bau
            // der App und keiner, den der Nutzer verursacht hat.
            return .fehler(String(localized: "Der Schlüsselbund gibt die Anmeldung nicht heraus (Status \(status))."))
        case .unlesbar:
            return .fehler(String(localized: "Die gespeicherte Anmeldung ist unlesbar — bitte abmelden und neu anmelden."))
        case .token(let gefunden):
            token = gefunden
        }

        let auth = ClaudeAuth()
        let usage = ClaudeUsageClient()
        // **Genau einmal.** Ein zweiter Refresh-Vorgang im selben Durchgang
        // löste denselben Token ein zweites Mal ein; sobald Anthropic ihn
        // dreht, scheitert der zweite — und die Anmeldung sieht kaputt aus,
        // obwohl sie es nicht ist.
        var schonErneuert = false

        do {
            if token.isExpired {
                token = try await auth.refresh(token)
                zugaenge.schreibToken(token)
                schonErneuert = true
            }
            return .daten(try await usage.fetch(accessToken: token.accessToken))
        } catch let fehler as ProviderError {
            // Ein abgelaufener Token kann auch ohne gesetztes `expiresAt`
            // auftreten — dann sagt es erst die Gegenstelle.
            guard case .unauthorized = fehler, !schonErneuert,
                  let erneuert = try? await auth.refresh(token) else {
                return .fehler(fehler.userMessage)
            }
            zugaenge.schreibToken(erneuert)
            do {
                return .daten(try await usage.fetch(accessToken: erneuert.accessToken))
            } catch {
                // Die Meldung des **zweiten** Versuchs zählt — sonst stünde da
                // die längst behobene erste Ursache.
                return .fehler(meldung(error))
            }
        } catch {
            return .fehler(meldung(error))
        }
    }

    // MARK: ChatGPT

    /// Wie `claude()`, nur beim anderen Dienst — und mit demselben Grundsatz:
    /// **genau einmal** erneuern. Ein zweiter Anlauf im selben Durchgang löste
    /// denselben Schlüssel ein zweites Mal ein.
    static func codex() async -> Quellenstand<CodexLimits> {
        let zugaenge = Zugaenge()
        var token: CodexToken

        switch zugaenge.pruefeCodexToken() {
        case .fehlt:
            return .nichtEingerichtet
        case .verweigert(let status):
            return .fehler(String(localized: "Der Schlüsselbund gibt die ChatGPT-Anmeldung nicht heraus (Status \(status))."))
        case .unlesbar:
            return .fehler(String(localized: "Die gespeicherte ChatGPT-Anmeldung ist unlesbar — bitte abmelden und neu anmelden."))
        case .token(let gefunden):
            token = gefunden
        }

        let auth = CodexAuth()
        let usage = CodexUsageClient()
        // **Genau einmal**, aus demselben Grund wie bei Claude: Ein zweiter
        // Anlauf im selben Durchgang löste denselben Schlüssel ein zweites Mal
        // ein, und die Anmeldung sähe kaputt aus, obwohl sie es nicht ist.
        var schonErneuert = false

        do {
            if token.isExpired {
                token = try await auth.erneuere(token)
                zugaenge.schreibCodexToken(token)
                schonErneuert = true
            }
            return .daten(try await usage.fetch(token: token))
        } catch let fehler as ProviderError {
            // `.unauthorized`, nicht `.notSignedIn`: Das wirft der Abruf bei
            // 401/403, also genau im Fall «Schlüssel abgelaufen, ohne dass
            // `expiresAt` es sagte». `.notSignedIn` trifft dagegen den Fall
            // «gar kein Erneuerungsschlüssel da» — dort ist ein zweiter
            // Versuch sinnlos. Der Claude-Pfad darüber macht es richtig.
            guard case .unauthorized = fehler, !schonErneuert,
                  let erneuert = try? await auth.erneuere(token) else {
                return .fehler(fehler.userMessage)
            }
            zugaenge.schreibCodexToken(erneuert)
            do { return .daten(try await usage.fetch(token: erneuert)) }
            catch { return .fehler(meldung(error)) }
        } catch {
            return .fehler(meldung(error))
        }
    }

    // MARK: OpenAI

    /// **`costs` statt `fetch` — und das ist der Unterschied zwischen ein paar
    /// Sekunden und über einer Minute.**
    ///
    /// `fetch` lädt zusätzlich Projekte und Kosten je Modell: zwei serverseitig
    /// gruppierte Seitenläufe, nacheinander und jeder mit einem zweiten Anlauf.
    /// Genau die beiden sind es, die bei OpenAI regelmässig ins Zeitlimit
    /// laufen. Diese Karte zeigt Heute, laufenden Monat und Gesamt — sie hat
    /// über eine Minute auf Daten gewartet, die sie nie angesehen hat.
    static func openAI() async -> Quellenstand<OpenAICosts> {
        guard let schluessel = Zugaenge().liesText(.openAIAdminKey), !schluessel.isEmpty else {
            return .nichtEingerichtet
        }
        do {
            return .daten(try await OpenAIUsageClient().costs(adminKey: schluessel))
        } catch {
            return .fehler(meldung(error))
        }
    }

    // MARK: Anthropic-API

    static func anthropic() async -> Quellenstand<AnthropicCosts> {
        guard let schluessel = Zugaenge().liesText(.anthropicAdminKey), !schluessel.isEmpty else {
            return .nichtEingerichtet
        }
        do {
            return .daten(try await AnthropicAdminClient().fetch(adminKey: schluessel))
        } catch {
            return .fehler(meldung(error))
        }
    }

    // MARK: Kimi

    static func kimi(region: KimiClient.Region) async -> Quellenstand<KimiClient.Balance> {
        guard let schluessel = Zugaenge().liesText(.kimiAPIKey), !schluessel.isEmpty else {
            return .nichtEingerichtet
        }
        do {
            return .daten(try await KimiClient().balance(apiKey: schluessel, region: region))
        } catch {
            return .fehler(meldung(error))
        }
    }

    /// `ProviderError` bringt bereits einen Satz mit, den man einem Menschen
    /// zeigen kann — samt Wartezeit bei einer Drosselung. Alles andere hat
    /// wenigstens `localizedDescription`.
    private static func meldung(_ fehler: any Error) -> String {
        (fehler as? ProviderError)?.userMessage ?? fehler.localizedDescription
    }
}

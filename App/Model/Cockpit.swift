import Foundation
import Observation
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
    private(set) var wirdAktualisiert = false

    /// Kennungen der eingeklappten Karten, mit Komma getrennt — dasselbe
    /// Format wie `AppSettings.collapsedCards` auf dem Mac. Zerlegt wird es von
    /// `CardLayout` im Kern; hier wird es nur gehalten und gesichert.
    var eingeklappteKarten: String {
        didSet {
            guard eingeklappteKarten != oldValue else { return }
            UserDefaults.standard.set(eingeklappteKarten, forKey: Self.schluesselEingeklappt)
        }
    }

    /// Solange es keine Einstellungen gibt, gelten die Vorgaben der Mac-Fassung
    /// (75 / 90). Sie hier als Eigenschaft zu führen statt an jeder Fundstelle
    /// `.standard` zu schreiben, ist der Unterschied zwischen einer späteren
    /// Zeile und einer späteren Suche.
    let schwellen = LimitThresholds.standard

    /// Die Abostufe zum angemeldeten Konto — steht als Etikett neben «Claude».
    private(set) var claudeAbo: String?

    // MARK: - Zustand je Quelle

    private var claude: Quellenstand<ClaudeLimits> = .laedt
    private var openAI: Quellenstand<OpenAIUsageClient.Snapshot> = .laedt
    private var anthropic: Quellenstand<AnthropicCosts> = .laedt
    private var kimi: Quellenstand<KimiClient.Balance> = .laedt

    private static let schluesselEingeklappt = "collapsedCards"

    init() {
        eingeklappteKarten = UserDefaults.standard.string(forKey: Self.schluesselEingeklappt) ?? ""
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
    func aktualisiere() async {
        // Zwei gleichzeitige Läufe würden denselben Refresh-Token doppelt
        // einlösen; der zweite scheitert, sobald Anthropic ihn dreht.
        guard !wirdAktualisiert else { return }
        wirdAktualisiert = true
        defer { wirdAktualisiert = false }

        claudeAbo = Self.abostufe()
        let region = Self.kimiRegion()

        async let claudeLauf = Abruf.claude()
        async let openAILauf = Abruf.openAI()
        async let anthropicLauf = Abruf.anthropic()
        async let kimiLauf = Abruf.kimi(region: region)

        let (c, o, a, k) = await (claudeLauf, openAILauf, anthropicLauf, kimiLauf)
        claude = c
        openAI = o
        anthropic = a
        kimi = k

        zuletztAktualisiert = Date()
        baueKarten()
        schreibeWidgetZustand()
    }

    /// Aktualisiert nur, wenn die Zahlen alt genug sind.
    ///
    /// Für den Weg zurück in den Vordergrund: Wer die App zehnmal am Tag kurz
    /// aufmacht, soll nicht zehn volle Kostenläufe auslösen — sehen will er
    /// trotzdem etwas Frisches.
    func aktualisiereFallsAelterAls(_ dauer: TimeInterval) async {
        guard let zuletztAktualisiert else { return await aktualisiere() }
        guard Date().timeIntervalSince(zuletztAktualisiert) >= dauer else { return }
        await aktualisiere()
    }

    /// Eine einzelne Quelle noch einmal versuchen — der Knopf an der
    /// Fehlermeldung. Die übrigen Karten bleiben unangetastet stehen, samt
    /// ihren Zahlen; sie haben mit dem Fehlschlag nichts zu tun.
    func versucheErneut(_ karte: CardLayout.Card) async {
        guard !wirdAktualisiert else { return }
        wirdAktualisiert = true
        defer { wirdAktualisiert = false }

        switch karte {
        case .claude:
            claude = await Abruf.claude()
            claudeAbo = Self.abostufe()
        case .openai:
            openAI = await Abruf.openAI()
        case .anthropic:
            anthropic = await Abruf.anthropic()
        case .kimi:
            kimi = await Abruf.kimi(region: Self.kimiRegion())
        case .chatgpt, .sitzungen:
            // Die beiden hängen am Mac, nicht an einer Abfrage von hier.
            return
        }
        baueKarten()
        schreibeWidgetZustand()
    }

    // MARK: - Knöpfe an den Karten

    /// Was der Knopf einer Karte auslösen soll.
    ///
    /// Absichtlich nur die zwei Fälle, für die es heute ein Ziel gibt. Ein
    /// dritter («Einrichten» für die drei API-Schlüssel) hätte keines: Ein
    /// Einstellungsfenster gibt es noch nicht, und ein Knopf, der ins Leere
    /// führt, ist schlimmer als kein Knopf. Die Karten dieser Dienste laden
    /// deshalb im Text ein statt mit einer Fläche.
    enum Kartenaktion: Equatable, Sendable {
        case anmelden
        case erneutVersuchen(CardLayout.Card)
    }

    func aktion(fuer karte: CardLayout.Card) -> Kartenaktion? {
        switch karte {
        case .claude:
            if case .nichtEingerichtet = claude { return .anmelden }
            if case .fehler = claude { return .erneutVersuchen(.claude) }
        case .openai:
            if case .fehler = openAI { return .erneutVersuchen(.openai) }
        case .anthropic:
            if case .fehler = anthropic { return .erneutVersuchen(.anthropic) }
        case .kimi:
            if case .fehler = kimi { return .erneutVersuchen(.kimi) }
        case .chatgpt, .sitzungen:
            return nil
        }
        return nil
    }

    // MARK: - Karten bauen

    private func baueKarten() {
        karten = [
            claudeKarte(),
            brueckenKarte(.chatgpt, titel: "ChatGPT", provider: .chatGPT,
                          erklaerung: String(localized: "Die ChatGPT-Kontingente gibt der Codex-Dienst nur einem Programm auf demselben Rechner heraus. Sie kommen vom Mac herüber, sobald AI Cockpit dort läuft.")),
            openAIKarte(),
            anthropicKarte(),
            kimiKarte(),
            brueckenKarte(.sitzungen, titel: String(localized: "Aktive Sitzungen"), provider: .sessions,
                          erklaerung: String(localized: "Die laufenden Claude-Code-Sitzungen stehen in Dateien auf dem Mac. Sie kommen von dort herüber, sobald AI Cockpit läuft."))
        ]
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
            teile.append("5 h \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        if let fenster = werte.weekly {
            teile.append("7 d \(Format.percent(fenster.usedPercent))")
            warnung = warnung || warnt(fenster)
        }
        for fenster in werte.weeklyScoped where warnt(fenster) {
            teile.append("\(fenster.label) \(Format.percent(fenster.usedPercent))")
            warnung = true
        }
        guard !teile.isEmpty else { return nil }
        return CardSummary(text: teile.joined(separator: " · "), warning: warnung)
    }

    private func warnt(_ fenster: LimitWindow) -> Bool {
        fenster.usedPercent >= schwellen.warn
    }

    // MARK: OpenAI

    private func openAIKarte() -> CockpitCard {
        var updated: Date?
        var summary: CardSummary?
        var geld: [CockpitMoney] = []
        var status: CardStatus?
        var knopf: String?

        switch openAI {
        case .laedt:
            summary = CardSummary(text: String(localized: "wird geholt …"))
            status = .loading(String(localized: "Kosten werden geholt …"))
        case .nichtEingerichtet:
            summary = CardSummary(text: String(localized: "nicht eingerichtet"))
            status = .missing(String(localized: "Kein Admin-Schlüssel hinterlegt. Diese Karte bleibt leer, bis einer da ist — sie ist keine Voraussetzung für die übrigen."))
        case .fehler(let text):
            summary = kurz(text)
            status = .failed(text)
            knopf = String(localized: "Erneut versuchen")
        case .daten(let werte):
            let kosten = werte.costs
            updated = kosten.fetchedAt
            geld = [
                CockpitMoney(title: String(localized: "Heute"), value: kosten.today, currency: kosten.currency),
                CockpitMoney(title: String(localized: "Laufender Monat"), value: kosten.month, currency: kosten.currency),
                CockpitMoney(title: String(localized: "Gesamt"), value: kosten.total, currency: kosten.currency,
                             emphasised: true)
            ]
            summary = CardSummary(text: String(localized: "Heute \(Format.money(kosten.today, kosten.currency)) · Monat \(Format.money(kosten.month, kosten.currency))"))
        }

        return CockpitCard(id: .openai, title: "OpenAI-API", provider: .openAI,
                           updated: updated, summary: summary,
                           money: geld, status: status, actionTitle: knopf)
    }

    // MARK: Anthropic-API

    /// Die Kosten der Anthropic-API — etwas anderes als das Abo darüber. Wer
    /// beides zahlt, will beides sehen; deshalb trägt die Karte die Farbe von
    /// Claude, aber einen eigenen Titel.
    private func anthropicKarte() -> CockpitCard {
        var updated: Date?
        var summary: CardSummary?
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
            summary = CardSummary(text: String(localized: "Heute \(Format.money(werte.today, werte.currency)) · Monat \(Format.money(werte.month, werte.currency))"))
        }

        return CockpitCard(id: .anthropic, title: "Anthropic-API", provider: .claude,
                           updated: updated, summary: summary,
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
        }

        return CockpitCard(id: .kimi, title: "Kimi K3", provider: .kimi,
                           badge: badge,
                           note: String(localized: "kein Verbrauch über die Schnittstelle"),
                           updated: updated, summary: summary,
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

    /// Legt die Claude-Fenster in die App Group.
    ///
    /// Nur bei Erfolg: Ein fehlgeschlagener Abruf soll den letzten guten Stand
    /// nicht wegwischen. Das Widget zeigt lieber eine Zahl von vorhin — mit
    /// ihrem Alter daneben — als gar keine.
    private func schreibeWidgetZustand() {
        guard case .daten(let werte) = claude else { return }

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

        WidgetZustand(erhoben: werte.fetchedAt, fenster: fenster).schreib()
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

    /// Solange es keine Einstellungen gibt, gilt die internationale Plattform.
    /// Gelesen wird trotzdem aus den Benutzervorgaben, und unter demselben
    /// Schlüsselnamen wie auf dem Mac: Steht dort später einmal etwas, wirkt es
    /// ohne eine Zeile Änderung hier.
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

    // MARK: OpenAI

    static func openAI() async -> Quellenstand<OpenAIUsageClient.Snapshot> {
        guard let schluessel = Zugaenge().liesText(.openAIAdminKey), !schluessel.isEmpty else {
            return .nichtEingerichtet
        }
        do {
            return .daten(try await OpenAIUsageClient().fetch(adminKey: schluessel))
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

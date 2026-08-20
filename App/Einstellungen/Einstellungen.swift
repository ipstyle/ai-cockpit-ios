import Foundation
import Observation
import Security
import WidgetKit
import AgentDeckCore

// Was sich einstellen lässt — und wo es liegt.
//
// Zwei Ablageorte, und die Trennung dazwischen ist die einzige Regel, die in
// dieser Datei wirklich zählt:
//
// - **Benutzervorgaben** für alles, was man beim Weitergeben des Geräts
//   achselzuckend hinnehmen würde: Darstellung, Schwellen, Kimi-Plattform.
// - **Schlüsselbund** für alles, was Zugriff auf ein fremdes Konto gibt.
//
// Es gibt keinen dritten Weg. Ein API-Schlüssel «kurz zum Testen» in
// `UserDefaults` liegt in einer Datei, die jedes Backup mitnimmt und jede
// Diagnose auslesen kann — und er bleibt dort, weil niemand die Zeile später
// wiederfindet.
//
// Ebenso wenig steht ein Schlüsselwert je in einer Logausgabe oder im
// Diagnosetext. Was diese Datei nach aussen gibt, sind Zustände: vorhanden,
// fehlt, verweigert — und höchstens die letzten vier Zeichen, damit man zwei
// Schlüssel auseinanderhalten kann, ohne einen davon lesen zu müssen.

/// Was der Schlüsselbund zu einem hinterlegten Schlüssel sagt — ohne ihn
/// herauszugeben.
enum SchluesselZustand: Equatable, Sendable {
    case fehlt
    /// Hinterlegt. `endung` sind die letzten bis zu vier Zeichen, mehr nicht.
    case hinterlegt(endung: String)
    /// Der Schlüsselbund weist den Zugriff ab. Auf iOS heisst das fast immer,
    /// dass Zugriffsgruppe und Provisioning-Profil nicht zusammenpassen — ein
    /// Fehler im Bau der App, den kein Nutzer beheben kann. Deshalb steht der
    /// Status daneben: Ohne ihn ist «geht nicht» die ganze Auskunft.
    case verweigert(OSStatus)

    var istHinterlegt: Bool {
        if case .hinterlegt = self { return true }
        return false
    }
}

/// Wie es um die Claude-Anmeldung steht.
enum ClaudeZustand: Equatable, Sendable {
    case nichtAngemeldet
    /// `ablauf` ist der Zeitpunkt, an dem der Zugriffsschlüssel ungültig wird.
    /// Die App erneuert ihn selbst — die Angabe steht da, damit ein Fehlschlag
    /// einordbar wird, nicht als Handlungsaufforderung.
    case angemeldet(ablauf: Date?, abo: String?)
    case verweigert(OSStatus)
    /// Eintrag vorhanden, aber nicht lesbar. Etwas anderes als «nicht
    /// angemeldet»: Hier hilft Abmelden und neu anmelden, dort nur anmelden.
    case unlesbar

    var istAngemeldet: Bool {
        if case .angemeldet = self { return true }
        return false
    }
}

@MainActor
@Observable
final class Einstellungen {

    // MARK: - Benutzervorgaben

    /// Die Schlüsselnamen sind **buchstabengleich zur Mac-Fassung**
    /// (`AppSettings.swift`). Das kostet hier nichts und hält die Tür für einen
    /// späteren Abgleich über iCloud offen — ein umbenannter Rohwert wäre der
    /// Unterschied zwischen «wird übernommen» und «steht wieder auf Vorgabe».
    private enum Schluessel {
        static let darstellung = "appearanceMode"
        static let kimiRegion = "kimiRegion"
        static let warn = "warnThreshold"
        static let kritisch = "criticalThreshold"
        static let eingeklappteKarten = "collapsedCards"

        static let alle = [darstellung, kimiRegion, warn, kritisch, eingeklappteKarten]
    }

    var darstellung: AppAppearance {
        didSet { vorgaben.set(darstellung.rawValue, forKey: Schluessel.darstellung) }
    }

    /// Welche der beiden Kimi-Plattformen gemeint ist.
    ///
    /// Keine Kleinigkeit und keine Vorliebe: Ein Schlüssel von
    /// `platform.kimi.ai` gilt nur gegen `api.moonshot.ai`, einer von
    /// `platform.kimi.com` nur gegen `api.moonshot.cn`. Über Kreuz kommt ein
    /// 401 zurück — und der sieht aus wie ein falscher Schlüssel.
    var kimiRegion: KimiClient.Region {
        didSet { vorgaben.set(kimiRegion.rawValue, forKey: Schluessel.kimiRegion) }
    }

    var warnSchwelle: Double {
        didSet {
            vorgaben.set(warnSchwelle, forKey: Schluessel.warn)
            // Die kritische Schwelle wird mitgeschoben statt der Warnschwelle
            // eine Obergrenze zu geben: Wer die Warnung hochzieht, meint «erst
            // ab hier ist es knapp» — und nicht, dass die Warnung künftig
            // hinter dem Alarm kommt.
            if kritischeSchwelle < warnSchwelle { kritischeSchwelle = warnSchwelle }
        }
    }

    var kritischeSchwelle: Double {
        didSet {
            let gedeckelt = max(kritischeSchwelle, warnSchwelle)
            guard gedeckelt == kritischeSchwelle else {
                kritischeSchwelle = gedeckelt
                return
            }
            vorgaben.set(kritischeSchwelle, forKey: Schluessel.kritisch)
        }
    }

    /// Die beiden Schwellen in der Form, die `LimitRow` und `UsageBar` erwarten.
    var schwellen: LimitThresholds {
        LimitThresholds(warn: warnSchwelle, critical: kritischeSchwelle)
    }

    // MARK: - Schlüsselbund

    /// Der zuletzt gelesene Stand — gehalten, nicht bei jedem Bildaufbau frisch
    /// geholt.
    ///
    /// Nicht aus Sparsamkeit: Ein Schlüsselbundzugriff wäre für SwiftUI
    /// **unsichtbar**. Eine Ansicht zeichnet nicht neu, weil sich draussen
    /// etwas geändert hat — sie zeichnet neu, weil etwas Beobachtbares sich
    /// geändert hat. Beobachtbar ist dieses Wörterbuch.
    private(set) var schluesselstand: [Zugaenge.Zugang: SchluesselZustand] = [:]
    private(set) var claudeZustand: ClaudeZustand = .nichtAngemeldet

    /// Die drei Schlüssel — ohne die Claude-Anmeldung, die kein eingetippter
    /// Wert ist, sondern ein Anmeldevorgang.
    static let schluesselDienste: [Zugaenge.Zugang] = [.openAIAdminKey, .anthropicAdminKey, .kimiAPIKey]

    private let vorgaben: UserDefaults
    private let zugaenge = Zugaenge()

    // MARK: - Anlegen

    init(vorgaben: UserDefaults = .standard) {
        self.vorgaben = vorgaben
        // «System» als Vorgabe, nicht «Dunkel» wie auf dem Mac: Solange niemand
        // gewählt hat, soll die App keine Meinung haben — ein iPhone, das im
        // Kontrollzentrum auf hell steht, hat die Frage bereits beantwortet.
        darstellung = AppAppearance(rawValue: vorgaben.string(forKey: Schluessel.darstellung) ?? "") ?? .system
        kimiRegion = KimiClient.Region(rawValue: vorgaben.string(forKey: Schluessel.kimiRegion) ?? "") ?? .international
        // Der Umweg über `object(forKey:)` ist nötig: `double(forKey:)` gibt
        // für einen fehlenden Wert 0 zurück, und eine Warnschwelle von 0 %
        // schlüge bei jedem Kontingent an, das je benutzt wurde.
        warnSchwelle = (vorgaben.object(forKey: Schluessel.warn) as? Double) ?? LimitThresholds.standard.warn
        kritischeSchwelle = (vorgaben.object(forKey: Schluessel.kritisch) as? Double) ?? LimitThresholds.standard.critical
        aktualisiereStand()
    }

    // MARK: - Nachsehen

    /// Liest den Schlüsselbund neu. Nach jeder Änderung — sonst zeigt die
    /// Ansicht den Stand von vorhin und man drückt ein zweites Mal.
    func aktualisiereStand() {
        var stand: [Zugaenge.Zugang: SchluesselZustand] = [:]
        for zugang in Self.schluesselDienste {
            stand[zugang] = Self.deute(zugaenge.pruefe(zugang))
        }
        schluesselstand = stand
        claudeZustand = Self.deute(zugaenge.pruefeToken())
    }

    func zustand(_ zugang: Zugaenge.Zugang) -> SchluesselZustand {
        schluesselstand[zugang] ?? .fehlt
    }

    private static func deute(_ fund: Zugaenge.Fund) -> SchluesselZustand {
        switch fund {
        case .fehlt:
            return .fehlt
        case .verweigert(let status):
            return .verweigert(status)
        case .gefunden(let daten):
            // Der Wert wird hier zwar kurz in Text verwandelt, aber nur, um die
            // letzten vier Zeichen abzuschneiden. Weiter als bis zur nächsten
            // Zeile kommt er nicht.
            let endung = String((String(data: daten, encoding: .utf8) ?? "").suffix(4))
            return .hinterlegt(endung: endung)
        }
    }

    private static func deute(_ fund: Zugaenge.TokenFund) -> ClaudeZustand {
        switch fund {
        case .fehlt:
            return .nichtAngemeldet
        case .verweigert(let status):
            return .verweigert(status)
        case .unlesbar:
            return .unlesbar
        case .token(let token):
            // Claude legt den Ablauf als Unix-Zeit in **Millisekunden** ab —
            // dieselbe Schreibweise wie Claude Code. Wer die 1000 vergisst,
            // landet im Jahr 56 000 und wundert sich über die Anzeige.
            let ablauf = token.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) }
            return .angemeldet(ablauf: ablauf, abo: token.subscriptionType)
        }
    }

    // MARK: - Ändern

    /// Legt einen Schlüssel ab.
    ///
    /// Der Wert wird vorher von Leerraum befreit. Das ist keine Kosmetik: Ein
    /// aus einer Mail kopierter Schlüssel bringt regelmässig einen Zeilenumbruch
    /// mit, und der Kopfzeile einer HTTP-Anfrage ist er nicht egal — die
    /// Gegenseite antwortet mit 401, und der Schlüssel gilt als falsch.
    @discardableResult
    func sichere(_ eingabe: String, in zugang: Zugaenge.Zugang) -> Bool {
        let sauber = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return false }
        let erfolg = zugaenge.schreib(sauber, nach: zugang)
        aktualisiereStand()
        return erfolg
    }

    func loesche(_ zugang: Zugaenge.Zugang) {
        zugaenge.loesche(zugang)
        aktualisiereStand()
    }

    /// Meldet von Claude ab — der Token wird gelöscht, sonst nichts.
    func meldeAb() {
        zugaenge.loesche(.claudeOAuth)
        aktualisiereStand()
    }

    /// Abmelden und alles Lokale wegräumen.
    ///
    /// «Alles» heisst hier wirklich alles, was diese App je abgelegt hat: die
    /// vier Schlüsselbund-Einträge, die Benutzervorgaben und der Stand, den das
    /// Widget liest. Letzterer wird gerne vergessen — er liegt in der App
    /// Group, nicht in den Vorgaben der App, und bliebe sonst als Zahlenrest
    /// auf dem Sperrbildschirm stehen, nachdem drinnen längst nichts mehr ist.
    func loescheAlles() {
        for zugang in Zugaenge.Zugang.allCases { zugaenge.loesche(zugang) }

        // Erst die Werte auf die Vorgaben stellen, dann die Schlüssel
        // entfernen: Die `didSet`-Beobachter schreiben beim Zuweisen zurück,
        // und in dieser Reihenfolge bleibt am Ende nichts stehen.
        darstellung = .system
        kimiRegion = .international
        warnSchwelle = LimitThresholds.standard.warn
        kritischeSchwelle = LimitThresholds.standard.critical
        for schluessel in Schluessel.alle { vorgaben.removeObject(forKey: schluessel) }

        AppGruppe.vorgaben?.removeObject(forKey: WidgetZustand.schluessel)
        WidgetCenter.shared.reloadAllTimelines()

        aktualisiereStand()
    }

    // MARK: - Diagnose

    /// Der Text, der im Fehlerfall zwei Tage spart.
    ///
    /// Er beantwortet die drei Fragen, die man sonst nur durch Ausprobieren
    /// klärt: Ist die App Group überhaupt erreichbar, was sagt der
    /// Schlüsselbund zu jedem einzelnen Eintrag, und wie alt sind die Zahlen.
    /// Besonders der Unterschied zwischen «fehlt» und «verweigert» ist der
    /// zwischen zwei Minuten und zwei Tagen Suche.
    ///
    /// Was **nicht** darin steht: irgendein Schlüsselwert. Nur die letzten vier
    /// Zeichen, und die stehen auch in der Oberfläche.
    func diagnoseText(zuletztAktualisiert: Date?) -> String {
        var zeilen: [String] = []
        zeilen.append("AI Cockpit (iOS) — Diagnose")
        zeilen.append("Erstellt: \(Self.zeitstempel(Date()))")
        zeilen.append("Version: \(AppKennung.version)")
        zeilen.append("")

        zeilen.append("App Group")
        zeilen.append("  Kennung:    \(AppGruppe.kennung)")
        zeilen.append("  Erreichbar: \(AppGruppe.erreichbar ? "ja" : "nein")")
        if !AppGruppe.erreichbar {
            zeilen.append("  Hinweis:    Die Kennung steht nicht in beiden Berechtigungsdateien — das Widget bleibt leer.")
        }
        zeilen.append("")

        zeilen.append("Schlüsselbund (Dienst «\(Zugaenge.dienst)»)")
        zeilen.append("  \(Zugaenge.Zugang.claudeOAuth.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)) \(Self.beschreibe(claudeZustand))")
        for zugang in Self.schluesselDienste {
            let name = zugang.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0)
            zeilen.append("  \(name) \(Self.beschreibe(zustand(zugang)))")
        }
        zeilen.append("")

        zeilen.append("Daten")
        if let zuletztAktualisiert {
            zeilen.append("  Zuletzt aktualisiert: \(Self.zeitstempel(zuletztAktualisiert)) (\(Theme.ago(zuletztAktualisiert)))")
        } else {
            zeilen.append("  Zuletzt aktualisiert: noch nie")
        }
        if let stand = WidgetZustand.lies() {
            zeilen.append("  Widget-Stand:         \(stand.fenster.count) Fenster, erhoben \(Self.zeitstempel(stand.erhoben))")
        } else {
            zeilen.append("  Widget-Stand:         keiner abgelegt")
        }
        zeilen.append("")

        zeilen.append("Einstellungen")
        zeilen.append("  Darstellung:    \(darstellung.rawValue)")
        zeilen.append("  Kimi-Plattform: \(kimiRegion.rawValue) (\(kimiRegion.apiHost))")
        zeilen.append("  Schwellen:      Warnung \(Int(warnSchwelle)) %, kritisch \(Int(kritischeSchwelle)) %")

        return zeilen.joined(separator: "\n")
    }

    private static func beschreibe(_ zustand: SchluesselZustand) -> String {
        switch zustand {
        case .fehlt: return "fehlt"
        case .hinterlegt(let endung): return "vorhanden (…\(endung))"
        case .verweigert(let status): return "verweigert (Status \(status))"
        }
    }

    private static func beschreibe(_ zustand: ClaudeZustand) -> String {
        switch zustand {
        case .nichtAngemeldet:
            return "fehlt (nicht angemeldet)"
        case .angemeldet(let ablauf, let abo):
            let bis = ablauf.map(zeitstempel) ?? "unbekannt"
            return "vorhanden (Abo \(abo ?? "unbekannt"), gültig bis \(bis))"
        case .verweigert(let status):
            return "verweigert (Status \(status))"
        case .unlesbar:
            return "vorhanden, aber unlesbar"
        }
    }

    private static func zeitstempel(_ datum: Date) -> String {
        datum.formatted(date: .numeric, time: .standard)
    }
}

// MARK: - Version

/// Fassung und Bauzahl der App, an einer Stelle.
///
/// Sie stehen in der Diagnose **und** im Über-Fenster — und müssen dort
/// dieselben sein. Zweimal aus `Bundle.main` zu lesen wäre keine Kopie, aber
/// zwei Formulierungen, und die eine altert.
enum AppKennung {
    static var kurz: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    static var bau: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }
    static var version: String { "\(kurz) (Build \(bau))" }
}

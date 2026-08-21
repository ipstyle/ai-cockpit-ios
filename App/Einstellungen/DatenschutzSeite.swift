import SwiftUI
import AgentDeckCore

// Datenschutz und Sicherheit — die Seite, auf der jemand nachliest, was diese
// App mit seinen Zugangsdaten tut.
//
// Sie steht bewusst **neben** der Über-Seite und nicht darin. «Über» beantwortet
// «wem gehört das, welche Fassung ist das, wie werde ich alles wieder los».
// Hier geht es um eine andere Frage, und die braucht Platz: sechs Netzziele mit
// Zweck, die Ablage der Schlüssel, die Zugriffsklasse und ihr Preis, und was
// noch **nicht** geprüft ist.
//
// **Der Massstab für jeden Satz auf dieser Seite: Er muss sich im Code
// nachweisen lassen.** Die Mac-Fassung wirbt auf ihrer Webseite mit
// «Sicherheitsgeprüft — vier dokumentierte Prüfdurchgänge». Diese Fassung hat
// keinen einzigen. Das Abzeichen mitzunehmen wäre eine Falschaussage an genau
// der Stelle, an der jemand nachsieht, ob er der App trauen kann — und Apple
// liest dieselbe Seite. Deshalb steht unten, was im Code nachprüfbar ist und
// was aussteht, statt eines Siegels, das einer anderen App gehört.
//
// Wer hier etwas ändert, ändert eine Zusage. Die Reihenfolge ist immer: erst im
// Code nachsehen, dann den Satz schreiben — nie umgekehrt.

struct DatenschutzSeite: View {

    var body: some View {
        EinstellungsForm(titel: String(localized: "Datenschutz und Sicherheit")) {
            kurzfassung
            netzziele
            wasSieNichtTut
            zugangsdaten
            wasSonstAufDemGeraetLiegt
            beimAbmelden
            geprueft
            abgrenzung
        }
    }

    // MARK: - Die Kurzfassung

    /// Steht zuoberst, weil die meisten nur diesen einen Abschnitt lesen.
    ///
    /// Er darf deshalb nichts behaupten, was weiter unten eingeschränkt wird.
    /// «Kein Server von uns» hält: Es gibt in der ganzen App keinen einzigen
    /// Netzaufruf an eine Adresse, die dem Entwickler gehört — die vollständige
    /// Liste steht direkt darunter und ist kurz genug zum Nachzählen.
    @ViewBuilder
    private var kurzfassung: some View {
        Section {
            Text("Diese App hat keinen Server. Sie spricht ausschliesslich mit den Diensten, für die du selbst einen Zugang hinterlegt hast, und holt dort Kontingente, Kosten und Kontostände — nichts sonst. Es gibt kein Konto bei AI Cockpit, keine Anmeldung beim Entwickler und keine Stelle, an der jemand mitliest.")
            Text("Inhalte deiner Unterhaltungen sieht die App nie. Die abgefragten Schnittstellen geben Zahlen heraus, keine Texte.")
        } header: {
            Text("Kurz")
        }
    }

    // MARK: - Wohin die App spricht

    /// Die vollständige Liste — einzeln, mit Zweck und mit der Voraussetzung.
    ///
    /// Vollständig ist hier wörtlich gemeint: Diese sechs Adressen sind alles,
    /// was App und Widget je aufrufen. Eine Sammelformel wie «nur offizielle
    /// Schnittstellen» wäre bequemer und weniger wert — sie liesse sich nicht
    /// überprüfen, und genau das soll man hier können.
    @ViewBuilder
    private var netzziele: some View {
        Section {
            ForEach(Netzziel.alle) { ziel in
                Netzzeile(ziel: ziel)
            }
        } header: {
            Text("Wohin diese App spricht")
        } footer: {
            Text("Mehr Adressen gibt es nicht. Jede Verbindung geht direkt von diesem Gerät zum genannten Dienst — keine Zwischenstation, kein Umweg über den Entwickler. Für die Verbindungen selbst gelten die Datenschutzbestimmungen des jeweiligen Anbieters.")
            Text("Das Widget fragt eine dieser Adressen selbst ab — die Nutzungsfenster bei api.anthropic.com —, damit es nicht darauf warten muss, dass jemand die App öffnet. Es benutzt dafür denselben Token und dieselbe Verbindung wie die App.")
        }
    }

    // MARK: - Was sie nicht tut

    /// Die Gegenliste.
    ///
    /// Jeder Punkt hier ist eine Aussage über den Bauplan, nicht über eine
    /// Absicht: Die genannten Bausteine sind schlicht nicht eingebunden, und
    /// die Info-Datei der App fragt keine einzige dieser Berechtigungen an.
    /// Was nicht da ist, kann auch nicht versehentlich anspringen.
    @ViewBuilder
    private var wasSieNichtTut: some View {
        Section {
            nichtZeile("Keine Werbung und keine Werbekennung.", "nosign")
            nichtZeile("Keine Analyse, keine Nutzungsstatistik, keine Absturzberichte an Dritte.", "chart.bar.xaxis")
            nichtZeile("Keine In-App-Käufe und kein Abonnement in der App.", "creditcard")
            nichtZeile("Kein Zugriff auf Standort, Kontakte, Fotos, Kalender, Mikrofon oder Kamera — die App fragt keine dieser Berechtigungen an.", "location.slash")
            nichtZeile("Kein eingebauter Browser: Anmeldungen laufen im geschützten Anmeldefenster des Systems, Verweise öffnen sich in deinem Browser.", "safari")
            nichtZeile("Keine Weitergabe an Dritte und kein Datenhandel.", "person.2.slash")
        } header: {
            Text("Was sie nicht tut")
        }
    }

    // MARK: - Wo die Zugangsdaten liegen

    /// Der Abschnitt, der den unbequemen Teil mitnimmt.
    ///
    /// «Alles im Schlüsselbund» allein wäre die halbe Wahrheit. Die Einträge
    /// stehen auf `AfterFirstUnlock`, damit das Widget sie auch bei gesperrtem
    /// Bildschirm lesen kann — sonst zeigte es nach jedem Neustart stumm nichts
    /// an. Der Preis dafür ist, dass sie nach der ersten Entsperrung lesbar
    /// bleiben, und wer das wissen will, soll es hier finden und nicht in einem
    /// Quelltext, den er nicht hat.
    @ViewBuilder
    private var zugangsdaten: some View {
        Section {
            Text("Die Claude-Anmeldung, die ChatGPT-Anmeldung und die drei API-Schlüssel liegen im Schlüsselbund dieses Geräts — unter einem eigenen Dienstnamen, getrennt von der Mac-Fassung. Sie stehen nie in den Benutzervorgaben, nie im gemeinsamen Ablageort des Widgets und in keiner Protokollzeile.")
            Text("Sichtbar sind sie auch in der App nicht. Die Kontenseite zeigt, **dass** ein Schlüssel hinterlegt ist, und höchstens seine letzten vier Zeichen — genug, um zwei auseinanderzuhalten, zu wenig zum Mitlesen über die Schulter. Derselbe Massstab gilt für den Diagnosetext.")
            Text("Die Einträge sind so abgelegt, dass sie **nach der ersten Entsperrung** des Geräts lesbar sind, auch bei gesperrtem Bildschirm. Das ist eine bewusste Abwägung: Das Widget wird vom System geweckt, wann es will, und käme sonst regelmässig nicht an die Zahlen. Vor der ersten Entsperrung nach einem Neustart kommt niemand heran.")
            Text("Lesen dürfen die Einträge genau zwei Programme: diese App und ihr Widget. Beide sind über dieselbe Zugriffsgruppe signiert; eine andere App auf dem Gerät kann sie nicht öffnen.")
        } header: {
            Text("Wo die Zugangsdaten liegen")
        }
    }

    // MARK: - Der Rest auf dem Gerät

    @ViewBuilder
    private var wasSonstAufDemGeraetLiegt: some View {
        Section {
            Text("In den Benutzervorgaben der App stehen sechs Dinge: Erscheinungsbild, Kimi-Region, die beiden Schwellenwerte und welche Karten eingeklappt sind.")
            Text("Im gemeinsamen Ablageort von App und Widget liegt der Stand, den das Widget zeichnet — Beschriftung, Prozentwert, Zeitpunkt der Zurücksetzung und wann die Zahlen erhoben wurden. Keine Schlüssel, keine Token, keine Beträge.")
        } header: {
            Text("Was sonst auf dem Gerät liegt")
        } footer: {
            Text("Beides bleibt hier. Die App schreibt nichts nach iCloud und nichts in eine Sicherung ausserhalb der üblichen Gerätesicherung.")
        }
    }

    // MARK: - Abmelden

    /// Beschreibt genau das, was `Einstellungen.loescheAlles()` tut — Zeile für
    /// Zeile nachgesehen. Der Satz über die Dienste steht dazu, weil das die
    /// häufigste falsche Erwartung ist: Ein hier gelöschter Schlüssel bleibt
    /// beim Anbieter gültig, bis man ihn **dort** widerruft.
    @ViewBuilder
    private var beimAbmelden: some View {
        Section {
            Text("«Abmelden und alles löschen» zuunterst in den Einstellungen entfernt beide Anmeldungen und alle drei Schlüssel aus dem Schlüsselbund, setzt Darstellung, Region und Schwellen auf die Vorgaben zurück und löscht den Stand, den das Widget zeigt.")
            Text("Bei den Diensten selbst ändert sich dadurch nichts. Die Schlüssel bleiben dort gültig und müssten in der jeweiligen Konsole widerrufen werden — diese App kann das nicht für dich tun.")
        } header: {
            Text("Beim Abmelden")
        }
    }

    // MARK: - Geprüft, und was aussteht

    /// Der ehrliche Abschnitt.
    ///
    /// Die vier Prüfdurchgänge, mit denen die Mac-Fassung wirbt, gelten der
    /// Mac-Fassung. Diese App ist neu; für sie gibt es keinen. Was hier steht,
    /// ist deshalb zweigeteilt: nachprüfbare Eigenschaften des Codes auf der
    /// einen Seite, die offene Prüfung auf der anderen — und kein Wort, das die
    /// beiden Hälften vermischt.
    @ViewBuilder
    private var geprueft: some View {
        Section {
            Text("**Diese Fassung ist neu. Für sie gibt es bis heute keinen dokumentierten Prüfdurchgang.** Die vier Selbstprüfungen, die auf der Projektseite genannt sind, betreffen die Mac-Fassung und sagen über diese App nichts aus.")
            Text("Nachprüfbar im Code ist heute: Beide Anmeldungen laufen als Autorisierungscode-Ablauf mit PKCE (S256) im geschützten Anmeldefenster des Systems — die App bekommt dein Passwort nie zu sehen. Jede Anfrage geht über eine Verbindung ohne Zwischenspeicher und ohne Kekse, und Weiterleitungen werden abgewiesen, damit kein Dienst eine Anfrage samt Token auf einen fremden Rechner umlenken kann. Jede Verbindung, die das Gerät verlässt, läuft über HTTPS.")
            Text("Offen ist eine dokumentierte Prüfung dieser Fassung gegen OWASP ASVS 4.0, OWASP MASVS, den Apple Secure Coding Guide, RFC 8252/7636 und die CWE Top 25. Sie ist vor der Einreichung im App Store vorgesehen. Bis sie vorliegt, steht hier nichts anderes.")
        } header: {
            Text("Geprüft — und was aussteht")
        } footer: {
            Text("Auch bei der Mac-Fassung waren es dokumentierte Selbstprüfungen, kein externes Audit. Diese Unterscheidung gehört dazu.")
        }
    }

    // MARK: - Abgrenzung

    /// Steht auf beiden Seiten — hier und unter «Über».
    ///
    /// Doppelt, und das mit Absicht: Die Namen der drei Anbieter stehen auf den
    /// Karten, und wer wegen der Namen misstrauisch wird, landet je nach
    /// Gemüt auf der einen oder der anderen Seite. Der Hinweis ist ausserdem
    /// die Antwort auf Apples Richtlinie 5.2.5 und sollte an beiden Stellen zu
    /// finden sein, an denen ein Prüfer nachsieht.
    @ViewBuilder
    private var abgrenzung: some View {
        Section {
            Text("AI Cockpit ist ein eigenständiges Werkzeug und **nicht** mit Anthropic, OpenAI oder Moonshot AI verbunden — weder betrieben noch beauftragt noch gebilligt. Die Namen stehen auf den Karten, weil dort deren Zahlen stehen.")
        } header: {
            Text("Abgrenzung")
        }
    }

    // MARK: - Bausteine

    /// Eine Zeile der Gegenliste.
    ///
    /// Zeichen **und** Text, wie überall in dieser App: Ein durchgestrichenes
    /// Symbol allein ist für einen Teil der Leser eine graue Form.
    private func nichtZeile(_ text: LocalizedStringKey, _ symbol: String) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Die Netzziele

/// Ein Ziel, das die App aufruft.
///
/// Die Liste ist von Hand geführt und nicht aus dem Code erzeugt — erzeugen
/// liesse sie sich nicht, die Adressen stehen in fünf Clients und zwei
/// Anmeldeabläufen. Dafür trägt jeder Eintrag einen Zweck in Worten, und
/// darauf kommt es hier an: Eine Adresse ohne Zweck beantwortet die Frage
/// nicht, die jemand mit dieser Seite hat.
///
/// **Kommt ein Aufruf dazu, gehört er hierher.** Eine Liste, die «vollständig»
/// heisst und es nicht ist, wäre schlimmer als gar keine.
private struct Netzziel: Identifiable, Sendable {
    /// Der Rechnername ist zugleich die Kennung — er kommt in dieser Liste nur
    /// einmal vor, und eine gewürfelte Kennung wechselte bei jedem Neuzeichnen.
    var id: String { host }
    /// Der Rechnername, wie er in der Adresse steht.
    let host: String
    /// Wofür — in einem Satz, ohne Fachbegriffe.
    let zweck: String
    /// Was hinterlegt sein muss, damit dieser Aufruf überhaupt stattfindet.
    let voraussetzung: String

    static let alle: [Netzziel] = [
        Netzziel(
            host: "claude.com · platform.claude.com",
            zweck: String(localized: "Anmeldung beim Claude-Abo. Die Seite gehört Anthropic; die App sieht dein Passwort nie, sie bekommt am Ende nur einen Token."),
            voraussetzung: String(localized: "nur während der Anmeldung")),
        Netzziel(
            host: "api.anthropic.com",
            zweck: String(localized: "Die Nutzungsfenster des Abos — und, wenn ein Admin-Schlüssel hinterlegt ist, die Kosten der Anthropic-Schnittstelle."),
            voraussetzung: String(localized: "Claude-Anmeldung, Admin-Schlüssel einzeln")),
        Netzziel(
            host: "auth.openai.com",
            zweck: String(localized: "Anmeldung beim ChatGPT-Konto für die Codex-Kontingente. Läuft über OpenAI selbst."),
            voraussetzung: String(localized: "nur während der Anmeldung")),
        Netzziel(
            host: "chatgpt.com",
            zweck: String(localized: "Die Kontingente des angemeldeten ChatGPT-Kontos."),
            voraussetzung: String(localized: "ChatGPT-Anmeldung")),
        Netzziel(
            host: "api.openai.com",
            zweck: String(localized: "Kosten, Token und Ausgabengrenzen der OpenAI-Organisation."),
            voraussetzung: String(localized: "OpenAI-Admin-Schlüssel")),
        Netzziel(
            host: "api.moonshot.ai · api.moonshot.cn",
            zweck: String(localized: "Der Kontostand bei Kimi. Welcher der beiden Rechner gefragt wird, entscheidet die Region auf der Kontenseite."),
            voraussetzung: String(localized: "Kimi-Schlüssel"))
    ]
}

/// Eine Zeile der Zielliste: Adresse, Zweck, Voraussetzung.
///
/// Die Adresse steht mit festem Zeichenabstand, damit sie als Adresse zu
/// erkennen ist und nicht als Fliesstext gelesen wird — es soll ja jemand
/// nachschlagen können, was dort liegt.
private struct Netzzeile: View {
    let ziel: Netzziel

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)

        VStack(alignment: .leading, spacing: 4) {
            Text(ziel.host)
                .font(.footnote.monospaced())
                .foregroundStyle(palette.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(ziel.zweck)
                .fixedSize(horizontal: false, vertical: true)
            Text(ziel.voraussetzung)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

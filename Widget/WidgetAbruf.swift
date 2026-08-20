import Foundation
import AgentDeckCore

// Der eigene Abruf des Widgets — die zweite Schicht.
//
// Die erste Schicht ist der Zwischenstand in der App Group: Was die App zuletzt
// gemessen hat, wird **immer sofort** gezeichnet, samt seinem Alter. Erst
// danach darf das Widget selbst nachfragen. Diese Reihenfolge ist der ganze
// Punkt: Ein Widget, das auf eine Netzantwort wartet, bevor es etwas zeigt, ist
// bei schlechtem Empfang ein leeres Rechteck.
//
// Deshalb hat der Abruf hier ein hartes Zeitlimit und kein Wiederholen. Er
// gelingt oder er gelingt nicht; im zweiten Fall bleibt der Zwischenstand
// stehen und wird als alt gekennzeichnet. Das System gibt einem Widget grob 40
// bis 70 Neuladungen am Tag — wer davon eine mit Warten verbringt, hat sie
// verbraucht.

enum WidgetAbruf {

    enum Ergebnis: Sendable {
        case frisch(WidgetZustand)
        /// Zeitüberschreitung, kein Netz, Drosselung, abgewiesener Token —
        /// alles dasselbe für die Anzeige: Es bleibt beim Zwischenstand.
        case fehlgeschlagen
    }

    /// Fragt die Claude-Kontingente ab und formt sie in den Anzeigezustand.
    ///
    /// - Parameter token: Kommt vom Aufrufer, nicht aus einem zweiten
    ///   Schlüsselbundzugriff. Der Anbieter braucht den Fund ohnehin, um zu
    ///   entscheiden, ob überhaupt gefragt wird.
    static func claude(token: OAuthTokens, zeitlimit: TimeInterval) async -> Ergebnis {
        let zugriff = token.accessToken
        guard let werte = await mitZeitlimit(zeitlimit, {
            // Bewusst `ClaudeUsageClient()` mit seiner Vorgabesitzung: Sie folgt
            // keinen Weiterleitungen. Eine eigene Sitzung mit kürzerem Zeitlimit
            // wäre hier ein Rückschritt — der Sperr-Delegat liegt im Kern und
            // ist nicht öffentlich, eine nachgebaute Sitzung schickte den Token
            // im Zweifel an einen fremden Host. Die Frist setzt darum die
            // Aufgabengruppe, nicht die Sitzung.
            try await ClaudeUsageClient().fetch(accessToken: zugriff)
        }) else { return .fehlgeschlagen }

        // Dieselbe Reihenfolge wie in `Cockpit.schreibeWidgetZustand`: erst das
        // Fünfstundenfenster, dann das Wochenfenster, dann die modellbezogenen.
        // Sie ist der stille Vertrag zwischen App und Widget — die Ansicht
        // nimmt das erste Fenster für den Ring, weil sie den übersetzten Namen
        // nicht kennen darf. Läuft die Reihenfolge hier auseinander, zeigt das
        // Widget je nach Herkunft ein anderes Fenster gross.
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

        // Eine Antwort ohne ein einziges Fenster ist kein Erfolg: Sie würde den
        // Zwischenstand durch nichts ersetzen.
        guard !fenster.isEmpty else { return .fehlgeschlagen }

        // **Die übrigen Zeilen bleiben stehen.** Das Widget erneuert nur
        // Claude; würde es den Stand mit einem reinen Claude-Zustand
        // überschreiben, wären ChatGPT, OpenAI und Kimi bis zum nächsten Lauf
        // der App aus der Kachel verschwunden.
        //
        // Die Claude-Zeile darin wird mitgezogen, sonst stünde neben dem
        // frischen Ring eine alte Zahl desselben Kontos.
        let bisher = WidgetZustand.lies()?.quellen ?? []
        let claudeZeile = WidgetZustand.Quelle(
            name: "Claude",
            wert: fenster.prefix(2).map { "\($0.name): \(Format.percent($0.prozent))" }
                         .joined(separator: " · "),
            kurz: fenster.first.map { "\($0.name): \(Format.percent($0.prozent))" },
            prozent: fenster.first?.prozent,
            warnung: fenster.contains { $0.prozent >= LimitThresholds.standard.warn },
            stand: werte.fetchedAt)
        var quellen = bisher
        if let stelle = quellen.firstIndex(where: { $0.name == "Claude" }) {
            quellen[stelle] = claudeZeile
        } else if quellen.isEmpty {
            // Erster Lauf oder ein Stand aus einer älteren Fassung.
            quellen = [claudeZeile]
        }
        // Fehlt Claude in einer nicht leeren Liste, ist die Karte in der App
        // ausgeblendet. Dann gehört sie auch hier nicht hinein — der Ring zeigt
        // sie ohnehin, aber die Liste ist die Auswahl des Nutzers.

        // Der älteste Stand zählt: Er steht als «vor x» auf der Kachel und muss
        // für alles gelten, was dort steht.
        let aeltester = ([werte.fetchedAt] + quellen.map(\.stand)).min() ?? werte.fetchedAt
        return .frisch(WidgetZustand(erhoben: aeltester, fenster: fenster, quellen: quellen))
    }

    /// Führt `arbeit` aus, aber höchstens `sekunden` lang.
    ///
    /// Zwei Aufgaben, die um die erste Antwort laufen — die Uhr gewinnt, wenn
    /// die Arbeit zu lange braucht, und `cancelAll()` bricht die laufende
    /// Netzabfrage dann wirklich ab (`URLSession` beachtet die Rücknahme).
    /// `HTTPJSON` setzt am Anfrageobjekt selbst 20 Sekunden; die stehen über
    /// jeder Sitzungseinstellung, weshalb die Frist von aussen kommen muss.
    private static func mitZeitlimit<T: Sendable>(
        _ sekunden: TimeInterval,
        _ arbeit: @escaping @Sendable () async throws -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { gruppe in
            gruppe.addTask { try? await arbeit() }
            gruppe.addTask {
                try? await Task.sleep(for: .seconds(sekunden))
                return nil
            }
            let erstes = await gruppe.next() ?? nil
            gruppe.cancelAll()
            return erstes
        }
    }
}

// MARK: - Ablegen ohne Anstossen

extension WidgetZustand {

    /// Legt den Stand in der App Group ab, **ohne** das Widget anzustossen.
    ///
    /// `schreib(nach:)` ruft `WidgetCenter.reloadAllTimelines()`, sobald sich
    /// die Werte geändert haben. Für die App ist das genau richtig. Von hier
    /// aus wäre es ein Kreis: Der Aufruf käme mitten aus `getTimeline` und
    /// bestellte die Zeitachse neu, die gerade entsteht — jede erfolgreiche
    /// Abfrage kostete zwei Neuladungen statt einer, und der Tagesvorrat wäre
    /// vor Mittag weg.
    ///
    /// Der gemeinsame Weg aus `Shared/WidgetZustand.swift`, ohne Anstoss:
    /// Von hier aus neu zu laden wäre ein Kreis — Neuladen führte zum Abruf,
    /// der Abruf zum Neuladen. Hier stand einmal ein eigener Kodierer, weil der
    /// dortige dateiprivat war; zwei Kodierer heisst zwei Datumsschreibweisen,
    /// die im Gleichschritt bleiben müssen, und die auseinanderlaufen, ohne dass
    /// es jemand merkt.
    func legAb(in vorgaben: UserDefaults? = AppGruppe.vorgaben) {
        legAbOhneNeuladen(nach: vorgaben)
    }
}

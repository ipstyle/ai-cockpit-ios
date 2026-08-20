import Foundation
import AgentDeckCore

// Die vom Nutzer gelegte Reihenfolge der Karten.
//
// Der Kern kennt in `CardLayout` bereits ein Format für Kartenlisten — einen
// String mit kommagetrennten Kennungen. Genau das wird hier weiterverwendet,
// **aber als Liste statt als Menge**: `CardLayout.parse` liefert ein `Set` und
// `serialize` sortiert alphabetisch, weil es dort um «zu oder auf» geht und
// eine Reihenfolge nur Rauschen wäre. Für die Sortierung ist die Reihenfolge
// die ganze Information — mit `Set` wäre sie beim ersten Speichern weg.
//
// Deshalb steht das hier daneben und nicht darin: dasselbe Trennzeichen,
// dieselben Kennungen (`CardLayout.Card.rawValue`), dieselbe Ablage in den
// Benutzervorgaben — nur eben geordnet. Sobald die Mac-Fassung dieselbe
// Personalisierung bekommt, gehört dieser Code als `CardLayout.parseOrder` /
// `serializeOrder` in den Kern; dann liest ihn nur eine Seite und beide
// benutzen ihn.

/// Zerlegt, setzt zusammen und wendet die gespeicherte Kartenreihenfolge an.
enum Kartenreihenfolge {

    /// Schlüssel in den Benutzervorgaben — im selben Stil wie
    /// `collapsedCards`, damit die Mac-Fassung ihn ohne Übersetzung übernehmen
    /// kann.
    static let schluessel = "cardOrder"

    /// Leere Stücke fallen weg, Leerzeichen werden abgeschnitten, Doppelte
    /// verschwinden — **die erste** Nennung gewinnt.
    ///
    /// Das Entdoppeln ist kein Schönheitsputz: Stünde eine Kennung zweimal
    /// drin, erschiene die Karte zweimal in der Liste, und `ForEach` bekäme
    /// zwei Zeilen mit derselben `id` — womit die Ansicht nicht mehr weiss,
    /// welche der beiden geschoben wurde.
    ///
    /// Unbekannte Kennungen bleiben stehen. Wer eine neuere Fassung benutzt
    /// hat und dann eine ältere startet, soll seine Anordnung nicht dadurch
    /// verlieren, dass die alte Fassung eine Karte noch nicht kennt.
    static func parse(_ raw: String) -> [String] {
        var gesehen = Set<String>()
        return raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && gesehen.insert($0).inserted }
    }

    /// Kein Sortieren wie in `CardLayout.serialize` — hier ist die Reihenfolge
    /// die Aussage.
    static func serialize(_ ids: [String]) -> String {
        ids.joined(separator: ",")
    }

    /// Bringt die gebauten Karten in die gespeicherte Reihenfolge.
    ///
    /// Die drei Fälle, an denen so etwas scheitert, sind hier alle drei
    /// abgefangen:
    ///
    /// - **Eine Karte fehlt in der Reihenfolge** (sie ist neu dazugekommen):
    ///   Sie landet hinten, in der Reihenfolge, in der `baueKarten()` sie
    ///   angelegt hat. Nicht im Nichts.
    /// - **Eine Kennung ohne Karte** (sie ist weggefallen): wird übergangen.
    /// - **Eine Kennung doppelt**: schon von `parse` erledigt.
    ///
    /// Ist nichts gespeichert, bleibt die gebaute Reihenfolge unangetastet —
    /// dann gibt es auch nichts anzuwenden.
    static func sortiere(_ karten: [CockpitCard], nach raw: String) -> [CockpitCard] {
        let wunsch = parse(raw)
        guard !wunsch.isEmpty else { return karten }

        var rest = karten
        var sortiert: [CockpitCard] = []
        sortiert.reserveCapacity(karten.count)
        for kennung in wunsch {
            guard let stelle = rest.firstIndex(where: { $0.id.rawValue == kennung }) else { continue }
            sortiert.append(rest.remove(at: stelle))
        }
        return sortiert + rest
    }

    /// Verschiebt Zeilen und gibt die **vollständige** neue Reihenfolge zurück.
    ///
    /// Absichtlich vollständig und nicht als Änderung gegenüber dem Bestand:
    /// Eine gespeicherte Teilliste wäre eine Einladung an genau den Fehler, den
    /// `sortiere` oben abfängt. Was auf dem Schirm steht, steht danach auch in
    /// den Vorgaben.
    static func verschoben(_ ids: [String], von: IndexSet, nach ziel: Int) -> String {
        var neu = ids
        neu.move(fromOffsets: von, toOffset: ziel)
        return serialize(neu)
    }

    /// Eine Karte um eine Stelle nach oben (`-1`) oder unten (`+1`).
    ///
    /// Der Weg ohne Ziehen — VoiceOver kann nicht ziehen, und ohne diesen Weg
    /// wäre die Personalisierung für einen Teil der Nutzer schlicht nicht
    /// vorhanden. Am Rand passiert nichts: `nil` heisst «geht nicht weiter».
    static func geschoben(_ ids: [String], kennung: String, um schritte: Int) -> String? {
        guard let stelle = ids.firstIndex(of: kennung) else { return nil }
        let ziel = stelle + schritte
        guard ids.indices.contains(ziel) else { return nil }
        var neu = ids
        neu.swapAt(stelle, ziel)
        return serialize(neu)
    }
}

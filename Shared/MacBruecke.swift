import Foundation

/// Was der Mac herüberreicht.
///
/// Zwei der sechs Karten haben auf einem iPhone keine Datenquelle: Die
/// ChatGPT-/Codex-Kontingente gibt der Codex-Dienst nur einem lokalen
/// Kindprozess heraus, und die aktiven Sitzungen stehen in Dateien unter
/// `~/.claude/projects`. Beides existiert hier nicht. Die Mac-App legt seinen
/// Zustand deshalb in der **privaten iCloud des Nutzers** ab; diese Seite liest
/// ihn und schreibt ihn in die App Group weiter, damit auch das Widget ihn
/// sieht.
///
/// Der Typ liegt vorerst hier. Sobald die Mac-Fassung 5.3 die Gegenseite
/// bekommt (Etappe E4), wandert er in den gemeinsamen Kern — sonst haben beide
/// Seiten je eine eigene Vorstellung davon, wie der Blob aussieht, und der
/// erste Feldname, der auseinanderläuft, fällt niemandem auf.
public struct MacZustand: Codable, Sendable, Equatable {

    /// Wird bei jeder Formänderung erhöht. Eine ältere App, die eine neuere
    /// Fassung liest, zeigt lieber nichts als etwas Falsches.
    public static let aktuelleVersion = 1

    public let version: Int
    /// Wann der Mac das geschrieben hat — nicht, wann wir es gelesen haben.
    /// Der Unterschied ist genau das, was die Karte anzeigen muss.
    public let geschrieben: Date
    public let codexFenster: [Fenster]
    public let sitzungen: [Sitzung]

    public struct Fenster: Codable, Sendable, Equatable {
        public let name: String
        public let verbrauchtProzent: Double
        public let zuruecksetzung: Date?
    }

    public struct Sitzung: Codable, Sendable, Equatable {
        /// Bereits durch `Sanitize` gelaufen, bevor der Mac sie geschrieben hat.
        /// Es sind Ordner- und Aufgabennamen aus echter Arbeit.
        public let titel: String
        public let zustand: String
        public let tokens: Int
    }
}

/// Woher der Mac-Zustand kommt.
///
/// Fassung 1 nutzt den iCloud-Schlüssel-Wert-Speicher: ein Schlüssel, ein
/// komprimiertes JSON, rund dreissig Zeilen. CloudKit wäre die grössere Lösung
/// mit Schema, Umgebungstrennung und Push — nötig erst, wenn die Nutzlast
/// wächst. Dass hier ein Protokoll steht und keine feste Klasse, ist der ganze
/// Unterschied zwischen «später austauschen» und «später umbauen».
public protocol ZustandsBruecke: Sendable {
    func lies() async throws -> MacZustand?
    /// Nur die Mac-Seite schreibt. Auf iOS wirft diese Methode.
    func schreib(_ zustand: MacZustand) async throws
}

public enum BrueckenFehler: Error, LocalizedError {
    case nichtVerfuegbar
    case zuNeu(gefunden: Int, erwartet: Int)
    case nurLesend

    public var errorDescription: String? {
        switch self {
        case .nichtVerfuegbar:
            return "Keine Verbindung zu iCloud."
        case let .zuNeu(gefunden, erwartet):
            return "Der Mac schreibt Fassung \(gefunden), diese App versteht \(erwartet). Bitte die App aktualisieren."
        case .nurLesend:
            return "Diese Seite liest nur."
        }
    }
}

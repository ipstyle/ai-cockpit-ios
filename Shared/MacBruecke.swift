import Foundation
import AgentDeckCore

/// Woher der Mac-Zustand kommt.
///
/// **Der Datensatz selbst liegt seit Etappe E4 im Kern**: `MacZustand` in
/// `AgentDeckCore`, zusammen mit seinem Codec, seiner Fassungsnummer, dem
/// Speicherschlüssel und dem Deckel. Er stand eine Weile hier, solange es die
/// Gegenseite noch nicht gab; jetzt gibt es sie, und damit gilt der Grund, aus
/// dem er wandern sollte: Zwei Strukturen mit denselben Feldnamen sind zwei
/// Strukturen. Der erste Feldname, der auseinanderläuft, fällt niemandem auf —
/// kein Übersetzungsfehler, keine Warnung, nur eine Karte, die leer bleibt.
/// Beide Seiten benutzen jetzt buchstäblich denselben Code.
///
/// Hier bleibt, was nur diese Seite angeht: wie sie an den Datensatz kommt und
/// was sie dem Nutzer sagt, wenn es nicht klappt.
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
    /// Es liegt etwas im Speicher, aber kein lesbarer Datensatz.
    case unlesbar

    public var errorDescription: String? {
        switch self {
        case .nichtVerfuegbar:
            return "Keine Verbindung zu iCloud."
        case let .zuNeu(gefunden, erwartet):
            return "Der Mac schreibt Fassung \(gefunden), diese App versteht \(erwartet). Bitte die App aktualisieren."
        case .nurLesend:
            return "Diese Seite liest nur."
        case .unlesbar:
            return "Der Mac hat etwas abgelegt, das sich nicht lesen lässt."
        }
    }

    /// Übersetzt, was der Codec im Kern meldet.
    ///
    /// Der Kern kennt weder iCloud noch Oberflächentexte — das ist gewollt und
    /// der Grund, warum es zwei Fehlertypen gibt. Diese Zuordnung ist die
    /// einzige Stelle, an der beides zusammenkommt.
    init(_ fehler: MacZustandFehler) {
        switch fehler {
        case let .zuNeu(gefunden, erwartet):
            self = .zuNeu(gefunden: gefunden, erwartet: erwartet)
        case .unlesbar, .zuGross:
            // `zuGross` kann beim Lesen nicht auftreten: Der Deckel greift beim
            // Schreiben, und geschrieben wird auf dieser Seite nicht.
            self = .unlesbar
        }
    }
}

import Foundation

/// Der gemeinsame Ablageort von App und Widget.
///
/// Das Widget kann die App nicht fragen — es läuft in einem eigenen Prozess, zu
/// einem Zeitpunkt, den das System bestimmt. Alles, was es anzeigen soll, muss
/// deshalb vorher hier liegen. Die App schreibt, das Widget liest; nie umgekehrt.
public enum AppGruppe {

    /// Muss buchstabengleich in beiden Entitlements stehen. Steht sie nur in
    /// einem, liefert `UserDefaults(suiteName:)` still `nil` und das Widget
    /// bleibt leer — ohne Fehlermeldung, ohne Absturz, ohne Hinweis.
    public static let kennung = "group.com.ipstyle.aicockpit"

    public static var vorgaben: UserDefaults? { UserDefaults(suiteName: kennung) }

    /// Meldet, ob die App Group überhaupt erreichbar ist. Wird im
    /// Diagnosefenster angezeigt — der Unterschied zwischen «keine Daten» und
    /// «kein Zugriff» ist der Unterschied zwischen zwei Minuten und zwei Tagen
    /// Fehlersuche.
    public static var erreichbar: Bool { vorgaben != nil }
}

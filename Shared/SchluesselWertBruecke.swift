import Foundation
import AgentDeckCore

/// Die Brücke über den iCloud-Schlüssel-Wert-Speicher — die lesende Seite.
///
/// Ein Schlüssel, ein komprimiertes JSON. Schlüsselname, Format, Deckel und
/// Fassungsprüfung stehen nicht mehr hier, sondern in `MacZustand` im Kern.
/// Das ist der Punkt: Die Mac-App schreibt mit demselben Code, mit dem hier
/// gelesen wird. Ein Schlüsselname, den nur eine Seite ändert, oder ein
/// Packverfahren, das nur eine Seite kennt, kann so nicht mehr entstehen.
///
/// **Die teuerste Falle dieses ganzen Vorhabens** liegt ohnehin nicht im Code,
/// sondern in den Entitlements: `com.apple.developer.ubiquity-kvstore-identifier`
/// muss in der Mac-App und hier buchstabengleich stehen. Xcode trägt
/// automatisch die jeweils eigene Bundle-ID ein — beide Apps haben
/// verschiedene. Wer das übersieht, bekommt keinen Fehler, keine Warnung und
/// keine Daten. Hier steht `$(TeamIdentifierPrefix)com.ipstyle.aicockpit` in
/// `App/Resources/AICockpitMobile.entitlements`, drüben derselbe Wert
/// ausgeschrieben in `Packaging/MAS.entitlements` — ausgeschrieben deshalb,
/// weil die Mac-Seite direkt über `codesign` signiert und codesign keine
/// Build-Variablen ersetzt.
public actor SchluesselWertBruecke: ZustandsBruecke {

    /// Aus dem Kern, nicht von Hand wiederholt.
    public static let schluessel = MacZustand.speicherSchluessel

    private let speicher: NSUbiquitousKeyValueStore

    public init(speicher: NSUbiquitousKeyValueStore = .default) {
        self.speicher = speicher
    }

    public func lies() async throws -> MacZustand? {
        // Anstossen, aber nicht darauf warten: `synchronize` schiebt lokale
        // Änderungen hoch und ist kein Abruf. Was von oben kommt, kommt, wenn
        // es kommt — deshalb trägt jeder Zustand seinen eigenen Zeitstempel.
        speicher.synchronize()
        guard let daten = speicher.data(forKey: Self.schluessel) else { return nil }
        do {
            return try MacZustand.dekodiere(daten)
        } catch let fehler as MacZustandFehler {
            // Übersetzt in die Sprache dieser Seite — der Kern soll keine
            // Oberflächentexte tragen.
            throw BrueckenFehler(fehler)
        }
    }

    /// Auf iOS wird nicht geschrieben. Die Mac-Fassung hat mit
    /// `ICloudBruecke` ihre eigene Schreibseite; hier wäre ein Schreibzugriff
    /// nur ein Weg, sich gegenseitig zu überschreiben.
    public func schreib(_ zustand: MacZustand) async throws {
        throw BrueckenFehler.nurLesend
    }
}

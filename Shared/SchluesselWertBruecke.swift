import Foundation

/// Die Brücke über den iCloud-Schlüssel-Wert-Speicher.
///
/// Ein Schlüssel, ein komprimiertes JSON. Die Grenze liegt bei einem Megabyte
/// für den ganzen Speicher; wir deckeln bei 500 KB, damit ein einzelner Eintrag
/// nie alles belegt.
///
/// **Die teuerste Falle dieses ganzen Vorhabens** liegt nicht im Code, sondern
/// in den Entitlements: `com.apple.developer.ubiquity-kvstore-identifier` muss
/// in der Mac-App und hier buchstabengleich stehen. Xcode trägt automatisch die
/// jeweils eigene Bundle-ID ein — beide Apps haben verschiedene. Wer das
/// übersieht, bekommt keinen Fehler, keine Warnung und keine Daten.
public actor SchluesselWertBruecke: ZustandsBruecke {

    public static let schluessel = "mac-zustand-v1"

    private let speicher: NSUbiquitousKeyValueStore
    private let decoder: JSONDecoder

    public init(speicher: NSUbiquitousKeyValueStore = .default) {
        self.speicher = speicher
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    public func lies() async throws -> MacZustand? {
        // Anstossen, aber nicht darauf warten: `synchronize` schiebt lokale
        // Änderungen hoch und ist kein Abruf. Was von oben kommt, kommt, wenn
        // es kommt — deshalb trägt jeder Zustand seinen eigenen Zeitstempel.
        speicher.synchronize()
        guard let gepackt = speicher.data(forKey: Self.schluessel) else { return nil }
        let roh = try entpacke(gepackt)
        let zustand = try decoder.decode(MacZustand.self, from: roh)
        guard zustand.version <= MacZustand.aktuelleVersion else {
            throw BrueckenFehler.zuNeu(gefunden: zustand.version,
                                       erwartet: MacZustand.aktuelleVersion)
        }
        return zustand
    }

    /// Auf iOS wird nicht geschrieben. Die Mac-Fassung bekommt in 5.3 ihre
    /// eigene Implementierung dieses Protokolls; hier wäre ein Schreibzugriff
    /// nur ein Weg, sich gegenseitig zu überschreiben.
    public func schreib(_ zustand: MacZustand) async throws {
        throw BrueckenFehler.nurLesend
    }

    private func entpacke(_ daten: Data) throws -> Data {
        // Ungepackt genauso annehmen: In der Entwicklung ist es bequem, den
        // Wert von Hand zu setzen, und ein JSON beginnt nie mit 0x1f.
        guard daten.count > 2, daten[daten.startIndex] == 0x1f else { return daten }
        return try (daten as NSData).decompressed(using: .zlib) as Data
    }
}

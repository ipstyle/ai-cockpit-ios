import SwiftUI

// Farben, Formate und Zeitangaben der iOS-Fassung — dieselbe Palette wie auf
// dem Mac, nur ohne AppKit.
//
// Auf dem Mac liest `Theme` bei jedem Zugriff die Benutzervorgaben und fragt
// im Fall «System» `NSApp.effectiveAppearance`. Beides gibt es hier nicht: Ein
// Widget hat kein `NSApp`, und statische Getter, die still ihre Farbe wechseln,
// sind für SwiftUI unsichtbar — die Ansicht wird nicht neu gezeichnet, weil
// nichts beobachtbar war. Deshalb ist die Palette hier ein Wert, den jede
// Ansicht aus `\.colorScheme` ableitet.

// MARK: - Erscheinungsbild

/// Die wählbare Darstellung — Rohwert liegt in den Benutzervorgaben
/// (`appearanceMode`), buchstabengleich zur Mac-Fassung, damit ein späterer
/// Abgleich über iCloud nicht an einem Rohwert scheitert.
enum AppAppearance: String, CaseIterable, Sendable {
    case dark
    case light
    case system

    var title: String {
        switch self {
        case .dark: return String(localized: "Dunkel")
        case .light: return String(localized: "Hell")
        case .system: return String(localized: "System")
        }
    }

    /// «System» heisst unter iOS: nichts vorgeben. Dann trägt die Umgebung den
    /// Wert ein, und ein Wechsel im Kontrollzentrum wirkt ohne Zutun.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

// MARK: - Farben

enum Theme {

    /// Wem eine Karte gehört. Die Ansichten reichen diesen Fall herum statt
    /// einer fertigen `Color`: Eine Farbe, die vor dem Farbschema festgelegt
    /// wurde, bliebe beim Umschalten stehen.
    enum Provider: String, CaseIterable, Sendable {
        case claude
        case chatGPT
        case openAI
        case kimi
        case sessions
        /// Ohne Anbieter — nimmt die Akzentfarbe der Palette.
        case neutral
    }

    struct Palette: Equatable, Sendable {
        let background, card, cardBorder, hairline: Color
        let primary, secondary, faint, accent: Color
        let claude, chatGPT, openAI, sessions, kimi: Color
        /// Warn- und Alarmfarbe an einer Stelle. Auf dem Mac stehen an den
        /// Fundstellen `.orange` und `.red`; hier laufen sie über die Palette,
        /// damit sich der helle Modus nachjustieren lässt, ohne ein Dutzend
        /// Ansichten anzufassen.
        let warning, critical: Color

        func color(for provider: Provider) -> Color {
            switch provider {
            case .claude: return claude
            case .chatGPT: return chatGPT
            case .openAI: return openAI
            case .kimi: return kimi
            case .sessions: return sessions
            case .neutral: return accent
            }
        }
    }

    // Anthrazit statt Schwarz. Der Sprung von Schwarz auf `white: 0.10` war
    // hart genug, dass die Karten schwebten; zwischen diesen beiden Werten
    // liegen dagegen keine zehn Prozent Helligkeit — deshalb bekommen die
    // Karten mit `cardBorder` eine feine Kante, sonst verschwimmt alles.
    static let dark = Palette(
        background: Color(red: 0.110, green: 0.122, blue: 0.141),
        card: Color(red: 0.145, green: 0.165, blue: 0.192),
        cardBorder: Color(red: 0.204, green: 0.227, blue: 0.263),
        hairline: Color(white: 0.30),
        primary: Color(white: 0.96),
        secondary: Color(red: 0.706, green: 0.729, blue: 0.761),
        faint: Color(red: 0.514, green: 0.545, blue: 0.584),
        accent: Color(red: 0.42, green: 0.71, blue: 1.0),
        claude: Color(red: 0.85, green: 0.53, blue: 0.34),
        chatGPT: Color(red: 0.29, green: 0.78, blue: 0.64),
        openAI: Color(red: 0.55, green: 0.60, blue: 0.95),
        sessions: Color(red: 0.68, green: 0.75, blue: 0.30),
        kimi: Color(red: 0.93, green: 0.45, blue: 0.55),
        warning: .orange,
        critical: .red
    )

    // Warmes Papier statt steriles Weiss. Die Akzentfarben sind gegenüber der
    // dunklen Palette deutlich nachgedunkelt — die hellen Originale hätten auf
    // Beige kaum Kontrast (das Akzentblau wäre fast unsichtbar).
    static let light = Palette(
        background: Color(red: 0.965, green: 0.933, blue: 0.874),
        card: Color(red: 0.925, green: 0.881, blue: 0.792),
        cardBorder: Color(red: 0.804, green: 0.741, blue: 0.616),
        hairline: Color(red: 0.72, green: 0.68, blue: 0.60),
        primary: Color(red: 0.16, green: 0.13, blue: 0.10),
        secondary: Color(red: 0.30, green: 0.25, blue: 0.20),
        faint: Color(red: 0.48, green: 0.43, blue: 0.36),
        accent: Color(red: 0.05, green: 0.30, blue: 0.62),
        claude: Color(red: 0.50, green: 0.24, blue: 0.04),
        chatGPT: Color(red: 0.03, green: 0.34, blue: 0.26),
        openAI: Color(red: 0.24, green: 0.26, blue: 0.60),
        sessions: Color(red: 0.28, green: 0.32, blue: 0.03),
        kimi: Color(red: 0.60, green: 0.10, blue: 0.20),
        warning: .orange,
        critical: .red
    )

    /// Im Zweifel dunkel: Das ist die Vorgabe der Mac-Fassung, und sollte
    /// `ColorScheme` je einen dritten Fall bekommen, ist Dunkel die Antwort,
    /// die nicht blendet.
    static func palette(_ scheme: ColorScheme) -> Palette {
        scheme == .light ? light : dark
    }

    // MARK: - Zeitangaben

    /// «vor 12 s», «vor 3 min» — knapp, damit die Kopfzeilen ruhig bleiben.
    static func ago(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        switch seconds {
        case ..<5: return String(localized: "gerade eben")
        case ..<60: return String(localized: "vor \(seconds) s")
        case ..<3600: return String(localized: "vor \(seconds / 60) min")
        case ..<86400: return String(localized: "vor \(seconds / 3600) h")
        default: return String(localized: "vor \(seconds / 86400) d")
        }
    }

    /// «16:40» heute, sonst mit Datum davor.
    ///
    /// Zwei feste Formatierer statt eines neuen je Aufruf: Diese Funktion läuft
    /// in jeder `LimitRow` — Zurücksetzung und Hochrechnung —, und die Liste
    /// zeichnet im Zehnsekundentakt neu.
    static func absolute(_ date: Date) -> String {
        (Calendar.current.isDateInToday(date) ? nurZeit : mitDatum).string(from: date)
    }

    private static let nurZeit = zeitFormat("jmm")
    private static let mitDatum = zeitFormat("dMMMjmm")

    /// Aus einer Vorlage statt einem festen Muster: So folgt die Schreibweise
    /// («16:40» oder «4:40 PM») der Sprache des Systems, nicht der des Autors.
    private static func zeitFormat(_ vorlage: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(vorlage)
        return formatter
    }
}

// MARK: - Zahlen

/// Zahlen, wie sie in der Liste erscheinen sollen — an **einer** Stelle.
enum Format {

    /// «42 %». Ganze Prozent genügen: Ein Kontingent auf die Nachkommastelle
    /// genau zu kennen ändert an keiner Entscheidung etwas.
    ///
    /// Gedeckelt und gegen NaN abgesichert, anders als auf dem Mac: Der Wert
    /// stammt aus einer Netzantwort, und `Int(Double.nan)` beendet das
    /// Programm. Ein Prozentwert ist es nicht wert, eine App abzuschiessen.
    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return "\(percentDigits(value)) %"
    }

    /// Nur die Ziffern — für den Ring, in dessen Mitte das Zeichen «%» keinen
    /// Platz hat und auch nichts erklärt: Ein Ring zeigt nie etwas anderes.
    static func percentDigits(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return "\(Int(min(max(value, 0), 9999).rounded()))"
    }

    /// «1.2 M», «340 k», «812» — kurz genug für eine Kachel.
    static func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1f M", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.0f k", Double(value) / 1000) }
        return "\(value)"
    }

    /// Betrag in der Währung, die die Schnittstelle mitgeliefert hat.
    ///
    /// Die Formatierer werden je Währung einmal angelegt und behalten: Ein
    /// `NumberFormatter` ist teuer, und in der Kostenkarte stehen ein Dutzend
    /// Beträge, die bei jedem Zeichnen neu gesetzt werden.
    static func money(_ value: Decimal, _ currency: String) -> String {
        formatter(for: currency).string(from: value as NSDecimalNumber) ?? "\(value)"
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var formatters: [String: NumberFormatter] = [:]

    private static func formatter(for currency: String) -> NumberFormatter {
        lock.lock()
        defer { lock.unlock() }
        if let existing = formatters[currency] { return existing }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 2
        formatters[currency] = formatter
        return formatter
    }
}

// MARK: - Schwellen

/// Ab wann ein Fenster warnt und ab wann es drückt.
///
/// Auf dem Mac stehen diese beiden Zahlen in `AppSettings` — einem Typ des
/// Mac-Ziels, nicht des Kerns. Bis es hier eine iOS-Fassung davon gibt, reicht
/// jede Ansicht ihre Schwellen durch; die Vorgaben sind dieselben wie dort.
struct LimitThresholds: Equatable, Sendable {
    /// Ab hier orange, ab `critical` rot. Vorgaben 80 und 95 — die
    /// macOS-Fassung warnt ab 75 und 90; auf dem Telefon schaut man seltener
    /// hin, und eine Warnung, die zu früh kommt, wird zur Tapete.
    var warn: Double = 80
    var critical: Double = 95

    static let standard = LimitThresholds()

    func level(_ percent: Double) -> LimitLevel {
        guard percent.isFinite else { return .normal }
        if percent >= critical { return .critical }
        if percent >= warn { return .warn }
        return .normal
    }

    /// Wo die Schwellen auf einem Balken von 0…100 liegen, als Anteil.
    var marks: [Double] { [warn / 100, critical / 100].filter { $0 > 0 && $0 < 1 } }
}

/// Wie ernst ein Wert ist — und wie man das **ohne** Farbe sieht.
///
/// Das ist der Kern der Sache: Unter iOS 26 tönt der Homescreen Widgets ein und
/// reduziert sie auf eine einzige Farbe. Ein Balken, dessen Aussage in Rot
/// steckt, ist dort ein grauer Balken. Deshalb hat jede Stufe ein eigenes
/// Zeichen — Dreieck und Achteck unterscheiden sich auch in Graustufen — und
/// eine Beschriftung für VoiceOver.
enum LimitLevel: Equatable, Sendable {
    case normal
    case warn
    case critical

    var symbol: String? {
        switch self {
        case .normal: return nil
        case .warn: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var spokenLabel: String? {
        switch self {
        case .normal: return nil
        case .warn: return String(localized: "Warnung")
        case .critical: return String(localized: "kritisch")
        }
    }

    func color(in palette: Theme.Palette, accent: Color) -> Color {
        switch self {
        case .normal: return accent
        case .warn: return palette.warning
        case .critical: return palette.critical
        }
    }
}

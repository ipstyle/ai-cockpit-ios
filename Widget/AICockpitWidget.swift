import WidgetKit
import SwiftUI

// Der Einstiegspunkt der Widget-Erweiterung.
//
// Die Zeitachse hat zwei Schichten, und die Reihenfolge ist der ganze Entwurf:
//
// 1. Was in der App Group liegt, wird **immer sofort** gerendert — mit
//    sichtbarem Stand. Das ist der Zustand, den die App zuletzt gemessen hat.
// 2. Erst danach fragt das Widget selbst nach, mit hartem Zeitlimit. Gelingt
//    es, wandert das Ergebnis in die App Group und in die Zeitachse; gelingt es
//    nicht, bleibt Schicht 1 stehen und altert sichtbar weiter.
//
// Was das Widget dabei **nie** tut: den Claude-Token erneuern. Ein
// Refresh-Token lässt sich einmal einlösen. Zwei gleichzeitige Erneuerungen —
// App und Widget — entwerten einander und melden den Nutzer grundlos ab.

@main
struct AICockpitWidgetBuendel: WidgetBundle {
    var body: some Widget { UeberblickWidget() }
}

// MARK: - Der Eintrag

struct UeberblickEintrag: TimelineEntry, Sendable, Equatable {
    /// Wann dieser Eintrag angezeigt werden soll.
    let date: Date
    /// Wann die Zahlen **erhoben** wurden — nicht, wann dieser Eintrag entstand.
    /// Das Widget zeigt beides nie als dasselbe an.
    let stand: Date?
    let fenster: [WidgetZustand.Fenster]
    /// Eine Zeile je eingeblendeter Karte mit Zahlen. Leer bei einem Stand aus
    /// einer älteren Fassung — dann zeigt die Kachel wie früher die Fenster.
    let quellen: [WidgetZustand.Quelle]
    /// Ob der Nutzer in die App muss, damit hier je wieder etwas Frisches
    /// erscheint (kein Token, abgelaufen oder unlesbar).
    let anmeldungFaellig: Bool

    /// Ab hier heisst der Stand «veraltet».
    ///
    /// Eine Stunde ist keine technische Grenze, sondern eine sprachliche: Bis
    /// dahin trägt «vor 40 Min.» die Aussage von selbst; darüber liest man eine
    /// Zahl und denkt nicht mehr daran, wie alt sie ist.
    static let altersgrenze: TimeInterval = 3600

    /// Gemessen zum **Anzeigezeitpunkt** dieses Eintrags, nicht zu jetzt: Die
    /// Zeitachse enthält absichtlich einen Eintrag, der erst später gilt.
    var veraltet: Bool {
        guard let stand else { return false }
        return date.timeIntervalSince(stand) >= Self.altersgrenze
    }

    /// «jetzt», «4 m», «2 h», «3 d» — der Stand für den Sperrbildschirm.
    ///
    /// Dort ist `Text(_:style: .relative)` unbrauchbar: Es schreibt «4 Min.,
    /// 4 Sek.» und braucht mehr Platz, als eine runde Kachel im Ganzen hat. Die
    /// Kurzfassung friert beim Zeichnen ein — dafür sorgt `zeitachse(ab:)` mit
    /// einer Leiter von Einträgen, deren jeder sein eigenes Alter zeichnet.
    var kurzesAlter: String? {
        guard let stand else { return nil }
        let sekunden = Int(max(date.timeIntervalSince(stand), 0))
        switch sekunden {
        case ..<60: return String(localized: "jetzt")
        case ..<3600: return String(localized: "\(sekunden / 60) m")
        case ..<86400: return String(localized: "\(sekunden / 3600) h")
        default: return String(localized: "\(sekunden / 86400) d")
        }
    }

    /// Das Fenster, das der Ring zeigt.
    ///
    /// **Das erste, nicht ein gesuchtes.** Die App legt die Fenster in fester
    /// Reihenfolge ab (`Cockpit.schreibeWidgetZustand`, ebenso `WidgetAbruf`):
    /// erst das Fünfstundenfenster, dann das Wochenfenster, dann die
    /// modellbezogenen. Nach dem Namen zu suchen hiesse, ihn hier zu kennen —
    /// und er kommt übersetzt aus einer Netzantwort. Fehlt das
    /// Fünfstundenfenster, steht eben das nächste da; sein Name steht darunter,
    /// also behauptet die Kachel nichts Falsches.
    ///
    /// Seit jede Quelle ihre eigenen Fenster mitbringt, wird zuerst dort
    /// gesucht; `fenster` ist nur noch der Rückfall für einen Stand aus einer
    /// älteren Fassung.
    var hauptfenster: WidgetZustand.Fenster? {
        quellen.first(where: { !$0.fenster.isEmpty })?.fenster.first ?? fenster.first
    }

    /// Wem der Ring gehört. Er stand fest auf Claude — ist die Claude-Karte
    /// ausgeblendet, zeigte er ein ChatGPT-Fenster in Claudes Farbe.
    var hauptanbieter: Theme.Provider {
        quellen.first(where: { !$0.fenster.isEmpty })?.alsAnbieter ?? .claude
    }

    /// Platzhalterwerte für Galerie und Vorschau.
    ///
    /// **Die einzige Stelle im ganzen Ziel, die Zahlen erfindet.** Sie wird von
    /// `placeholder(in:)` und von `getSnapshot` im Vorschaufall aufgerufen —
    /// nie aus `getTimeline`. Eine Kachel auf dem Homescreen zeigt entweder
    /// Gemessenes oder eine Einladung.
    static func vorschau(am datum: Date = .now) -> UeberblickEintrag {
        let erhoben = datum.addingTimeInterval(-4 * 60)
        return UeberblickEintrag(
            date: datum,
            stand: erhoben,
            fenster: [
                .init(name: String(localized: "5 Stunden"), prozent: 42,
                      zuruecksetzung: datum.addingTimeInterval(2 * 3600)),
                .init(name: String(localized: "7 Tage"), prozent: 78,
                      zuruecksetzung: datum.addingTimeInterval(3 * 86400)),
                .init(name: "Fable 5", prozent: 12,
                      zuruecksetzung: datum.addingTimeInterval(3 * 86400))
            ],
            quellen: [
                // Auch die Vorschau trägt die Kurzfassungen — sonst zeigte die
                // Galerie auf der kleinen Kachel einen abgeschnittenen Betrag,
                // also genau das Bild, das die App gerade nicht abgibt.
                .init(name: "Claude", anbieter: "claude", wert: "5 h: 42 % · 7 d: 78 %", kurz: "5 h: 42 %",
                      fenster: [.init(name: String(localized: "5 Stunden"), prozent: 42,
                                      zuruecksetzung: datum.addingTimeInterval(2 * 3600)),
                                .init(name: String(localized: "7 Tage"), prozent: 78,
                                      zuruecksetzung: datum.addingTimeInterval(3 * 86400))],
                      prozent: 78, warnung: false, stand: erhoben),
                .init(name: "ChatGPT", anbieter: "chatGPT", wert: "5 h: 8 % · 7 d: 21 %", kurz: "5 h: 8 %",
                      fenster: [.init(name: String(localized: "5 Stunden"), prozent: 8,
                                      zuruecksetzung: datum.addingTimeInterval(3600)),
                                .init(name: String(localized: "7 Tage"), prozent: 21,
                                      zuruecksetzung: datum.addingTimeInterval(4 * 86400))],
                      prozent: 21, warnung: false, stand: erhoben),
                .init(name: String(localized: "OpenAI-API"), anbieter: "openAI",
                      wert: String(localized: "Heute \(Format.money(0.4, "USD")) · Monat \(Format.money(12.3, "USD"))"),
                      kurz: Format.money(12.3, "USD"),
                      prozent: nil, warnung: false, stand: erhoben),
                .init(name: "Kimi K3", anbieter: "kimi",
                      wert: String(localized: "\(Format.money(9.9, "USD")) verfügbar"),
                      kurz: Format.money(9.9, "USD"),
                      prozent: nil, warnung: false, stand: erhoben)
            ],
            anmeldungFaellig: false)
    }

    /// Nichts gemessen — die Einladung.
    static func leer(am datum: Date, anmeldungFaellig: Bool) -> UeberblickEintrag {
        UeberblickEintrag(date: datum, stand: nil, fenster: [], quellen: [],
                          anmeldungFaellig: anmeldungFaellig)
    }

    /// Hat die Kachel überhaupt etwas zu zeigen?
    var hatInhalt: Bool { !quellen.isEmpty || !fenster.isEmpty }
}

// MARK: - Der Anbieter

struct UeberblickAnbieter: TimelineProvider {

    /// Wunsch, keine Zusage: Das System vergibt rund 40 bis 70 Neuladungen am
    /// Tag und verteilt sie nach Sichtbarkeit. Deshalb steht auf jeder Kachel,
    /// wie alt die Zahlen sind.
    static let wunschabstand: TimeInterval = 15 * 60

    /// Ohne Anmeldung und ohne Daten gibt es nichts zu holen. Die App stösst
    /// das Widget von selbst an, sobald sie etwas geschrieben hat
    /// (`WidgetZustand.schreib`) — bis dahin wäre jede Neuladung verschenkt.
    static let ruheabstand: TimeInterval = 60 * 60

    /// Unter dieser Frische lohnt kein eigener Abruf. Der Usage-Endpunkt ist
    /// nicht dokumentiert und sichert keine Rate zu; Mac-App, iOS-App und
    /// Widget fragen dieselbe Stelle. Ein Boden verhindert, dass ein Schwall
    /// Neuladungen zur Drosselung führt.
    static let mindestabstand: TimeInterval = 5 * 60

    /// Zwischen 8 und 10 Sekunden — mehr Zeit gibt das System einem Widget
    /// nicht verlässlich, und länger warten hiesse: gar nichts zeichnen.
    static let zeitlimit: TimeInterval = 9

    func placeholder(in context: Context) -> UeberblickEintrag {
        .vorschau()
    }

    func getSnapshot(in context: Context,
                     completion: @escaping @Sendable (UeberblickEintrag) -> Void) {
        // In der Galerie darf die Vorschau Platzhalterwerte zeigen — sie ist ein
        // Bild davon, wie das Widget aussieht. Auf dem Homescreen beantwortet
        // derselbe Aufruf eine andere Frage, und dort gilt: nur Gemessenes.
        completion(context.isPreview ? .vorschau() : Self.ausZwischenstand(.now))
    }

    func getTimeline(in context: Context,
                     completion: @escaping @Sendable (Timeline<UeberblickEintrag>) -> Void) {
        // `TimelineProviderContext` ist nicht `Sendable`; was die Aufgabe unten
        // braucht, wird vorher herausgezogen.
        let istVorschau = context.isPreview

        Task {
            let jetzt = Date.now
            let fund = WidgetSchluesselbund.claudeToken()
            var eintrag = Self.ausZwischenstand(jetzt, anmeldungFaellig: fund.brauchtDieApp)

            if !istVorschau, case .token(let token) = fund, Self.lohntAbruf(eintrag, jetzt: jetzt) {
                if case .frisch(let zustand) = await WidgetAbruf.claude(token: token,
                                                                       zeitlimit: Self.zeitlimit) {
                    // Ohne Anstossen — der Aufruf käme sonst mitten aus dieser
                    // Zeitachse und bestellte sie gleich noch einmal.
                    zustand.legAb()
                    eintrag = UeberblickEintrag(date: jetzt,
                                                stand: zustand.erhoben,
                                                fenster: zustand.fenster,
                                                quellen: zustand.quellen,
                                                anmeldungFaellig: false)
                }
                // Fehlschlag: Der Zwischenstand bleibt stehen und altert
                // sichtbar. Das ist die richtige Antwort — eine Zahl von vorhin
                // mit ihrem Alter daneben ist mehr wert als eine leere Fläche.
            }

            completion(Self.zeitachse(ab: eintrag))
        }
    }

    // MARK: Zusammensetzen

    private static func ausZwischenstand(_ jetzt: Date,
                                         anmeldungFaellig: Bool = false) -> UeberblickEintrag {
        guard let zustand = WidgetZustand.lies(),
              !zustand.fenster.isEmpty || !zustand.quellen.isEmpty else {
            return .leer(am: jetzt, anmeldungFaellig: anmeldungFaellig)
        }
        return UeberblickEintrag(date: jetzt,
                                 stand: zustand.erhoben,
                                 fenster: zustand.fenster,
                                 quellen: zustand.quellen,
                                 anmeldungFaellig: anmeldungFaellig)
    }

    private static func lohntAbruf(_ eintrag: UeberblickEintrag, jetzt: Date) -> Bool {
        guard let stand = eintrag.stand else { return true }
        return jetzt.timeIntervalSince(stand) >= mindestabstand
    }

    /// Wann der Stand sichtbar altern soll — Sekunden nach der Erhebung.
    ///
    /// Anfangs eng, später weit: Zwischen «1 m» und «2 m» liegt für den Leser
    /// ein Unterschied, zwischen «3 h» und «4 h» kaum noch einer. Die Stufe bei
    /// 3600 ist zugleich die, an der «veraltet» einsetzt.
    private static let altersstufen: [TimeInterval] = [
        60, 120, 180, 300, 420, 600, 900, 1200, 1800, 2700,
        3600, 5400, 7200, 10800, 14400, 21600, 43200, 86400
    ]

    /// Eine Leiter von Einträgen statt eines einzigen — und keine einzige
    /// zusätzliche Neuladung dafür.
    ///
    /// Jeder Eintrag zeichnet sein eigenes Alter: Der auf `erhoben + 20 min`
    /// schreibt «20 m», der auf `erhoben + 1 h` schaltet auf «veraltet». Ohne
    /// diese Leiter hinge beides an der Gunst des Systems — kommt die nächste
    /// Neuladung erst in zwei Stunden, stünde bis dahin eine Zahl da, die sich
    /// frisch gibt. Einträge einer Zeitachse kosten nichts extra, Neuladungen
    /// kosten.
    private static func zeitachse(ab eintrag: UeberblickEintrag) -> Timeline<UeberblickEintrag> {
        var eintraege = [eintrag]

        if let stand = eintrag.stand {
            for stufe in altersstufen {
                let zeitpunkt = stand.addingTimeInterval(stufe)
                guard zeitpunkt > eintrag.date else { continue }
                eintraege.append(UeberblickEintrag(date: zeitpunkt,
                                                   stand: stand,
                                                   fenster: eintrag.fenster,
                                                   quellen: eintrag.quellen,
                                                   anmeldungFaellig: eintrag.anmeldungFaellig))
            }
        }

        let abstand = eintrag.hatInhalt ? wunschabstand : ruheabstand
        return Timeline(entries: eintraege,
                        policy: .after(eintrag.date.addingTimeInterval(abstand)))
    }
}

// MARK: - Die Konfiguration

struct UeberblickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AICockpitUeberblick", provider: UeberblickAnbieter()) { eintrag in
            UeberblickAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("AI Cockpit")
        .description("Alle eingeblendeten Karten auf einen Blick — mit dem Alter der Zahlen.")
        .supportedFamilies(Self.familien)
        // CarPlay abwählen: Dort landet ein Widget sonst automatisch in einem
        // Layout, das nie jemand geprüft hat — und im Auto ist die Auslastung
        // eines Abos ohnehin die falsche Auskunft.
        .disfavoredLocations([.carPlay], for: Self.familien)
        // StandBy nimmt die kleine Kachel (dort ist sie richtig) und lässt die
        // mittlere und die grosse liegen: Auf einem quer stehenden Telefon in
        // anderthalb Metern Abstand ist eine Balkenliste nicht lesbar.
        .disfavoredLocations([.standBy], for: [.systemMedium, .systemLarge])
    }

    /// `systemLarge` ist auf dem iPad zu Hause — dort hat der Homescreen den
    /// Platz für alle Fenster samt Zurücksetzung. Angeboten wird sie trotzdem
    /// überall: Die Familienliste je Gerät auszuwählen wäre ein Kniff, dessen
    /// Verhalten in der Galerie sich nicht prüfen lässt, und die Ansicht trägt
    /// auf einem iPhone genauso — sie zeigt dann einfach mehr Zeilen.
    ///
    /// visionOS fehlt hier bewusst als Ort: `WidgetLocation` gibt es dort nicht
    /// (im SDK ausdrücklich `@available(visionOS, unavailable)`), abwählen lässt
    /// es sich über diesen Weg also nicht.
    static let familien: [WidgetFamily] = [
        .systemSmall, .systemMedium, .systemLarge,
        .accessoryCircular, .accessoryRectangular
    ]
}

// MARK: - Vorschauen

// Beispieleinträge. Sie stehen ausschliesslich in Vorschauen — der
// Auslieferungspfad kennt nur Gemessenes und die Einladung.
extension UeberblickEintrag {
    static var beispielRuhig: UeberblickEintrag {
        UeberblickEintrag(date: .now, stand: .now.addingTimeInterval(-3 * 60),
                          fenster: [
                            .init(name: "5 Stunden", prozent: 42, zuruecksetzung: .now.addingTimeInterval(2 * 3600)),
                            .init(name: "7 Tage", prozent: 61, zuruecksetzung: .now.addingTimeInterval(3 * 86400)),
                            .init(name: "Fable 5", prozent: 12, zuruecksetzung: .now.addingTimeInterval(3 * 86400)),
                            .init(name: "Opus", prozent: 33, zuruecksetzung: .now.addingTimeInterval(3 * 86400))
                          ],
                          quellen: [
                            .init(name: "Claude", anbieter: "claude", wert: "5 h: 42 % · 7 d: 61 %", kurz: "5 h: 42 %",
                                  prozent: 61, warnung: false, stand: .now.addingTimeInterval(-3 * 60)),
                            .init(name: "ChatGPT", anbieter: "chatGPT", wert: "5 h: 8 % · 7 d: 21 %", kurz: "5 h: 8 %",
                                  prozent: 21, warnung: false, stand: .now.addingTimeInterval(-3 * 60)),
                            .init(name: "OpenAI-API", anbieter: "openAI", wert: "Heute US$ 0.40 · Monat US$ 12.30",
                                  kurz: "US$ 12.30",
                                  prozent: nil, warnung: false, stand: .now.addingTimeInterval(-3 * 60)),
                            .init(name: "Kimi K3", anbieter: "kimi", wert: "US$ 9.90 verfügbar", kurz: "US$ 9.90",
                                  prozent: nil, warnung: false, stand: .now.addingTimeInterval(-3 * 60))
                          ],
                          anmeldungFaellig: false)
    }

    static var beispielKritisch: UeberblickEintrag {
        UeberblickEintrag(date: .now, stand: .now.addingTimeInterval(-12 * 60),
                          fenster: [
                            .init(name: "5 Stunden", prozent: 94, zuruecksetzung: .now.addingTimeInterval(38 * 60)),
                            .init(name: "7 Tage", prozent: 81, zuruecksetzung: .now.addingTimeInterval(2 * 86400))
                          ],
                          quellen: [
                            .init(name: "Claude", anbieter: "claude", wert: "5 h: 94 % · 7 d: 81 %", kurz: "5 h: 94 %",
                                  prozent: 94, warnung: true, stand: .now.addingTimeInterval(-12 * 60)),
                            .init(name: "ChatGPT", anbieter: "chatGPT", wert: "5 h: 88 %", kurz: "5 h: 88 %",
                                  prozent: 88, warnung: true, stand: .now.addingTimeInterval(-12 * 60))
                          ],
                          anmeldungFaellig: false)
    }

    /// Derselbe Stand, aber vier Stunden alt — prüft die deutlichere Kennzeichnung.
    static var beispielVeraltet: UeberblickEintrag {
        UeberblickEintrag(date: .now, stand: .now.addingTimeInterval(-4 * 3600),
                          fenster: beispielRuhig.fenster,
                          quellen: beispielRuhig.quellen,
                          anmeldungFaellig: false)
    }

    static var beispielAbgemeldet: UeberblickEintrag {
        .leer(am: .now, anmeldungFaellig: true)
    }

    /// Zahlen da, Anmeldung fällig — der Fall, in dem beides gleichzeitig gilt.
    static var beispielAnmeldungFaellig: UeberblickEintrag {
        UeberblickEintrag(date: .now, stand: .now.addingTimeInterval(-2 * 3600),
                          fenster: beispielKritisch.fenster,
                          quellen: beispielKritisch.quellen,
                          anmeldungFaellig: true)
    }

    static var beispielOhneDaten: UeberblickEintrag {
        .leer(am: .now, anmeldungFaellig: false)
    }
}

#Preview("Klein", as: .systemSmall) {
    UeberblickWidget()
} timeline: {
    UeberblickEintrag.beispielRuhig
    UeberblickEintrag.beispielKritisch
    UeberblickEintrag.beispielVeraltet
    UeberblickEintrag.beispielAnmeldungFaellig
    UeberblickEintrag.beispielAbgemeldet
    UeberblickEintrag.beispielOhneDaten
}

#Preview("Mittel", as: .systemMedium) {
    UeberblickWidget()
} timeline: {
    UeberblickEintrag.beispielRuhig
    UeberblickEintrag.beispielKritisch
    UeberblickEintrag.beispielVeraltet
    UeberblickEintrag.beispielAnmeldungFaellig
    UeberblickEintrag.beispielAbgemeldet
}

#Preview("Gross", as: .systemLarge) {
    UeberblickWidget()
} timeline: {
    UeberblickEintrag.beispielRuhig
    UeberblickEintrag.beispielVeraltet
    UeberblickEintrag.beispielAbgemeldet
}

#Preview("Sperrbildschirm rund", as: .accessoryCircular) {
    UeberblickWidget()
} timeline: {
    UeberblickEintrag.beispielRuhig
    UeberblickEintrag.beispielKritisch
    UeberblickEintrag.beispielVeraltet
    UeberblickEintrag.beispielAbgemeldet
}

#Preview("Sperrbildschirm rechteckig", as: .accessoryRectangular) {
    UeberblickWidget()
} timeline: {
    UeberblickEintrag.beispielRuhig
    UeberblickEintrag.beispielKritisch
    UeberblickEintrag.beispielVeraltet
    UeberblickEintrag.beispielAnmeldungFaellig
    UeberblickEintrag.beispielAbgemeldet
}

// Die Familienvorschauen oben zeichnen im Erscheinungsbild von Xcode. Für den
// Vergleich hell/dunkel und für den getönten Homescreen braucht es die
// Ansichten selbst — `\.colorScheme` und `\.widgetRenderingMode` lassen sich
// nur dort setzen (`\.widgetFamily` ist nur lesbar).

private struct VorschauKachel<Inhalt: View>: View {
    let titel: String
    let breite: CGFloat
    let hoehe: CGFloat
    let schema: ColorScheme
    var modus: WidgetRenderingMode = .fullColor
    @ViewBuilder let inhalt: Inhalt

    var body: some View {
        VStack(spacing: 4) {
            inhalt
                .padding(14)
                .frame(width: breite, height: hoehe)
                .background(Theme.palette(schema).background)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .environment(\.colorScheme, schema)
                .environment(\.widgetRenderingMode, modus)
            Text(titel).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct Familienvergleich: View {
    let schema: ColorScheme
    var modus: WidgetRenderingMode = .fullColor

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                VorschauKachel(titel: "klein · ruhig", breite: 158, hoehe: 158, schema: schema, modus: modus) {
                    KleineAnsicht(eintrag: .beispielRuhig)
                }
                VorschauKachel(titel: "klein · kritisch", breite: 158, hoehe: 158, schema: schema, modus: modus) {
                    KleineAnsicht(eintrag: .beispielKritisch)
                }
                VorschauKachel(titel: "klein · abgemeldet", breite: 158, hoehe: 158, schema: schema, modus: modus) {
                    KleineAnsicht(eintrag: .beispielAbgemeldet)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                VorschauKachel(titel: "mittel · kritisch", breite: 338, hoehe: 158, schema: schema, modus: modus) {
                    MittlereAnsicht(eintrag: .beispielKritisch)
                }
                VorschauKachel(titel: "mittel · veraltet", breite: 338, hoehe: 158, schema: schema, modus: modus) {
                    MittlereAnsicht(eintrag: .beispielVeraltet)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                VorschauKachel(titel: "gross · ruhig", breite: 338, hoehe: 354, schema: schema, modus: modus) {
                    MittlereAnsicht(eintrag: .beispielRuhig, maximum: 6, mitZuruecksetzung: true)
                }
                VStack(spacing: 18) {
                    VorschauKachel(titel: "rund", breite: 76, hoehe: 76, schema: schema, modus: modus) {
                        RundeAnsicht(eintrag: .beispielKritisch)
                    }
                    VorschauKachel(titel: "rechteckig", breite: 172, hoehe: 82, schema: schema, modus: modus) {
                        RechteckigeAnsicht(eintrag: .beispielKritisch)
                    }
                    VorschauKachel(titel: "rechteckig · veraltet", breite: 172, hoehe: 82, schema: schema, modus: modus) {
                        RechteckigeAnsicht(eintrag: .beispielVeraltet)
                    }
                }
            }
        }
        .padding(24)
        .background(schema == .dark ? Color.black : Color(white: 0.85))
        .environment(\.colorScheme, schema)
    }
}

#Preview("Alle Familien · dunkel") {
    Familienvergleich(schema: .dark)
}

#Preview("Alle Familien · hell") {
    Familienvergleich(schema: .light)
}

/// Der Ernstfall der ersten Regel: Wenn der Homescreen alles einfärbt, muss
/// jede Aussage ohne Farbe noch dastehen.
#Preview("Getönt · einfarbig") {
    Familienvergleich(schema: .dark, modus: .accented)
}

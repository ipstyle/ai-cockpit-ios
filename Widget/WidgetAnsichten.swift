import SwiftUI
import WidgetKit

// Was auf der Kachel steht.
//
// Drei Regeln liegen über allem anderen, und sie sind der Grund für fast jede
// ungewöhnliche Zeile in dieser Datei:
//
// **Farbe trägt nie allein.** Unter iOS 26 tönt der Homescreen Widgets ein und
// reduziert sie auf eine einzige Farbe. Ein Balken, dessen Aussage in Rot
// steckt, ist dort ein grauer Balken. Jede Zahl steht deshalb als Text daneben,
// jede Warnung trägt zusätzlich ein Zeichen (Dreieck und Achteck unterscheiden
// sich auch in Graustufen), und Spur und Füllung eines Balkens unterscheiden
// sich in der Deckkraft — die überlebt die Tönung, der Farbton nicht.
//
// **Keine Zahl ohne ihr Alter.** Wann ein Widget neu lädt, entscheidet das
// System; realistisch 40 bis 70 Mal am Tag. «Aktuell» wäre eine Behauptung, die
// niemand einlösen kann. Der Stand steht auf jeder Familie, auch auf der
// kleinsten — und ab etwa einer Stunde deutlicher.
//
// **Nichts Erfundenes.** Ohne gemessene Zahlen zeigt die Kachel eine Einladung,
// keine Platzhalter. Die einzigen Platzhalterwerte im ganzen Ziel stehen in
// `UeberblickEintrag.vorschau(am:)` und werden nur von `placeholder` und der
// Galerie-Vorschau angefasst.

// MARK: - Farben

/// Die Farben einer Widget-Ansicht — abhängig vom Erscheinungsbild **und** von
/// der Darstellungsart.
///
/// `\.widgetRenderingMode` ist der Unterschied zwischen «unsere Palette» und
/// «das System färbt gleich alles um». Im getönten und im vibrierenden Modus
/// werden Farbtöne verworfen; was bleibt, ist die Deckkraft. Deshalb gibt es
/// hier zwei Sätze und nicht einen mit Sonderfällen an den Fundstellen.
struct WidgetTon {
    let palette: Theme.Palette
    /// Homescreen-Tönung oder Sperrbildschirm: Der Farbton ist verloren.
    let einfarbig: Bool

    init(_ schema: ColorScheme, _ darstellung: WidgetRenderingMode) {
        palette = Theme.palette(schema)
        einfarbig = darstellung != .fullColor
    }

    var haupt: Color { einfarbig ? .primary : palette.primary }
    var neben: Color { einfarbig ? .secondary : palette.secondary }
    var leise: Color { einfarbig ? .secondary : palette.faint }
    var akzent: Color { einfarbig ? .primary : palette.claude }
    var warnung: Color { einfarbig ? .primary : palette.warning }

    func wert(_ stufe: LimitLevel) -> Color {
        einfarbig ? .primary : stufe.color(in: palette, accent: palette.claude)
    }

    /// Die leere Spur eines Balkens. Im einfarbigen Modus über die Deckkraft
    /// statt über einen eigenen Grauton — ein Grauton wird mitgetönt, ein
    /// Alphawert nicht.
    var spur: Color { einfarbig ? Color.primary.opacity(0.22) : palette.hairline.opacity(0.45) }
    var marke: Color { einfarbig ? Color.primary.opacity(0.55) : palette.faint.opacity(0.7) }
}

// MARK: - Der Stand

/// «vor 4 Min.» — und ab einer Stunde mit Nachdruck.
///
/// Der Zeitabstand kommt aus `Text(_:style: .relative)` und nicht aus
/// `Theme.ago`: Diese Schreibweise zählt in einem Widget von selbst weiter,
/// ohne dass eine Neuladung dafür verbraucht wird. `Theme.ago` liefert eine
/// Zeichenkette, die im Augenblick des Zeichnens einfriert — auf einer Kachel,
/// die stundenlang unverändert dasteht, wäre das genau die Lüge, die hier
/// vermieden werden soll.
struct StandZeile: View {
    let eintrag: UeberblickEintrag
    /// Sperrbildschirm und kleine Kachel: nur das Nötigste.
    var kompakt = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)

        HStack(spacing: 3) {
            Image(systemName: eintrag.veraltet ? "clock.badge.exclamationmark" : "clock")
            inhalt
        }
        .font(.caption2)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(eintrag.veraltet ? ton.warnung : ton.leise)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(gesprochen)
    }

    @ViewBuilder
    private var inhalt: some View {
        if let stand = eintrag.stand {
            // Das Wort dazu, nicht nur das Zeichen: Ein Uhrsymbol mit
            // Ausrufezeichen ist auf neun Punkten kaum vom schlichten
            // Uhrsymbol zu unterscheiden.
            if eintrag.veraltet, kompakt {
                Text("alt · vor \(stand, style: .relative)")
            } else if eintrag.veraltet {
                Text("veraltet · vor \(stand, style: .relative)")
            } else {
                Text("vor \(stand, style: .relative)")
            }
        } else {
            Text("noch nichts gemessen")
        }
    }

    /// VoiceOver bekommt die Aussage ausgeschrieben — dort ist kein Platz knapp.
    private var gesprochen: String {
        guard let stand = eintrag.stand else { return String(localized: "Noch nichts gemessen") }
        let abstand = stand.formatted(.relative(presentation: .named))
        return eintrag.veraltet
            ? String(localized: "Stand \(abstand), veraltet")
            : String(localized: "Stand \(abstand)")
    }
}

/// Der Stand in seiner kürzesten Form — «4 m», «2 h», «3 d».
///
/// Auf dem Sperrbildschirm ist `Text(_:style: .relative)` unbrauchbar: Es
/// schreibt «4 Min., 4 Sek.» und braucht dafür mehr Platz, als eine runde
/// Kachel im Ganzen hat. Diese Fassung friert beim Zeichnen ein — dafür sorgt
/// die Zeitachse für Nachschub: Sie legt Einträge auf 1, 2, 3, 5 … Minuten nach
/// der Erhebung, und jeder zeichnet sein eigenes Alter. Einträge kosten nichts,
/// Neuladungen kosten.
struct KurzStand: View {
    let eintrag: UeberblickEintrag

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)
        HStack(spacing: 2) {
            Image(systemName: eintrag.veraltet ? "clock.badge.exclamationmark" : "clock")
            Text(beschriftung)
        }
        .font(.caption2)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(eintrag.veraltet ? ton.warnung : ton.leise)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(gesprochen)
    }

    private var beschriftung: String {
        guard let alter = eintrag.kurzesAlter else { return String(localized: "—") }
        return eintrag.veraltet ? String(localized: "alt · \(alter)") : alter
    }

    private var gesprochen: String {
        guard let stand = eintrag.stand else { return String(localized: "Noch nichts gemessen") }
        let abstand = stand.formatted(.relative(presentation: .named))
        return eintrag.veraltet
            ? String(localized: "Stand \(abstand), veraltet")
            : String(localized: "Stand \(abstand)")
    }
}

// MARK: - Balken

/// Der Füllstand eines Fensters.
///
/// Eine schlanke Zwillingsfassung von `UsageBar` aus `App/Views/CardKit.swift`
/// — jene Datei liegt im App-Ziel, das Widget-Ziel sieht sie nicht. Der
/// Unterschied ist nicht nur die Herkunft: Hier zählt die Deckkraft statt der
/// Farbe, weil ein getöntes Widget den Farbton wegnimmt. Die Marken an Warn-
/// und Alarmschwelle sind der eigentliche Gewinn dieser Fassung: Sie sagen ohne
/// jede Farbe, wo «zu viel» anfängt.
struct WidgetBalken: View {
    let prozent: Double
    let ton: Color
    var schwellen: LimitThresholds = .standard
    var hoehe: CGFloat = 5

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let farben = WidgetTon(schema, darstellung)
        let anteil = prozent.isFinite ? min(max(prozent / 100, 0), 1) : 0

        GeometryReader { proxy in
            let breite = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(farben.spur)

                ForEach(schwellen.marks, id: \.self) { marke in
                    Rectangle()
                        .fill(farben.marke)
                        .frame(width: 1, height: hoehe)
                        .offset(x: min(breite * marke, max(breite - 1, 0)))
                }

                // Mindestens so breit wie hoch: Ein Prozent wäre sonst ein
                // einzelner Punkt und von «leer» nicht zu unterscheiden.
                Capsule()
                    .fill(ton)
                    .frame(width: anteil > 0 ? max(breite * anteil, hoehe) : 0)
            }
        }
        .frame(height: hoehe)
        // Die Zahl steht daneben und wird vorgelesen; der Balken ist ihr Bild.
        .accessibilityHidden(true)
    }
}

// MARK: - Eine Fensterzeile

/// Name, Prozentzahl, Balken — und auf der grossen Kachel die Zurücksetzung.
struct FensterZeile: View {
    let fenster: WidgetZustand.Fenster
    var schwellen: LimitThresholds = .standard
    var zeigtZuruecksetzung = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)
        let stufe = schwellen.level(fenster.prozent)
        let farbe = ton.wert(stufe)

        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // Eine Zeile, dann gekürzt: In den modellbezogenen Fenstern
                // steckt ein Name aus der Netzantwort.
                Text(fenster.name)
                    .font(.caption)
                    .foregroundStyle(ton.neben)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Die Zahl steht **immer** da. Niemand muss eine Farbe deuten
                // können, um den Wert zu kennen.
                Text(Format.percent(fenster.prozent))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(farbe)

                if let symbol = stufe.symbol {
                    // Eine Warnung behält ihre Farbe, auch wenn der Homescreen
                    // alles andere einfärbt. Sie ist kein Schmuck — und ihre
                    // Aussage hängt trotzdem nicht daran: Dreieck und Achteck
                    // unterscheiden sich auch in Graustufen.
                    //
                    // Der Aufruf steht direkt am Bild, nicht am Ergebnis der
                    // Schrift- und Farbmodifikatoren: `widgetAccentedRenderingMode`
                    // ist auf `Image` erklärt, nicht auf `View`.
                    Image(systemName: symbol)
                        .widgetAccentedRenderingMode(.fullColor)
                        .font(.caption2)
                        .foregroundStyle(farbe)
                }
            }

            WidgetBalken(prozent: fenster.prozent, ton: farbe, schwellen: schwellen)

            if zeigtZuruecksetzung, let reset = fenster.zuruecksetzung {
                Text("Zurücksetzung \(Theme.absolute(reset))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(ton.leise)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fenster.name)
        .accessibilityValue(gesprochen(stufe))
    }

    private func gesprochen(_ stufe: LimitLevel) -> String {
        var teile = [Format.percent(fenster.prozent)]
        if let hinweis = stufe.spokenLabel { teile.append(hinweis) }
        if let reset = fenster.zuruecksetzung {
            teile.append(String(localized: "Zurücksetzung \(reset.formatted(.relative(presentation: .named)))"))
        }
        return teile.joined(separator: ", ")
    }
}

// MARK: - Ohne Zahlen

/// Was dasteht, wenn nichts gemessen wurde.
///
/// Keine Nullen, keine Striche, kein Ladekreisel — eine Auskunft. Ein Widget,
/// das «0 %» zeigt, weil es nichts weiss, sagt etwas Falsches über ein
/// Kontingent, und zwar ausgerechnet das Beruhigende.
struct EinladungsAnsicht: View {
    let eintrag: UeberblickEintrag
    /// Sperrbildschirm und kleine Kachel: nur die erste Zeile.
    var kompakt = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)

        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: eintrag.anmeldungFaellig ? "key.slash" : "hourglass")
                .font(.footnote)
                .foregroundStyle(ton.akzent)
            Text(eintrag.anmeldungFaellig ? "In der App anmelden" : "Noch keine Zahlen")
                .font(.caption.weight(.medium))
                .foregroundStyle(ton.haupt)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !kompakt {
                Text(eintrag.anmeldungFaellig
                     ? "Das Widget erneuert die Anmeldung nicht — das macht die App."
                     : "AI Cockpit einmal öffnen, dann stehen die Kontingente hier.")
                    .font(.caption2)
                    .foregroundStyle(ton.leise)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }
}

/// Der Hinweis, dass die Anmeldung fällig ist, während trotzdem Zahlen dastehen.
///
/// Die Zahlen bleiben stehen, weil sie gemessen wurden — sie zu verwerfen, nur
/// weil sie nicht frischer werden, nähme dem Nutzer etwas Richtiges weg. Was er
/// zusätzlich wissen muss, ist der Grund, warum sie nicht frischer werden.
struct AnmeldeHinweis: View {
    /// Sperrbildschirm und kleine Kachel: Der Hinweis muss sich die Zeile mit
    /// dem Stand teilen, und der Stand geht vor.
    var kompakt = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)
        HStack(spacing: 3) {
            Image(systemName: "key.slash")
            if kompakt {
                Text("anmelden")
            } else {
                Text("in der App anmelden")
            }
        }
        .font(.caption2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(ton.warnung)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Anmeldung fällig — in der App anmelden"))
    }
}

// MARK: - Die kompakte Liste

/// Eine Zeile je Karte: Name links, Wert rechts.
///
/// Das Widget zeigte lange nur Claude, obwohl in der App fünf Karten standen.
/// Diese Liste ist die Antwort — und sie ist bewusst **nur Text**: Fünf Balken
/// auf einer mittleren Kachel wären fünf Zeilen mehr, als dort hingehen, und
/// der Wert steht ohnehin ausgeschrieben daneben. Die Ampel trägt hier ein
/// Zeichen vor dem Namen, keine Farbe allein — auf einem eingetönten Homescreen
/// wäre Farbe gar nichts.
struct QuellenListe: View {
    let eintrag: UeberblickEintrag
    var maximum = 5
    /// Kleine Kachel und Sperrbildschirm: je Quelle **eine** Angabe. Der volle
    /// Wert würde dort abgeschnitten, und ein halber Betrag ist keine Auskunft.
    var knapp = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    private var sichtbare: ArraySlice<WidgetZustand.Quelle> { eintrag.quellen.prefix(maximum) }

    var body: some View {
        let ton = WidgetTon(schema, darstellung)

        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(sichtbare.enumerated()), id: \.offset) { _, quelle in
                zeile(quelle, ton: ton)
            }
            if eintrag.quellen.count > maximum {
                Text("+ \(eintrag.quellen.count - maximum) weitere in der App")
                    .font(.caption2)
                    .foregroundStyle(ton.leise)
            }
        }
    }

    private func zeile(_ quelle: WidgetZustand.Quelle, ton: WidgetTon) -> some View {
        // Ohne Prozentsatz gibt es keine Stufe — Geldkarten führen kein
        // Kontingent, und eine erfundene Ampel wäre schlimmer als keine.
        let stufe = quelle.prozent.map { LimitThresholds.standard.level($0) }

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let symbol = stufe?.symbol {
                Image(systemName: symbol)
                    .widgetAccentedRenderingMode(.fullColor)
                    .font(.system(size: 9))
            }
            Text(quelle.name)
                .fontWeight(.medium)
                .foregroundStyle(ton.neben)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Spacer(minLength: 3)
            Text(knapp ? quelle.kurz : quelle.wert)
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(stufe.map(ton.wert) ?? ton.haupt)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .font(knapp ? .system(size: 10) : .caption2)
        .accessibilityElement(children: .combine)
        // VoiceOver bekommt immer die volle Fassung — dort ist kein Platz knapp.
        .accessibilityLabel("\(quelle.name): \(quelle.wert)")
    }
}

// MARK: - Familien

/// Klein: ein Ring, die Prozentzahl in der Mitte, darunter Kürzel und Stand.
/// Dasselbe Bild zeigt StandBy.
struct KleineAnsicht: View {
    let eintrag: UeberblickEintrag

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)

        if eintrag.quellen.count > 1 {
            // Mehr als eine Quelle passt nicht in einen Ring. Die Liste ist
            // dann die ehrlichere Kachel — vier Zeilen statt einer Zahl, die
            // vier Fünftel des Bildes verschweigt.
            VStack(alignment: .leading, spacing: 5) {
                Text("AI Cockpit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ton.akzent)
                QuellenListe(eintrag: eintrag, maximum: 4, knapp: true)
                Spacer(minLength: 0)
                StandZeile(eintrag: eintrag, kompakt: true)
                if eintrag.anmeldungFaellig { AnmeldeHinweis(kompakt: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let fenster = eintrag.hauptfenster {
            VStack(spacing: 4) {
                UsageRing(percent: fenster.prozent,
                          provider: .claude,
                          label: .percent,
                          accessibilityTitle: "Claude \(fenster.name)")
                    // Der Ring ist das, was die Tönung einfärben soll; alles
                    // andere bleibt in der Grundgruppe.
                    .widgetAccentable()
                    .frame(maxHeight: .infinity)

                Text(fenster.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ton.neben)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Beides, nicht eines von beiden: Der Hinweis erklärt, warum
                // die Zahl nicht frischer wird — er ersetzt aber nicht die
                // Auskunft, wie alt sie ist. Der Ring gibt den Platz dafür her
                // (er wächst nur, soweit etwas übrig bleibt).
                StandZeile(eintrag: eintrag, kompakt: true)
                if eintrag.anmeldungFaellig { AnmeldeHinweis(kompakt: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EinladungsAnsicht(eintrag: eintrag)
        }
    }
}

/// Mittel: bis zu drei Balken mit Titel und Prozentzahl, plus Stand.
struct MittlereAnsicht: View {
    let eintrag: UeberblickEintrag
    /// Wie viele Zeilen die Liste zeigt. Balken brauchen mehr Platz als
    /// Textzeilen — für den Rückfall auf die Fensterliste bleibt es bei drei.
    var maximum = 3
    var mitZuruecksetzung = false

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        let ton = WidgetTon(schema, darstellung)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                // Der Kopf trägt den Namen der App, sobald mehrere Quellen
                // darunter stehen — «Claude» stimmte nur, solange die Kachel
                // nichts anderes zeigte.
                Text(eintrag.quellen.isEmpty ? "Claude" : "AI Cockpit")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ton.akzent)
                Spacer(minLength: 8)
                if eintrag.anmeldungFaellig { AnmeldeHinweis() }
                StandZeile(eintrag: eintrag)
            }

            if !eintrag.quellen.isEmpty {
                QuellenListe(eintrag: eintrag, maximum: maximum)
                // Auf der grossen Kachel ist unter der Liste noch Platz für die
                // Claude-Fenster mit Balken und Zurücksetzung. Auf der mittleren
                // nicht — dort ist die Liste die ganze Auskunft.
                if mitZuruecksetzung, !eintrag.fenster.isEmpty {
                    Divider().opacity(0.4)
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(eintrag.fenster.prefix(3).enumerated()), id: \.offset) { _, fenster in
                            FensterZeile(fenster: fenster, zeigtZuruecksetzung: true)
                        }
                    }
                }
                Spacer(minLength: 0)
            } else if eintrag.fenster.isEmpty {
                EinladungsAnsicht(eintrag: eintrag)
            } else {
                VStack(alignment: .leading, spacing: mitZuruecksetzung ? 9 : 7) {
                    ForEach(Array(eintrag.fenster.prefix(3).enumerated()), id: \.offset) { _, fenster in
                        FensterZeile(fenster: fenster, zeigtZuruecksetzung: mitZuruecksetzung)
                    }
                }
                // Weitere Fenster verschweigen wäre eine halbe Auskunft: Die
                // Kachel zeigt die ersten drei und sagt, dass es mehr gibt.
                if eintrag.fenster.count > 3 {
                    Text("+ \(eintrag.fenster.count - 3) weitere in der App")
                        .font(.caption2)
                        .foregroundStyle(ton.leise)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Sperrbildschirm, rund: ein Ring, ein Wert, sein Alter.
///
/// Hier steht **nicht** `Gauge`. Der Systemring sähe vertrauter aus, aber
/// `AccessoryCircularCapacityGaugeStyle` zeichnet seine Beschriftung auf dieser
/// Grösse gar nicht — gemessen, nicht vermutet: In der Vorschau blieb sie
/// spurlos weg. Übrig geblieben wäre eine Zahl ohne ihr Alter, und das ist
/// genau das, was hier nirgends stehen darf. Also der eigene Ring, mit zwei
/// Zeilen in der Mitte.
struct RundeAnsicht: View {
    let eintrag: UeberblickEintrag

    @Environment(\.colorScheme) private var schema
    @Environment(\.widgetRenderingMode) private var darstellung

    var body: some View {
        if let fenster = eintrag.hauptfenster {
            // Die Verhältnisse sind auf die 58 Punkte gerechnet, die eine
            // runde Zubehörkachel innen hat — `UsageRing` skaliert sie mit.
            UsageRing(percent: fenster.prozent,
                      provider: .claude,
                      label: .none,
                      lineWidthRatio: 5.0 / 58.0,
                      paddingRatio: 1.5 / 58.0)
                .overlay { mitte(fenster) }
                .widgetAccentable()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Claude \(fenster.name)")
                .accessibilityValue(gesprochen(fenster))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: eintrag.anmeldungFaellig ? "key.slash" : "hourglass")
                    Text(eintrag.anmeldungFaellig ? "anmelden" : "öffnen")
                        .font(.system(size: 9))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(eintrag.anmeldungFaellig
                                ? String(localized: "In der App anmelden")
                                : String(localized: "Noch keine Zahlen — AI Cockpit öffnen"))
        }
    }

    private func mitte(_ fenster: WidgetZustand.Fenster) -> some View {
        VStack(spacing: -1) {
            Text(Format.percentDigits(fenster.prozent))
                .font(.system(size: 19, weight: .semibold))
            // Winzig, aber vorhanden. Eine Zahl ohne ihr Alter gibt es auch
            // auf der kleinsten Fläche nicht.
            HStack(spacing: 1) {
                Image(systemName: eintrag.veraltet ? "clock.badge.exclamationmark" : "clock")
                Text(eintrag.kurzesAlter ?? "—")
            }
            .font(.system(size: 9))
            .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.horizontal, 2)
    }

    private func gesprochen(_ fenster: WidgetZustand.Fenster) -> String {
        var teile = [Format.percent(fenster.prozent)]
        if let hinweis = LimitThresholds.standard.level(fenster.prozent).spokenLabel {
            teile.append(hinweis)
        }
        if let stand = eintrag.stand {
            teile.append(String(localized: "Stand \(stand.formatted(.relative(presentation: .named)))"))
        }
        if eintrag.anmeldungFaellig { teile.append(String(localized: "Anmeldung fällig")) }
        return teile.joined(separator: ", ")
    }
}

/// Sperrbildschirm, rechteckig: zwei Zeilen.
///
/// Oben das Fenster, das drückt, unten das zweite und der Stand. Mehr passt
/// nicht, und mehr braucht es auch nicht: Wer hier nachsieht, will wissen, ob
/// es reicht — nicht, wie es sich verteilt.
struct RechteckigeAnsicht: View {
    let eintrag: UeberblickEintrag

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if eintrag.quellen.count > 1 {
                // Drei Zeilen sind hier das Mass; der Stand gehört in die
                // letzte, sonst stünde eine Zahl ohne ihr Alter da.
                QuellenListe(eintrag: eintrag, maximum: 2, knapp: true)
                HStack(spacing: 5) {
                    if eintrag.anmeldungFaellig { AnmeldeHinweis(kompakt: true) }
                    KurzStand(eintrag: eintrag)
                }
            } else if let erstes = eintrag.hauptfenster {
                zeile(erstes, betont: true)
                zweiteZeile
            } else {
                EinladungsAnsicht(eintrag: eintrag, kompakt: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Die zweite Zeile trägt den Stand — **immer**. Das zweite Fenster weicht,
    /// wenn der Anmeldehinweis dazukommt: Zwei Zahlen und zwei Hinweise passen
    /// auf 160 Punkte nicht, und von den vieren ist das zweite Fenster das
    /// entbehrlichste.
    @ViewBuilder
    private var zweiteZeile: some View {
        HStack(spacing: 5) {
            if eintrag.anmeldungFaellig {
                AnmeldeHinweis(kompakt: true)
            } else if eintrag.fenster.count > 1 {
                zeile(eintrag.fenster[1], betont: false)
            }
            // Kurzfassung, nicht die laufende: «vor 3 Min., 10 Sek.» wurde auf
            // dieser Breite abgeschnitten — und abgeschnitten ist das Alter
            // keine Auskunft mehr.
            KurzStand(eintrag: eintrag)
        }
    }

    private func zeile(_ fenster: WidgetZustand.Fenster, betont: Bool) -> some View {
        let stufe = LimitThresholds.standard.level(fenster.prozent)
        return HStack(spacing: 4) {
            if let symbol = stufe.symbol {
                Image(systemName: symbol).widgetAccentedRenderingMode(.fullColor)
            }
            Text(fenster.name)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(Format.percent(fenster.prozent))
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(betont ? .headline : .caption2)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        // Die obere Zeile ist das, was die Tönung des Sperrbildschirms
        // hervorheben soll.
        .widgetAccentable(betont)
    }
}

// MARK: - Verteiler

/// Wählt die Ansicht zur Familie und setzt den Hintergrund.
struct UeberblickAnsicht: View {
    let eintrag: UeberblickEintrag

    @Environment(\.widgetFamily) private var familie
    @Environment(\.colorScheme) private var schema

    var body: some View {
        inhalt
            // Zubehör auf dem Sperrbildschirm bekommt seinen Grund vom System;
            // eine eigene Fläche darunter sähe dort wie ein Fehler aus.
            .containerBackground(for: .widget) {
                if istZubehoer { Color.clear } else { Theme.palette(schema).background }
            }
    }

    /// `accessoryCorner` fehlt in dieser Aufzählung, weil es die Familie unter
    /// iOS nicht gibt — sie ist eine Sache der Uhr.
    private var istZubehoer: Bool {
        familie == .accessoryCircular || familie == .accessoryRectangular
            || familie == .accessoryInline
    }

    @ViewBuilder
    private var inhalt: some View {
        switch familie {
        case .systemSmall:
            KleineAnsicht(eintrag: eintrag)
        case .systemMedium:
            // Fünf statt der früheren drei: Die Liste führt eine Zeile je
            // Karte, und «+ 2 weitere in der App» auf einer Kachel, auf der
            // fünf Zeilen Platz haben, wäre eine selbstgemachte Lücke.
            MittlereAnsicht(eintrag: eintrag, maximum: 5)
        case .systemLarge:
            MittlereAnsicht(eintrag: eintrag, maximum: 5, mitZuruecksetzung: true)
        case .accessoryCircular:
            RundeAnsicht(eintrag: eintrag)
        case .accessoryRectangular:
            RechteckigeAnsicht(eintrag: eintrag)
        default:
            // Nicht angemeldete Familien kann das System trotzdem anfragen —
            // etwa bei einer neuen Systemfassung. Die kleine Ansicht ist die
            // anspruchsloseste; sie kommt mit jeder Fläche zurecht.
            KleineAnsicht(eintrag: eintrag)
        }
    }
}

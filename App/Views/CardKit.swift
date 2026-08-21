import SwiftUI
import AgentDeckCore

// Die Bausteine einer Karte: der Rahmen, die Limit-Zeile, der Balken.
//
// Übernommen aus der Mac-Fassung (`AgentDeck/Views/CardKit.swift`) sind die
// Masse, die das Aussehen ausmachen — Akzentkante, Radius, Rahmenstärke,
// Badge — und die Ampellogik. Anders ist alles, was mit einem Finger statt
// einem Zeiger bedient wird: mehr Innenabstand, 44 Punkte hohe Tippflächen,
// ein eigener Balken statt `ProgressView(.small)` (der ist auf iOS drei Punkte
// dünn und in einer Liste kaum zu treffen mit dem Auge).

// MARK: - Karte

/// Ein abgesetzter Abschnitt mit farbiger Kante — die Quellen sollen sich auf
/// einen Blick unterscheiden, nicht nur durch eine dünne Linie.
struct Card<Content: View>: View {
    let title: String
    var badge: String?
    var note: String?
    var updated: Date?
    /// Wird für diese Karte gerade nachgeladen?
    ///
    /// Die Karte behält dabei ihre letzten Zahlen — ein Abruf, der eine Minute
    /// braucht, soll die Anzeige nicht eine Minute lang leeren. Ohne ein
    /// Zeichen dafür sähe der alte Stand allerdings aus wie der aktuelle: Das
    /// Alter daneben liest niemand, solange nichts darauf hinweist.
    var wirdGeholt = false
    /// Kurzfassung für den eingeklappten Zustand. `nil` heisst: nichts
    /// Sinnvolles zu zeigen — dann lässt sich die Karte auch nicht einklappen,
    /// eine leere Zeile zuzuklappen bringt niemandem etwas.
    var summary: CardSummary?
    var provider: Theme.Provider
    /// Wer den Zustand über die Karte hinaus behalten will, reicht eine Bindung
    /// herein; sonst merkt sich die Karte es selbst.
    var collapsed: Binding<Bool>?
    /// Weckt die «vor x Minuten»-Angabe. Ohne diesen Wert bliebe sie stehen,
    /// bis die Karte aus einem anderen Grund neu gezeichnet wird.
    var tick: Date
    let content: Content

    @State private var localCollapsed = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: String,
         badge: String? = nil,
         note: String? = nil,
         updated: Date? = nil,
         wirdGeholt: Bool = false,
         summary: CardSummary? = nil,
         provider: Theme.Provider = .neutral,
         collapsed: Binding<Bool>? = nil,
         tick: Date = .distantPast,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.badge = badge
        self.note = note
        self.updated = updated
        self.wirdGeholt = wirdGeholt
        self.summary = summary
        self.provider = provider
        self.collapsed = collapsed
        self.tick = tick
        self.content = content()
    }

    private var collapsible: Bool { summary != nil }
    private var isCollapsed: Bool { collapsible && (collapsed?.wrappedValue ?? localCollapsed) }

    private func toggle() {
        if let collapsed {
            collapsed.wrappedValue.toggle()
        } else {
            localCollapsed.toggle()
        }
    }

    var body: some View {
        let palette = Theme.palette(scheme)
        let accent = palette.color(for: provider)

        VStack(alignment: .leading, spacing: 10) {
            header(palette: palette, accent: accent)
            if !isCollapsed { content }
        }
        // 14 statt 10 wie auf dem Mac: Ein Finger braucht Rand, sonst trifft er
        // beim Scrollen den Kartenkopf.
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(palette.cardBorder, lineWidth: 0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3).padding(.vertical, 8)
        }
        .animation(.snappy(duration: 0.18), value: isCollapsed)
    }

    // MARK: Kopfzeile

    private func header(palette: Theme.Palette, accent: Color) -> some View {
        // Bei den grossen Schriftgraden stehen Titel und Kurzfassung
        // untereinander. Nebeneinander bliebe für die Kurzfassung eine Spalte
        // von zwei Zentimetern — und die trifft die Regel, dass nichts
        // abgeschnitten werden darf, härter als jede andere Stelle.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return layout {
            titleBlock(palette: palette, accent: accent)
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing(palette: palette)
        }
        // Die Kopfzeile ist der Schalter der Karte — sie muss so hoch sein,
        // dass ein Daumen sie trifft, auch wenn nur «Kimi» darin steht.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .modifier(TapOrButton(enabled: collapsible, action: toggle))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(collapsible
                            ? (isCollapsed ? String(localized: "eingeklappt") : String(localized: "ausgeklappt"))
                            : "")
        .accessibilityHint(collapsible ? String(localized: "Klappt die Karte auf oder zu") : "")
        .accessibilityAddTraits(collapsible ? .isButton : [])
    }

    private func titleBlock(palette: Theme.Palette, accent: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if collapsible {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.faint)
                    .frame(width: 12)
            }
            // Das Zeichen vor dem Namen. Die farbige Kante links steht weiter
            // am Rand, aber sie liegt ausserhalb des Blicks, sobald er auf dem
            // Text ruht — und in der Widget-Zeile gibt es sie gar nicht. Ein
            // Zeichen an dieser Stelle findet man in beiden.
            AnbieterZeichen(name: title, anbieter: provider, groesse: 22)
                // In einer Zeile, die an der Schriftlinie ausgerichtet ist,
                // hätte ein Feld ohne Text keine — es sässe sonst auf der
                // Unterkante und damit sichtbar zu tief.
                .alignmentGuide(.firstTextBaseline) { $0.height * 0.78 }
            // Der Name trägt die Anbieterfarbe: die schmale Kante links sieht
            // man nicht mehr, sobald der Blick auf dem Text liegt.
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .fixedSize(horizontal: false, vertical: true)
            if let badge {
                Text(badge)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(accent.opacity(0.22), in: Capsule())
                    .foregroundStyle(accent)
            }
            if let note, !isCollapsed {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func trailing(palette: Theme.Palette) -> some View {
        HStack(alignment: .center, spacing: 6) {
            if wirdGeholt {
                ProgressView()
                    .controlSize(.mini)
                    // Ein Kreisel ist für VoiceOver stumm. Ohne diese Zeile
                    // wäre der Hinweis genau für die nicht da, die ihn am
                    // wenigsten erraten können.
                    .accessibilityLabel(Text("wird aktualisiert …"))
            }
            inhalt(palette: palette)
        }
    }

    @ViewBuilder
    private func inhalt(palette: Theme.Palette) -> some View {
        if isCollapsed, let summary {
            // Der Kern der Sache: Eine Warnung darf sich nicht wegklappen
            // lassen. Steht ein Fenster über der Schwelle, fällt die
            // Kurzfassung auf — mit Zeichen, nicht nur mit Farbe.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if summary.warning {
                    // Das Zeichen darf nicht schrumpfen, wenn der Text es tut.
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .layoutPriority(1)
                }
                Text(summary.text)
                    .font(.callout.weight(.semibold)).monospacedDigit()
                    // Die Kurzfassung bringt ihre Zeilen selbst mit: je ein
                    // Zeitraum und ein Wert, untereinander. Zwei kurze Zeilen
                    // lassen sich mit einem Blick vergleichen, eine lange
                    // nicht. Abgeschnitten wird nichts — «7 d: 48…» wäre eine
                    // halbe Zahl, und die ist schlimmer als keine.
                    .lineLimit(nil)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(summary.warning ? palette.warning : palette.secondary)
        } else if let updated {
            Text(ago(updated))
                .font(.caption2).monospacedDigit()
                .foregroundStyle(palette.faint)
        }
    }

    private func ago(_ date: Date) -> String {
        _ = tick
        return Theme.ago(date)
    }
}

/// Macht aus einer Ansicht einen Knopf — aber nur, wenn es etwas zu drücken gibt.
///
/// Eine Kopfzeile ohne Kurzfassung ist nicht einklappbar; sie dann trotzdem als
/// Knopf auszuzeichnen, hiesse VoiceOver etwas zu versprechen, das nicht
/// passiert.
private struct TapOrButton: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            Button(action: action) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Was von einer Karte übrig bleibt, wenn sie zugeklappt ist.
struct CardSummary: Equatable, Sendable {
    let text: String
    var warning = false

    init(text: String, warning: Bool = false) {
        self.text = text
        self.warning = warning
    }
}

// MARK: - Balken

/// Der Füllstand eines Fensters.
///
/// Statt `ProgressView`: Der iOS-Balken ist dünner als der des Mac, lässt sich
/// in der Höhe nicht setzen und bringt einen Rand mit, der auf einer Karte
/// stört. Sechs Punkte und eine Kapsel sind hier näher am Original als das
/// Systemelement.
///
/// Die Marken an Warn- und Alarmschwelle sind eine Zutat: Sie sagen ohne jede
/// Farbe, wo «zu viel» anfängt — auch in einem eingefärbten Widget.
struct UsageBar: View {
    let percent: Double
    let tint: Color
    var thresholds: LimitThresholds = .standard
    var height: CGFloat = 6

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)
        let anteil = percent.isFinite ? min(max(percent / 100, 0), 1) : 0

        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(palette.hairline.opacity(0.45))

                ForEach(thresholds.marks, id: \.self) { marke in
                    Rectangle()
                        .fill(palette.faint.opacity(0.7))
                        .frame(width: 1, height: height)
                        .offset(x: min(width * marke, max(width - 1, 0)))
                }

                // Mindestens so breit wie hoch, sonst ist ein Prozent ein
                // Punkt und damit nicht von «leer» zu unterscheiden.
                Capsule()
                    .fill(tint)
                    .overlay { Glanz().clipShape(Capsule()) }
                    .frame(width: anteil > 0 ? max(width * anteil, height) : 0)
            }
        }
        .frame(height: height)
        // Die Zahl steht daneben und wird vorgelesen; der Balken ist nur ihr Bild.
        .accessibilityHidden(true)
    }
}

// MARK: - Limit-Zeile

/// Ein Nutzungsfenster: Titel, Prozent, Balken, Zurücksetzung, Hochrechnung.
struct LimitRow: View {
    let title: String
    let window: LimitWindow
    var thresholds: LimitThresholds = .standard
    /// Hochrechnung dieses Fensters, falls genug Verlauf vorliegt.
    var forecast: Forecast?
    var provider: Theme.Provider = .neutral
    var muted = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: String,
         window: LimitWindow,
         thresholds: LimitThresholds = .standard,
         forecast: Forecast? = nil,
         provider: Theme.Provider = .neutral,
         muted: Bool = false) {
        self.title = title
        self.window = window
        self.thresholds = thresholds
        self.forecast = forecast
        self.provider = provider
        self.muted = muted
    }

    var body: some View {
        let palette = Theme.palette(scheme)
        let level = thresholds.level(window.usedPercent)
        let tint = level.color(in: palette, accent: palette.color(for: provider))

        VStack(alignment: .leading, spacing: 5) {
            kopf(palette: palette, level: level, tint: tint)
            UsageBar(percent: window.usedPercent, tint: tint, thresholds: thresholds)
            if let reset = window.resetsAt { resetZeile(reset, palette: palette) }
            if let forecast, let text = forecastText(forecast) {
                hochrechnung(forecast, text: text, palette: palette)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(gesprochenerWert(level))
    }

    // MARK: Zeilen

    private func kopf(palette: Theme.Palette, level: LimitLevel, tint: Color) -> some View {
        // Bei den grössten Schriftgraden rutscht der Prozentwert unter den
        // Titel, statt ihn wegzudrücken.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return layout {
            // Eine Zeile, dann gekürzt: Bei den modellbezogenen Fenstern steckt
            // im Titel ein Name aus der Netzantwort.
            Text(title)
                .font(muted ? .caption : .callout)
                .foregroundStyle(palette.primary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                // Die Zahl steht **immer** da. Der Balken färbt sich, aber
                // niemand muss die Farbe deuten können, um den Wert zu kennen.
                Text(Format.percent(window.usedPercent))
                    // Ein Wert sieht überall gleich aus: `.callout`, halbfett,
                    // Ziffern gleich breit. Vorher trugen Prozent, Betrag und
                    // Kurzfassung drei verschiedene Grössen für dieselbe Art
                    // Information, und das las sich wie eine Rangfolge, die es
                    // nicht gibt.
                    .font(muted ? .caption.weight(.semibold) : .callout.weight(.semibold))
                    .monospacedDigit()
                    // **Ruhig, solange nichts ist.**
                    //
                    // Vorher trug die Zahl durchgehend die Auslastungsfarbe —
                    // bei fünf Karten mit je zwei bis drei Fenstern also ein
                    // Dutzend farbiger Zahlen, von denen keine etwas meldete.
                    // Farbe, die immer da ist, sagt nichts mehr, wenn sie
                    // einmal etwas sagen müsste. Jetzt ist sie ein Signal:
                    // normal steht weiss, orange heisst eng, rot heisst voll.
                    .foregroundStyle(level == .normal ? palette.primary : tint)
                if let symbol = level.symbol {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                Text("genutzt")
                    .font(.caption2)
                    .foregroundStyle(palette.faint)
            }
        }
    }

    /// Ein Text statt drei nebeneinander: So bricht die Zeile bei grosser
    /// Schrift um, statt den Trenner in die nächste Zeile zu schieben.
    private func resetZeile(_ reset: Date, palette: Theme.Palette) -> some View {
        Text("Zurücksetzung \(Theme.absolute(reset))")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(palette.faint)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func hochrechnung(_ forecast: Forecast, text: String, palette: Theme.Palette) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: forecast.hitsLimitBeforeReset
                  ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis")
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption2)
        .foregroundStyle(forecast.hitsLimitBeforeReset ? palette.warning : palette.faint)
    }

    /// «≈ 14 %/h · voll um 16:40 — vor der Zurücksetzung». Steht der Verbrauch,
    /// bleibt die Zeile weg: eine Hochrechnung ohne Bewegung sagt nichts.
    private func forecastText(_ forecast: Forecast) -> String? {
        guard forecast.ratePerHour > 0.05 else { return nil }
        let rate = String(format: "≈ %.1f %%/h", forecast.ratePerHour)
        guard let exhausted = forecast.exhaustedAt else {
            return String(localized: "\(rate) · reicht über die Zurücksetzung hinaus")
        }
        let base = String(localized: "\(rate) · voll um \(Theme.absolute(exhausted))")
        return forecast.hitsLimitBeforeReset ? String(localized: "\(base) — vor der Zurücksetzung") : base
    }

    private func gesprochenerWert(_ level: LimitLevel) -> String {
        var teile = [Format.percent(window.usedPercent)]
        if let hinweis = level.spokenLabel { teile.append(hinweis) }
        if let reset = window.resetsAt {
            teile.append(String(localized: "Zurücksetzung \(reset.formatted(.relative(presentation: .named)))"))
        }
        return teile.joined(separator: ", ")
    }
}

// MARK: - Geldzeile

struct MoneyRow: View {
    let title: String
    let value: Decimal
    let currency: String
    var muted = false
    var emphasised = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: String, value: Decimal, currency: String, muted: Bool = false, emphasised: Bool = false) {
        self.title = title
        self.value = value
        self.currency = currency
        self.muted = muted
        self.emphasised = emphasised
    }

    var body: some View {
        let palette = Theme.palette(scheme)
        // Die Beschriftung bleibt schlank, der **Wert** ist überall halbfett —
        // dieselbe Grösse wie die Prozentzahl in der Fensterzeile.
        let beschriftung: Font = emphasised ? .callout.weight(.medium) : .callout
        let wertschrift: Font = .callout.weight(.semibold)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return layout {
            Text(title)
                .font(beschriftung)
                .foregroundStyle(muted ? palette.secondary : palette.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.money(value, currency))
                .font(wertschrift)
                .monospacedDigit()
                .foregroundStyle(muted ? palette.secondary : palette.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Zustände ohne Daten

/// Was eine Karte zeigt, solange sie keine Daten hat.
///
/// Drei Lagen, die auf dem Mac lange dieselbe Meldung trugen und deshalb
/// irreführten: Es lädt noch, es ist nichts eingerichtet, oder es ist etwas
/// schiefgegangen. Jede bekommt ihr eigenes Zeichen — wieder nicht nur Farbe.
enum CardStatus: Equatable, Sendable {
    case loading(String)
    case missing(String)
    case failed(String)
}

struct StatusNote: View {
    let status: CardStatus
    /// Knopftext und Aktion — «Einrichten» bzw. «Erneut versuchen».
    var actionTitle: String?
    var action: (() -> Void)?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    init(status: CardStatus, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.status = status
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        let palette = Theme.palette(scheme)
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return layout {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                switch status {
                case .loading:
                    ProgressView().controlSize(.small)
                case .missing:
                    Image(systemName: "key.slash").font(.caption)
                case .failed:
                    Image(systemName: "exclamationmark.circle.fill").font(.caption)
                }
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(farbe(palette))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.callout.weight(.medium))
                    .buttonStyle(.borderless)
                    .tint(palette.accent)
                    .frame(minHeight: 44)
            }
        }
    }

    private var text: String {
        switch status {
        case .loading(let s), .missing(let s), .failed(let s): return s
        }
    }

    private func farbe(_ palette: Theme.Palette) -> Color {
        switch status {
        case .loading, .missing: return palette.secondary
        case .failed: return palette.warning
        }
    }
}

/// Ein kleines Etikett — Modellname, Denkstufe, Zustand einer Sitzung.
struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        // In einem Etikett steht auch Fremdes — Modellname, Denkstufe. Ohne
        // Begrenzung schöbe ein langer Wert die ganze Zeile auseinander.
        Text(text)
            .lineLimit(1).truncationMode(.tail)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
            .foregroundStyle(color)
    }
}

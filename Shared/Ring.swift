import SwiftUI

// Der Ring aus der Menüleiste, als Ansicht.
//
// Auf dem Mac zeichnet `MenuBarIconRenderer.ringImage` ihn mit `NSBezierPath`
// in eine Bitmap von 22 Punkten — eine feste Grösse, weil die Menüleiste eine
// feste Höhe hat. Hier ist er eine `Shape`: Dieselbe Ansicht soll in einer
// Karte, in der Kennzahlenleiste und später in einem Widget stehen, und ein
// Widget wird vom System skaliert, nicht von uns. Alle Masse sind deshalb
// Anteile der Kantenlänge, keine Punktwerte.

// MARK: - Form

/// Der Füllbogen: ab 12 Uhr, im Uhrzeigersinn, `fraction` von 0…1.
struct RingArc: Shape {
    var fraction: Double

    /// Damit ein Wertwechsel läuft statt springt.
    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let anteil = min(max(fraction, 0), 1)
        guard anteil > 0 else { return Path() }

        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        // SwiftUI misst Winkel ab 3 Uhr in einem Koordinatensystem, dessen
        // y-Achse nach unten zeigt. −90° ist damit 12 Uhr, und weil die Achse
        // gespiegelt ist, läuft `clockwise: false` genau im Uhrzeigersinn.
        // (AppKit braucht für dieselbe Richtung `clockwise: true` — dort zeigt
        // y nach oben. Wer das verwechselt, bekommt einen Ring, der rückwärts
        // läuft, und merkt es erst bei Werten über 50 %.)
        path.addArc(center: center,
                    radius: side / 2,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * anteil),
                    clockwise: false)
        return path
    }
}

// MARK: - Ansicht

/// Was in der Mitte des Rings steht.
enum RingLabel: Equatable {
    /// Nichts — für sehr kleine Ringe und für Stellen, an denen die Zahl
    /// ohnehin daneben steht.
    case none
    /// Der Prozentwert als Ziffern.
    case percent
    /// Ein SF-Symbol, wie es die Menüleiste zeigt.
    case symbol(String)
    /// Ziffern, sobald sie lesbar sind; darunter nichts.
    case automatic
}

/// Ein Nutzungsfenster als Ring.
///
/// Die Farbe sagt hier nie allein, wie es steht: Ab der Warnschwelle tritt ein
/// Zeichen an den Rand des Rings, und der Wert steht als Text in der Mitte oder
/// zumindest im VoiceOver-Wert. Ein eingefärbtes Widget bleibt damit lesbar.
struct UsageRing: View {
    let percent: Double?
    var thresholds: LimitThresholds = .standard
    var provider: Theme.Provider = .neutral
    var label: RingLabel = .automatic
    /// 3 von 22 Punkten — das Verhältnis der Menüleistenfassung.
    var lineWidthRatio: CGFloat = 3.0 / 22.0
    /// Ein Punkt Luft bei 22 — sonst schneidet der runde Abschluss an der Kante ab.
    var paddingRatio: CGFloat = 1.0 / 22.0
    /// Wird VoiceOver vorangestellt: «Claude 5 Stunden, 42 Prozent».
    var accessibilityTitle: String? = nil

    @Environment(\.colorScheme) private var scheme

    init(percent: Double?,
         thresholds: LimitThresholds = .standard,
         provider: Theme.Provider = .neutral,
         label: RingLabel = .automatic,
         lineWidthRatio: CGFloat = 3.0 / 22.0,
         paddingRatio: CGFloat = 1.0 / 22.0,
         accessibilityTitle: String? = nil) {
        self.percent = percent
        self.thresholds = thresholds
        self.provider = provider
        self.label = label
        self.lineWidthRatio = lineWidthRatio
        self.paddingRatio = paddingRatio
        self.accessibilityTitle = accessibilityTitle
    }

    var body: some View {
        let palette = Theme.palette(scheme)
        let level = percent.map { thresholds.level($0) } ?? .normal
        let tint = level.color(in: palette, accent: palette.color(for: provider))

        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(side * lineWidthRatio, 1)
            let inset = lineWidth / 2 + side * paddingRatio
            // Das grösste Quadrat im freien Innenkreis, minus etwas Luft — ein
            // Zeichen, das den Ring berührt, sieht aus wie ein Zeichenfehler.
            //
            // In drei Schritten und nicht in einem: Als eine Zeile gab der
            // Typprüfer für watchOS auf («unable to type-check this expression
            // in reasonable time»). Sechs CGFloat-Operationen mit einem
            // Literal dazwischen reichen dafür schon. Gerechnet wird
            // unverändert dasselbe.
            let innenDurchmesser = side - 2 * inset - lineWidth
            let luft = side * paddingRatio
            let clear = max(innenDurchmesser / 1.414 - luft, 0)

            ZStack {
                // Dezenter Spurring, sonst ist der Füllstand bei kleinen Werten
                // kaum zu erkennen.
                RingArc(fraction: 1)
                    .stroke(palette.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: lineWidth))

                RingArc(fraction: (percent ?? 0) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                center(level: level, palette: palette, tint: tint, clear: clear)
                    .frame(width: clear, height: clear)
            }
            .padding(inset)
            .frame(width: side, height: side)
            // Die Warnung sitzt aussen auf dem Ring, nicht in ihm: In der Mitte
            // stünde sie gegen die Ziffern, und genau die will man behalten.
            .overlay(alignment: .topTrailing) {
                if let symbol = level.symbol {
                    Image(systemName: symbol)
                        .font(.system(size: max(side * 0.26, 8)))
                        .foregroundStyle(tint)
                        .background(palette.background, in: Circle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle ?? String(localized: "Auslastung"))
        .accessibilityValue(spokenValue(level))
        .animation(.snappy(duration: 0.25), value: percent)
    }

    @ViewBuilder
    private func center(level: LimitLevel, palette: Theme.Palette, tint: Color, clear: CGFloat) -> some View {
        switch resolvedLabel(clear: clear) {
        case .none, .automatic:
            EmptyView()
        case .percent:
            // Hier steht ausnahmsweise eine gerechnete Schriftgrösse statt
            // eines semantischen Stils: Die Ziffer ist Teil einer Zeichnung und
            // muss sich mit ihr skalieren. Vorgelesen wird ohnehin der Wert aus
            // `accessibilityValue`, und `minimumScaleFactor` fängt lange
            // Zahlen ab.
            Text(percent.map { Format.percentDigits($0) } ?? "–")
                .font(.system(size: clear * 0.62, weight: .semibold))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(palette.primary)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: clear * 0.8))
                .foregroundStyle(palette.primary)
        }
    }

    /// Unter etwa zwölf Punkten freier Fläche ist eine zweistellige Zahl nur
    /// noch ein grauer Fleck — dann lieber nichts.
    private func resolvedLabel(clear: CGFloat) -> RingLabel {
        guard case .automatic = label else { return label }
        return clear >= 12 ? .percent : .none
    }

    private func spokenValue(_ level: LimitLevel) -> String {
        guard let percent else { return String(localized: "kein Wert") }
        guard let hinweis = level.spokenLabel else { return Format.percent(percent) }
        return "\(Format.percent(percent)), \(hinweis)"
    }
}

#Preview("Ring in allen Grössen") {
    VStack(spacing: 24) {
        HStack(alignment: .bottom, spacing: 16) {
            UsageRing(percent: 42, provider: .claude).frame(width: 20, height: 20)
            UsageRing(percent: 42, provider: .claude).frame(width: 44, height: 44)
            UsageRing(percent: 78, provider: .chatGPT).frame(width: 72, height: 72)
            UsageRing(percent: 94, provider: .openAI).frame(width: 120, height: 120)
        }
        UsageRing(percent: 63, provider: .kimi, label: .symbol("brain"))
            .frame(width: 96, height: 96)
    }
    .padding(32)
    .background(Theme.dark.background)
}

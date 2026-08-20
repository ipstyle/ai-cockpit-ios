import SwiftUI
import AgentDeckCore

// Die Kartenliste — das, was die Mac-App im Popover zeigt, für einen Finger.
//
// Auf dem Mac stehen die Karten in zwei festen Spalten, weil das Fenster
// mindestens 780 Punkte breit ist. Hier entscheidet die Breite: ein iPhone
// bekommt eine Spalte, ein iPad zwei. Es ist **eine** Anordnung mit einer
// Zahl darin, kein zweites Layout — ein iPad im Splitview ist mal 320 und mal
// 1100 Punkte breit, und nach dem Gerät zu fragen beantwortet die falsche
// Frage.

// MARK: - Was die Liste zeigt

/// Eine Karte, wie die Liste sie zeigt.
///
/// Die Mac-Fassung baut ihre Karten direkt aus `AppStore` — einem Typ des
/// Mac-Ziels mit rund vierzig Eigenschaften, Netzabruf und Schlüsselbund.
/// Solange es hier kein iOS-Gegenstück gibt, ist das hier die Nahtstelle: Die
/// Ansicht kennt nur diese Struktur, und wer sie füllt, ist ihr gleich.
struct CockpitCard: Identifiable {
    let id: CardLayout.Card
    let title: String
    var provider: Theme.Provider
    var badge: String?
    var note: String?
    var updated: Date?
    var summary: CardSummary?
    var limits: [CockpitLimit] = []
    var money: [CockpitMoney] = []
    var status: CardStatus?
    /// Text des Knopfs neben `status` — «Einrichten», «Erneut versuchen».
    var actionTitle: String?

    init(id: CardLayout.Card,
         title: String,
         provider: Theme.Provider,
         badge: String? = nil,
         note: String? = nil,
         updated: Date? = nil,
         summary: CardSummary? = nil,
         limits: [CockpitLimit] = [],
         money: [CockpitMoney] = [],
         status: CardStatus? = nil,
         actionTitle: String? = nil) {
        self.id = id
        self.title = title
        self.provider = provider
        self.badge = badge
        self.note = note
        self.updated = updated
        self.summary = summary
        self.limits = limits
        self.money = money
        self.status = status
        self.actionTitle = actionTitle
    }
}

/// Ein Nutzungsfenster einer Karte. `id` ist der Titel plus Fenstername — die
/// modellbezogenen Wochenfenster tragen einen Namen aus der Netzantwort, und
/// zwei davon können gleich heissen.
struct CockpitLimit: Identifiable {
    let id: String
    let title: String
    let window: LimitWindow
    var forecast: Forecast?

    init(id: String? = nil, title: String, window: LimitWindow, forecast: Forecast? = nil) {
        self.id = id ?? "\(title)|\(window.label)"
        self.title = title
        self.window = window
        self.forecast = forecast
    }
}

/// Eine Kostenzeile.
struct CockpitMoney: Identifiable {
    let id: String
    let title: String
    let value: Decimal
    let currency: String
    var emphasised = false

    init(id: String? = nil, title: String, value: Decimal, currency: String, emphasised: Bool = false) {
        self.id = id ?? title
        self.title = title
        self.value = value
        self.currency = currency
        self.emphasised = emphasised
    }
}

// MARK: - Liste

struct CardsView: View {
    let cards: [CockpitCard]
    var lastUpdated: Date?
    var isRefreshing: Bool
    var thresholds: LimitThresholds
    /// Kennungen der eingeklappten Karten, mit Komma getrennt — genau das
    /// Format, das `AppSettings.collapsedCards` auf dem Mac ablegt. Zerlegt
    /// wird es von `CardLayout` im Kern, damit beide Seiten dieselbe Regel
    /// benutzen und nicht je eine eigene.
    @Binding var collapsedCards: String
    let refresh: @Sendable () async -> Void
    var openSettings: () -> Void
    var cardAction: (CardLayout.Card) -> Void

    @Environment(\.colorScheme) private var scheme
    /// Hält die «vor x Minuten»-Angaben in Bewegung.
    @State private var tick = Date()
    private let clock = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    init(cards: [CockpitCard],
         lastUpdated: Date? = nil,
         isRefreshing: Bool = false,
         thresholds: LimitThresholds = .standard,
         collapsedCards: Binding<String>,
         refresh: @escaping @Sendable () async -> Void,
         openSettings: @escaping () -> Void = {},
         cardAction: @escaping (CardLayout.Card) -> Void = { _ in }) {
        self.cards = cards
        self.lastUpdated = lastUpdated
        self.isRefreshing = isRefreshing
        self.thresholds = thresholds
        self._collapsedCards = collapsedCards
        self.refresh = refresh
        self.openSettings = openSettings
        self.cardAction = cardAction
    }

    var body: some View {
        let palette = Theme.palette(scheme)

        VStack(spacing: 0) {
            header(palette)
            Rectangle().fill(palette.cardBorder).frame(height: 0.5)
            liste(palette)
        }
        .background(palette.background)
        .onReceive(clock) { tick = $0 }
    }

    // MARK: Kopfzeile

    /// Steht fest über der Liste statt mit ihr zu scrollen: Der
    /// Aktualisieren-Knopf ist das, was man am häufigsten drückt, und der
    /// Zeitstempel ist das, was man am häufigsten liest.
    private func header(_ palette: Theme.Palette) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Cockpit")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(palette.primary)
                Text(updatedText)
                    .font(.caption)
                    .foregroundStyle(palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            // Alle auf einmal — wie in der Menüleistenfassung. Das Zeichen
            // zeigt an, was der Druck bewirkt, nicht den heutigen Zustand:
            // Sind alle zu, weist es nach aussen («aufklappen»), sonst nach
            // innen. Zusammen mit der Beschriftung für VoiceOver ist damit
            // beides eindeutig, ohne dass Farbe eine Rolle spielt.
            knopf(systemImage: alleZu ? "arrow.up.left.and.arrow.down.right"
                                      : "arrow.down.right.and.arrow.up.left",
                  label: alleZu ? String(localized: "Alle Karten aufklappen")
                                : String(localized: "Alle Karten einklappen"),
                  palette: palette,
                  busy: false) {
                withAnimation(.snappy(duration: 0.18)) { klappeAlle() }
            }

            knopf(systemImage: "arrow.clockwise",
                  label: String(localized: "Jetzt aktualisieren"),
                  palette: palette,
                  busy: isRefreshing) {
                Task { await refresh() }
            }
            .disabled(isRefreshing)

            knopf(systemImage: "gearshape",
                  label: String(localized: "Einstellungen"),
                  palette: palette,
                  busy: false,
                  action: openSettings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// 44 × 44 Punkte, auch wenn das Zeichen halb so gross ist — was man nicht
    /// trifft, ist nicht bedienbar, egal wie schön es aussieht.
    private func knopf(systemImage: String,
                       label: String,
                       palette: Theme.Palette,
                       busy: Bool,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if busy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: systemImage).font(.body)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accent)
        .accessibilityLabel(label)
    }

    private var updatedText: String {
        if isRefreshing { return String(localized: "wird aktualisiert …") }
        guard let lastUpdated else { return String(localized: "noch keine Daten") }
        _ = tick
        return String(localized: "Aktualisiert \(Theme.ago(lastUpdated))")
    }

    // MARK: Karten

    private func liste(_ palette: Theme.Palette) -> some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: spalten(fuer: proxy.size.width), alignment: .leading, spacing: 12) {
                    ForEach(cards) { card in
                        karte(card)
                    }
                }
                .padding(14)

                if cards.isEmpty {
                    Text("Keine Karten eingeschaltet.")
                        .font(.callout)
                        .foregroundStyle(palette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                }
            }
            .refreshable { await refresh() }
            .scrollIndicators(.automatic)
        }
    }

    /// Zwei Spalten erst, wenn jede noch über 340 Punkte behält — darunter
    /// bricht die Zeile «Zurücksetzung … · 16:40» um und die Karte wird höher
    /// statt schmaler, was nichts gewinnt.
    private func spalten(fuer breite: CGFloat) -> [GridItem] {
        let zweispaltig = breite >= 700
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                     count: zweispaltig ? 2 : 1)
    }

    private func karte(_ card: CockpitCard) -> some View {
        Card(title: card.title,
             badge: card.badge,
             note: card.note,
             updated: card.updated,
             summary: card.summary,
             provider: card.provider,
             collapsed: bindung(fuer: card.id),
             tick: tick) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(card.limits) { limit in
                    LimitRow(title: limit.title,
                             window: limit.window,
                             thresholds: thresholds,
                             forecast: limit.forecast,
                             provider: card.provider)
                }
                ForEach(card.money) { zeile in
                    MoneyRow(title: zeile.title,
                             value: zeile.value,
                             currency: zeile.currency,
                             emphasised: zeile.emphasised)
                }
                if let status = card.status {
                    StatusNote(status: status,
                               actionTitle: card.actionTitle,
                               action: statusAktion(card))
                }
            }
        }
    }

    /// Ohne Knopftext kein Knopf — sonst stünde in der Karte eine Fläche, die
    /// nichts sagt und trotzdem etwas tut.
    private func statusAktion(_ card: CockpitCard) -> (() -> Void)? {
        guard card.actionTitle != nil else { return nil }
        return { cardAction(card.id) }
    }

    /// Der eingeklappte Zustand liegt als String vor, nicht als Menge — deshalb
    /// hier eine Bindung, die beim Setzen über `CardLayout` geht statt selbst
    /// zu basteln. Wird nichts geändert, wird auch nichts geschrieben: Sonst
    /// stösst jede Neuzeichnung eine Schreiboperation an.
    /// Sind alle sichtbaren Karten eingeklappt?
    ///
    /// Gefragt wird nach den **angezeigten** Karten, nicht nach allen, die das
    /// Layout kennt: Eine Karte, die es hier gar nicht gibt, darf nicht darüber
    /// entscheiden, was der Knopf tut.
    private var alleZu: Bool {
        let zu = CardLayout.parse(collapsedCards)
        return cards.isEmpty == false && cards.allSatisfy { zu.contains($0.id.rawValue) }
    }

    /// Klappt alle zu — oder alle auf, wenn schon alle zu sind.
    private func klappeAlle() {
        if alleZu {
            collapsedCards = ""
        } else {
            // Über `CardLayout.toggling` gehen statt die Zeichenkette selbst zu
            // bauen: Das Format teilen wir uns mit der Mac-Fassung, und wer es
            // an zwei Stellen schreibt, schreibt es irgendwann verschieden.
            var neu = collapsedCards
            let zu = CardLayout.parse(collapsedCards)
            for karte in cards where zu.contains(karte.id.rawValue) == false {
                neu = CardLayout.toggling(karte.id.rawValue, in: neu)
            }
            collapsedCards = neu
        }
    }

    private func bindung(fuer id: CardLayout.Card) -> Binding<Bool> {
        Binding(
            get: { CardLayout.parse(collapsedCards).contains(id.rawValue) },
            set: { neu in
                let ist = CardLayout.parse(collapsedCards).contains(id.rawValue)
                guard neu != ist else { return }
                collapsedCards = CardLayout.toggling(id.rawValue, in: collapsedCards)
            }
        )
    }
}

// MARK: - Vorschau

#Preview("iPhone") {
    CardsVorschau()
}

#Preview("iPad") {
    CardsVorschau()
        .frame(width: 1024, height: 768)
}

/// Beispieldaten, damit die Anordnung ohne Datenquelle zu sehen ist.
private struct CardsVorschau: View {
    @State private var collapsed = ""

    var body: some View {
        CardsView(cards: beispiel,
                  lastUpdated: Date().addingTimeInterval(-95),
                  collapsedCards: $collapsed,
                  refresh: { })
    }

    private var beispiel: [CockpitCard] {
        let jetzt = Date()
        return [
            CockpitCard(
                id: .claude, title: "Claude", provider: .claude, badge: "Max",
                updated: jetzt.addingTimeInterval(-40),
                summary: CardSummary(text: "5 h 42 % · 7 d 88 %", warning: true),
                limits: [
                    CockpitLimit(title: String(localized: "5-Stunden-Fenster"),
                                 window: LimitWindow(label: "5h", usedPercent: 42,
                                                     resetsAt: jetzt.addingTimeInterval(3 * 3600))),
                    CockpitLimit(title: String(localized: "7-Tage-Fenster"),
                                 window: LimitWindow(label: "7d", usedPercent: 88,
                                                     resetsAt: jetzt.addingTimeInterval(50 * 3600)))
                ]),
            CockpitCard(
                id: .chatgpt, title: "ChatGPT", provider: .chatGPT, badge: "Plus",
                note: String(localized: "aus Sitzungsprotokoll"),
                updated: jetzt.addingTimeInterval(-600),
                summary: CardSummary(text: "5 h 96 %", warning: true),
                limits: [
                    CockpitLimit(title: String(localized: "5-Stunden-Fenster"),
                                 window: LimitWindow(label: "5h", usedPercent: 96,
                                                     resetsAt: jetzt.addingTimeInterval(1800)))
                ]),
            CockpitCard(
                id: .openai, title: "OpenAI", provider: .openAI,
                updated: jetzt.addingTimeInterval(-1200),
                summary: CardSummary(text: "Monat 41.20 USD"),
                money: [
                    CockpitMoney(title: String(localized: "Heute"), value: 3.40, currency: "USD"),
                    CockpitMoney(title: String(localized: "Monat"), value: 41.20, currency: "USD",
                                 emphasised: true)
                ]),
            CockpitCard(
                id: .kimi, title: "Kimi", provider: .kimi,
                summary: CardSummary(text: String(localized: "nicht eingerichtet")),
                status: .missing(String(localized: "Kein Schlüssel hinterlegt.")),
                actionTitle: String(localized: "Einrichten"))
        ]
    }
}

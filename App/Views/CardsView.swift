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
    /// Läuft für diese Karte gerade ein Abruf? Wird beim Bauen gesetzt, nicht
    /// von den einzelnen Kartenbauern — sie wissen nichts davon.
    var wirdGeholt = false
    var summary: CardSummary?
    /// Der eine Wert für die kleinste Widget-Kachel.
    ///
    /// Nur dort, wo die Kurzfassung dafür zu lang ist: «Heute US$ 0.00 · Monat
    /// US$ 3.05» wird auf 155 Punkten abgeschnitten, und ein halber Betrag ist
    /// keine Auskunft. Bleibt er `nil`, nimmt das Widget die erste Zeile der
    /// Kurzfassung — bei Kontingenten ist das genau richtig.
    var widgetKurz: String?
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
         widgetKurz: String? = nil,
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
        self.widgetKurz = widgetKurz
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

// MARK: - Die Karte als Widget-Zeile

extension WidgetZustand.Quelle {

    /// Baut die Widget-Zeile aus einer Karte — oder gar keine.
    ///
    /// `nil`, wenn die Karte keine Zahlen zeigt: Eine Karte ohne Schlüssel oder
    /// mitten im Abruf trägt einen Statushinweis, und für «nicht eingerichtet»
    /// ist auf einer Kachel weder Platz noch Anlass.
    ///
    /// **An einer Stelle, weil zwei Seiten sie brauchen.** Der Zustand entsteht
    /// im Betrieb aus `Cockpit.schreibeWidgetZustand()` und im Demomodus aus
    /// `DemoDaten`. Getrennt gebaut liefen sie auseinander — und genau das war
    /// der Fall: Die Demo legte nur Claude-Fenster ab und zeigte damit eine
    /// Kachel, die es so nicht mehr gibt.
    init?(karte: CockpitCard) {
        guard karte.status == nil, let kurz = karte.summary else { return nil }
        let zeilen = kurz.text.split(separator: "\n").map(String.init)
        self.init(
            name: karte.title,
            anbieter: karte.provider.rawValue,
            // Die Kurzfassung bringt ihre Zeilen mit; auf dem Widget ist eine
            // Zeile je Quelle das Mass, also wird umgehängt.
            wert: zeilen.joined(separator: " · "),
            // Auf die knappste Kachel passt **eine** Angabe. Bei einem
            // Kontingent ist das die erste — das nächste Fenster, das
            // zuschlägt. Bei Geld nimmt die Karte selbst Stellung.
            kurz: karte.widgetKurz ?? zeilen.first ?? kurz.text,
            fenster: karte.limits.map {
                .init(name: $0.window.label, prozent: $0.window.usedPercent,
                      zuruecksetzung: $0.window.resetsAt)
            },
            prozent: karte.limits.first?.window.usedPercent,
            warnung: kurz.warning,
            stand: karte.updated ?? Date())
    }
}

// MARK: - Liste

struct CardsView: View {
    let cards: [CockpitCard]
    var lastUpdated: Date?
    /// Namen der Quellen, die gerade noch geholt werden.
    ///
    /// Eine Liste statt eines `Bool`: Solange **irgendetwas** lief, stand hier
    /// «wird aktualisiert …» und im Knopf ein Kreisel — eine knappe Minute
    /// lang, weil der OpenAI-Kostenabruf so lange braucht. Vier von fünf Karten
    /// standen derweil fertig da, und die Kopfzeile behauptete das Gegenteil.
    /// Ein Kreisel ohne Gegenstand sieht nicht geduldig aus, sondern kaputt.
    var laufend: [String]
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

    /// Die selbst gelegte Reihenfolge — kommagetrennte Kartenkennungen, siehe
    /// `Kartenreihenfolge`. Liegt direkt in den Benutzervorgaben statt über
    /// eine Bindung von aussen: Diese Ansicht ist die einzige Stelle, die sie
    /// ändert. `collapsedCards` reist nur deshalb durch `Cockpit`, weil dort
    /// auch der Widget-Zustand geschrieben wird. Leer heisst «wie gebaut».
    @AppStorage(Kartenreihenfolge.schluessel) private var reihenfolge = ""
    /// Sortieren ist ein eigener Zustand, kein Nebenher — Begründung bei
    /// `sortierliste(_:)`.
    @State private var sortiermodus = false

    /// Die Karten in der Reihenfolge, in der sie zu zeigen sind.
    private var sortierteKarten: [CockpitCard] {
        Kartenreihenfolge.sortiere(cards, nach: reihenfolge)
    }

    init(cards: [CockpitCard],
         lastUpdated: Date? = nil,
         laufend: [String] = [],
         thresholds: LimitThresholds = .standard,
         collapsedCards: Binding<String>,
         refresh: @escaping @Sendable () async -> Void,
         openSettings: @escaping () -> Void = {},
         cardAction: @escaping (CardLayout.Card) -> Void = { _ in }) {
        self.cards = cards
        self.lastUpdated = lastUpdated
        self.laufend = laufend
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
            if sortiermodus {
                sortierliste(palette)
            } else {
                liste(palette)
            }
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
                Text(sortiermodus ? String(localized: "Reihenfolge ändern") : updatedText)
                    .font(.caption)
                    .foregroundStyle(palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            // Im Sortiermodus bleibt genau ein Knopf stehen. Aktualisieren,
            // Einklappen und Einstellungen haben dort nichts zu suchen — und
            // vier 44-Punkt-Flächen neben einem «Fertig» wären auf einem
            // schmalen iPhone ohnehin eine Zeile zu viel.
            if sortiermodus {
                Button {
                    withAnimation(.snappy(duration: 0.18)) { sortiermodus = false }
                } label: {
                    Text("Fertig")
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.accent)
            } else {
                knoepfe(palette: palette)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// Die Knöpfe der normalen Ansicht.
    @ViewBuilder
    private func knoepfe(palette: Theme.Palette) -> some View {
            knopf(systemImage: "arrow.up.arrow.down",
                  label: String(localized: "Reihenfolge ändern"),
                  palette: palette,
                  busy: false) {
                withAnimation(.snappy(duration: 0.18)) { sortiermodus = true }
            }

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
                  busy: laeuft) {
                Task { await refresh() }
            }
            .disabled(laeuft)

            knopf(systemImage: "gearshape",
                  label: String(localized: "Einstellungen"),
                  palette: palette,
                  busy: false,
                  action: openSettings)
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

    private var laeuft: Bool { laufend.isEmpty == false }

    /// Was unter dem Titel steht — und zwar so genau, wie es geht.
    ///
    /// Hier stand einmal pauschal «wird aktualisiert …», solange irgendetwas
    /// lief. Der Unterschied zwischen Fortschritt und Hänger ist aber nicht der
    /// Kreisel, sondern die Auskunft, worauf er wartet: Ein benannter
    /// Nachzügler neben vier fertigen Karten liest sich als «gleich soweit»,
    /// dieselbe Wartezeit ohne Namen als «steht».
    private var updatedText: String {
        _ = tick
        let stand = lastUpdated.map { String(localized: "Aktualisiert \(Theme.ago($0))") }
        guard laeuft else { return stand ?? String(localized: "noch keine Daten") }

        let offen: String
        switch (laufend.count, stand) {
        case (1, .none): offen = String(localized: "\(laufend[0]) wird geholt …")
        case (1, .some): offen = String(localized: "\(laufend[0]) läuft noch")
        // Ab zwei Namen wäre die Zeile länger als der Bildschirm breit. Die
        // Zahl sagt dasselbe, und wer es genauer wissen will, sieht es an den
        // Karten selbst.
        case (_, .none): offen = String(localized: "\(laufend.count) Quellen werden geholt …")
        case (_, .some): offen = String(localized: "noch \(laufend.count) Quellen")
        }
        guard let stand else { return offen }
        return "\(stand) · \(offen)"
    }

    // MARK: Karten

    private func liste(_ palette: Theme.Palette) -> some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVGrid(columns: spalten(fuer: proxy.size.width), alignment: .leading, spacing: 12) {
                    ForEach(sortierteKarten) { card in
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

    // MARK: Reihenfolge

    /// Der Sortiermodus: eine Spalte, kurze Zeilen, System-Anfasser.
    ///
    /// Warum ein eigener Modus und nicht Ziehen direkt an den Karten — die drei
    /// Gesten, die sich sonst um denselben Finger streiten:
    ///
    /// 1. **Ziehen gegen Scrollen.** Beginnt das Ziehen irgendwo auf der Karte,
    ///    fängt jede zweite Scrollbewegung ein Verschieben an. Hier zieht nur
    ///    der Anfasser rechts; die Liste scrollt daneben unverändert.
    /// 2. **Ziehen gegen Aufklappen.** Der Kartenkopf ist ein Knopf, der die
    ///    Karte umklappt. Löste derselbe Druck auch das Ziehen aus, wäre beides
    ///    unzuverlässig. Im Sortiermodus gibt es die Karten gar nicht — nur
    ///    Zeilen, die nichts anderes können als sich verschieben zu lassen.
    /// 3. **Zwei Spalten auf dem iPad.** In einem zweispaltigen Raster ist
    ///    «eine Stelle weiter» mehrdeutig: mal rechts daneben, mal unten links.
    ///    Der Sortiermodus ist deshalb **immer einspaltig**, auf jedem Gerät.
    ///    Das ist der bewusst andere Weg fürs iPad — nicht kein Ziehen, sondern
    ///    Ziehen in einer Liste, in der jede Bewegung nur eine Bedeutung hat.
    ///
    /// Was es kostet: Man sieht beim Sortieren die Zahlen nicht mehr, sondern
    /// Name, Farbe und Kurzfassung. Und es ist ein Modus — man muss ihn öffnen
    /// und wieder schliessen.
    private func sortierliste(_ palette: Theme.Palette) -> some View {
        VStack(spacing: 0) {
            List {
                ForEach(sortierteKarten) { card in
                    SortierZeile(card: card, palette: palette)
                        .listRowBackground(palette.background)
                        .listRowSeparatorTint(palette.cardBorder)
                        // VoiceOver kann nicht ziehen. Ohne diese beiden
                        // Aktionen wäre die Personalisierung für einen Teil der
                        // Nutzer schlicht nicht vorhanden.
                        .accessibilityAction(named: Text("Nach oben")) {
                            schiebe(card.id, um: -1)
                        }
                        .accessibilityAction(named: Text("Nach unten")) {
                            schiebe(card.id, um: 1)
                        }
                }
                .onMove(perform: verschiebe)
            }
            .listStyle(.plain)
            // Fest auf «aktiv»: Der Anfasser soll da sein, sobald man den Modus
            // betreten hat — ein zweiter Bearbeiten-Knopf innerhalb eines
            // Bearbeiten-Modus wäre eine Tür zu viel.
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(palette.background)

            zurueckKnopf(palette)
        }
    }

    /// Der Weg zurück. Steht nur da, wenn es etwas zurückzunehmen gibt —
    /// ein Knopf, der nichts tut, ist schlimmer als keiner.
    ///
    /// Er sitzt hier und nicht nur in den Einstellungen: Wer sich beim
    /// Verschieben verlegt hat, sucht die Rückkehr dort, wo er steht.
    @ViewBuilder
    private func zurueckKnopf(_ palette: Theme.Palette) -> some View {
        if !reihenfolge.isEmpty {
            Button {
                withAnimation(.snappy(duration: 0.18)) { reihenfolge = "" }
            } label: {
                Label("Ursprüngliche Reihenfolge", systemImage: "arrow.uturn.backward")
                    .font(.callout)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
    }

    /// Gespeichert wird immer die **ganze** sichtbare Reihenfolge, nicht die
    /// Verschiebung. Was auf dem Schirm steht, steht danach in den Vorgaben.
    private func verschiebe(_ von: IndexSet, _ ziel: Int) {
        reihenfolge = Kartenreihenfolge.verschoben(sortierteKarten.map(\.id.rawValue),
                                                   von: von, nach: ziel)
    }

    /// Eine Stelle hoch oder runter — für VoiceOver und für jeden, dem Ziehen
    /// zu fummelig ist. Am Rand passiert nichts, statt still zu klemmen.
    private func schiebe(_ id: CardLayout.Card, um schritte: Int) {
        guard let neu = Kartenreihenfolge.geschoben(sortierteKarten.map(\.id.rawValue),
                                                    kennung: id.rawValue,
                                                    um: schritte) else { return }
        reihenfolge = neu
    }

    private func karte(_ card: CockpitCard) -> some View {
        Card(title: card.title,
             badge: card.badge,
             note: card.note,
             updated: card.updated,
             wirdGeholt: card.wirdGeholt,
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

// MARK: - Zeile im Sortiermodus

/// Eine Karte, auf das reduziert, was man zum Wiedererkennen braucht:
/// Anbieterfarbe, Name, Etikett, Kurzfassung.
///
/// Bewusst niedrig — beim Sortieren will man die ganze Liste auf einmal sehen,
/// sonst zieht man blind über den Rand hinaus. Die Zahlen fehlen hier; sie
/// stehen zwei Fingertipps entfernt in der Kartenansicht.
private struct SortierZeile: View {
    let card: CockpitCard
    let palette: Theme.Palette

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let accent = palette.color(for: card.provider)

        HStack(spacing: 10) {
            // Dieselbe Kante wie auf der Karte — daran erkennt man die Quelle
            // wieder, auch wenn hier nur eine Zeile steht.
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(card.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(accent)
                        .fixedSize(horizontal: false, vertical: true)
                    if let badge = card.badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(accent.opacity(0.22), in: Capsule())
                            .foregroundStyle(accent)
                    }
                }
                if let summary = card.summary {
                    Text(summary.text)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(palette.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        // Der Anfasser sitzt rechts daneben und ist Sache der Liste; diese
        // Zeile trägt nur dafür Sorge, dass er auf 44 Punkten sitzt.
        .frame(minHeight: 44)
        // Ein Element statt drei: Die Zeile ist beim Sortieren eine Sache, und
        // die beiden Aktionen «nach oben» / «nach unten» hängen daran.
        .accessibilityElement(children: .combine)
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

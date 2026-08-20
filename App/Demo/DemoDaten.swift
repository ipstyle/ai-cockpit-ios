import Foundation
import AgentDeckCore

// Die Zahlen des Demomodus — ein vollständiger Satz für alle sechs Karten.
//
// Wozu das überhaupt gebraucht wird: Wer diese App zum ersten Mal öffnet, hat
// weder ein Claude-Abo noch einen der drei API-Schlüssel. Er sieht sechs
// Karten, die alle dasselbe sagen — «nicht eingerichtet». Das ist fachlich
// richtig und als erster Eindruck wertlos: Man kann daran nicht erkennen, was
// die App überhaupt tut, wenn sie etwas zu tun hat. Der Demomodus beantwortet
// genau diese Frage, und zwar bevor jemand einen Schlüssel eintippt.
//
// Drei Regeln, an die sich hier alles hält:
//
// 1. **Alles relativ zu `jetzt`.** Kein einziger fester Zeitpunkt. Ein hart
//    hingeschriebenes Rücksetzdatum wäre in drei Monaten Vergangenheit, und die
//    Demo zeigte dann «Zurücksetzung vor 94 Tagen» — schlimmer als gar keine
//    Demo, weil es nach einem Fehler aussieht statt nach einem Beispiel.
// 2. **Krumme Zahlen.** 63.4 statt 60, 41.63 statt 40. Ein Satz runder Werte
//    liest sich sofort als erfunden; das Ziel ist ein Bildschirm, der aussieht
//    wie nach einem Arbeitstag, nicht wie eine Tabellenvorlage.
//    Nichts hier stammt aus jemandes Arbeit und nichts sieht danach aus.
//
// Gestreut ist auch die Lage: Eine Karte steht deutlich über der Warnschwelle,
// eine kratzt knapp darunter, eine ist entspannt grün, und der Verlauf ist im
// roten Bereich. Wer die Ampel sehen will, muss sie sehen können.

enum DemoDaten {

    // MARK: - Die Karten

    /// Der ganze Satz, in der Reihenfolge, in der `Cockpit.baueKarten()` ihn
    /// auch sonst liefert. Die Reihenfolge ist kein Zufall: `CardLayout` merkt
    /// sich eingeklappte Karten über die Kennung, und ein Nutzer, der in der
    /// Demo etwas zuklappt, soll dieselbe Karte danach zugeklappt vorfinden.
    static func karten(jetzt: Date = .now) -> [CockpitCard] {
        [claude(jetzt),
         chatGPT(jetzt),
         openAI(jetzt),
         anthropic(jetzt),
         kimi(jetzt)]
    }

    // MARK: Claude

    /// Das Abo: ein volles Fünfstundenfenster im Anmarsch, ein Wochenfenster
    /// über der Warnschwelle, dazu ein Modellfenster, das entspannt dasteht.
    ///
    /// Beide Hochrechnungen entstehen **nicht** von Hand, sondern über
    /// `Forecast.project` aus einem kurzen Messwertverlauf. Das hat einen
    /// Grund: `Forecast` hat keinen öffentlichen Initialisierer, und nachbauen
    /// liesse sich die Rechnung nur mit anderen Rundungen. Über den Kern zu
    /// gehen heisst, dass in der Demo dieselbe Zeile steht, die später auch aus
    /// echten Zahlen entstünde — samt der Entscheidung, ob das Fenster vor
    /// seiner Zurücksetzung volläuft.
    private static func claude(_ jetzt: Date) -> CockpitCard {
        let fuenfStunden = LimitWindow(label: "5 Stunden",
                                       usedPercent: 63.4,
                                       resetsAt: jetzt.addingTimeInterval(2 * 3600 + 11 * 60))
        let woche = LimitWindow(label: "7 Tage",
                                usedPercent: 81.7,
                                resetsAt: jetzt.addingTimeInterval(3 * 86400 + 6 * 3600))
        let opus = LimitWindow(label: "Opus",
                               usedPercent: 37.2,
                               resetsAt: jetzt.addingTimeInterval(3 * 86400 + 6 * 3600))

        return CockpitCard(
            id: .claude, title: "Claude", provider: .claude,
            badge: String(localized: "Max 5×"),
            updated: jetzt.addingTimeInterval(-142),
            summary: CardSummary(text: "5 h \(Format.percent(fuenfStunden.usedPercent)) · 7 d \(Format.percent(woche.usedPercent))",
                                 warning: true),
            limits: [
                CockpitLimit(title: String(localized: "5-Stunden-Fenster"),
                             window: fuenfStunden,
                             // Steigt zügig, läuft aber erst **nach** der
                             // Zurücksetzung voll — die ruhige Variante der
                             // Hochrechnungszeile.
                             forecast: hochrechnung(von: 47.9, auf: 63.4,
                                                    ueber: 79 * 60,
                                                    zuruecksetzung: fuenfStunden.resetsAt,
                                                    jetzt: jetzt)),
                CockpitLimit(title: String(localized: "7-Tage-Fenster"),
                             window: woche,
                             // Kriecht langsam, hat aber nur noch 18 Punkte
                             // Luft: läuft vor der Zurücksetzung voll und
                             // bekommt deshalb das Warndreieck.
                             forecast: hochrechnung(von: 80.4, auf: 81.7,
                                                    ueber: 84 * 60,
                                                    zuruecksetzung: woche.resetsAt,
                                                    jetzt: jetzt)),
                CockpitLimit(title: String(localized: "7 Tage · \(opus.label)"), window: opus)
            ])
    }

    // MARK: ChatGPT / Codex

    /// **Im Demomodus zeigt diese Karte Zahlen** — im Betrieb kann sie das auf
    /// einem iPhone nicht, weil der Codex-Dienst seine Kontingente nur einem
    /// Programm auf demselben Rechner herausgibt.
    ///
    /// Das ist bewusst so und kein Widerspruch: Die Demo führt vor, wie die
    /// Karte aussieht, wenn der Mac sie herüberreicht. Eine sechste leere Karte
    /// im Demomodus würde niemandem etwas zeigen — am wenigsten dem, der die
    /// App zum ersten Mal in der Hand hält und wissen will, wofür sie da ist.
    private static func chatGPT(_ jetzt: Date) -> CockpitCard {
        let fuenfStunden = LimitWindow(label: "5 Stunden",
                                       usedPercent: 48.9,
                                       resetsAt: jetzt.addingTimeInterval(1 * 3600 + 47 * 60))
        let woche = LimitWindow(label: "7 Tage",
                                usedPercent: 71.5,
                                resetsAt: jetzt.addingTimeInterval(4 * 86400 + 9 * 3600))

        return CockpitCard(
            id: .chatgpt, title: "ChatGPT", provider: .chatGPT,
            badge: String(localized: "Plus"),
            updated: jetzt.addingTimeInterval(-386),
            summary: CardSummary(text: "5 h \(Format.percent(fuenfStunden.usedPercent)) · 7 d \(Format.percent(woche.usedPercent))"),
            limits: [
                CockpitLimit(title: String(localized: "5-Stunden-Fenster"), window: fuenfStunden),
                CockpitLimit(title: String(localized: "7-Tage-Fenster"), window: woche)
            ])
    }

    // MARK: OpenAI-API

    /// Tages-, Monats- und Gesamtkosten, darunter die drei teuersten Modelle
    /// des laufenden Monats.
    ///
    /// Die Modellzeilen tragen «· Monat» im Titel. Ohne diesen Zusatz stünden
    /// sie unter «Gesamt» und läsen sich als dessen Aufschlüsselung — sie
    /// summieren sich aber auf den Monat, nicht auf die Gesamtsumme. Eine Zahl,
    /// die zum falschen Bezug daneben steht, ist schlimmer als keine.
    private static func openAI(_ jetzt: Date) -> CockpitCard {
        let waehrung = "USD"
        return CockpitCard(
            id: .openai, title: "OpenAI-API", provider: .openAI,
            updated: jetzt.addingTimeInterval(-671),
            summary: CardSummary(text: String(localized: "Heute \(Format.money(geld(287), waehrung)) · Monat \(Format.money(geld(4163), waehrung))")),
            money: [
                CockpitMoney(title: String(localized: "Heute"), value: geld(287), currency: waehrung),
                CockpitMoney(title: String(localized: "Laufender Monat"), value: geld(4163), currency: waehrung),
                CockpitMoney(title: String(localized: "Gesamt"), value: geld(31894), currency: waehrung,
                             emphasised: true),
                CockpitMoney(title: String(localized: "gpt-5.2 · Monat"), value: geld(2418), currency: waehrung),
                CockpitMoney(title: String(localized: "gpt-5.2-mini · Monat"), value: geld(1105), currency: waehrung),
                CockpitMoney(title: String(localized: "o4-mini · Monat"), value: geld(640), currency: waehrung)
            ])
    }

    // MARK: Anthropic-API

    /// Die Kosten der Programmierschnittstelle — etwas anderes als das Abo auf
    /// der Claude-Karte. Genau darum steht die Demo hier mit spürbar kleineren
    /// Beträgen: Wer beides zahlt, soll auf einen Blick sehen, dass es zwei
    /// Dinge sind und nicht dieselbe Zahl zweimal.
    private static func anthropic(_ jetzt: Date) -> CockpitCard {
        let waehrung = "USD"
        return CockpitCard(
            id: .anthropic, title: "Anthropic-API", provider: .claude,
            updated: jetzt.addingTimeInterval(-671),
            summary: CardSummary(text: String(localized: "Heute \(Format.money(geld(114), waehrung)) · Monat \(Format.money(geld(2785), waehrung))")),
            money: [
                CockpitMoney(title: String(localized: "Heute"), value: geld(114), currency: waehrung),
                CockpitMoney(title: String(localized: "Laufender Monat"), value: geld(2785), currency: waehrung),
                CockpitMoney(title: String(localized: "Gesamt"), value: geld(15620), currency: waehrung,
                             emphasised: true),
                CockpitMoney(title: String(localized: "Opus · Monat"), value: geld(1944), currency: waehrung),
                CockpitMoney(title: String(localized: "Sonnet · Monat"), value: geld(631), currency: waehrung),
                CockpitMoney(title: String(localized: "Haiku · Monat"), value: geld(210), currency: waehrung)
            ])
    }

    // MARK: Kimi

    /// Kimi kennt nur den Kontostand — einen Endpunkt für Verbrauch gibt es
    /// nicht. Die Demo lässt diesen Hinweis absichtlich stehen: Er ist keine
    /// Entschuldigung für fehlende Daten, sondern die Auskunft, warum hier
    /// etwas anderes steht als auf den beiden Kostenkarten darüber.
    private static func kimi(_ jetzt: Date) -> CockpitCard {
        let waehrung = "USD"
        return CockpitCard(
            id: .kimi, title: "Kimi K3", provider: .kimi,
            badge: String(localized: "aktiv"),
            note: String(localized: "kein Verbrauch über die Schnittstelle"),
            updated: jetzt.addingTimeInterval(-838),
            summary: CardSummary(text: String(localized: "\(Format.money(geld(3862), waehrung)) verfügbar")),
            money: [
                CockpitMoney(title: String(localized: "Verfügbares Guthaben"), value: geld(3862),
                             currency: waehrung, emphasised: true),
                CockpitMoney(title: String(localized: "davon Gutscheine"), value: geld(1200), currency: waehrung),
                CockpitMoney(title: String(localized: "davon Bargeld"), value: geld(2662), currency: waehrung)
            ])
    }

    // MARK: Aktive Sitzungen


    // MARK: - Was das Widget bekommt

    /// Derselbe Claude-Stand, in der Form, die das Widget lesen kann.
    ///
    /// Die Reihenfolge ist der stille Vertrag zwischen App und Widget: erst das
    /// Fünfstundenfenster, dann das Wochenfenster, dann die modellbezogenen.
    /// Die Widget-Ansicht nimmt das **erste** Fenster für den Ring, ohne den
    /// Namen zu kennen. Wer hier umsortiert, ändert unbemerkt, was gross auf
    /// dem Homescreen steht.
    ///
    /// Die Namen tragen «· Demo». Das ist keine Zierde: Eine Kachel auf dem
    /// Homescreen hat keinen Platz für ein Band und keinen Knopf zum
    /// Verlassen — der Zusatz im Namen ist die einzige Stelle, an der sie sagen
    /// kann, dass diese Zahlen nichts gemessen haben.
    static func widgetZustand(jetzt: Date = .now) -> WidgetZustand {
        WidgetZustand(
            erhoben: jetzt.addingTimeInterval(-142),
            fenster: [
                .init(name: String(localized: "5 Stunden · Demo"), prozent: 63.4,
                      zuruecksetzung: jetzt.addingTimeInterval(2 * 3600 + 11 * 60)),
                .init(name: String(localized: "7 Tage · Demo"), prozent: 81.7,
                      zuruecksetzung: jetzt.addingTimeInterval(3 * 86400 + 6 * 3600)),
                .init(name: String(localized: "Opus · Demo"), prozent: 37.2,
                      zuruecksetzung: jetzt.addingTimeInterval(3 * 86400 + 6 * 3600))
            ])
    }

    // MARK: - Kleinkram

    /// Beträge in Cent statt als Kommazahl.
    ///
    /// `let betrag: Decimal = 2.87` geht über einen `Double` und landet bei
    /// 2.8700000000000001. Das fällt bei zwei Nachkommastellen nie auf — bis
    /// jemand zwei solche Werte addiert und die Summe um einen Rappen daneben
    /// liegt. Über die ganze Zahl gerechnet ist es exakt und liest sich
    /// genauso gut.
    private static func geld(_ cent: Int) -> Decimal {
        Decimal(cent) / 100
    }

    /// Baut aus zwei Eckwerten einen kurzen Messwertverlauf und lässt den Kern
    /// daraus die Hochrechnung machen.
    ///
    /// Fünf Werte, gleichmässig verteilt: `Forecast.project` braucht mindestens
    /// zwei Messwerte und mindestens zehn Minuten Abstand, und es rechnet die
    /// Steigung nach kleinsten Quadraten. Mit nur zwei Punkten wäre die Rate
    /// dieselbe, aber `samples` stünde auf 2 — und das ist der Wert, an dem
    /// später einmal hängen könnte, wie belastbar die Angabe gilt.
    ///
    /// - Parameter ueber: Zeitraum in Sekunden, über den der Anstieg lief.
    ///   Muss unter der Rückschau von 90 Minuten bleiben, sonst fallen die
    ///   frühen Werte aus dem Fenster und die Rate wird flacher als gedacht.
    private static func hochrechnung(von start: Double,
                                     auf ende: Double,
                                     ueber sekunden: TimeInterval,
                                     zuruecksetzung: Date?,
                                     jetzt: Date) -> Forecast? {
        let schritte = 4
        let messwerte = (0...schritte).map { index -> UsageSample in
            let anteil = Double(index) / Double(schritte)
            return UsageSample(at: jetzt.addingTimeInterval(-sekunden * (1 - anteil)),
                               value: start + (ende - start) * anteil)
        }
        return Forecast.project(samples: messwerte,
                                current: ende,
                                resetsAt: zuruecksetzung,
                                now: jetzt)
    }
}

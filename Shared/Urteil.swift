import Foundation

// Was die Uhr in einem Satz sagt.
//
// **Warum das in `Shared/` liegt und nicht bei der Uhr.** Das iPhone braucht
// dieselbe Ableitung: Es muss entscheiden, ob sich die Auskunft überhaupt
// geändert hat, bevor es einen der rund fünfzig täglichen Weckrufe zur Uhr
// verbraucht. Zwei Fassungen derselben Regel wären zwei Fassungen, die
// auseinanderlaufen — und der Tag, an dem das passiert, fällt niemandem auf:
// Die Uhr zeigte einfach etwas anderes als das Telefon.
//
// Am Handgelenk fragt niemand, wie sich die Nutzung verteilt. Gefragt ist, ob
// es reicht — in unter zwei Sekunden, mit erhobenem Arm. Diese Ableitung macht
// aus dem Zustand genau diese eine Auskunft.
//
// **Das Urteil erfindet keine Meinung.** Es benutzt `LimitThresholds` — die
// Schwellen, die in den Einstellungen der iPhone-App stehen — und die Worte
// dazu gibt es im Kern schon: `LimitLevel.spokenLabel` liefert seit jeher
// «Warnung» und «kritisch» für VoiceOver. Die Uhr schreibt sie hin, statt sie
// vorzulesen. Wer dem Satz nicht glaubt, findet die Zahl direkt darunter.

struct Urteil: Equatable, Sendable {

    enum Lage: Equatable, Sendable {
        case ruhig
        case knapp
        case voll
        /// Weder ein Fenster noch ein Prozentwert — nicht eingerichtet, noch
        /// nie gelaufen, oder eine Kopplung, die noch nichts geschickt hat.
        case keineZahlen

        var satz: String {
            switch self {
            case .ruhig:       return String(localized: "Reicht noch")
            case .knapp:       return String(localized: "Wird knapp")
            case .voll:        return String(localized: "Fenster voll")
            case .keineZahlen: return String(localized: "Keine Zahlen")
            }
        }
    }

    let lage: Lage
    /// «Claude», «ChatGPT» — der Name der Karte, nicht der Kennung.
    let quelle: String?
    /// «7 Tage», «5 Stunden». `nil` bei Quellen, die nur einen Gesamtwert
    /// führen.
    let fenster: String?
    /// Dasselbe auf zwei bis drei Zeichen: «5H», «1W».
    ///
    /// Nicht hier abgeleitet, sondern aus `WidgetZustand.Fenster.kurzname`
    /// übernommen — der wird beim Schreiben aus der **Dauer** bestimmt und
    /// nicht aus dem Text, weil «5 Stunden» und «5 hours» beide «5H» ergeben
    /// müssen. Auf 40 Millimetern ist das der Unterschied zwischen «7 d…» und
    /// einer lesbaren Angabe.
    let fensterKurz: String?
    let prozent: Double?
    let anbieter: Theme.Provider
    let zuruecksetzung: Date?

    static let leer = Urteil(lage: .keineZahlen, quelle: nil, fenster: nil,
                             fensterKurz: nil, prozent: nil, anbieter: .neutral,
                             zuruecksetzung: nil)

    /// Das drängendste Fenster über **alle** Quellen.
    ///
    /// Nicht das erste und nicht Claude: Wer ein Wochenfenster bei 96 % hat und
    /// ein Fünfstundenfenster bei 12 %, will das Wochenfenster sehen. Die
    /// Reihenfolge der Quellen ist die Auswahl des Nutzers und sagt nichts
    /// darüber, was drückt.
    ///
    /// Geldkarten bleiben aussen vor. Sie haben keinen Prozentsatz
    /// (`Quelle.prozent == nil`), und einen zu erfinden wäre schlimmer als
    /// keiner — dieselbe Regel wie in `WidgetZustand.Quelle`.
    static func aus(_ zustand: WidgetZustand?,
                    schwellen: LimitThresholds = .standard) -> Urteil {
        guard let zustand else { return .leer }

        var bestes: (quelle: WidgetZustand.Quelle, fenster: WidgetZustand.Fenster?)?

        for quelle in zustand.quellen {
            // Erst die eigenen Fenster der Quelle …
            for fenster in quelle.fenster where fenster.prozent.isFinite {
                if fenster.prozent > (bestes?.fenster?.prozent ?? bestes?.quelle.prozent ?? -1) {
                    bestes = (quelle, fenster)
                }
            }
            // … und sonst ihr Sammelwert, falls sie einen führt.
            if quelle.fenster.isEmpty, let prozent = quelle.prozent, prozent.isFinite,
               prozent > (bestes?.fenster?.prozent ?? bestes?.quelle.prozent ?? -1) {
                bestes = (quelle, nil)
            }
        }

        // Ein Stand aus einer älteren Fassung kennt `quellen` nicht und trägt
        // die Claude-Fenster flach auf oberster Ebene. Ihn zu verwerfen hiesse:
        // leere Uhr, bis die iPhone-App das nächste Mal läuft.
        if bestes == nil, let fenster = zustand.fenster.filter({ $0.prozent.isFinite })
            .max(by: { $0.prozent < $1.prozent }) {
            return Urteil(lage: lage(fenster.prozent, schwellen),
                          quelle: "Claude", fenster: fenster.name,
                          fensterKurz: fenster.kurzname,
                          prozent: fenster.prozent, anbieter: .claude,
                          zuruecksetzung: fenster.zuruecksetzung)
        }

        guard let bestes else { return .leer }
        let prozent = bestes.fenster?.prozent ?? bestes.quelle.prozent
        guard let prozent else { return .leer }

        return Urteil(lage: lage(prozent, schwellen),
                      quelle: bestes.quelle.name,
                      fenster: bestes.fenster?.name,
                      fensterKurz: bestes.fenster?.kurzname,
                      prozent: prozent,
                      anbieter: bestes.quelle.alsAnbieter,
                      zuruecksetzung: bestes.fenster?.zuruecksetzung)
    }

    private static func lage(_ prozent: Double, _ schwellen: LimitThresholds) -> Lage {
        switch schwellen.level(prozent) {
        case .normal:   return .ruhig
        case .warn:     return .knapp
        case .critical: return .voll
        }
    }

    /// Sagt dieses Urteil dasselbe wie das vorige?
    ///
    /// Nicht `==`: Ein Prozentwert wandert ständig um Zehntel, und jede
    /// Bewegung als Neuigkeit zu behandeln hiesse, den Vorrat an Weckrufen vor
    /// Mittag zu verbrauchen. Was zählt, ist die Stufe — und ein voller
    /// Prozentpunkt, denn mehr steht auf der Kachel ohnehin nicht.
    func sagtDasselbeWie(_ anderes: Urteil?) -> Bool {
        guard let anderes else { return false }
        guard lage == anderes.lage, quelle == anderes.quelle, fenster == anderes.fenster
        else { return false }
        switch (prozent, anderes.prozent) {
        case (nil, nil): return true
        case (let a?, let b?): return Int(a.rounded()) == Int(b.rounded())
        default: return false
        }
    }

    /// Die Stufe hinter dem Urteil — für Farbe und Warnzeichen.
    var stufe: LimitLevel {
        switch lage {
        case .ruhig, .keineZahlen: return .normal
        case .knapp:               return .warn
        case .voll:                return .critical
        }
    }
}

import Testing
import Foundation
@testable import AICockpitMobile

// Was die Uhr sagt, und warum.
//
// Geprüft wird die **Auswahl**, nicht die Formulierung: Welches Fenster trägt
// die Auskunft, und ab wann kippt sie? Der Satz selbst ist übersetzbar und
// darf sich ändern; die Regel dahinter nicht.

private func fenster(_ name: String, _ prozent: Double,
                     kurz: String? = nil) -> WidgetZustand.Fenster {
    WidgetZustand.Fenster(name: name, prozent: prozent, zuruecksetzung: nil, kurzname: kurz)
}

private func quelle(_ name: String, _ anbieter: Theme.Provider,
                    fenster liste: [WidgetZustand.Fenster] = [],
                    prozent: Double? = nil) -> WidgetZustand.Quelle {
    WidgetZustand.Quelle(name: name, anbieter: anbieter.rawValue, wert: "",
                         fenster: liste, prozent: prozent, warnung: false, stand: Date())
}

private func zustand(_ quellen: [WidgetZustand.Quelle],
                     fenster: [WidgetZustand.Fenster] = []) -> WidgetZustand {
    WidgetZustand(erhoben: Date(), fenster: fenster, quellen: quellen)
}

@Suite("Urteil")
struct UrteilTests {

    @Test("Ohne Zustand gibt es keine Zahlen")
    func leer() {
        #expect(Urteil.aus(nil).lage == .keineZahlen)
        #expect(Urteil.aus(zustand([])).lage == .keineZahlen)
    }

    /// Der eigentliche Zweck der Ableitung. Vorher stand auf der Kachel das
    /// erste Fenster der ersten Quelle — das ist die Reihenfolge des Nutzers
    /// und sagt nichts darüber, was drückt.
    @Test("Das drängendste Fenster gewinnt, quer über alle Quellen")
    func draengendstes() {
        let u = Urteil.aus(zustand([
            quelle("Claude", .claude, fenster: [fenster("5 Stunden", 12), fenster("7 Tage", 96)]),
            quelle("ChatGPT", .chatGPT, fenster: [fenster("5 Stunden", 40)])
        ]))
        #expect(u.quelle == "Claude")
        #expect(u.fenster == "7 Tage")
        #expect(u.prozent == 96)
    }

    @Test("Eine fremde Quelle darf gewinnen")
    func fremdeQuelle() {
        let u = Urteil.aus(zustand([
            quelle("Claude", .claude, fenster: [fenster("5 Stunden", 20)]),
            quelle("ChatGPT", .chatGPT, fenster: [fenster("7 Tage", 88)])
        ]))
        #expect(u.quelle == "ChatGPT")
        #expect(u.anbieter == .chatGPT)
    }

    /// Geldkarten führen keinen Prozentsatz. Einen zu erfinden wäre schlimmer
    /// als keiner — dieselbe Regel wie in `WidgetZustand`.
    @Test("Geldkarten bleiben aussen vor")
    func geldkarten() {
        let u = Urteil.aus(zustand([
            quelle("OpenAI-API", .openAI),
            quelle("Kimi K3", .kimi)
        ]))
        #expect(u.lage == .keineZahlen)
    }

    @Test("Die Schwellen des Nutzers entscheiden, nicht feste Zahlen",
          arguments: [(50.0, Urteil.Lage.ruhig), (80.0, .knapp), (94.9, .knapp), (95.0, .voll)])
    func schwellen(prozent: Double, erwartet: Urteil.Lage) {
        let u = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", prozent)])]))
        #expect(u.lage == erwartet)
    }

    @Test("Eigene Schwellen verschieben das Urteil")
    func eigeneSchwellen() {
        let z = zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 70)])])
        #expect(Urteil.aus(z).lage == .ruhig)
        #expect(Urteil.aus(z, schwellen: LimitThresholds(warn: 60, critical: 90)).lage == .knapp)
    }

    /// Ein Stand aus einer älteren Fassung kennt `quellen` nicht. Ihn zu
    /// verwerfen hiesse: leere Uhr, bis die iPhone-App das nächste Mal läuft.
    @Test("Ein alter Stand ohne Quellen trägt trotzdem")
    func alterStand() {
        let u = Urteil.aus(zustand([], fenster: [fenster("5 Stunden", 30), fenster("7 Tage", 84)]))
        #expect(u.lage == .knapp)
        #expect(u.quelle == "Claude")
        #expect(u.prozent == 84)
    }

    @Test("Die Kurzform des Fensters wandert mit")
    func kurzform() {
        let u = Urteil.aus(zustand([
            quelle("Claude", .claude, fenster: [fenster("7 Tage", 84, kurz: "1W")])
        ]))
        #expect(u.fensterKurz == "1W")
    }

    /// Der Vorrat an Weckrufen zur Uhr liegt bei rund fünfzig am Tag. Jede
    /// Zehntelbewegung als Neuigkeit zu behandeln verbrauchte ihn vor Mittag.
    @Test("Zehntel sind keine Neuigkeit, ganze Punkte schon")
    func neuigkeit() {
        let a = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 81.2)])]))
        let b = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 81.4)])]))
        let c = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 83.0)])]))
        #expect(a.sagtDasselbeWie(b))
        #expect(!a.sagtDasselbeWie(c))
        #expect(!a.sagtDasselbeWie(nil))
    }

    @Test("Ein Wechsel der Stufe ist immer eine Neuigkeit")
    func stufenwechsel() {
        let a = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 79.6)])]))
        let b = Urteil.aus(zustand([quelle("Claude", .claude, fenster: [fenster("7 Tage", 80.1)])]))
        #expect(a.lage == .ruhig)
        #expect(b.lage == .knapp)
        #expect(!a.sagtDasselbeWie(b))
    }

    /// `Int(Double.nan)` beendet das Programm. Der Wert kommt aus einer
    /// Netzantwort — ein Prozentwert ist es nicht wert, eine App abzuschiessen.
    @Test("Unbrauchbare Zahlen kippen nichts um")
    func nichtEndlich() {
        let u = Urteil.aus(zustand([
            quelle("Claude", .claude, fenster: [fenster("5 Stunden", .nan), fenster("7 Tage", 44)])
        ]))
        #expect(u.prozent == 44)
    }
}

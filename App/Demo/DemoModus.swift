import Foundation
import Observation
import WidgetKit

// Der Schalter für den Demomodus.
//
// Was er zusichert, und warum jede Zusicherung nötig ist:
//
// **Solange er an ist, wird nichts abgefragt.** Kein Netzabruf, kein
// Schlüsselbund. Nicht aus Sparsamkeit, sondern weil beides in die falsche
// Richtung wirken könnte: Ein Abruf, der nebenher losläuft, überschriebe die
// Demokarten mit «nicht eingerichtet», sobald er zurückkommt — und ein
// Schlüsselbundzugriff im Demomodus wäre eine Zumutung gegenüber jemandem, der
// gerade nur zuschauen wollte. Durchgesetzt wird das nicht hier, sondern an der
// einen Stelle, an der abgefragt wird: `Cockpit.aktualisiere()`.
//
// **Er überschreibt nichts Echtes.** Der Widget-Zustand in der App Group ist
// die einzige Stelle, an der die Demo etwas hinterlässt. Deshalb wird der
// vorhandene Stand beim Einschalten weggelegt und beim Ausschalten
// zurückgeholt. Wer die Demo aus Neugier anschaut, findet danach seine eigenen
// Zahlen wieder — und nicht eine Kachel, die behauptet, er habe 63 % verbraucht.
//
// **Er liegt in der App Group, nicht in den Vorgaben der App.** Nur so sieht
// das Widget ihn. Geschrieben wird zusätzlich in die App-eigenen Vorgaben: Ohne
// gültige Berechtigungsdatei — im Simulator der Regelfall — ist
// `AppGruppe.vorgaben` schlicht `nil`, und ein Demomodus, der sich dann nicht
// merken lässt, wäre genau dort kaputt, wo man ihn am häufigsten ausprobiert.

@MainActor
@Observable
final class DemoModus {

    /// Eine Instanz für die ganze App.
    ///
    /// Kein `enum` mit statischen Funktionen, obwohl der Zustand ein einziges
    /// Ja/Nein ist: Als `@Observable` gehalten, zeichnet SwiftUI das Band und
    /// den Knopf von selbst neu, sobald jemand umschaltet. Ein statischer
    /// Schalter wäre für die Oberfläche unsichtbar — sie erführe erst beim
    /// nächsten Neuzeichnen aus anderem Anlass davon, und das ist genau die
    /// Sorte Fehler, die man auf dem eigenen Gerät nie sieht.
    static let geteilt = DemoModus()

    /// Läuft die Demo gerade?
    private(set) var laeuft: Bool

    /// Für alles ausserhalb einer Ansicht — `Cockpit` fragt so.
    static var laeuft: Bool { geteilt.laeuft }

    // MARK: - Schlüsselnamen

    /// Steht in der App Group **und** in den Vorgaben der App, unter demselben
    /// Namen. Wer ihn ändert, schaltet bei jedem, der die Demo offen hatte,
    /// stillschweigend zurück auf echte Daten — harmlos, aber verwirrend.
    private static let schluessel = "demomodus-aktiv"

    /// Hier liegt der echte Widget-Zustand, solange die Demo ihn verdrängt.
    private static let sicherung = "widget-zustand-vor-demo"

    private init() {
        // Zwei Ablagen, eine Wahrheit: Die App Group hat Vorrang, weil nur sie
        // das Widget erreicht. Fehlt sie, gelten die Vorgaben der App.
        laeuft = Self.laeuftLautAblage()
    }

    private static func laeuftLautAblage() -> Bool {
        if let gruppe = AppGruppe.vorgaben, gruppe.object(forKey: schluessel) != nil {
            return gruppe.bool(forKey: schluessel)
        }
        return UserDefaults.standard.bool(forKey: schluessel)
    }

    // MARK: - Umschalten

    /// Schaltet die Demo ein und legt den Demostand fürs Widget hin.
    ///
    /// Reihenfolge mit Absicht: erst sichern, dann das Kennzeichen setzen, dann
    /// überschreiben. Bricht etwas dazwischen ab, ist der schlimmste Fall ein
    /// gesicherter Stand, der nie zurückgeholt wird — nicht ein verlorener.
    func starte() {
        guard !laeuft else { return }
        sichereWidgetZustand()

        AppGruppe.vorgaben?.set(true, forKey: Self.schluessel)
        UserDefaults.standard.set(true, forKey: Self.schluessel)
        laeuft = true

        // Stösst das Widget an, sobald sich die Werte unterscheiden — und das
        // tun sie hier immer, sonst hätte es vorher schon Demozahlen gezeigt.
        UhrVersorgung.veroeffentliche(DemoDaten.widgetZustand())
    }

    /// Schaltet die Demo aus und stellt her, was vorher war.
    ///
    /// Das Widget wird ausdrücklich angestossen, auch wenn nichts
    /// wiederherzustellen war: Ohne Anstoss stünden die Demozahlen bis zur
    /// nächsten Neuladung auf dem Homescreen, und die kann Stunden entfernt
    /// sein. Eine Kachel, die nach dem Verlassen noch Demodaten zeigt, ist
    /// genau die Verwechslung, die der ganze Modus vermeiden soll.
    func beende() {
        guard laeuft else { return }

        AppGruppe.vorgaben?.removeObject(forKey: Self.schluessel)
        UserDefaults.standard.removeObject(forKey: Self.schluessel)
        laeuft = false

        stelleWidgetZustandHer()
        // Dieselbe Überlegung wie beim Widget, eine Etage weiter: Ohne diesen
        // Schub trüge die Uhr die Demozahlen weiter, und dort gibt es kein
        // Band, das sie als erfunden ausweist.
        UhrVersorgung.schiebeAktuellen()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Der Widget-Zustand, geliehen und zurückgegeben

    /// Legt den vorhandenen Stand roh zur Seite — als `Data`, nicht als
    /// dekodierter Wert.
    ///
    /// Roh, weil hier nichts an den Zahlen zu tun ist. Wer dekodiert und neu
    /// kodiert, hat eine zweite Stelle, an der eine Formänderung von
    /// `WidgetZustand` nachgezogen werden muss — und diese hier fiele niemandem
    /// auf, bis eines Tages ein zurückgeholter Stand nicht mehr lesbar ist.
    private func sichereWidgetZustand() {
        guard let vorgaben = AppGruppe.vorgaben else { return }
        if let vorhanden = vorgaben.data(forKey: WidgetZustand.schluessel) {
            vorgaben.set(vorhanden, forKey: Self.sicherung)
        } else {
            // Vorher war nichts da. Das ist eine Auskunft und muss festgehalten
            // werden: Ohne sie liesse sich später nicht unterscheiden zwischen
            // «nichts zu sichern» und «Sicherung verlorengegangen».
            vorgaben.removeObject(forKey: Self.sicherung)
        }
    }

    private func stelleWidgetZustandHer() {
        guard let vorgaben = AppGruppe.vorgaben else { return }
        if let gesichert = vorgaben.data(forKey: Self.sicherung) {
            vorgaben.set(gesichert, forKey: WidgetZustand.schluessel)
            vorgaben.removeObject(forKey: Self.sicherung)
        } else {
            // Nichts gesichert heisst: Vor der Demo stand hier nichts. Dann
            // muss danach auch nichts stehen — das Widget zeigt seine
            // Einladung, nicht drei Zahlen aus dem Nichts.
            vorgaben.removeObject(forKey: WidgetZustand.schluessel)
        }
    }
}

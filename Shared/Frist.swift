import Foundation

// Eine Obergrenze, die wirklich greift.
//
// **Warum das nicht die Sitzung erledigt.** `URLRequest.timeoutInterval` — das,
// was die Abrufe im Kern setzen — ist eine *Untätigkeits*frist: Sie misst die
// Pause zwischen zwei Lebenszeichen, nicht die Gesamtdauer. Eine Gegenstelle,
// die alle paar Sekunden ein Byte schickt, hält eine Anfrage damit beliebig
// lange offen. Und weil `timeoutInterval` am Anfrageobjekt steht, sticht sie
// jede Einstellung der Sitzung — die Frist muss also von aussen kommen.
//
// Am Gerät gesehen (20.08.2026): Der OpenAI-Kostenabruf paginiert drei Jahre
// Tagesbuckets und lief nach 35 Minuten immer noch. Solange er lief, galt seine
// Quelle als «unterwegs», der Aktualisieren-Knopf blieb gesperrt, und dem
// Nutzer blieb nur das Herunterziehen — genau der Weg, der die anderen Karten
// mitriss.
//
// Das Widget kannte diese Lösung schon (`WidgetAbruf.mitZeitlimit`); die App
// nicht. Jetzt steht sie an einer Stelle, für beide.
enum Frist {

    /// Führt `arbeit` aus, aber höchstens `sekunden` lang.
    ///
    /// Zwei Aufgaben laufen um die erste Antwort. Gewinnt die Uhr, bricht
    /// `cancelAll()` die laufende Netzabfrage tatsächlich ab — `URLSession`
    /// beachtet die Rücknahme. Rückgabe `nil` heisst: Die Frist war es, nicht
    /// die Arbeit.
    ///
    /// Fehler der Arbeit werden **nicht** verschluckt; sie kommen als `nil`
    /// zurück, wenn `arbeit` selbst wirft. Für die Abrufe dieser App spielt das
    /// keine Rolle: Sie werfen nicht, sondern liefern ihren Fehlerzustand als
    /// Wert.
    static func hoechstens<T: Sendable>(
        _ sekunden: TimeInterval,
        _ arbeit: @escaping @Sendable () async throws -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { gruppe in
            gruppe.addTask { try? await arbeit() }
            gruppe.addTask {
                try? await Task.sleep(for: .seconds(sekunden))
                return nil
            }
            let erstes = await gruppe.next() ?? nil
            gruppe.cancelAll()
            return erstes
        }
    }
}

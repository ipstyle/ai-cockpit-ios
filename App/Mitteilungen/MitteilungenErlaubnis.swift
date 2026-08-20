import Foundation
import Observation
import UserNotifications
import UIKit

// Die Erlaubnis — und warum sie nicht beim Start erfragt wird.
//
// iOS lässt genau **einen** Versuch zu. Wird der Dialog abgelehnt, kommt er nie
// wieder; ab da führt der Weg nur noch über die Systemeinstellungen, und dort
// geht so gut wie niemand hin. Wer beim ersten Start gefragt wird, weiss noch
// nicht, wofür — und im Zweifel sagt man Nein. Damit wäre die Funktion
// dauerhaft verloren, bevor sie einmal gezeigt hat, was sie kann.
//
// Deshalb wird hier erst gefragt, wenn jemand den Schalter umlegt. Zu diesem
// Zeitpunkt ist die Frage beantwortbar: Man hat gerade gelesen, was gemeldet
// wird, und will es haben.

/// Was das System zu Mitteilungen dieser App sagt.
@MainActor
@Observable
final class MitteilungenErlaubnis {

    enum Zustand: Equatable {
        /// Noch nicht nachgesehen. Kein Zustand, sondern das Fehlen einer Auskunft.
        case unbekannt
        /// Der Dialog kam noch nie. Genau hier ist Fragen erlaubt.
        case nichtGefragt
        case erlaubt
        /// Abgelehnt oder später abgeschaltet. Ein zweiter Dialog ist nicht
        /// möglich — nur der Weg über die Systemeinstellungen.
        case abgelehnt

        var darfFragen: Bool { self == .nichtGefragt || self == .unbekannt }
    }

    private(set) var zustand: Zustand = .unbekannt

    /// Sieht nach, ohne zu fragen.
    ///
    /// Gehört auch an die Rückkehr aus dem Hintergrund: Wer die App verlässt,
    /// in den Systemeinstellungen etwas umstellt und zurückkommt, soll hier
    /// nicht den Stand von vorhin sehen.
    func lade() async {
        zustand = Self.deute(await Self.systemzustand())
    }

    /// Stellt den Dialog — genau einmal, und nur wenn es etwas zu fragen gibt.
    ///
    /// - Returns: ob am Ende gemeldet werden darf.
    @discardableResult
    func frage() async -> Bool {
        await lade()
        guard zustand.darfFragen else { return zustand == .erlaubt }

        // `.alert` und `.sound`, dieselben zwei wie in der Mac-Fassung. Kein
        // `.badge`: Eine Zahl am Symbol müsste jemand wieder wegräumen, und für
        // «zwei Fenster sind voll» gibt es nichts zu zählen.
        let erlaubt = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
        // Nicht den Rückgabewert glauben, sondern nachsehen: Bei
        // «vorläufig zugestellt» meldet das System Wahrheiten, die zwischen
        // beiden Fällen liegen.
        await lade()
        return erlaubt || zustand == .erlaubt
    }

    /// Führt in die Systemeinstellungen dieser App — der einzige Weg zurück,
    /// wenn der Dialog einmal verneint wurde.
    static func oeffneSystemeinstellungen() {
        guard let ziel = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(ziel)
    }

    /// Fragt das System, gibt aber nur den Status weiter.
    ///
    /// Der Umweg über die Fortsetzung ist Absicht: `UNNotificationSettings` ist
    /// eine Klasse, die zwischen zwei nebenläufigen Bereichen nichts zu suchen
    /// hat. Was hier hinausgeht, ist ein Aufzählungswert.
    private nonisolated static func systemzustand() async -> UNAuthorizationStatus {
        await withCheckedContinuation { fortsetzung in
            UNUserNotificationCenter.current().getNotificationSettings { einstellungen in
                fortsetzung.resume(returning: einstellungen.authorizationStatus)
            }
        }
    }

    private static func deute(_ status: UNAuthorizationStatus) -> Zustand {
        switch status {
        case .notDetermined:
            return .nichtGefragt
        case .authorized, .provisional, .ephemeral:
            // «Vorläufig» heisst: zugestellt, aber leise. Für unsere Zwecke ist
            // das ein Ja — die Meldung kommt an.
            return .erlaubt
        case .denied:
            return .abgelehnt
        @unknown default:
            // Neue Fälle gelten als Nein. Eine Meldung, die nicht ankommt, ist
            // ärgerlich; ein Schalter, der Ja verspricht und Nein meint, ist
            // schlimmer.
            return .abgelehnt
        }
    }
}

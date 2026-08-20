import Foundation
import Security
import AgentDeckCore

// Der lesende Zugriff des Widgets auf den Schlüsselbund.
//
// Eine eigene, sehr schmale Fassung von `App/Model/Zugaenge.swift` — nicht aus
// Sparsamkeit, sondern weil das Widget-Ziel jene Datei gar nicht sieht:
// `project.yml` gibt ihm nur `Widget/` und `Shared/` als Quellen. Und weil es
// sie auch nicht sehen soll: Was hier steht, kann **nur lesen** und **nur den
// einen** Eintrag, den es zum Nachfragen braucht.
//
// **Das Widget erneuert die Anmeldung nie.** Ein Refresh-Token lässt sich genau
// einmal einlösen; Anthropic dreht ihn dabei. Erneuerten App und Widget
// gleichzeitig, entwertete die zweite Antwort die erste — der Nutzer stünde
// abgemeldet da, ohne etwas getan zu haben. Ist der Token abgelaufen, sagt das
// Widget deshalb «in der App anmelden» und lässt die Finger davon.

enum WidgetSchluesselbund {

    /// Dienst und Konto stehen **buchstabengleich** in `Zugaenge` (Dienstname
    /// `Zugaenge.dienst`, Konto `Zugaenge.Zugang.claudeOAuth`). Sie hier noch
    /// einmal hinzuschreiben ist der Preis dafür, dass die App-Datei nicht im
    /// Widget-Ziel liegt. Wandert einer der beiden Werte, muss er hier mit —
    /// der Schlüsselbund meldet keinen falschen Namen, er findet dann nichts.
    private static let dienst = SchluesselbundNamen.dienst
    private static let konto = SchluesselbundNamen.claudeOAuth

    /// Was der Schlüsselbund hergibt.
    ///
    /// Vier Fälle statt eines Optionals, weil das Widget auf drei davon
    /// verschieden antwortet: «fehlt» ist eine Einladung, «abgelaufen» ein
    /// Hinweis auf die App, «unbrauchbar» ein Schaden, den ein neuer Abruf
    /// nicht heilt. Nur der vierte darf ans Netz.
    enum Fund: Sendable {
        case token(OAuthTokens)
        case fehlt
        case abgelaufen
        case unbrauchbar

        /// Ob der Nutzer in die App muss, damit hier je wieder eine frische
        /// Zahl erscheint.
        var brauchtDieApp: Bool {
            if case .token = self { return false }
            return true
        }
    }

    /// Liest den Claude-Token — ohne Zugriffsgruppe im Abfragewörterbuch.
    ///
    /// `nil` heisst dort nicht «keine Gruppe», sondern «die erste aus den
    /// Entitlements». App und Widget führen unter `keychain-access-groups`
    /// denselben einen Eintrag, also landen beide von selbst in derselben
    /// Gruppe. Eine ausgeschriebene Zeichenkette bräuchte den Team-Präfix, und
    /// der steht erst beim Signieren fest.
    static func claudeToken() -> Fund {
        let abfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var element: CFTypeRef?
        let status = SecItemCopyMatching(abfrage as CFDictionary, &element)
        // Ein abgewiesener Zugriff (falsche Gruppe, gesperrtes Gerät) wird hier
        // wie «fehlt» behandelt: Für die Anzeige ist beides dasselbe — es kommt
        // keine frische Zahl, und der Weg dahin führt über die App. Die
        // Unterscheidung gehört ins Diagnosefenster der App, nicht auf eine
        // Kachel von 155 Punkten.
        guard status == errSecSuccess, let daten = element as? Data else { return .fehlt }
        guard let token = try? JSONDecoder().decode(OAuthTokens.self, from: daten) else {
            return .unbrauchbar
        }
        return token.isExpired ? .abgelaufen : .token(token)
    }
}

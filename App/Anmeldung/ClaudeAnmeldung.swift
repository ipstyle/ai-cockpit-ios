import SwiftUI
import AuthenticationServices
import AgentDeckCore

/// Die Anmeldung bei Claude auf iOS.
///
/// Der Kern erledigt den ganzen Ablauf bereits — `ClaudeAuth.signIn(openURL:)`
/// öffnet einen lokalen Rückkanal, baut die Autorisierungs-URL mit PKCE, wartet
/// auf den Rücksprung und tauscht den Code gegen Token. Was auf iOS anders ist,
/// steckt allein in dem einen Baustein, den der Kern nach aussen gibt: **wie**
/// die Seite geöffnet wird.
///
/// Auf dem Mac reicht `NSWorkspace.open` — der Browser springt anschliessend
/// nach `http://localhost:<port>/callback` zurück, wo die App lauscht. Auf iOS
/// gibt es dafür keinen App-übergreifenden Rückweg: Safari kann eine App nur
/// über ein eigenes URL-Schema oder einen Universal Link erreichen, und beides
/// müsste bei Anthropic hinterlegt sein. Hinterlegt sind aber nur der lokale
/// Rücksprung und die Bestätigungsseite zum Abtippen.
///
/// Der Weg hier: `ASWebAuthenticationSession` zeigt die Seite **in der eigenen
/// Fensterhierarchie** an. Die App bleibt damit im Vordergrund und ihr Zuhörer
/// am Leben — anders als beim Sprung in Safari, der die App in den Hintergrund
/// schöbe und den Socket kostete. Der Rücksprung nach `localhost` verlässt das
/// Gerät nie und landet beim Zuhörer der App.
///
/// Ein Rückruf-Schema muss trotzdem angegeben werden, obwohl es nie greift.
/// Deshalb schliesst die App die Sitzung selbst, sobald der Code da ist.
@MainActor
final class ClaudeAnmeldung: NSObject, ObservableObject {

    enum Zustand: Equatable {
        case bereit
        case laeuft(schritt: String)
        case erfolg(abo: String)
        case abgebrochen(grund: String)
        case fehler(String)
    }

    @Published private(set) var zustand: Zustand = .bereit
    /// Wird im Diagnosefenster gezeigt: Ohne sie ist «es geht nicht» die
    /// einzige verfügbare Fehlerbeschreibung.
    @Published private(set) var protokoll: [String] = []

    private var sitzung: ASWebAuthenticationSession?
    /// Das Fenster, an dem das Anmeldefenster hängt. Wird beim Öffnen ermittelt,
    /// nicht beim Rückruf: Zu dem Zeitpunkt ist sicher, dass es eines gibt —
    /// sonst wird die Anmeldung gar nicht erst gestartet.
    private var anker: ASPresentationAnchor?
    private var laufenderAuftrag: Task<Void, Never>?

    func melde() {
        guard laufenderAuftrag == nil else { return }
        protokoll = []
        laufenderAuftrag = Task { await ablauf() }
    }

    /// Wird gerufen, wenn die App in den Hintergrund geht.
    ///
    /// Dann ist der lokale Zuhörer verloren — das System nimmt suspendierten
    /// Apps ihre Sockets weg. Ohne diesen Abbruch wartet die Anmeldung stumm
    /// bis zum Zeitlimit von fünf Minuten, und der Nutzer sieht nichts als
    /// einen Kreisel, der nie aufhört.
    func brichAbWegenHintergrund() {
        guard case .laeuft = zustand else { return }
        notiere("App ging in den Hintergrund — Zuhörer verloren")
        abbrechen(grund: "Die Anmeldung wurde unterbrochen. Bitte noch einmal versuchen.")
    }

    private func abbrechen(grund: String) {
        laufenderAuftrag?.cancel(); laufenderAuftrag = nil
        sitzung?.cancel(); sitzung = nil
        zustand = .abgebrochen(grund: grund)
    }

    private func ablauf() async {
        zustand = .laeuft(schritt: "Rückkanal öffnen")
        notiere("Anmeldung gestartet")
        do {
            let tokens = try await ClaudeAuth().signIn { [weak self] url in
                Task { @MainActor in self?.zeige(url) }
            }
            sitzung?.cancel(); sitzung = nil
            laufenderAuftrag = nil
            notiere("Token erhalten, gültig bis \(ablaufText(tokens))")
            zustand = .erfolg(abo: tokens.subscriptionType ?? "unbekannt")
        } catch is CancellationError {
            laufenderAuftrag = nil
        } catch {
            sitzung?.cancel(); sitzung = nil
            laufenderAuftrag = nil
            notiere("Fehler: \(error.localizedDescription)")
            zustand = .fehler(error.localizedDescription)
        }
    }

    private func zeige(_ url: URL) {
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let szene = szenen.first { $0.activationState == .foregroundActive } ?? szenen.first
        guard let fenster = szene?.keyWindow ?? szene?.windows.first else {
            notiere("Kein Fenster gefunden, an dem das Anmeldefenster hängen könnte")
            zustand = .fehler("Das Anmeldefenster liess sich nicht öffnen.")
            return
        }
        anker = fenster

        notiere("Rückkanal offen, Anmeldeseite wird geöffnet")
        zustand = .laeuft(schritt: "Anmeldeseite geöffnet")

        // Das Schema greift nie: Der Rücksprung geht nach `http://localhost`,
        // und darauf kann eine Rückruf-Sitzung nicht lauschen. Es steht hier,
        // weil die Programmierschnittstelle eines verlangt.
        let s = ASWebAuthenticationSession(url: url, callback: .customScheme("aicockpit-unbenutzt")) { [weak self] _, fehler in
            guard let self else { return }
            // Nur der Abbruch durch den Nutzer ist hier eine Nachricht. Der
            // Erfolgsfall kommt über den Zuhörer, nicht über diesen Rückruf.
            if let fehler = fehler as? ASWebAuthenticationSessionError,
               fehler.code == .canceledLogin, case .laeuft = self.zustand {
                self.notiere("Anmeldefenster vom Nutzer geschlossen")
                self.abbrechen(grund: "Die Anmeldung wurde abgebrochen.")
            }
        }
        s.presentationContextProvider = self
        // Nicht flüchtig: So kann eine bestehende Safari-Anmeldung mitgenutzt
        // werden, statt den Nutzer sein Passwort noch einmal tippen zu lassen.
        s.prefersEphemeralWebBrowserSession = false
        sitzung = s
        if s.start() == false {
            notiere("Anmeldefenster liess sich nicht öffnen")
            zustand = .fehler("Das Anmeldefenster liess sich nicht öffnen.")
        }
    }

    private func ablaufText(_ tokens: OAuthTokens) -> String {
        guard let ms = tokens.expiresAt else { return "unbekannt" }
        return Date(timeIntervalSince1970: ms / 1000).formatted(date: .abbreviated, time: .shortened)
    }

    private func notiere(_ text: String) {
        protokoll.append("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)")
    }
}

extension ClaudeAnmeldung: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Das aktive Fenster der App. Über die Szenen zu gehen statt über
        // `UIApplication.windows` ist der Weg, der auf dem iPad im Split View
        // und in mehreren Fenstern noch stimmt.
        // `zeige(_:)` setzt den Anker, bevor es die Sitzung startet, und startet
        // sie ohne Anker gar nicht — hierher kommt also nur, wer ein Fenster hat.
        guard let anker else {
            preconditionFailure("Anmeldefenster ohne Anker — zeige(_:) hätte nicht starten dürfen.")
        }
        return anker
    }
}

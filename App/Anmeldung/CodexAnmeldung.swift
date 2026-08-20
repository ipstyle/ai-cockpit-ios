import SwiftUI
import AuthenticationServices
import AgentDeckCore

/// Die Anmeldung bei ChatGPT auf iOS.
///
/// Zwei Wege, in dieser Reihenfolge:
///
/// **1. Rücksprung**, wie bei Claude — anmelden, fertig, nichts abzutippen.
/// Ein Unterschied bleibt: Der Port ist bei diesem Client **fest** (1455,
/// ersatzweise 1457), weil der Autorisierungsserver nur hinterlegte
/// Rücksprungadressen annimmt. Ist er belegt, geht dieser Weg nicht.
///
/// **2. Gerätecode**, falls kein Port frei war. Dann zeigt die App einen Code,
/// den der Nutzer auf einer Seite von OpenAI eingibt. Umständlicher, aber
/// unabhängig von Ports — und er erlaubt die Eingabe am Rechner, während man
/// das Telefon in der Hand hält.
@MainActor
final class CodexAnmeldung: ObservableObject {

    typealias Geraetecode = CodexAuth.Geraetecode

    enum Zustand: Equatable {
        case bereit
        case laeuft(schritt: String)
        case erfolg(abo: String?)
        case abgebrochen(grund: String)
        case fehler(String)
    }

    @Published private(set) var zustand: Zustand = .bereit
    @Published private(set) var code: Geraetecode?
    /// Jeder Schritt mit Uhrzeit. Bleibt als Diagnose erhalten: «geht nicht»
    /// ist keine brauchbare Fehlerbeschreibung.
    @Published private(set) var protokoll: [String] = []

    private var auftrag: Task<Void, Never>?
    private var sitzung: ASWebAuthenticationSession?
    private let anker = Fensteranker()
    private let auth = CodexAuth()

    func melde() {
        guard auftrag == nil else { return }
        protokoll = []
        code = nil
        auftrag = Task { await ablauf() }
    }

    func brichAb() {
        auftrag?.cancel(); auftrag = nil
        sitzung?.cancel(); sitzung = nil
        code = nil
        notiere(String(localized: "Vom Nutzer abgebrochen"))
        zustand = .abgebrochen(grund: String(localized: "Die Anmeldung wurde abgebrochen."))
    }

    private func ablauf() async {
        notiere(String(localized: "Anmeldung gestartet"))
        // Erst der bequeme Weg. Klappt er nicht, weil beide Häfen belegt sind,
        // kommt der Gerätecode — und zwar mit einer Meldung, die den Grund
        // nennt, statt kommentarlos etwas anderes zu tun.
        for port in CodexAuth.loopbackPorts {
            do {
                try await ueberRuecksprung(port: port)
                return
            } catch let fehler as ProviderError {
                auftrag = nil
                notiere(String(localized: "Fehler: \(fehler.userMessage)"))
                zustand = .fehler(fehler.userMessage)
                return
            } catch is CancellationError {
                auftrag = nil
                return
            } catch {
                // `String(port)` und nicht die Zahl selbst: `String(localized:)`
                // formatiert eingesetzte Zahlen nach Landesart — aus Port 1455
                // würde «1'455», und das ist keine Portnummer mehr.
                notiere(String(localized: "Port \(String(port)) nicht verfügbar"))
                continue
            }
        }
        notiere(String(localized: "Kein Rücksprung möglich — weiter über den Gerätecode"))
        await ueberGeraetecode()
    }

    /// Der Weg wie bei Claude: Anmeldeseite im eigenen Fenster, Rücksprung auf
    /// die Rückschleife.
    ///
    /// Die Sitzung zeigt die Seite **innerhalb** der App an, nicht in Safari —
    /// dadurch bleibt die App im Vordergrund und behält ihren Zuhörer. Beim
    /// Sprung in Safari wäre sie im Hintergrund und der Socket weg.
    private func ueberRuecksprung(port: UInt16) async throws {
        let server = try LoopbackCallbackServer(port: port)
        defer { server.stop() }
        _ = try await server.start()

        let anmeldung = try CodexAuth.beginneRuecksprung(port: port)
        notiere(String(localized: "Rückkanal auf Port \(String(port)) offen"))
        zustand = .laeuft(schritt: String(localized: "Anmeldeseite geöffnet"))
        zeige(anmeldung.adresse)

        let rueckgabe = try await server.waitForCallback()
        sitzung?.cancel(); sitzung = nil
        notiere(String(localized: "Rücksprung angekommen"))
        zustand = .laeuft(schritt: String(localized: "Zugriffsschlüssel wird geholt"))

        let token = try await auth.tausche(code: rueckgabe.code, state: rueckgabe.state, anmeldung: anmeldung)
        auftrag = nil
        sichere(token)
    }

    /// Der Ausweichweg, wenn kein Hafen frei war.
    private func ueberGeraetecode() async {
        zustand = .laeuft(schritt: String(localized: "Code wird angefordert"))
        do {
            let geraetecode = try await auth.fordereCode()
            code = geraetecode
            notiere(String(localized: "Code erhalten — Eingabe auf \(geraetecode.adresse.host() ?? String(localized: "der Seite von OpenAI"))"))
            zustand = .laeuft(schritt: String(localized: "Warte auf die Eingabe des Codes"))

            let freigabe = try await warteAufFreigabe(geraetecode)
            zustand = .laeuft(schritt: String(localized: "Zugriffsschlüssel wird geholt"))
            let token = try await auth.tausche(freigabe)

            auftrag = nil
            code = nil
            sichere(token)
        } catch is CancellationError {
            auftrag = nil
        } catch {
            auftrag = nil
            code = nil
            let text = (error as? ProviderError)?.userMessage ?? error.localizedDescription
            notiere(String(localized: "Fehler: \(text)"))
            zustand = .fehler(text)
        }
    }

    /// Legt den Schlüssel ab und meldet den Erfolg.
    ///
    /// Ohne die Ablage bliebe die Anmeldung ein Bildschirmtext: Der Schlüssel
    /// lebte nur hier, die Karte suchte ihn im Schlüsselbund und fände nichts.
    /// Genau so ist es bei der Claude-Anmeldung einmal gewesen.
    private func sichere(_ token: CodexToken) {
        notiere(String(localized: "Zugriffsschlüssel erhalten"))
        guard Zugaenge().schreibCodexToken(token) else {
            notiere(String(localized: "Schlüssel liess sich nicht im Schlüsselbund ablegen"))
            zustand = .fehler(String(localized: "Die Anmeldung hat geklappt, aber der Zugriffsschlüssel liess sich nicht sichern. Bitte noch einmal versuchen."))
            return
        }
        notiere(String(localized: "Im Schlüsselbund abgelegt"))
        zustand = .erfolg(abo: token.planType)
    }

    private func zeige(_ adresse: URL) {
        let s = ASWebAuthenticationSession(url: adresse, callback: .customScheme("aicockpit-unbenutzt")) { [weak self] _, fehler in
            guard let self else { return }
            // Nur der Abbruch durch den Nutzer ist hier eine Nachricht: Der
            // Erfolg kommt über den Zuhörer, nicht über diesen Rückruf.
            if let fehler = fehler as? ASWebAuthenticationSessionError,
               fehler.code == .canceledLogin, case .laeuft = self.zustand {
                self.brichAb()
            }
        }
        s.presentationContextProvider = anker
        s.prefersEphemeralWebBrowserSession = false
        sitzung = s
        if s.start() == false {
            notiere(String(localized: "Anmeldefenster liess sich nicht öffnen"))
            zustand = .fehler(String(localized: "Das Anmeldefenster liess sich nicht öffnen."))
        }
    }

    /// Fragt im vorgegebenen Takt nach, bis der Nutzer den Code eingegeben hat.
    ///
    /// Die Schleife steht hier und nicht in `CodexAuth`: Nur hier ist bekannt,
    /// ob der Nutzer inzwischen abgebrochen hat, und nur hier lässt sich jeder
    /// Versuch ins sichtbare Ablaufprotokoll schreiben. Ein «noch nicht» ist
    /// dabei der Normalfall und kein Grund aufzuhören.
    private func warteAufFreigabe(_ code: Geraetecode) async throws -> CodexAuth.Freigabe {
        let ende = Date().addingTimeInterval(CodexAuth.maximaleWartezeit)
        var versuche = 0
        while Date() < ende {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: UInt64(code.takt * 1_000_000_000))
            versuche += 1
            if case .freigegeben(let freigabe) = try await auth.frageNach(code) {
                notiere(String(localized: "Freigabe erhalten nach \(versuche) Nachfragen"))
                return freigabe
            }
        }
        throw ProviderError.unavailable(String(localized: "Der Code wurde nicht innerhalb von 15 Minuten eingegeben"))
    }

    private func notiere(_ text: String) {
        protokoll.append("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)")
    }
}

/// Sagt der Anmeldesitzung, an welchem Fenster sie hängen soll.
///
/// Eine eigene kleine Klasse, weil `ASWebAuthenticationPresentationContextProviding`
/// von `NSObject` erben muss — und die Anmeldung selbst soll deswegen nicht zur
/// `NSObject`-Unterklasse werden.
private final class Fensteranker: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let szene = szenen.first { $0.activationState == .foregroundActive } ?? szenen.first
        if let fenster = szene?.keyWindow ?? szene?.windows.first { return fenster }
        // Ohne Fensterszene läuft die App nicht mehr; die Sitzung wird dann
        // gar nicht erst gestartet.
        preconditionFailure("Anmeldefenster ohne Fensterszene")
    }
}

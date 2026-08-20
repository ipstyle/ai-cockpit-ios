import SwiftUI
import AgentDeckCore

/// Die Anmeldung bei ChatGPT auf iOS.
///
/// Anders als bei Claude läuft hier kein Rücksprung auf `localhost`, sondern
/// der Gerätecode-Fluss: Die App holt einen Code, der Nutzer tippt ihn auf
/// einer Seite von OpenAI ein, und die App fragt so lange nach, bis er
/// bestätigt ist. Warum dieser Weg und nicht der Rücksprung, steht in
/// `CodexZugang.swift`.
///
/// Für den Nutzer hat er einen Vorzug, der nicht offensichtlich ist: Er kann
/// den Code auch am Rechner eingeben, während er das Telefon in der Hand hält.
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
    private let auth = CodexAuth()

    func melde() {
        guard auftrag == nil else { return }
        protokoll = []
        code = nil
        auftrag = Task { await ablauf() }
    }

    func brichAb() {
        auftrag?.cancel(); auftrag = nil
        code = nil
        notiere("Vom Nutzer abgebrochen")
        zustand = .abgebrochen(grund: String(localized: "Die Anmeldung wurde abgebrochen."))
    }

    private func ablauf() async {
        zustand = .laeuft(schritt: String(localized: "Code wird angefordert"))
        notiere("Anmeldung gestartet")
        do {
            let geraetecode = try await auth.fordereCode()
            code = geraetecode
            notiere("Code erhalten — Eingabe auf \(geraetecode.adresse.host() ?? "der Seite von OpenAI")")
            zustand = .laeuft(schritt: String(localized: "Warte auf die Eingabe des Codes"))

            let freigabe = try await warteAufFreigabe(geraetecode)
            zustand = .laeuft(schritt: String(localized: "Zugriffsschlüssel wird geholt"))
            let token = try await auth.tausche(freigabe)

            auftrag = nil
            code = nil
            notiere("Zugriffsschlüssel erhalten")

            // Ohne diese Zeile bliebe die Anmeldung ein Bildschirmtext: Der
            // Schlüssel lebte nur in dieser Ansicht, die Karte suchte ihn im
            // Schlüsselbund und fände nichts. Genau so ist es bei der
            // Claude-Anmeldung einmal gewesen.
            guard Zugaenge().schreibCodexToken(token) else {
                notiere("Schlüssel liess sich nicht im Schlüsselbund ablegen")
                zustand = .fehler(String(localized: "Die Anmeldung hat geklappt, aber der Zugriffsschlüssel liess sich nicht sichern. Bitte noch einmal versuchen."))
                return
            }
            notiere("Im Schlüsselbund abgelegt")
            zustand = .erfolg(abo: token.planType)
        } catch is CancellationError {
            auftrag = nil
        } catch {
            auftrag = nil
            code = nil
            let text = (error as? ProviderError)?.userMessage ?? error.localizedDescription
            notiere("Fehler: \(text)")
            zustand = .fehler(text)
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
                notiere("Freigabe erhalten nach \(versuche) Nachfragen")
                return freigabe
            }
        }
        throw ProviderError.unavailable(String(localized: "Der Code wurde nicht innerhalb von 15 Minuten eingegeben"))
    }

    private func notiere(_ text: String) {
        protokoll.append("\(Date.now.formatted(date: .omitted, time: .standard))  \(text)")
    }
}

import Foundation
import CryptoKit
import AgentDeckCore

// Anmeldung und Kontingentabruf für ChatGPT/Codex — die iOS-Fassung.
//
// Warum das hier steht und nicht im Kern: Auf dem Mac holt `CodexAppServer`
// dieselben Zahlen, indem er den mitgelieferten `codex`-Dienst als Kindprozess
// startet — der kümmert sich selbst um die Anmeldung aus `~/.codex/auth.json`.
// Auf einem iPhone gibt es weder den Dienst noch `Process`. Bleibt der direkte
// Weg: sich selbst anmelden und selbst abfragen.
//
// **Jede Angabe hier ist am Quellcode von `openai/codex` (main, Stand
// 312b62a, 20.08.2026) nachgelesen und nicht aus einer Beschreibung
// übernommen.** Das ist keine Koketterie: Drei Punkte, die in der Vorlage für
// diese Datei standen, waren nachweislich falsch — der Gerätecode-Fluss ist
// **kein** RFC 8628, die Erneuerung schickt **JSON** statt Formulardaten, und
// die Kontingentantwort trägt **nicht** die Feldnamen, die in den
// Protokolldateien stehen. Wer hier etwas ändert, liest bitte wieder im
// Quellcode nach, nicht in einer Zusammenfassung.
//
// Nichts aus dieser Datei landet in `UserDefaults`, in der App Group oder in
// einer Logausgabe. Was hier durchläuft, ist der Zugriff auf ein fremdes Konto.

// MARK: - Der abgelegte Zugang

/// Die Anmeldung bei ChatGPT, so wie sie im Schlüsselbund liegt.
///
/// Bewusst **nicht** `OAuthTokens` aus dem Kern: Dort fehlen die zwei Angaben,
/// ohne die der Kontingentabruf nicht auskommt — die Kennung des Arbeitsbereichs
/// (`ChatGPT-Account-Id`) und der Rohtext des ID-Tokens, aus dem sie stammt.
/// Ein Feld im Kern zu ergänzen hiesse, die Mac-Fassung anzufassen, die diese
/// Anmeldung gar nicht kennt.
///
/// Die Zeitkonvention ist trotzdem dieselbe wie bei `OAuthTokens`:
/// Millisekunden seit 1970. Zwei Konventionen im selben Schlüsselbund wären
/// ein Fehler, der erst in ein paar Monaten auffiele.
public struct CodexToken: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    /// Der ID-Token im Rohtext. Er wird aufbewahrt, weil er die einzige Quelle
    /// für Arbeitsbereich und Abostufe ist und die Erneuerung ihn nicht immer
    /// mitschickt.
    public var idToken: String?
    /// Ablauf als Unix-Zeit in **Millisekunden**.
    public var expiresAt: Double?
    /// `chatgpt_account_id` — der Arbeitsbereich, für den die Kontingente
    /// gelten. Wer in mehreren ist, bekommt ohne diese Angabe die Zahlen eines
    /// beliebigen davon.
    public var accountId: String?
    /// `chatgpt_plan_type` («plus», «pro», «business» …).
    public var planType: String?

    /// Codex erneuert **fünf Minuten** vor Ablauf
    /// (`CHATGPT_ACCESS_TOKEN_REFRESH_WINDOW_MINUTES = 5`). Dieselbe Frist hier:
    /// Ein Abruf, der unterwegs abläuft, kostet einen zweiten Anlauf und sieht
    /// für den Nutzer aus wie ein Fehler.
    public var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date().timeIntervalSince1970 * 1000 >= expiresAt - 300_000
    }

    public init(accessToken: String, refreshToken: String? = nil, idToken: String? = nil,
                expiresAt: Double? = nil, accountId: String? = nil, planType: String? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.accountId = accountId
        self.planType = planType
    }
}

// MARK: - Die Anmeldung

/// Der Gerätecode-Fluss von Codex.
///
/// **Es gibt zwei Wege, und der andere passt nicht.** Codex kennt daneben den
/// gewöhnlichen Rücksprung nach `http://localhost:1455/auth/callback`
/// (Ausweichport 1457). Anders als bei Claude ist der Port dort **fest**: Der
/// Anmeldedienst nimmt nur eingetragene Rücksprungadressen an, eine mit
/// beliebigem Port lehnt er ab. Auf iOS hiesse das, genau diesen einen Port zu
/// belegen und ihn über den ganzen Anmeldevorgang zu halten — auch während der
/// Nutzer die App verlässt, um sein Passwort aus dem Passwortspeicher zu holen.
/// Das ist die Stelle, an der schon die Claude-Anmeldung gezittert hat.
///
/// Der Gerätecode-Fluss braucht **keinen Zuhörer**. Die App fragt einen Code
/// an, zeigt ihn an und fragt in Ruhe nach, ob er eingelöst wurde. Wer
/// zwischendurch die App verlässt, verliert nichts.
///
/// **Und es ist kein RFC 8628.** Wer den Ablauf aus dem Kopf nachbaut, baut das
/// Falsche: Die Kennung heisst `device_auth_id` und nicht `device_code`, die
/// Anfragen tragen JSON statt Formulardaten, «noch nicht eingelöst» ist ein
/// **HTTP 403 oder 404** und nicht `authorization_pending`, und das PKCE-Paar
/// erzeugt nicht der Client, sondern der Server — er schickt Verifier und
/// Challenge beim Einlösen mit zurück.
public struct CodexAuth: Sendable {

    /// Der öffentliche Client von Codex — `login/src/auth/manager.rs:1678`.
    public static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    public static let issuer = "https://auth.openai.com"

    /// Die Seite, auf der der Nutzer den Code eintippt. Sie wird **lokal
    /// zusammengesetzt**, nicht vom Server geliefert
    /// (`login/src/device_code_auth.rs:174`).
    public static let verificationURL = URL(string: "\(issuer)/codex/device")!

    static let userCodeURL = URL(string: "\(issuer)/api/accounts/deviceauth/usercode")!
    static let devicePollURL = URL(string: "\(issuer)/api/accounts/deviceauth/token")!
    static let tokenURL = URL(string: "\(issuer)/oauth/token")!

    /// Der Rücksprung, den der Tausch beim Gerätecode-Fluss nennen muss. Er
    /// wird nie aufgerufen — der Anmeldedienst prüft nur, dass derselbe Wert
    /// dasteht wie bei der Ausgabe (`device_code_auth.rs:202`). Ein anderer
    /// Wert lässt den Tausch scheitern, ohne dass die Meldung verriete, warum.
    static let deviceRedirectURI = "\(issuer)/deviceauth/callback"

    /// Wie oft höchstens nachgefragt wird, bevor aufgegeben wird — Codex
    /// wartet 15 Minuten (`device_code_auth.rs:108`), und so lange gilt der
    /// Code laut Anmeldeseite auch.
    public static let maximaleWartezeit: TimeInterval = 15 * 60

    private let session: URLSession
    public init(session: URLSession = SecureSession.noRedirects) { self.session = session }

    // MARK: Schritt 1 — Code anfordern

    /// Was der Nutzer zu sehen bekommt, und was die App zum Nachfragen braucht.
    public struct Geraetecode: Sendable, Equatable {
        /// Der Code zum Abtippen.
        public let benutzercode: String
        /// `device_auth_id` — die Kennung dieses Anmeldevorgangs. Gehört nicht
        /// auf den Bildschirm; sie ist der halbe Schlüssel zum Vorgang.
        let anmeldeKennung: String
        /// Der vom Server vorgegebene Takt zum Nachfragen.
        public let takt: TimeInterval
        public let adresse: URL
    }

    public func fordereCode() async throws -> Geraetecode {
        let daten = try await sendeJSON(an: Self.userCodeURL,
                                        koerper: ["client_id": Self.clientID],
                                        was: String(localized: "Codeanforderung"))

        guard let wurzel = try? JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw ProviderError.decoding(String(localized: "kein JSON-Objekt"))
        }
        // `user_code` heisst in manchen Antworten `usercode` — Codex führt
        // beide Schreibweisen als gleichwertig (`device_code_auth.rs:30`).
        guard let kennung = wurzel["device_auth_id"] as? String, !kennung.isEmpty,
              let code = (wurzel["user_code"] ?? wurzel["usercode"]) as? String, !code.isEmpty
        else {
            throw ProviderError.decoding(String(localized: "kein Anmeldecode in der Antwort"))
        }

        return Geraetecode(benutzercode: code,
                           anmeldeKennung: kennung,
                           takt: Self.takt(aus: wurzel["interval"]),
                           adresse: Self.verificationURL)
    }

    /// Der Takt kommt als **Zeichenkette** («"5"»), nicht als Zahl — Codex
    /// entpackt ihn ausdrücklich über einen String-Umweg
    /// (`device_code_auth.rs:47`). Eine Zahl wird trotzdem angenommen: Der Wert
    /// kommt aus dem Netz, und ein Formatwechsel dort darf keine Anmeldung
    /// kosten.
    ///
    /// **Der Deckel nach unten ist Absicht.** Codex nimmt den Wert ungeprüft,
    /// und in seinen eigenen Tests steht `"interval": "0"`. Das wäre hier eine
    /// Schleife ohne Pause — Dauerlast auf dem Anmeldedienst und ein leerer
    /// Akku, für nichts.
    static func takt(aus roh: Any?) -> TimeInterval {
        let sekunden: Double
        switch roh {
        case let text as String: sekunden = Double(text.trimmingCharacters(in: .whitespaces)) ?? 0
        case let zahl as Double: sekunden = zahl
        case let zahl as Int: sekunden = Double(zahl)
        default: sekunden = 0
        }
        guard sekunden.isFinite else { return 5 }
        return min(max(sekunden, 2), 30)
    }

    // MARK: Schritt 2 — Nachfragen

    /// Das Ergebnis **einer** Nachfrage.
    ///
    /// Die Schleife steht bewusst nicht hier, sondern beim Aufrufer: Nur der
    /// weiss, ob der Nutzer inzwischen abgebrochen hat, und nur er kann jeden
    /// Versuch ins sichtbare Ablaufprotokoll schreiben.
    public enum Nachfrage: Sendable {
        /// Der Code ist noch nicht eingelöst. Weiter warten.
        case nochNicht
        case freigegeben(Freigabe)
    }

    /// Was der Server beim Einlösen herausgibt — samt dem PKCE-Paar, das er
    /// selbst erzeugt hat.
    public struct Freigabe: Sendable, Equatable {
        let autorisierungscode: String
        let verifier: String
    }

    public func frageNach(_ code: Geraetecode) async throws -> Nachfrage {
        var anfrage = URLRequest(url: Self.devicePollURL)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = try? JSONSerialization.data(withJSONObject: [
            "device_auth_id": code.anmeldeKennung,
            "user_code": code.benutzercode
        ])
        anfrage.timeoutInterval = 30

        let (daten, antwort): (Data, URLResponse)
        do {
            (daten, antwort) = try await session.data(for: anfrage)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }

        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299:
            guard let wurzel = try? JSONSerialization.jsonObject(with: daten) as? [String: Any],
                  let autorisierungscode = wurzel["authorization_code"] as? String,
                  let verifier = wurzel["code_verifier"] as? String
            else {
                throw ProviderError.decoding(String(localized: "unvollständige Freigabe"))
            }
            return .freigegeben(Freigabe(autorisierungscode: autorisierungscode, verifier: verifier))
        case 403, 404:
            // **Das ist kein Fehler.** Solange der Nutzer den Code nicht
            // eingetippt hat, antwortet der Dienst mit «verboten» oder «nicht
            // gefunden» — Codex behandelt genau diese zwei Fälle als «warte
            // weiter» (`device_code_auth.rs:131`). Wer sie als Fehler zeigt,
            // bricht jede Anmeldung nach der ersten Sekunde ab.
            return .nochNicht
        default:
            throw ProviderError.unauthorized(
                String(localized: "Die Anmeldung wurde abgewiesen (HTTP \(status))."))
        }
    }

    // MARK: Schritt 3 — Token holen

    /// Löst den Autorisierungscode ein.
    ///
    /// **Formulardaten, nicht JSON.** Das ist die eine Stelle, an der Codex
    /// `application/x-www-form-urlencoded` schickt (`login/src/server.rs:836`);
    /// die Erneuerung weiter unten nimmt JSON. Wer beide gleich behandelt,
    /// bekommt eine Fehlermeldung, die nichts darüber verrät.
    public func tausche(_ freigabe: Freigabe) async throws -> CodexToken {
        let koerper = [
            ("grant_type", "authorization_code"),
            ("code", freigabe.autorisierungscode),
            ("redirect_uri", Self.deviceRedirectURI),
            ("client_id", Self.clientID),
            ("code_verifier", freigabe.verifier)
        ]
        .map { "\($0)=\(Self.formularkodiert($1))" }
        .joined(separator: "&")

        var anfrage = URLRequest(url: Self.tokenURL)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = Data(koerper.utf8)
        anfrage.timeoutInterval = 30

        let daten = try await fuehreAus(anfrage, was: String(localized: "Anmeldung"))
        return try Self.werteTokenAus(daten, bisher: nil)
    }

    // MARK: Der bequeme Weg — Rücksprung auf die Rückschleife

    /// Die Häfen, die dieser Client hinterlegt hat.
    ///
    /// **Fest**, anders als bei Claude: Der Autorisierungsserver nimmt nur
    /// Rücksprungadressen an, die zur Client-Kennung eingetragen sind. Einen
    /// freien Port zu wählen hiesse, die Anmeldeseite gar nicht erst zu sehen.
    public static let loopbackPorts: [UInt16] = [1455, 1457]

    /// Was eine laufende Anmeldung über den Rücksprung zusammenhält.
    public struct LoopbackAnmeldung: Sendable {
        public let adresse: URL
        let verifier: String
        let state: String
        let rueckweg: String
    }

    /// Baut die Anmeldeadresse für den Rücksprungweg.
    ///
    /// Hier erzeugt **der Client** das PKCE-Paar — anders als im
    /// Gerätecode-Fluss, wo der Server es mitschickt. Und hier gehören die drei
    /// Zusatzparameter dazu (`login/src/server.rs:575-612`): Bei der
    /// Claude-Anmeldung hat seinerzeit ein einziger fehlender Parameter
    /// «Invalid request format» ergeben.
    public static func beginneRuecksprung(port: UInt16) throws -> LoopbackAnmeldung {
        let verifier = try zufall(bytes: 64)
        let challenge = base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = try zufall(bytes: 32)
        let rueckweg = "http://localhost:\(port)/auth/callback"

        let query = [
            ("response_type", "code"),
            ("client_id", clientID),
            ("redirect_uri", rueckweg),
            // `login/src/server.rs:588-597` — genau diese Liste, genau diese
            // Reihenfolge. Bei Claude hat eine abweichende Auswahl die
            // Autorisierung mit «Invalid request format» scheitern lassen.
            ("scope", "openid profile email offline_access api.connectors.read api.connectors.invoke"),
            ("code_challenge", challenge),
            ("code_challenge_method", "S256"),
            ("id_token_add_organizations", "true"),
            ("codex_cli_simplified_flow", "true"),
            ("state", state),
            // Derselbe Wert, den der Codex-Client mit dieser Kennung sendet.
            // Ein eigener wäre ehrlicher — aber der Server kennt nur die
            // hinterlegten, und eine unbekannte Angabe kostet die Anmeldung.
            ("originator", "codex_cli_rs")
        ]
        .map { "\($0)=\(formularkodiert($1))" }
        .joined(separator: "&")

        guard let adresse = URL(string: "\(issuer)/oauth/authorize?\(query)") else {
            throw ProviderError.decoding(String(localized: "Anmeldeadresse liess sich nicht bilden"))
        }
        return LoopbackAnmeldung(adresse: adresse, verifier: verifier, state: state, rueckweg: rueckweg)
    }

    /// Tauscht den zurückgesprungenen Code gegen Token.
    public func tausche(code: String, state: String?, anmeldung: LoopbackAnmeldung) async throws -> CodexToken {
        // Der Zustandswert ist der Schutz davor, dass jemand anderes eine
        // Anmeldung unterschiebt. Stimmt er nicht, wird nicht getauscht.
        guard state == nil || state == anmeldung.state else {
            throw ProviderError.unauthorized(String(localized: "Die Antwort gehört nicht zu dieser Anmeldung"))
        }
        let koerper = [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", anmeldung.rueckweg),
            ("client_id", Self.clientID),
            ("code_verifier", anmeldung.verifier)
        ]
        .map { "\($0)=\(Self.formularkodiert($1))" }
        .joined(separator: "&")

        var anfrage = URLRequest(url: Self.tokenURL)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = Data(koerper.utf8)
        anfrage.timeoutInterval = 30

        let daten = try await fuehreAus(anfrage, was: String(localized: "Anmeldung"))
        return try Self.werteTokenAus(daten, bisher: nil)
    }

    static func zufall(bytes: Int) throws -> String {
        var roh = [UInt8](repeating: 0, count: bytes)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes, &roh) == errSecSuccess else {
            throw ProviderError.decoding(String(localized: "Zufallswerte nicht verfügbar"))
        }
        return base64URL(Data(roh))
    }

    static func base64URL(_ daten: Data) -> String {
        daten.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: Erneuern

    /// Erneuert einen abgelaufenen Zugriffstoken.
    ///
    /// **JSON**, anders als beim Tausch oben — `login/src/auth/manager.rs:1557`.
    /// Und ohne `scope`: Ältere Codex-Fassungen schickten eines mit, die
    /// heutige nicht mehr.
    ///
    /// Die Antwort führt alle drei Token als **freiwillig**. Was fehlt, bleibt
    /// stehen: Der Anmeldedienst dreht den Refresh-Token nicht bei jedem Mal,
    /// und wer das gute alte Stück durch `nil` ersetzt, hat sich abgemeldet.
    public func erneuere(_ token: CodexToken) async throws -> CodexToken {
        guard let refresh = token.refreshToken, !refresh.isEmpty else {
            throw ProviderError.notSignedIn(
                String(localized: "Kein Refresh-Token vorhanden — bitte neu anmelden"))
        }
        var anfrage = URLRequest(url: Self.tokenURL)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = try? JSONSerialization.data(withJSONObject: [
            "client_id": Self.clientID,
            "grant_type": "refresh_token",
            "refresh_token": refresh
        ])
        anfrage.timeoutInterval = 30

        let daten = try await fuehreAus(anfrage, was: String(localized: "Erneuerung"))
        return try Self.werteTokenAus(daten, bisher: token)
    }

    // MARK: - Antworten auswerten

    /// - Parameter bisher: Der bisherige Stand bei einer Erneuerung. Fehlende
    ///   Felder werden daraus übernommen.
    static func werteTokenAus(_ daten: Data, bisher: CodexToken?) throws -> CodexToken {
        guard let wurzel = try? JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw ProviderError.decoding(String(localized: "kein JSON-Objekt"))
        }
        guard let zugriff = (wurzel["access_token"] as? String) ?? bisher?.accessToken,
              !zugriff.isEmpty
        else {
            throw ProviderError.decoding(String(localized: "kein access_token in der Antwort"))
        }

        let idToken = (wurzel["id_token"] as? String) ?? bisher?.idToken
        // Die Namen im Tupel gehören auch in den Ausweichwert: Ohne sie
        // leitet Swift ein unbenanntes `(String?, String?)` ab, und die
        // Zugriffe darunter finden ihre Felder nicht mehr.
        let angaben = idToken.map(kontoangaben(aus:)) ?? (konto: nil, abo: nil)

        return CodexToken(
            accessToken: zugriff,
            refreshToken: (wurzel["refresh_token"] as? String) ?? bisher?.refreshToken,
            idToken: idToken,
            // Der Ablauf steht **nicht** in der Antwort: Codex liest weder
            // `expires_in` noch `expires_at`, sondern den Anspruch `exp` aus
            // dem Zugriffstoken selbst (`login/src/token_data.rs:130`).
            expiresAt: ablauf(ausJWT: zugriff) ?? bisher?.expiresAt,
            accountId: angaben.konto ?? bisher?.accountId,
            planType: angaben.abo ?? bisher?.planType)
    }

    /// Arbeitsbereich und Abostufe aus dem ID-Token.
    ///
    /// Sie stehen in einem Anspruch, dessen Name eine ganze Adresse ist:
    /// `https://api.openai.com/auth` — darin `chatgpt_account_id` und
    /// `chatgpt_plan_type` (`login/src/token_data.rs:77`).
    ///
    /// **Die Signatur wird nicht geprüft**, genauso wenig wie Codex sie prüft.
    /// Das ist vertretbar, weil der Token von derselben Verbindung kommt, über
    /// die auch der Zugriffstoken kam — geprüft würde also nur die eigene
    /// Antwort. Es wäre **nicht** vertretbar, wenn dieser Inhalt je über eine
    /// Rechtefrage entschiede; er benennt hier ein Konto und ein Abo, sonst
    /// nichts.
    static func kontoangaben(aus jwt: String) -> (konto: String?, abo: String?) {
        guard let nutzlast = jwtNutzlast(jwt),
              let auth = nutzlast["https://api.openai.com/auth"] as? [String: Any]
        else { return (nil, nil) }
        // Beide Werte kommen aus dem Netz und werden zu Bildschirmtext.
        let konto = (auth["chatgpt_account_id"] as? String).map { Sanitize.line($0, limit: 80) }
        let abo = (auth["chatgpt_plan_type"] as? String).map { Sanitize.line($0, limit: 40) }
        return (konto?.isEmpty == false ? konto : nil, abo?.isEmpty == false ? abo : nil)
    }

    /// `exp` in Sekunden — hier auf Millisekunden gebracht, damit im
    /// Schlüsselbund überall dieselbe Einheit steht.
    static func ablauf(ausJWT jwt: String) -> Double? {
        guard let nutzlast = jwtNutzlast(jwt) else { return nil }
        let sekunden = (nutzlast["exp"] as? Double) ?? (nutzlast["exp"] as? Int).map(Double.init)
        guard let sekunden, sekunden.isFinite, sekunden > 0 else { return nil }
        return sekunden * 1000
    }

    /// Der mittlere Teil eines JWT, Base64 in der URL-sicheren Schreibweise
    /// ohne Auffüllzeichen. Die muss vor dem Entpacken ergänzt werden — sonst
    /// gibt `Data(base64Encoded:)` stillschweigend `nil` zurück, und das sähe
    /// aus wie ein Token ohne Ablauf.
    static func jwtNutzlast(_ jwt: String) -> [String: Any]? {
        let teile = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard teile.count == 3 else { return nil }
        var roh = String(teile[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rest = roh.count % 4
        if rest > 0 { roh += String(repeating: "=", count: 4 - rest) }
        guard let daten = Data(base64Encoded: roh),
              let nutzlast = try? JSONSerialization.jsonObject(with: daten) as? [String: Any]
        else { return nil }
        return nutzlast
    }

    // MARK: - Kleinkram

    private func sendeJSON(an ziel: URL, koerper: [String: String], was: String) async throws -> Data {
        var anfrage = URLRequest(url: ziel)
        anfrage.httpMethod = "POST"
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        anfrage.httpBody = try? JSONSerialization.data(withJSONObject: koerper)
        anfrage.timeoutInterval = 30
        return try await fuehreAus(anfrage, was: was)
    }

    private func fuehreAus(_ anfrage: URLRequest, was: String) async throws -> Data {
        let (daten, antwort): (Data, URLResponse)
        do {
            (daten, antwort) = try await session.data(for: anfrage)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200...299:
            return daten
        case 404:
            // Der eigene Fall, weil er etwas Bestimmtes heisst: Codex meldet
            // ihn als «Gerätecode-Anmeldung ist für diesen Server nicht
            // freigeschaltet» (`device_code_auth.rs:83`) und weicht dann auf
            // den Browser aus. Diese App hat kein Ausweichen — sie muss es
            // wenigstens verständlich sagen.
            throw ProviderError.unavailable(
                String(localized: "OpenAI nimmt die Anmeldung per Code gerade nicht an. Bitte später noch einmal versuchen."))
        case 400...499:
            throw ProviderError.unauthorized(
                String(localized: "\(was) fehlgeschlagen (HTTP \(status))"))
        case 500...599:
            throw ProviderError.transient(
                String(localized: "OpenAI antwortete mit HTTP \(status)"))
        default:
            throw ProviderError.network(
                String(localized: "OpenAI antwortete mit HTTP \(status)"))
        }
    }

    /// Kodiert wie `urlencoding::encode` auf der Gegenseite: alles ausser den
    /// in RFC 3986 unreservierten Zeichen. **Kein `+` für Leerzeichen** —
    /// anders als bei Claude, wo genau das verlangt ist.
    static func formularkodiert(_ wert: String) -> String {
        let unreserviert = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return wert.addingPercentEncoding(withAllowedCharacters: unreserviert) ?? wert
    }
}

// MARK: - Der Kontingentabruf

/// Fragt die ChatGPT-Kontingente ab — ohne Modellaufruf.
///
/// `GET https://chatgpt.com/backend-api/wham/usage`, mit dem Zugriffstoken im
/// Kopf. Denselben Aufruf macht `account/rateLimits/read` des Codex-Dienstes,
/// den die Mac-Fassung benutzt; die Zwischenschicht dort ist nur eine dünne
/// Hülle.
///
/// **Die Antwort sieht anders aus als in den Protokolldateien.** Wer sie aus
/// `CodexLogParser` kennt, sucht hier vergeblich nach `primary`,
/// `window_minutes` und `resets_at`. Auf dem Draht steht:
///
///     { "plan_type": "plus",
///       "rate_limit": {
///         "allowed": true, "limit_reached": false,
///         "primary_window":   { "used_percent": 12,
///                               "limit_window_seconds": 18000,
///                               "reset_after_seconds": 4200,
///                               "reset_at": 1786512000 },
///         "secondary_window": { … } },
///       "credits": { "has_credits": true, "unlimited": false, "balance": "12.30" } }
///
/// Die vertrauten Namen entstehen erst in Codex selbst: `window_minutes` wird
/// aus `limit_window_seconds` **aufgerundet** (`backend-client/src/client.rs:719`),
/// `resets_at` ist umbenanntes `reset_at`. Genau diese Umrechnung passiert hier,
/// damit am Ende dieselben `LimitWindow` herauskommen wie auf dem Mac.
public struct CodexUsageClient: Sendable {

    public static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    /// Eine eigene, ehrliche Kennung statt der von Codex.
    ///
    /// Codex schickt `codex_cli_rs/…`. Sich als fremdes Programm auszugeben
    /// wäre bei einer App im Store der falsche Weg — und wäre es auch dann,
    /// wenn niemand hinsähe. Ob die Gegenstelle eine unbekannte Kennung
    /// annimmt, ist **ungeprüft**; ändert sich das, steht der Wert hier an
    /// einer Stelle.
    public static let kennung = "AI-Cockpit/1.0 (iOS)"

    private let session: URLSession
    public init(session: URLSession = SecureSession.noRedirects) { self.session = session }

    public func fetch(token: CodexToken) async throws -> CodexLimits {
        var anfrage = URLRequest(url: Self.usageURL)
        anfrage.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        anfrage.setValue(Self.kennung, forHTTPHeaderField: "User-Agent")
        // Nur wenn bekannt: Wer in mehreren Arbeitsbereichen ist, bekommt ohne
        // diese Kopfzeile die Zahlen irgendeines davon. Eine leere Kopfzeile
        // wäre schlimmer als keine.
        if let konto = token.accountId, !konto.isEmpty {
            anfrage.setValue(konto, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        anfrage.timeoutInterval = 20

        let (daten, antwort): (Data, URLResponse)
        do {
            (daten, antwort) = try await session.data(for: anfrage)
        } catch {
            throw ProviderError.network(error.localizedDescription)
        }

        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200:
            return try Self.parse(daten)
        case 401, 403:
            throw ProviderError.unauthorized(
                String(localized: "ChatGPT-Anmeldung abgelaufen — bitte neu anmelden"))
        case 429:
            throw ProviderError.rateLimited(
                String(localized: "ChatGPT drosselt gerade — zu viele Anfragen"),
                retryAfter: Self.wiederholenNach(antwort))
        case 500...599:
            throw ProviderError.transient(String(localized: "ChatGPT antwortete mit HTTP \(status)"))
        default:
            throw ProviderError.network(String(localized: "ChatGPT antwortete mit HTTP \(status)"))
        }
    }

    // MARK: Auswertung

    public static func parse(_ daten: Data, now: Date = Date()) throws -> CodexLimits {
        guard let wurzel = try? JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw ProviderError.decoding(String(localized: "kein JSON-Objekt"))
        }

        let grenzen = wurzel["rate_limit"] as? [String: Any]
        var fenster: [LimitWindow] = []
        // Die Reihenfolge der Schlüssel sagt nichts über die Länge des
        // Fensters aus — genau wie bei den Protokolldateien läuft die
        // Zuordnung unten allein über die Fensterlänge.
        for schluessel in ["primary_window", "secondary_window"] {
            guard let roh = grenzen?[schluessel] as? [String: Any],
                  let gefunden = fensterAus(roh) else { continue }
            fenster.append(gefunden)
        }

        let guthaben = wurzel["credits"] as? [String: Any]
        let limits = CodexLimits(
            fiveHour: fenster.first { $0.windowMinutes == 300 },
            weekly: fenster.first { $0.windowMinutes == 10080 },
            planType: (wurzel["plan_type"] as? String).map { Sanitize.line($0, limit: 40) },
            // `balance` ist auf dem Draht eine **Zeichenkette**, keine Zahl.
            creditBalance: (guthaben?["balance"] as? String).map { Sanitize.line($0, limit: 40) },
            observedAt: now,
            // `.appServer` heisst im Kern «live vom Codex-Dienst geholt», im
            // Gegensatz zum Nachlesen in alten Protokolldateien. Genau das ist
            // es hier — nur ohne den Dienst dazwischen. Ein eigener Fall wäre
            // ehrlicher, stünde aber im Mac-Projekt.
            source: .appServer)

        // Eine Antwort ohne ein einziges bekanntes Fenster ist keine leere
        // Karte, sondern ein Formatwechsel. Der gehört gemeldet, sonst sucht
        // man den Fehler im Konto statt im Code.
        guard limits.fiveHour != nil || limits.weekly != nil else {
            throw ProviderError.decoding(String(localized: "keine bekannten Fenster in der Antwort"))
        }
        return limits
    }

    static func fensterAus(_ roh: [String: Any]) -> LimitWindow? {
        guard let anteil = zahl(roh["used_percent"]) else { return nil }
        let minuten = zahl(roh["limit_window_seconds"]).flatMap(minutenAus(sekunden:))
        let zuruecksetzung = zahl(roh["reset_at"]).map { Date(timeIntervalSince1970: $0) }
        return LimitWindow(label: beschriftung(fuer: minuten),
                           usedPercent: anteil,
                           resetsAt: zuruecksetzung,
                           windowMinutes: minuten)
    }

    /// Aufgerundet, wie Codex es tut: `(sekunden + 59) / 60`, und `nil` bei
    /// null oder negativ (`backend-client/src/client.rs:719`). Ohne das
    /// Aufrunden ergäben 18 000 Sekunden zwar sauber 300 Minuten, aber jede
    /// krumme Angabe der Gegenstelle liefe an der Zuordnung unten vorbei.
    static func minutenAus(sekunden: Double) -> Int? {
        guard sekunden.isFinite, sekunden > 0 else { return nil }
        // Deckel gegen einen unsinnigen Wert aus dem Netz: Ohne ihn riesse
        // `Int(...)` auf einer Zahl jenseits von `Int.max` den Prozess mit.
        let begrenzt = min(sekunden, 60 * 60 * 24 * 366)
        return Int((begrenzt + 59) / 60)
    }

    /// Dieselben Bezeichnungen wie auf dem Mac. Sie stehen hier noch einmal,
    /// weil `CodexLogParser.label(forMinutes:)` im Kern nicht öffentlich ist —
    /// und weil sie auf dem Bildschirm landen, gehören sie übersetzt.
    static func beschriftung(fuer minuten: Int?) -> String {
        switch minuten {
        case 300: return String(localized: "5 Stunden")
        case 10080: return String(localized: "7 Tage")
        case .some(let m) where m % 1440 == 0: return String(localized: "\(m / 1440) Tage")
        case .some(let m) where m % 60 == 0: return String(localized: "\(m / 60) Stunden")
        case .some(let m): return String(localized: "\(m) Minuten")
        case .none: return String(localized: "Fenster")
        }
    }

    /// `used_percent` ist auf dem Draht eine Ganzzahl, `limit_window_seconds`
    /// ebenso. Trotzdem beide Fälle: Eine JSON-Zahl ohne Nachkommastellen
    /// kommt je nach Gegenstelle als `Int` **oder** als `Double` an.
    static func zahl(_ wert: Any?) -> Double? {
        switch wert {
        case let d as Double: return d.isFinite ? d : nil
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue.isFinite ? n.doubleValue : nil
        default: return nil
        }
    }

    /// `Retry-After` kommt als Sekundenzahl oder als HTTP-Datum. Nach oben auf
    /// einen Tag begrenzt: Der Wert stammt aus dem Netz und landet in einer
    /// Zeitrechnung.
    static func wiederholenNach(_ antwort: URLResponse) -> TimeInterval? {
        guard let roh = (antwort as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces), !roh.isEmpty else { return nil }
        if let sekunden = Double(roh) { return min(max(0, sekunden), 86_400) }

        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = TimeZone(secondsFromGMT: 0)
        format.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let datum = format.date(from: roh) else { return nil }
        return max(0, datum.timeIntervalSinceNow)
    }
}

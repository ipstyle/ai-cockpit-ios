import Foundation
import Security
import AgentDeckCore

// Die Zugangsdaten der iOS-Fassung.
//
// Aufbau und Wortwahl folgen `KeychainStore` aus dem Kern — bewusst als eigene
// Datei und nicht als Wiederverwendung, denn zwei Dinge müssen hier anders sein
// und beide betreffen jeden einzelnen Eintrag:
//
// **Eigener Dienstname.** Der Kern legt unter `AF Agent Deck` ab; das ist die
// Mac-App. Zwei Programme, die sich denselben Eintrag teilen, überschreiben
// einander früher oder später — und beim Abmelden auf dem einen Gerät wäre man
// auf dem anderen mit abgemeldet.
//
// **`AfterFirstUnlock` statt `WhenUnlocked`.** Das Widget wird vom System
// geweckt, wann es will — auch bei gesperrtem Bildschirm, auch kurz nach einem
// Neustart. Mit `WhenUnlocked` bekäme es an genau diesen Stellen `errSecInteractionNotAllowed`
// zurück und zeigte stumm nichts an, ohne dass irgendwo ein Fehler auftauchte.
//
// Nichts davon landet je in `UserDefaults`, in der App Group oder in einer
// Logausgabe: Was hier steht, ist der Zugriff auf fremde Konten.

/// Zugangsdaten im Schlüsselbund dieses Geräts.
struct Zugaenge: Sendable {

    /// Konto-Kennungen unter dem Dienst `Self.dienst`.
    ///
    /// Die Rohwerte sind buchstabengleich zu `KeychainStore.Account` im Kern.
    /// Sie stehen zwar unter einem anderen Dienst und können sich deshalb nicht
    /// in die Quere kommen — aber wer beide Seiten liest, soll nicht zwei
    /// Vokabulare für dieselbe Sache lernen müssen.
    enum Zugang: String, Sendable, CaseIterable {
        /// JSON mit access/refresh-Token der App-eigenen Claude-Anmeldung.
        case claudeOAuth = "claude-oauth"
        /// OpenAI-Organization-Admin-Key für die Costs-API.
        case openAIAdminKey = "openai-admin-key"
        /// Anthropic-Admin-Schlüssel (`sk-ant-admin…`) für die Kosten der API —
        /// etwas anderes als die OAuth-Anmeldung des Abos.
        case anthropicAdminKey = "anthropic-admin-key"
        /// API-Schlüssel der Kimi-Plattform (Kontostand).
        case kimiAPIKey = "kimi-api-key"
    }

    static let dienst = "AI Cockpit Mobile"

    /// Die Zugriffsgruppe, unter der App und Widget denselben Eintrag sehen.
    ///
    /// **`nil` heisst hier nicht «keine Gruppe», sondern «die erste aus den
    /// Entitlements».** Genau das ist die richtige Antwort: Beide Ziele führen
    /// unter `keychain-access-groups` denselben einen Eintrag,
    /// `$(AppIdentifierPrefix)com.ip-style.aicockpitmobile`, und damit landet
    /// jeder ungeschriebene Zugriff von selbst in der gemeinsamen Gruppe.
    ///
    /// Sie hier auszuschreiben ginge nicht ohne den Team-Präfix, und der steht
    /// erst beim Signieren fest. Eine geratene Zeichenkette wäre der teuerste
    /// aller Fehler: Der Schlüsselbund meldet keine falsche Gruppe, er findet
    /// dann einfach nichts.
    ///
    /// Kommt später eine zweite Gruppe dazu, muss hier eine stehen — dann ist
    /// «die erste» keine Aussage mehr.
    static let zugriffsgruppe: String? = nil

    init() {}

    // MARK: - Nachsehen

    /// Was der Schlüsselbund auf eine Anfrage sagt.
    ///
    /// «Nichts bekommen» hat zwei sehr verschiedene Gründe: Es ist keiner
    /// hinterlegt — oder der Zugriff wurde abgewiesen. Auf iOS heisst das
    /// zweite fast immer, dass Zugriffsgruppe und Provisioning-Profil nicht
    /// zusammenpassen. Wer beides gleich behandelt, schickt den Nutzer auf die
    /// Suche nach einem Schlüssel, der längst da ist.
    enum Fund: Equatable, Sendable {
        case gefunden(Data)
        case fehlt
        case verweigert(OSStatus)
    }

    func pruefe(_ zugang: Zugang) -> Fund {
        var abfrage = basis(konto: zugang.rawValue)
        abfrage[kSecReturnData as String] = true
        abfrage[kSecMatchLimit as String] = kSecMatchLimitOne
        var element: CFTypeRef?
        let status = SecItemCopyMatching(abfrage as CFDictionary, &element)
        switch status {
        case errSecSuccess:
            guard let daten = element as? Data else { return .fehlt }
            return .gefunden(daten)
        case errSecItemNotFound:
            return .fehlt
        default:
            return .verweigert(status)
        }
    }

    func lies(_ zugang: Zugang) -> Data? {
        if case .gefunden(let daten) = pruefe(zugang) { return daten }
        return nil
    }

    func liesText(_ zugang: Zugang) -> String? {
        lies(zugang).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Ablegen

    @discardableResult
    func schreib(_ daten: Data, nach zugang: Zugang) -> Bool {
        let abfrage = basis(konto: zugang.rawValue)
        let werte: [String: Any] = [
            kSecValueData as String: daten,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemUpdate(abfrage as CFDictionary, werte as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var neu = abfrage
        neu.merge(werte) { _, frisch in frisch }
        return SecItemAdd(neu as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    func schreib(_ text: String, nach zugang: Zugang) -> Bool {
        schreib(Data(text.utf8), nach: zugang)
    }

    @discardableResult
    func loesche(_ zugang: Zugang) -> Bool {
        SecItemDelete(basis(konto: zugang.rawValue) as CFDictionary) == errSecSuccess
    }

    private func basis(konto: String) -> [String: Any] {
        var abfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.dienst,
            kSecAttrAccount as String: konto
        ]
        if let gruppe = Self.zugriffsgruppe {
            abfrage[kSecAttrAccessGroup as String] = gruppe
        }
        return abfrage
    }
}

// MARK: - Claude-Token

extension Zugaenge {

    /// Wie `Fund`, eine Stufe weiter: Ein **vorhandener, aber unlesbarer**
    /// Eintrag ist etwas anderes als gar keiner. Ein `try?` an dieser Stelle
    /// machte aus einem beschädigten Eintrag ein «nicht angemeldet» — man
    /// meldet sich neu an und versteht nicht, warum es vorher nicht ging.
    enum TokenFund: Sendable {
        case token(OAuthTokens)
        case fehlt
        case verweigert(OSStatus)
        case unlesbar
    }

    func pruefeToken() -> TokenFund {
        switch pruefe(.claudeOAuth) {
        case .fehlt:
            return .fehlt
        case .verweigert(let status):
            return .verweigert(status)
        case .gefunden(let daten):
            guard let token = try? JSONDecoder().decode(OAuthTokens.self, from: daten) else {
                return .unlesbar
            }
            return .token(token)
        }
    }

    func liesToken() -> OAuthTokens? {
        if case .token(let token) = pruefeToken() { return token }
        return nil
    }

    @discardableResult
    func schreibToken(_ token: OAuthTokens) -> Bool {
        guard let daten = try? JSONEncoder().encode(token) else { return false }
        return schreib(daten, nach: .claudeOAuth)
    }
}

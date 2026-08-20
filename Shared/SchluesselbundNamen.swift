import Foundation

/// Die Namen, unter denen die Zugangsdaten im Schlüsselbund liegen.
///
/// Sie stehen hier und nicht bei der App, weil die Widget-Erweiterung
/// denselben Eintrag lesen muss. Zweimal geschrieben wären es zwei Namen, die
/// im Gleichschritt bleiben müssten — und beim Tag, an dem einer nachzieht,
/// meldet der Schlüsselbund keinen Fehler. Er findet einfach nichts, und das
/// Widget bleibt leer, ohne dass irgendwo etwas rot wird.
public enum SchluesselbundNamen {

    /// Bewusst **nicht** «AF Agent Deck» wie auf dem Mac: Das ist ein eigener
    /// Eintrag auf einem eigenen Gerät, und die beiden gehen einander nichts an.
    public static let dienst = "AI Cockpit Mobile"

    public static let claudeOAuth = "claude-oauth"
    public static let codexOAuth = "codex-oauth"
    public static let openAIAdminKey = "openai-admin-key"
    public static let anthropicAdminKey = "anthropic-admin-key"
    public static let kimiAPIKey = "kimi-api-key"
}

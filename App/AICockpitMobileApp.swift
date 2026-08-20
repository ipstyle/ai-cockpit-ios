import SwiftUI
import AgentDeckCore

/// Einstiegspunkt der iPhone- und iPad-Fassung.
///
/// Noch ein Gerüst: Es beweist die Verdrahtung — dass der Kern aus dem
/// Mac-Projekt eingebunden ist, dass die App Group erreichbar ist und dass das
/// Widget mitgeliefert wird. Die Karten kommen in Etappe E2.
@main
struct AICockpitMobileApp: App {
    var body: some Scene {
        WindowGroup { GeruestAnsicht() }
    }
}

/// Zeigt, was schon steht. Wird durch die Kartenliste ersetzt.
struct GeruestAnsicht: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Cockpit").font(.largeTitle.weight(.semibold))
            Zeile("Kern eingebunden", ClaudeAuth.clientID.isEmpty == false)
            Zeile("App Group erreichbar", AppGruppe.erreichbar)
            Text(AppGruppe.erreichbar
                 ? "Bereit für die Karten."
                 : "Ohne App Group bleibt das Widget leer — Entitlements prüfen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Häkchen **und** Text: Eine Aussage, die allein an der Farbe hängt, ist
    /// keine Aussage — weder für das eingetönte Widget noch für jemanden, der
    /// Rot und Grün nicht unterscheidet.
    @ViewBuilder
    private func Zeile(_ titel: String, _ erfuellt: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: erfuellt ? "checkmark.circle" : "xmark.circle")
            Text(titel)
            Spacer()
            Text(erfuellt ? "ja" : "nein").foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

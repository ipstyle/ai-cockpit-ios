import SwiftUI

/// Die Anmeldeseite — und zugleich der Machbarkeitsnachweis aus Etappe E0.
///
/// Sie zeigt absichtlich mehr, als eine fertige Anmeldung zeigen würde: jeden
/// Schritt mit Uhrzeit. Ob der Rücksprung über `localhost` auf einem echten
/// iPhone ankommt, ist die eine Frage, an der dieses Vorhaben hängt — und wenn
/// sie mit «geht nicht» beantwortet wird, ist das keine brauchbare Antwort.
/// Das Protokoll bleibt später als Diagnose erhalten.
struct AnmeldeAnsicht: View {
    @StateObject private var anmeldung = ClaudeAnmeldung()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bei Claude anmelden")
                    .font(.title2.weight(.semibold))

                Text("Die Anmeldung läuft über Claude selbst. Diese App sieht dein Passwort nie — sie bekommt nur einen Zugriffsschlüssel, der im Schlüsselbund dieses Geräts bleibt.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                zustandsZeile

                Button(action: anmeldung.melde) {
                    Text(knopfText).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(laeuft)

                if anmeldung.protokoll.isEmpty == false {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ablauf").font(.footnote.weight(.medium))
                        ForEach(anmeldung.protokoll, id: \.self) { zeile in
                            Text(zeile)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(20)
        }
        .onChange(of: phase) { _, neu in
            if neu == .background { anmeldung.brichAbWegenHintergrund() }
        }
    }

    /// Symbol **und** Text, nie Farbe allein — das gilt in der App genauso wie
    /// im eingetönten Widget.
    @ViewBuilder
    private var zustandsZeile: some View {
        switch anmeldung.zustand {
        case .bereit:
            Label("Noch nicht angemeldet", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
        case let .laeuft(schritt):
            HStack(spacing: 8) { ProgressView(); Text(schritt) }
        case let .erfolg(abo):
            // Ohne Abostufe steht schlicht «Angemeldet». «Abo: unbekannt» wäre
            // eine Auskunft über unser Nichtwissen, nicht über das Konto.
            Label(abo.map { "Angemeldet — Abo: \($0)" } ?? "Angemeldet",
                  systemImage: "checkmark.circle")
                .foregroundStyle(.green)
        case let .abgebrochen(grund):
            Label(grund, systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        case let .fehler(text):
            Label(text, systemImage: "xmark.circle")
                .foregroundStyle(.red)
        }
    }

    private var laeuft: Bool {
        if case .laeuft = anmeldung.zustand { return true }
        return false
    }

    private var knopfText: String {
        switch anmeldung.zustand {
        case .bereit: return "Anmelden"
        case .laeuft: return "Läuft …"
        case .erfolg: return "Erneut anmelden"
        case .abgebrochen, .fehler: return "Noch einmal versuchen"
        }
    }
}

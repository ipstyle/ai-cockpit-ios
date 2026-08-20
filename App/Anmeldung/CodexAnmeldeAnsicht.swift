import SwiftUI

/// Die Anmeldeseite für ChatGPT/Codex.
///
/// Sie sieht anders aus als `AnmeldeAnsicht` und muss es auch: Bei Claude
/// öffnet sich ein Anmeldeblatt und der Nutzer schaut zu. Hier bekommt er eine
/// **Aufgabe** — eine Adresse öffnen und einen Code abtippen —, und eine
/// Aufgabe braucht die beiden Dinge, die man dafür in der Hand haben will:
/// den Code gross genug zum Ablesen und einen Knopf, der ihn in die
/// Zwischenablage legt.
///
/// Das Ablaufprotokoll steht hier aus demselben Grund wie drüben: «Es geht
/// nicht» ist keine Fehlerbeschreibung, mit der jemand etwas anfangen kann.
struct CodexAnmeldeAnsicht: View {
    @StateObject private var anmeldung = CodexAnmeldung()
    @Environment(\.openURL) private var oeffne

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Bei ChatGPT anmelden")
                    .font(.title2.weight(.semibold))

                Text("Die Anmeldung läuft über OpenAI selbst. Diese App sieht dein Passwort nie — sie bekommt nur einen Zugriffsschlüssel, der im Schlüsselbund dieses Geräts bleibt.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                zustandsZeile

                // Der Codeblock steht **über** dem Knopf, nicht darunter: Sobald
                // er da ist, ist er das Einzige, was der Nutzer noch braucht.
                if let code = anmeldung.code { codeBlock(code) }

                Button(action: anmeldung.melde) {
                    Text(knopfText).frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(laeuft)

                if laeuft {
                    Button(role: .cancel, action: anmeldung.brichAb) {
                        Text("Abbrechen").frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }

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
    }

    // MARK: - Der Code

    /// Code, Adresse und die zwei Knöpfe, die man dafür braucht.
    ///
    /// Der Code steht einstellig gesperrt und in einer Schrift mit gleichen
    /// Zeichenbreiten: Er enthält Buchstaben und Ziffern nebeneinander, und in
    /// einer Proportionalschrift verwechselt man dort «0» und «O».
    @ViewBuilder
    private func codeBlock(_ code: CodexAnmeldung.Geraetecode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Öffne die Adresse und gib diesen Code ein:")
                .font(.callout)

            Text(code.benutzercode)
                .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
                .tracking(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                // Kein reiner Farbhinweis: Der Code steht gross und beschriftet
                // da, die Fläche ist nur Rahmen.
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))

            Text(code.adresse.absoluteString)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                Button {
                    oeffne(code.adresse)
                } label: {
                    Label("Adresse öffnen", systemImage: "safari")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    // `UIPasteboard` und nicht der Umweg über die Ansicht:
                    // Ein `Text` mit Kopierbefehl verlangt eine lange
                    // Berührung, und wer den Code gerade abtippen will, sucht
                    // keine versteckte Geste.
                    UIPasteboard.general.string = code.benutzercode
                    kopiert = true
                } label: {
                    Label(kopiert ? "Kopiert" : "Code kopieren",
                          systemImage: kopiert ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }

            Text("Der Code gilt 15 Minuten. Danach fängt die Anmeldung von vorn an.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 14))
        // Wechselt der Code (neuer Anlauf), gilt die Erfolgsmeldung des
        // Kopierknopfs nicht mehr — sonst stünde «Kopiert» an einem Code, der
        // nie in der Zwischenablage war.
        .onChange(of: code.benutzercode) { _, _ in kopiert = false }
    }

    @State private var kopiert = false

    // MARK: - Zustand

    /// Symbol **und** Text, nie Farbe allein — dieselbe Regel wie bei Claude
    /// und im eingetönten Widget.
    @ViewBuilder
    private var zustandsZeile: some View {
        switch anmeldung.zustand {
        case .bereit:
            Label("Noch nicht angemeldet", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
        case let .laeuft(schritt):
            HStack(spacing: 8) { ProgressView(); Text(schritt) }
        case let .erfolg(abo):
            // Ohne Abostufe schlicht «Angemeldet». «Abo: unbekannt» wäre eine
            // Auskunft über unser Nichtwissen, nicht über das Konto.
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

    // Vier feste Texte, alle durch `String(localized:)`: Ein blosses
    // Zeichenkettenliteral in einer `String`-Rückgabe geht am Katalog vorbei
    // und stünde in jeder Sprache deutsch da.
    private var knopfText: String {
        switch anmeldung.zustand {
        case .bereit: return String(localized: "Anmelden")
        case .laeuft: return String(localized: "Läuft …")
        case .erfolg: return String(localized: "Erneut anmelden")
        case .abgebrochen, .fehler: return String(localized: "Noch einmal versuchen")
        }
    }
}

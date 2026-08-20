import SwiftUI
import AgentDeckCore

// Konten — die Seite, ohne die drei der sechs Karten dauerhaft leer bleiben.
//
// Vier Abschnitte, einer je Dienst. Claude ist ein Anmeldevorgang, die übrigen
// drei sind ein Schlüssel zum Einsetzen. Der Ton ist überall derselbe: **Ein
// Dienst ohne Schlüssel ist kein Fehler.** Wer die Anthropic-API nie benutzt
// hat, soll hier keine rote Zeile sehen, sondern erfahren, was er bekäme, wenn
// er einen Schlüssel hinterlegte — und wo er ihn findet.
//
// Was der Bildschirm nie zeigt, ist ein hinterlegter Schlüssel im Klartext.
// Weder beim Nachsehen noch beim Ersetzen. Sichtbar ist, **dass** einer da ist,
// und höchstens seine letzten vier Zeichen — genug, um zwei auseinanderzuhalten,
// zu wenig, um über die Schulter mitgelesen zu werden.

struct KontenSeite: View {
    let einstellungen: Einstellungen

    @State private var zeigtAnmeldung = false

    var body: some View {
        EinstellungsForm(titel: String(localized: "Konten")) {
            claudeAbschnitt

            SchluesselAbschnitt(
                einstellungen: einstellungen,
                zugang: .openAIAdminKey,
                titel: "OpenAI-Admin",
                platzhalter: String(localized: "Admin-Schlüssel (sk-admin-…)"),
                herkunft: String(localized: "Zu finden unter platform.openai.com → Settings → Admin keys. Es muss ein Organisations-Admin-Schlüssel sein; ein gewöhnlicher Projektschlüssel gibt die Kosten nicht heraus."),
                nutzen: String(localized: "Zeigt die Kosten der OpenAI-API — heute, laufender Monat, gesamt."))

            SchluesselAbschnitt(
                einstellungen: einstellungen,
                zugang: .anthropicAdminKey,
                titel: "Anthropic-Admin",
                platzhalter: String(localized: "Admin-Schlüssel (sk-ant-admin-…)"),
                herkunft: String(localized: "Zu finden unter console.anthropic.com → Settings → Admin keys."),
                nutzen: String(localized: "Zeigt die Kosten der Anthropic-API — etwas anderes als das Abo, das über die Anmeldung oben läuft. Wer beides zahlt, sieht beides."))

            kimiAbschnitt
        }
        .sheet(isPresented: $zeigtAnmeldung) {
            // Nach dem Zumachen den Schlüsselbund neu lesen: Die Anmeldeansicht
            // legt den Token selbst ab, und ohne diesen Griff stünde hier
            // weiter «nicht angemeldet», während es längst geklappt hat.
            einstellungen.aktualisiereStand()
        } content: {
            AnmeldeAnsicht()
        }
    }

    // MARK: - Claude

    @ViewBuilder
    private var claudeAbschnitt: some View {
        Section {
            zustandsZeileClaude
            switch einstellungen.claudeZustand {
            case .angemeldet, .unlesbar:
                Button(role: .destructive) {
                    einstellungen.meldeAb()
                } label: {
                    Text("Abmelden").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            case .nichtAngemeldet, .verweigert:
                Button {
                    zeigtAnmeldung = true
                } label: {
                    Text("Anmelden …").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        } header: {
            Text("Claude")
        } footer: {
            Text("Die Anmeldung läuft über Anthropic selbst — diese App sieht dein Passwort nie. Sie bekommt einen Zugriffsschlüssel, der im Schlüsselbund dieses Geräts bleibt und den sie selbsttätig erneuert. Ohne Anmeldung bleibt die Claude-Karte leer.")
        }
    }

    @ViewBuilder
    private var zustandsZeileClaude: some View {
        switch einstellungen.claudeZustand {
        case .nichtAngemeldet:
            ZustandsZeile(text: String(localized: "Nicht angemeldet"), symbol: "person.crop.circle")
        case .angemeldet(let ablauf, let abo):
            VStack(alignment: .leading, spacing: 4) {
                ZustandsZeile(text: abo.map { String(localized: "Angemeldet — Abo \($0)") }
                                    ?? String(localized: "Angemeldet"),
                              symbol: "checkmark.seal.fill",
                              farbe: .green)
                // Der Ablauf steht da, damit ein Fehlschlag einordbar wird —
                // nicht als Aufforderung. Erneuert wird von selbst.
                Text(ablauf.map { String(localized: "Zugriffsschlüssel gültig bis \(Theme.absolute($0)) · wird selbsttätig erneuert") }
                           ?? String(localized: "Ablauf des Zugriffsschlüssels unbekannt · wird bei Bedarf erneuert"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .verweigert(let status):
            ZustandsZeile(text: String(localized: "Der Schlüsselbund gibt die Anmeldung nicht heraus (Status \(status)). Das ist ein Fehler im Bau der App, nicht in deiner Eingabe."),
                          symbol: "lock.trianglebadge.exclamationmark",
                          farbe: .orange)
        case .unlesbar:
            ZustandsZeile(text: String(localized: "Die gespeicherte Anmeldung ist unlesbar. Abmelden und neu anmelden räumt das auf."),
                          symbol: "exclamationmark.triangle.fill",
                          farbe: .orange)
        }
    }

    // MARK: - Kimi

    /// Kimi bekommt einen eigenen Abschnitt, weil zum Schlüssel eine zweite
    /// Angabe gehört: die Plattform. Sie steht **über** dem Eingabefeld, denn
    /// sie entscheidet, welcher Schlüssel überhaupt der richtige ist.
    private var kimiAbschnitt: some View {
        SchluesselAbschnitt(
            einstellungen: einstellungen,
            zugang: .kimiAPIKey,
            titel: "Kimi K3",
            platzhalter: String(localized: "API-Schlüssel"),
            herkunft: String(localized: "Zu finden in der Kontoverwaltung der oben gewählten Plattform."),
            nutzen: String(localized: "Zeigt das verfügbare Guthaben. Einen Endpunkt für Tages-, Monats- oder Gesamtverbrauch bietet Kimi nicht — diese Zahlen stehen nur in der Weboberfläche.")) {
                KimiPlattform(einstellungen: einstellungen)
            }
    }
}

// MARK: - Plattformwahl

/// International oder China — zwei getrennte Plattformen mit getrennten
/// Schlüsseln.
private struct KimiPlattform: View {
    @Bindable var einstellungen: Einstellungen

    var body: some View {
        Picker(selection: $einstellungen.kimiRegion) {
            ForEach(KimiClient.Region.allCases, id: \.self) { region in
                Text(region.label).tag(region)
            }
        } label: {
            Text("Plattform")
        }
        .pickerStyle(.inline)

        Text("Die Schlüssel der beiden Plattformen sind nicht austauschbar: Über Kreuz antwortet Kimi mit 401 — was aussieht wie ein falscher Schlüssel und keiner ist.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Ein Schlüssel

/// Ein Dienst mit Schlüssel: Zustand, Eingabefeld, Sichern, Löschen, Erklärung.
///
/// `Zusatz` ist der Platz für das, was nur einen Dienst betrifft — bei Kimi die
/// Plattformwahl. Er steht vor dem Eingabefeld, weil er im Zweifel bestimmt,
/// welcher Schlüssel hineingehört.
struct SchluesselAbschnitt<Zusatz: View>: View {
    let einstellungen: Einstellungen
    let zugang: Zugaenge.Zugang
    let titel: String
    let platzhalter: String
    /// Wo man den Schlüssel herbekommt.
    let herkunft: String
    /// Was er bringt — und damit auch, was ohne ihn fehlt.
    let nutzen: String
    let zusatz: Zusatz

    @State private var eingabe = ""
    @State private var fragtNachLoeschen = false
    @State private var fehler: String?

    init(einstellungen: Einstellungen,
         zugang: Zugaenge.Zugang,
         titel: String,
         platzhalter: String,
         herkunft: String,
         nutzen: String,
         @ViewBuilder zusatz: () -> Zusatz) {
        self.einstellungen = einstellungen
        self.zugang = zugang
        self.titel = titel
        self.platzhalter = platzhalter
        self.herkunft = herkunft
        self.nutzen = nutzen
        self.zusatz = zusatz()
    }

    private var zustand: SchluesselZustand { einstellungen.zustand(zugang) }

    private var sauber: String { eingabe.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Section {
            zusatz
            zustandsZeile

            // `.password` statt `.newPassword`: Der Schlüssel ist ein
            // bestehendes Geheimnis, keines, das hier entsteht — sonst bietet
            // iOS an, ein starkes Passwort zu erzeugen. Autokorrektur und
            // Grossschreibung sind aus, weil beide einen Schlüssel zuverlässig
            // zerstören, ohne dass man es beim Tippen sieht.
            SecureField(platzhalter, text: $eingabe)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit(sichere)
                .frame(minHeight: 44)

            Button(action: sichere) {
                Text(zustand.istHinterlegt ? "Ersetzen" : "Sichern")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(sauber.isEmpty)

            if zustand.istHinterlegt {
                Button(role: .destructive) {
                    fragtNachLoeschen = true
                } label: {
                    Text("Löschen").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .confirmationDialog(Text("Schlüssel für \(titel) löschen?"),
                                    isPresented: $fragtNachLoeschen,
                                    titleVisibility: .visible) {
                    Button("Löschen", role: .destructive) {
                        einstellungen.loesche(zugang)
                        eingabe = ""
                    }
                    Button("Abbrechen", role: .cancel) { }
                } message: {
                    Text("Der Eintrag verschwindet aus dem Schlüsselbund dieses Geräts. Die Karte bleibt danach leer, bis wieder einer da ist.")
                }
            }

            if let fehler {
                ZustandsZeile(text: fehler, symbol: "exclamationmark.circle.fill", farbe: .orange)
            }
        } header: {
            Text(titel)
        } footer: {
            // Erst was es bringt, dann wo es herkommt, dann die Entwarnung —
            // in dieser Reihenfolge, weil die dritte Zeile sonst wie eine
            // Ausrede klingt statt wie eine Auskunft.
            Text("\(nutzen)\n\n\(herkunft)\n\nFreiwillig: Ohne diesen Schlüssel bleibt nur diese eine Karte leer, alles andere läuft weiter.")
        }
    }

    @ViewBuilder
    private var zustandsZeile: some View {
        switch zustand {
        case .fehlt:
            ZustandsZeile(text: String(localized: "Kein Schlüssel hinterlegt"), symbol: "key.slash")
        case .hinterlegt(let endung):
            // Die letzten vier Zeichen, mehr nie. Sie beantworten die einzige
            // Frage, die sich ohne den Wert stellen lässt: Ist das noch der von
            // damals oder schon der neue?
            ZustandsZeile(text: endung.isEmpty
                          ? String(localized: "Schlüssel hinterlegt")
                          : String(localized: "Schlüssel hinterlegt · endet auf \(endung)"),
                          symbol: "checkmark.circle.fill",
                          farbe: .green)
        case .verweigert(let status):
            ZustandsZeile(text: String(localized: "Der Schlüsselbund weist den Zugriff ab (Status \(status)). Ein Schlüssel kann hinterlegt sein und trotzdem nicht gelesen werden — das ist ein Fehler im Bau der App."),
                          symbol: "lock.trianglebadge.exclamationmark",
                          farbe: .orange)
        }
    }

    private func sichere() {
        guard !sauber.isEmpty else { return }
        if einstellungen.sichere(sauber, in: zugang) {
            fehler = nil
        } else {
            fehler = String(localized: "Der Schlüssel liess sich nicht im Schlüsselbund ablegen. Bitte noch einmal versuchen.")
        }
        // In jedem Fall leeren — auch beim Fehlschlag. Ein Geheimnis, das in
        // einem Eingabefeld stehenbleibt, wandert ins nächste Bildschirmfoto
        // und in jeden Blick über die Schulter.
        eingabe = ""
    }
}

/// Der gewöhnliche Fall: ein Dienst ohne Zusatzangabe.
///
/// Als eigener, auf `EmptyView` festgelegter Initialisierer und nicht als
/// Vorgabewert im Rumpf oben — Swift lässt einen Standardwert nicht zu, der
/// den generischen Parameter erst festlegen würde.
extension SchluesselAbschnitt where Zusatz == EmptyView {
    init(einstellungen: Einstellungen,
         zugang: Zugaenge.Zugang,
         titel: String,
         platzhalter: String,
         herkunft: String,
         nutzen: String) {
        self.init(einstellungen: einstellungen,
                  zugang: zugang,
                  titel: titel,
                  platzhalter: platzhalter,
                  herkunft: herkunft,
                  nutzen: nutzen) { EmptyView() }
    }
}

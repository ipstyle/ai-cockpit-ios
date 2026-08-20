import SwiftUI
import AgentDeckCore

// Die Einstellungen der iOS-Fassung.
//
// Auf dem Mac sind es sieben Reiter. Hier sind es sechs Seiten in einem
// `NavigationStack`, und das ist kein Sparzwang: Sieben Reiter nebeneinander
// setzen voraus, dass man alle sieben gleichzeitig sieht und sich den Weg
// merkt. Auf einem Telefon sieht man einen Bildschirm. Eine Liste, aus der man
// hineingeht und mit «Zurück» wieder heraus, ist dort die ehrlichere Form.
//
// Weggefallen sind gegenüber dem Mac: **Aktualisierung** (es gibt keinen Takt,
// der sich einstellen liesse — aktualisiert wird auf Zuruf), **Verlauf** (er
// bräuchte einen Prozess, der läuft, während niemand hinsieht) und
// **Hinweise** (Mitteilungen kommen, wenn es sie gibt, nicht vorher).

struct EinstellungenAnsicht: View {
    /// Nur zum Ablesen: Wann zuletzt geholt wurde, gehört in die Diagnose, und
    /// nach dem Löschen aller Daten sollen die Karten nicht mit Zahlen
    /// stehenbleiben, die es nicht mehr gibt.
    let cockpit: Cockpit

    @State private var einstellungen = Einstellungen()

    var body: some View {
        NavigationStack {
            Inhalt(einstellungen: einstellungen, cockpit: cockpit)
        }
        // Steht **hier** und nicht in `Inhalt`: `preferredColorScheme` wirkt auf
        // das, was die Ansicht umgibt. Der Inhalt liest das Farbschema danach
        // aus der Umgebung — deshalb ist er eine eigene Ansicht und nicht
        // derselbe Rumpf, in dem die Vorgabe gesetzt wird.
        .preferredColorScheme(einstellungen.darstellung.preferredColorScheme)
    }
}

// MARK: - Die Liste

private struct Inhalt: View {
    let einstellungen: Einstellungen
    let cockpit: Cockpit

    @Environment(\.dismiss) private var schliesse
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)

        List {
            Section {
                zeile(ziel: KontenSeite(einstellungen: einstellungen),
                      titel: String(localized: "Konten"),
                      symbol: "person.badge.key",
                      wert: kontenKurzfassung)
                zeile(ziel: DarstellungSeite(einstellungen: einstellungen),
                      titel: String(localized: "Darstellung"),
                      symbol: "circle.lefthalf.filled",
                      wert: einstellungen.darstellung.title)
                zeile(ziel: SchwellenSeite(einstellungen: einstellungen),
                      titel: String(localized: "Schwellenwerte"),
                      symbol: "speedometer",
                      wert: "\(Int(einstellungen.warnSchwelle)) % · \(Int(einstellungen.kritischeSchwelle)) %")

                zeile(ziel: MitteilungenSeite(vorgaben: MitteilungenVorgaben.geteilt),
                      titel: String(localized: "Mitteilungen"),
                      symbol: "bell.badge",
                      wert: mitteilungenKurzfassung)
            }
            .listRowBackground(palette.card)

            Section {
                // Steht **vor** der Diagnose und nicht als Absatz in «Über»:
                // Wer wissen will, wohin seine Schlüssel gehen, sucht das nicht
                // unter «Über». Die Fusszeile dieses Abschnitts macht dieselbe
                // Zusage in einem Satz — der Weg hinein ist der Beleg dazu.
                zeile(ziel: DatenschutzSeite(),
                      titel: String(localized: "Datenschutz und Sicherheit"),
                      symbol: "lock.shield",
                      wert: nil)
                zeile(ziel: DiagnoseSeite(einstellungen: einstellungen, cockpit: cockpit),
                      titel: String(localized: "Diagnose"),
                      symbol: "stethoscope",
                      wert: nil)
                zeile(ziel: UeberSeite(einstellungen: einstellungen, cockpit: cockpit),
                      titel: String(localized: "Über"),
                      symbol: "info.circle",
                      wert: AppKennung.kurz)
            } footer: {
                Text("Alle Angaben bleiben auf diesem Gerät. Es gibt kein Konto bei AI Cockpit und keinen Server, der etwas davon zu sehen bekäme.")
            }
            .listRowBackground(palette.card)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .tint(palette.accent)
        .navigationTitle(Text("Einstellungen"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { schliesse() }
            }
        }
    }

    /// Eine Zeile der Übersicht: Zeichen, Name, aktueller Wert.
    ///
    /// Der Wert rechts spart den Weg hinein — wer nur nachsehen will, ob die
    /// Schwelle noch bei 75 steht, soll dafür nicht zweimal tippen müssen.
    private func zeile<Ziel: View>(ziel: Ziel, titel: String, symbol: String, wert: String?) -> some View {
        NavigationLink {
            ziel
        } label: {
            Label {
                HStack(alignment: .firstTextBaseline) {
                    Text(titel)
                    if let wert {
                        Spacer(minLength: 8)
                        Text(wert)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } icon: {
                Image(systemName: symbol)
            }
        }
        .frame(minHeight: 44)
    }

    /// «Angemeldet · 2 von 3 Schlüsseln» — und wenn nichts eingerichtet ist,
    /// steht das auch so da, ohne Warnzeichen. Ein leeres Konto ist kein
    /// Fehlerzustand.
    /// Was gemeldet wird — oder «aus». Dieselbe Absicht wie bei den anderen
    /// Zeilen: Wer nur nachsehen will, ob die Hinweise an sind, soll dafür
    /// nicht hineingehen müssen.
    private var mitteilungenKurzfassung: String {
        let vorgaben = MitteilungenVorgaben.geteilt
        switch (vorgaben.beiLimit, vorgaben.beiNeuemFenster) {
        case (false, false): return String(localized: "aus")
        case (true, false): return String(localized: "Limit")
        case (false, true): return String(localized: "neues Fenster")
        case (true, true): return String(localized: "Limit · neues Fenster")
        }
    }

    private var kontenKurzfassung: String {
        let schluessel = Einstellungen.schluesselDienste.filter { einstellungen.zustand($0).istHinterlegt }.count
        let anmeldung = einstellungen.claudeZustand.istAngemeldet
            ? String(localized: "angemeldet")
            : String(localized: "nicht angemeldet")
        guard schluessel > 0 else { return anmeldung }
        return String(localized: "\(anmeldung) · \(schluessel) von 3 Schlüsseln")
    }
}

// MARK: - Gemeinsame Bausteine

/// Der Rahmen jeder Unterseite: Hintergrund der App statt Systemgrau, damit
/// die Einstellungen nicht wie ein fremdes Programm aussehen.
struct EinstellungsForm<Inhalt: View>: View {
    let titel: String
    @ViewBuilder let inhalt: Inhalt

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)
        Form {
            // Die Zeilenfarbe wird auf den ganzen Inhalt gelegt und nicht auf
            // jeden Abschnitt einzeln: Sonst müsste jede neue Seite daran
            // denken, und die eine, die es vergisst, fällt auf.
            inhalt.listRowBackground(palette.card)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background)
        .tint(palette.accent)
        .navigationTitle(Text(titel))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Eine Zustandszeile — Zeichen **und** Text, nie Farbe allein.
///
/// Dieselbe Regel wie in den Karten, und sie gilt hier aus demselben Grund:
/// Ein grüner Haken ohne Wort ist für jeden zehnten Mann eine graue Form.
struct ZustandsZeile: View {
    let text: String
    let symbol: String
    var farbe: Color?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .foregroundStyle(farbe ?? palette.secondary)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

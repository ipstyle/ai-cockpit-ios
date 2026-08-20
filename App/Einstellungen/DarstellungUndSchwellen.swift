import SwiftUI
import UIKit
import AgentDeckCore

// Drei kurze Seiten: wie es aussieht, in welcher Sprache es dasteht, und ab
// wann es drückt.

// MARK: - Darstellung

/// Hell, dunkel oder wie das System.
///
/// «System» ist die Vorgabe und gibt bewusst **nichts** vor: Dann wirkt ein
/// Wechsel im Kontrollzentrum ohne Zutun der App, und wer sein Telefon abends
/// automatisch umschalten lässt, bekommt hier nicht die eine Ansicht, die sich
/// daran nicht hält.
struct DarstellungSeite: View {
    @Bindable var einstellungen: Einstellungen

    var body: some View {
        EinstellungsForm(titel: String(localized: "Darstellung")) {
            Section {
                Picker(selection: $einstellungen.darstellung) {
                    // Feste Reihenfolge statt `allCases`: hell, dunkel, System
                    // ist die Ordnung, in der iOS selbst fragt.
                    ForEach([AppAppearance.light, .dark, .system], id: \.self) { modus in
                        Text(modus.title).tag(modus)
                    }
                } label: {
                    Text("Erscheinungsbild")
                }
                .pickerStyle(.inline)
            } footer: {
                Text("Die Farben der Karten folgen der Wahl: Anthrazit im dunklen, warmes Papier im hellen Modus. «System» übernimmt, was das Gerät gerade vorgibt.")
            }

            Section {
                Button(role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: "cardOrder")
                } label: {
                    Label("Ursprüngliche Reihenfolge", systemImage: "arrow.uturn.backward")
                        .frame(minHeight: 44)
                }
            } footer: {
                // Den Knopf gibt es auch im Sortiermodus selbst. Hier steht er
                // ein zweites Mal für alle, die ihn dort nicht vermuten — und
                // weil «zurück zum Anfang» in die Einstellungen gehört.
                Text("Stellt die Karten wieder in die Reihenfolge, in der die App sie anlegt. Was eingeklappt ist, bleibt.")
            }
        }
    }
}

// MARK: - Sprache

/// Woher die App weiss, in welcher Sprache sie gerade läuft.
///
/// `Bundle.main.preferredLocalizations` und nicht `Locale.current`: Gefragt ist
/// nicht, welche Sprache das Gerät bevorzugt, sondern welche Sprachdatei die
/// App tatsächlich geladen hat. Wer sein iPhone auf Französisch stellt, sieht
/// hier Englisch — und genau das soll die Zeile dann auch sagen.
enum Sprachwahl {
    /// «de», «en» — das Kürzel der geladenen Sprachdatei.
    static var aktuellesKuerzel: String {
        Bundle.main.preferredLocalizations.first ?? "en"
    }

    /// Der Name der Sprache **in dieser Sprache selbst**: «Deutsch», «English».
    ///
    /// Absichtlich nicht in der laufenden Oberflächensprache. Wer die App
    /// versehentlich auf Englisch stehen hat, erkennt «Deutsch» auch dann,
    /// wenn er die Zeile daneben nicht liest — und darum geht es bei dieser
    /// einen Zeile.
    static var aktuellerName: String { name(fuer: aktuellesKuerzel) }

    static func name(fuer kuerzel: String) -> String {
        let sprache = Locale(identifier: kuerzel)
        let roh = sprache.localizedString(forLanguageCode: kuerzel) ?? kuerzel
        return roh.prefix(1).uppercased() + roh.dropFirst()
    }

    /// Merkt die gewählte Sprache für den nächsten Start.
    ///
    /// `AppleLanguages` ist der Schlüssel, aus dem iOS beim Start liest. Setzen
    /// wirkt deshalb erst beim nächsten Start — die Oberfläche sagt das auch.
    /// Ein leerer Wert übergibt die Wahl wieder dem Gerät.
    static func setze(_ kuerzel: String) {
        UserDefaults.standard.set([kuerzel], forKey: "AppleLanguages")
    }

    /// Führt in die Systemeinstellungen dieser App.
    ///
    /// Dieselbe Zeile steht in `MitteilungenErlaubnis`. Sie bleibt dort, wo sie
    /// ist: Der Erlaubnistyp der Mitteilungen soll nicht die allgemeine
    /// Anlaufstelle für jeden Weg in die Systemeinstellungen werden.
    @MainActor
    static func oeffneSystemeinstellungen() {
        guard let ziel = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(ziel)
    }
}

/// Die Sprachseite — und der Grund, warum hier kein Schalter steht.
///
/// iOS lädt die Sprachdateien einer App beim Start. Ein Umschalter in der App
/// könnte den nächsten Start vorbereiten, aber nicht die Ansicht ändern, in der
/// er sitzt: Zurück auf der Kartenliste stünde weiter die alte Sprache, und
/// dass das kein Fehler ist, müsste ein Beipackzettel erklären. Ein Schalter,
/// der umgelegt aussieht und nichts bewirkt, ist eine Lüge — dieselbe Regel wie
/// bei den Mitteilungen, und dieselbe Antwort: sagen, was gilt, und den Weg
/// dorthin zeigen, wo es tatsächlich geht.
///
/// In den Systemeinstellungen bietet iOS seit Version 13 eine Sprachwahl je
/// App an. Sie wirkt sofort, weil das System die App dabei neu startet.
struct SpracheSeite: View {
    /// Die Sprache, die iOS beim nächsten Start laden soll.
    ///
    /// `AppleLanguages` hält iOS als **Liste**, nicht als Zeichenkette —
    /// `@AppStorage` taugt dafür nicht. Gesetzt wird über `Sprachwahl.setze`,
    /// und gewirkt hat es erst beim nächsten Start; die Fusszeile sagt das.
    @State private var wahl: String = Sprachwahl.aktuellesKuerzel
    @State private var umgestellt = false

    var body: some View {
        EinstellungsForm(titel: String(localized: "Sprache")) {
            Section {
                Picker(selection: $wahl) {
                    // Jede in ihrem **eigenen** Namen. Wer die App gerade in
                    // einer Sprache vor sich hat, die er nicht liest, findet
                    // «Deutsch» und «English» trotzdem.
                    Text(verbatim: "English").tag("en")
                    Text(verbatim: "Deutsch").tag("de")
                } label: {
                    Text("Sprache")
                }
                .pickerStyle(.inline)
                .onChange(of: wahl) { _, neu in
                    Sprachwahl.setze(neu)
                    umgestellt = true
                }
            } footer: {
                if umgestellt {
                    Text("Die neue Sprache erscheint, sobald AI Cockpit das nächste Mal startet. Schliesse die App dafür ganz — aus dem Hintergrund zurückzukehren genügt nicht.")
                } else {
                    Text("Deutsch und Englisch sind vollständig übersetzt. Ohne eigene Wahl richtet sich die App nach dem Gerät und fällt sonst auf Englisch zurück.")
                }
            }

            Section {
                Button {
                    Sprachwahl.oeffneSystemeinstellungen()
                } label: {
                    Label(String(localized: "In den Systemeinstellungen ändern"), systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            } footer: {
                Text("Dort steht dieselbe Wahl, und das System startet AI Cockpit beim Umstellen gleich neu.")
            }
        }
    }
}

// MARK: - Schwellenwerte

/// Ab wann ein Kontingent warnt und ab wann es drückt.
///
/// Die Regel, die die Seite trägt: **Die kritische Schwelle liegt nie unter der
/// Warnschwelle.** Sonst käme der Alarm vor der Warnung, und die Warnung wäre
/// eine Stufe, die niemand je sieht. Erzwungen wird das im Modell, nicht hier —
/// die Schieberegler dürfen sich nicht darauf verlassen, die einzigen Wege in
/// diese Werte zu sein.
struct SchwellenSeite: View {
    @Bindable var einstellungen: Einstellungen

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EinstellungsForm(titel: String(localized: "Schwellenwerte")) {
            Section {
                regler(titel: String(localized: "Warnung ab"),
                       wert: $einstellungen.warnSchwelle,
                       von: 50,
                       symbol: LimitLevel.warn.symbol,
                       farbe: Theme.palette(scheme).warning)
                regler(titel: String(localized: "Kritisch ab"),
                       wert: $einstellungen.kritischeSchwelle,
                       von: einstellungen.warnSchwelle,
                       symbol: LimitLevel.critical.symbol,
                       farbe: Theme.palette(scheme).critical)
            } header: {
                Text("Prozent des Kontingents")
            } footer: {
                Text("Die kritische Schwelle kann nicht unter die Warnschwelle rutschen — sie wird mitgezogen. Vorgabe sind 75 und 90 Prozent, dieselben Werte wie in der Mac-Fassung.")
            }

            Section {
                beispiel
            } header: {
                Text("Beispiel")
            } footer: {
                Text("Die zwei feinen Marken auf dem Balken zeigen, wo die Schwellen liegen — sie sagen es ohne Farbe, und damit auch in einem eingefärbten Widget.")
            }
        }
    }

    private func regler(titel: String,
                        wert: Binding<Double>,
                        von: Double,
                        symbol: String?,
                        farbe: Color) -> some View {
        // Der untere Anschlag wird bei 99 gekappt. Sonst entstünde bei einer
        // Warnschwelle von 100 % für den zweiten Regler der Bereich 100…100 —
        // und ein `Slider` mit leerem Bereich beendet das Programm.
        let unten = min(von, 99)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol {
                    Image(systemName: symbol).font(.caption).foregroundStyle(farbe)
                }
                Text(titel).frame(maxWidth: .infinity, alignment: .leading)
                // Die Zahl steht immer daneben, nicht nur im Regler: Ein
                // Schieber ohne Wert ist eine Schätzung.
                Text("\(Int(wert.wrappedValue)) %")
                    .monospacedDigit()
                    .foregroundStyle(farbe)
            }
            // Ganze Prozentschritte. Feiner wäre eine Genauigkeit, die keine
            // Entscheidung ändert — und mit dem Daumen ohnehin nicht zu treffen.
            Slider(value: wert, in: unten...100, step: 1) {
                Text(titel)
            } minimumValueLabel: {
                Text("\(Int(unten))").font(.caption2).monospacedDigit()
            } maximumValueLabel: {
                Text("100").font(.caption2).monospacedDigit()
            }
            .accessibilityValue(Text("\(Int(wert.wrappedValue)) Prozent"))
        }
        .padding(.vertical, 4)
    }

    /// Ein Balken bei 82 Prozent — hoch genug, dass die Warnschwelle in der
    /// Vorgabe greift, und niedrig genug, dass die kritische es nicht tut. So
    /// sieht man beim Schieben, was die Zahlen bewirken.
    private var beispiel: some View {
        let palette = Theme.palette(scheme)
        let fenster = LimitWindow(label: String(localized: "Beispiel"), usedPercent: 82, resetsAt: nil)
        return LimitRow(title: String(localized: "7-Tage-Fenster"),
                        window: fenster,
                        thresholds: einstellungen.schwellen,
                        provider: .claude)
            .padding(.vertical, 4)
            .foregroundStyle(palette.primary)
    }
}

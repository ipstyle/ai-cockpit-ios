import SwiftUI
import AgentDeckCore

/// Welche Karten überhaupt erscheinen.
///
/// Ausblenden ist etwas anderes als Einklappen: Eine eingeklappte Karte wird
/// weiter abgerufen und zeigt ihre Kurzfassung, eine ausgeblendete gibt es in
/// der Liste nicht mehr. Wer die Anthropic-Schnittstelle nie benutzt, will sie
/// auch nicht als leere Zeile sehen.
struct KartenSeite: View {
    @Environment(\.colorScheme) private var scheme
    /// Dasselbe Format wie bei Reihenfolge und eingeklappten Karten: eine Liste
    /// von Kennungen. Über `@AppStorage`, damit die Kartenansicht die Änderung
    /// beim Zumachen von selbst bemerkt.
    @AppStorage("hiddenCards") private var versteckt = ""

    /// Die Reihenfolge, in der die App die Karten anlegt — nicht die, die der
    /// Nutzer gelegt hat. Hier geht es um das Was, nicht um das Wohin.
    private let karten: [(id: CardLayout.Card, titel: String, anbieter: Theme.Provider)] = [
        (.claude, "Claude", .claude),
        (.chatgpt, "ChatGPT", .chatGPT),
        (.openai, String(localized: "OpenAI-API"), .openAI),
        // Anthropic-API und Claude teilen sich die Farbe: derselbe Anbieter,
        // zwei Zugänge.
        (.anthropic, String(localized: "Anthropic-API"), .claude),
        (.kimi, "Kimi K3", .kimi)
    ]

    var body: some View {
        let palette = Theme.palette(scheme)

        EinstellungsForm(titel: String(localized: "Karten")) {
            Section {
                ForEach(karten, id: \.id) { karte in
                    Toggle(isOn: bindung(fuer: karte.id)) {
                        HStack(spacing: 10) {
                            // Dieselbe Akzentkante wie auf der Karte selbst —
                            // damit die Zeile hier und die Karte dort ohne
                            // Nachdenken zusammenfinden.
                            RoundedRectangle(cornerRadius: 2)
                                .fill(palette.color(for: karte.anbieter))
                                .frame(width: 3, height: 22)
                            Text(karte.titel)
                                .foregroundStyle(palette.primary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            } footer: {
                Text("Ausgeblendete Karten verschwinden aus der Liste. Abgerufen werden sie trotzdem — wer eine wieder einblendet, sieht sofort Zahlen statt einer Wartemeldung.")
            }
            .listRowBackground(palette.card)

            if versteckt.isEmpty == false {
                Section {
                    Button {
                        versteckt = ""
                    } label: {
                        Label("Alle wieder einblenden", systemImage: "eye")
                            .frame(minHeight: 44)
                    }
                }
                .listRowBackground(palette.card)
            }
        }
    }

    /// Der Schalter zeigt **sichtbar**, nicht **versteckt** — ein Schalter, der
    /// eingeschaltet bedeutet «weg», liest sich falsch herum.
    private func bindung(fuer id: CardLayout.Card) -> Binding<Bool> {
        Binding(
            get: { liste.contains(id.rawValue) == false },
            set: { sichtbar in
                var neu = liste
                if sichtbar {
                    neu.removeAll { $0 == id.rawValue }
                } else if neu.contains(id.rawValue) == false {
                    neu.append(id.rawValue)
                }
                versteckt = neu.joined(separator: ",")
            }
        )
    }

    private var liste: [String] {
        versteckt.split(separator: ",").map(String.init).filter { $0.isEmpty == false }
    }
}

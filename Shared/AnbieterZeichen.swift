import SwiftUI

// Das Zeichen vor einem Anbieternamen — und das Licht darauf.
//
// **Warum ein eigenes Zeichen und nicht das echte Logo.** Vergleichbare Apps
// legen die Marken der Anbieter mit ins Bundle. Das ist bequem und ein
// vermeidbares Risiko: Diese App steht in keiner Verbindung zu Anthropic,
// OpenAI oder Moonshot, und fremde Bildmarken in einer nicht verbundenen App
// sind genau die Art Detail, an der eine Prüfung hängenbleibt. Ein Buchstabe in
// der Farbe des Anbieters trägt dieselbe Information — welche Zeile zu wem
// gehört — und gehört uns.
//
// **Warum ein Buchstabe und keine Form.** Auf 17 Punkten in einer
// Widget-Zeile ist ein Monogramm auf einen Blick eindeutig; abstrakte Formen
// muss man erst lernen. Und iOS 26 rechnet Widgets im getönten Modus auf eine
// einzige Farbe herunter — der Buchstabe überlebt das als Silhouette, ein
// feiner Bogen nicht.

/// Ein farbiges Feld mit dem Anfangsbuchstaben des Dienstes.
struct AnbieterZeichen: View {

    let name: String
    let anbieter: Theme.Provider
    var groesse: CGFloat = 20
    /// Im getönten Modus (Sperrbildschirm) fällt das Feld weg — dort gäbe es
    /// nur eine graue Fläche mit einem grauen Buchstaben darin.
    var einfarbig = false

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Theme.palette(scheme)
        let form = RoundedRectangle(cornerRadius: groesse * 0.3, style: .continuous)

        Text(Self.buchstabe(fuer: name))
            .font(.system(size: groesse * 0.58, weight: .semibold, design: .rounded))
            .foregroundStyle(einfarbig ? Color.primary : palette.aufAnbieter)
            .frame(width: groesse, height: groesse)
            .background {
                if !einfarbig {
                    form.fill(palette.color(for: anbieter))
                        .overlay { Glanz().clipShape(form) }
                }
            }
            // Der Name steht daneben — das Zeichen wiederholt ihn nur.
            .accessibilityHidden(true)
    }

    /// Der Buchstabe zum Dienst.
    ///
    /// Aus dem **Namen**, nicht aus dem Anbieter: Claude und die
    /// Anthropic-Schnittstelle teilen sich einen Anbieter und damit eine Farbe
    /// — zwei Zugänge zum selben Haus. Unterscheiden muss sie trotzdem etwas,
    /// und das ist hier das C gegen das A.
    static func buchstabe(fuer name: String) -> String {
        // Reihenfolge egal, die Präfixe überschneiden sich nicht: «ChatGPT»
        // beginnt nicht mit «Claude».
        switch true {
        case name.hasPrefix("Claude"):    return "C"
        case name.hasPrefix("ChatGPT"):   return "G"
        case name.hasPrefix("OpenAI"):    return "O"
        case name.hasPrefix("Anthropic"): return "A"
        case name.hasPrefix("Kimi"):      return "K"
        default: return name.first.map { String($0).uppercased() } ?? "·"
        }
    }
}

/// Das Lichtband über einer farbigen Fläche.
///
/// Zwei Lagen: ein weiches Licht von oben, das der Fläche Tiefe gibt, und ein
/// schmales Band quer darüber, das sie wie Glas aussehen lässt. Beides sind
/// Verläufe ohne Unschärfe — die kostet auf einer Widget-Kachel mehr, als sie
/// einbringt.
///
/// **Was der Glanz nicht darf:** Er liegt nie unter Text, der gelesen werden
/// muss, und er verändert nie eine Aussage. Die Prozentzahl steht als Zahl
/// daneben, der Balken trägt seine Schwellenmarken — daran ändert Licht nichts.
struct Glanz: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.30), location: 0),
            .init(color: .white.opacity(0.04), location: 0.55),
            .init(color: .clear, location: 1)
        ], startPoint: .top, endPoint: .bottom)
        .overlay {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.28),
                .init(color: .white.opacity(0.42), location: 0.44),
                .init(color: .clear, location: 0.60)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Zeichen") {
    HStack(spacing: 10) {
        AnbieterZeichen(name: "Claude", anbieter: .claude, groesse: 28)
        AnbieterZeichen(name: "ChatGPT", anbieter: .chatGPT, groesse: 28)
        AnbieterZeichen(name: "OpenAI-API", anbieter: .openAI, groesse: 28)
        AnbieterZeichen(name: "Anthropic-API", anbieter: .claude, groesse: 28)
        AnbieterZeichen(name: "Kimi K3", anbieter: .kimi, groesse: 28)
    }
    .padding()
    .background(Theme.dark.background)
}

import SwiftUI
import WidgetKit

// Die Komplikation — auf der Uhr das eigentliche Produkt.
//
// Die App ist der Weg ins Detail; gelesen wird das Zifferblatt. Deshalb steht
// hier dieselbe Auskunft in vier Zuschnitten und nicht eine Kurzfassung der
// App.
//
// **Der getönte Modus ist hier die Regel, nicht die Ausnahme.** Die meisten
// Zifferblätter rechnen Komplikationen auf eine einzige Farbe herunter. Genau
// dafür trägt jede Warnstufe in `LimitLevel` ein eigenes *Zeichen* — Dreieck
// gegen Achteck —, das auch in Graustufen unterscheidbar bleibt. Was für den
// getönten Sperrbildschirm auf dem iPhone gebaut wurde, trägt hier ohne Zutun.

@main
struct UhrKomplikationBuendel: WidgetBundle {
    var body: some Widget { UhrKomplikation() }
}


struct UhrAnbieter: TimelineProvider {

    func placeholder(in context: Context) -> UhrEintrag { .beispiel }

    func getSnapshot(in context: Context, completion: @escaping (UhrEintrag) -> Void) {
        completion(context.isPreview ? .beispiel : eintrag())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UhrEintrag>) -> Void) {
        // Keine gerechnete Zeitachse: Die Zahlen ändern sich, wenn das iPhone
        // etwas schickt, nicht mit der Uhr. `.never` und ein Anstoss aus der
        // Brücke ist ehrlicher als ein Takt, der Neuladungen verbraucht, um
        // dieselbe Zahl noch einmal hinzuschreiben.
        completion(Timeline(entries: [eintrag()], policy: .never))
    }

    private func eintrag() -> UhrEintrag {
        let zustand = WidgetZustand.lies()
        return UhrEintrag(date: .now, urteil: Urteil.aus(zustand), stand: zustand?.erhoben)
    }
}

struct UhrKomplikation: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AICockpitUhr", provider: UhrAnbieter()) { eintrag in
            KomplikationsAnsicht(eintrag: eintrag)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("AI Cockpit")
        .description("Wie voll dein drängendstes Fenster ist.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner,
                            .accessoryRectangular, .accessoryInline])
    }
}

struct KomplikationsAnsicht: View {
    let eintrag: UhrEintrag
    @Environment(\.widgetFamily) private var familie

    var body: some View {
        switch familie {
        case .accessoryInline:      EinzeiligeAnsicht(eintrag: eintrag)
        case .accessoryRectangular: RechteckigeUhrAnsicht(eintrag: eintrag)
        case .accessoryCorner:      EckAnsicht(eintrag: eintrag)
        default:                    RundeUhrAnsicht(eintrag: eintrag)
        }
    }
}

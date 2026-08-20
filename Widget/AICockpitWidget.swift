import WidgetKit
import SwiftUI

/// Der Einstiegspunkt der Widget-Erweiterung.
///
/// Noch ein Gerüst: Es beweist, dass Ziel, Entitlements und App Group
/// zusammenpassen. Die Darstellungen — Ring, Balken, Sperrbildschirm — kommen
/// in Etappe E3.
@main
struct AICockpitWidgetBuendel: WidgetBundle {
    var body: some Widget { UeberblickWidget() }
}

struct UeberblickEintrag: TimelineEntry {
    let date: Date
    /// Wann die Zahlen erhoben wurden — nicht, wann dieser Eintrag entstand.
    /// Das Widget zeigt beides nie als dasselbe an.
    let stand: Date?
}

struct UeberblickAnbieter: TimelineProvider {
    func placeholder(in context: Context) -> UeberblickEintrag {
        UeberblickEintrag(date: .now, stand: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (UeberblickEintrag) -> Void) {
        completion(UeberblickEintrag(date: .now, stand: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UeberblickEintrag>) -> Void) {
        // Fünfzehn Minuten ist ein Wunsch, keine Zusage: Das System vergibt
        // rund 40 bis 70 Neuladungen am Tag und verteilt sie nach Sichtbarkeit.
        // Deshalb steht auf dem Widget immer, wie alt die Zahlen sind.
        let naechste = Date.now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: [UeberblickEintrag(date: .now, stand: nil)],
                            policy: .after(naechste)))
    }
}

struct UeberblickWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AICockpitUeberblick", provider: UeberblickAnbieter()) { eintrag in
            UeberblickAnsicht(eintrag: eintrag)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("AI Cockpit")
        .description("Die Auslastung auf einen Blick.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        // Auf CarPlay und visionOS landet ein Widget sonst automatisch — in
        // einem Layout, das nie jemand geprüft hat.
        .disfavoredLocations([.standBy], for: [.systemMedium])
    }
}

struct UeberblickAnsicht: View {
    let eintrag: UeberblickEintrag

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AI Cockpit").font(.caption.weight(.medium))
            Text(eintrag.stand.map { $0.formatted(date: .omitted, time: .shortened) } ?? "noch keine Daten")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

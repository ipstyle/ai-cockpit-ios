import SwiftUI

// Die Seite, auf der die Erlaubnis tatsächlich entsteht.
//
// Der Schalter ist hier mehr als eine Einstellung: Er ist der Moment, in dem
// gefragt wird. Wer ihn umlegt, hat gerade gelesen, was gemeldet wird — das ist
// der einzige Zeitpunkt, an dem die Systemfrage beantwortbar ist. Beim ersten
// Start wäre sie es nicht, und ein Nein von damals liesse sich nie mehr
// zurücknehmen.
//
// Deshalb steht hier auch der andere Fall: Wurde abgelehnt, zeigt die Seite
// **keinen** Schalter. Ein Schalter, der sich umlegen lässt und nichts bewirkt,
// ist eine Lüge — an seiner Stelle steht, was los ist und wo es sich beheben
// lässt.

struct MitteilungenSeite: View {
    @Bindable var vorgaben: MitteilungenVorgaben

    @State private var erlaubnis = MitteilungenErlaubnis()
    @Environment(\.scenePhase) private var phase

    var body: some View {
        EinstellungsForm(titel: String(localized: "Mitteilungen")) {
            if erlaubnis.zustand == .abgelehnt {
                verweigert
            } else {
                schalter
            }

            Section {
                ZustandsZeile(text: String(localized: "Die Hinweise entstehen auf diesem Gerät. Es gibt keinen Server, der mitliest, und nichts wird versendet."),
                              symbol: "iphone")
            }
        }
        .task { await erlaubnis.lade() }
        // Wer in den Systemeinstellungen etwas umstellt, kommt hierher zurück —
        // und soll nicht den Stand von vorhin sehen.
        .onChange(of: phase) { _, neu in
            guard neu == .active else { return }
            Task { await erlaubnis.lade() }
        }
    }

    // MARK: - Die zwei Schalter

    private var schalter: some View {
        Section {
            Toggle(isOn: $vorgaben.beiLimit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wenn ein Limit erreicht wird")
                    Text("Bei der Warn- und bei der kritischen Schwelle — einmal je Überschreitung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .onChange(of: vorgaben.beiLimit) { _, an in
                pruefeErlaubnis(an) { vorgaben.beiLimit = false }
            }

            Toggle(isOn: $vorgaben.beiNeuemFenster) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wenn ein neues Fünf-Stunden-Fenster beginnt")
                    Text("Kommt zum Zeitpunkt der Zurücksetzung, auch bei geschlossener App.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            .onChange(of: vorgaben.beiNeuemFenster) { _, an in
                pruefeErlaubnis(an) { vorgaben.beiNeuemFenster = false }
            }
        } header: {
            Text("Hinweise")
        } footer: {
            Text("Beide Hinweise sind einzeln abschaltbar und stehen zu Beginn auf «aus» — beim ersten Einschalten fragt iOS um Erlaubnis. Die Schwellen selbst stehen unter «Schwellenwerte».")
        }
    }

    // MARK: - Abgelehnt

    /// Kein Schalter, sondern der Weg zurück.
    ///
    /// iOS stellt den Dialog genau einmal. Ab hier führt der einzige Weg über
    /// die Systemeinstellungen — und weil das niemand von selbst findet, steht
    /// der Knopf dorthin gleich daneben.
    private var verweigert: some View {
        Section {
            ZustandsZeile(text: String(localized: "Mitteilungen sind für AI Cockpit im System ausgeschaltet. Solange das so ist, kommt kein Hinweis an — auch nicht, wenn hier etwas eingeschaltet wäre."),
                          symbol: "bell.slash",
                          farbe: .secondary)
            Button {
                MitteilungenErlaubnis.oeffneSystemeinstellungen()
            } label: {
                Label("Systemeinstellungen öffnen", systemImage: "arrow.up.forward.app")
            }
            .frame(minHeight: 44)
        } header: {
            Text("Hinweise")
        } footer: {
            Text("Unter «Mitteilungen» ist AI Cockpit dort wieder freizugeben. Danach genügt es, hierher zurückzukommen.")
        }
    }

    // MARK: - Erlaubnis

    /// Fragt beim Einschalten — und stellt den Schalter zurück, wenn es beim
    /// Nein bleibt.
    ///
    /// Beim Ausschalten des letzten Hinweises werden die Vormerkungen
    /// abgeräumt: Eine für heute Nachmittag eingeplante Meldung käme sonst
    /// trotzdem, und niemand verzeiht einen Hinweis, den er abbestellt hat.
    private func pruefeErlaubnis(_ an: Bool, zuruecksetzen: @escaping () -> Void) {
        guard an else {
            if vorgaben.allesAus { Mitteilungen.geteilt.entferneVormerkungen() }
            return
        }
        Task {
            let ja = await erlaubnis.frage()
            if !ja { zuruecksetzen() }
        }
    }
}

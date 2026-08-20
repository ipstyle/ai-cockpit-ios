# Kartenaufbau — die Oberfläche der iOS-Fassung

Vier Dateien, alle in `App/Views/`, alle gegen `AgentDeckCore` programmiert:
`Theme.swift`, `CardKit.swift`, `Ring.swift`, `CardsView.swift`.

Ziel: Sie soll aussehen wie die Mac-App und sich bedienen wie eine iOS-App.
Was davon woher kommt, steht unten — und ebenso, was noch fehlt.

---

## 1 Was 1:1 aus der Mac-Fassung stammt

| Sache | Quelle | Bemerkung |
|---|---|---|
| Palette dunkel und hell, alle 26 Farbwerte | `AgentDeck/Views/Theme.swift:56-89` | Zahlenwerte unverändert übernommen |
| `Theme.ago` / `Theme.absolute` samt der zwei festen `DateFormatter` | `Theme.swift:120-151` | unverändert |
| `Format.compact` / `Format.money` samt Formatierer-Zwischenspeicher | `AgentDeck/Views/Format.swift` | unverändert |
| Linke Akzentkante: 3 pt breit, `RoundedRectangle(cornerRadius: 2)`, `.padding(.vertical, 8)` | `CardKit.swift:35-37` | unverändert |
| Kartenradius 9, Rahmen `strokeBorder` 0.5 pt in `cardBorder` | `CardKit.swift:33-34` | unverändert |
| Titel in Anbieterfarbe, `.title3.weight(.semibold)` | `CardKit.swift:50` | unverändert |
| Badge: `.caption2.weight(.medium)` auf `accent.opacity(0.22)` in einer `Capsule` | `CardKit.swift:51-57` | Innenabstand vertikal 1 → 2 |
| Aufklapp-Animation `.snappy(duration: 0.18)` | `CardKit.swift:38` | unverändert |
| `TapOrButton` — Knopf nur, wenn es etwas zu drücken gibt | `CardKit.swift:98-109` | unverändert, samt Begründung |
| Ampellogik: rot ab kritisch, orange ab Warnung, sonst Akzent; 90 % / 75 % | `CardKit.swift:179-183`, `AppSettings.swift` | in `LimitThresholds`/`LimitLevel` gefasst |
| Zeilenaufbau Titel / Prozent / Balken / Zurücksetzung / Hochrechnung | `CardKit.swift:127-165` | Reihenfolge unverändert |
| `forecastText` inklusive der 0.05-Schwelle und der drei Satzvarianten | `CardKit.swift:169-177` | unverändert |
| Ring: Spurring in Sekundärfarbe mit 25 % Deckkraft, Füllbogen ab 12 Uhr im Uhrzeigersinn, runde Enden, Innenquadrat `/1.414` | `MenuBarIconRenderer.swift:324-374` | Masse in Anteile umgerechnet |
| Kopfzeile «AI Cockpit» + «Aktualisiert vor …», Zehnsekundentakt | `PopoverView.swift:68-98`, `:328-333` | unverändert |
| Kennungen der eingeklappten Karten als Komma-String über `CardLayout` | `AgentDeckCore/CardLayout.swift` | Kernfunktion, nicht nachgebaut |

### Farbwerte — nachgerechnet

Alle im Auftrag genannten Hexwerte stimmen mit `Theme.swift:56-89` überein,
**mit einer Ausnahme**:

- ChatGPT dunkel ist `Color(red: 0.29, green: 0.78, blue: 0.64)`.
  0.78 × 255 = 198.9 → 199 → `C7`. Der Wert ist also **#4AC7A3**, im Auftrag
  stand #4ACAA3 (das wären 0.792). Ein Unterschied von einem Schritt in Grün,
  mit blossem Auge nicht zu sehen — aber übernommen ist der Originalwert
  0.29/0.78/0.64, nicht der Hexwert aus dem Auftrag.

Alle übrigen 25 Werte prüfen sich sauber durch, dunkel wie hell.
Übernommen sind durchweg die RGB-Werte in 0–1 aus dem Original, nicht die
Hexwerte — so kann keine Rundung dazwischenkommen.

---

## 2 Was bewusst anders ist

### Weil iOS kein AppKit hat

- **Kein `NSApp.effectiveAppearance`.** Auf dem Mac ist `Theme.background`
  ein statischer Getter, der bei jedem Zugriff die Benutzervorgaben liest.
  Das geht hier aus zwei Gründen nicht: Ein Widget hat kein `NSApp`, und —
  wichtiger — ein statischer Getter, der still seine Farbe wechselt, ist für
  SwiftUI unsichtbar. Es gäbe kein Neuzeichnen, weil nichts beobachtbar war.
  Deshalb ist die Palette hier ein **Wert**: `Theme.palette(colorScheme)`,
  und jede Ansicht liest `@Environment(\.colorScheme)`.
- **`AppAppearance.system` gibt `nil` zurück** statt zu fragen, wie das System
  gerade steht. `preferredColorScheme(nil)` heisst: nichts vorgeben — dann
  wirkt ein Wechsel im Kontrollzentrum ohne Zutun der App. Der Rohwert
  («dark»/«light»/«system») ist buchstabengleich zur Mac-Fassung geblieben,
  damit ein späterer Abgleich über iCloud nicht an einem Rohwert scheitert.

### Weil ein Finger kein Zeiger ist

- **Innenabstand 14 statt 10** in der Karte.
- **Kopfzeile mindestens 44 pt hoch**, mit `.contentShape(Rectangle())` — auch
  wenn nur «Kimi» darin steht. Dasselbe für die zwei Knöpfe im Kopf der Liste
  und für den Knopf in `StatusNote`.
- **Eigener Balken** (`UsageBar`, 6 pt, `Capsule`) statt
  `ProgressView(.small)`: Der iOS-Fortschrittsbalken lässt sich in der Höhe
  nicht setzen, ist rund drei Punkte dünn und bringt einen Rand mit, der auf
  einer Karte stört.
- **Kopfzeile der Liste steht fest** über dem Scrollbereich statt mitzuscrollen.
  Der Aktualisieren-Knopf ist das, was man am häufigsten drückt; der
  Zeitstempel ist das, was man am häufigsten liest. Zusätzlich `.refreshable`.
- **Eine Spalte bis 700 pt Breite, darüber zwei.** Es ist eine Anordnung mit
  einer Zahl darin, kein zweites Layout und keine `UIDevice`-Abfrage — ein
  iPad im Splitview ist mal 320 und mal 1100 Punkte breit, und nach dem Gerät
  zu fragen beantwortet die falsche Frage. `GridItem(.adaptive(...))` wurde
  verworfen: Damit ergäbe ein iPad 11" quer drei Spalten und hoch eine, je
  nach Mindestbreite — die Schwelle ist die ehrlichere Steuerung.

### Farbe ist nie der einzige Träger

Das ist die Regel, die alles andere überschreibt, und sie kostet an fünf
Stellen etwas:

1. **Die Prozentzahl steht immer als Text neben ihrem Balken** — in
   `LimitRow.kopf`, `monospacedDigit`, nie ausgeblendet.
2. **Jede Warnstufe hat ein eigenes Zeichen**, und zwar zwei verschiedene
   Formen: Warnung = Dreieck (`exclamationmark.triangle.fill`), kritisch =
   Achteck (`exclamationmark.octagon.fill`). Dreieck und Achteck unterscheiden
   sich auch in Graustufen; zweimal dasselbe Zeichen in Orange und Rot täte
   das nicht.
3. **Der Balken trägt Marken an Warn- und Alarmschwelle** (`UsageBar`, ein
   Punkt breit). Damit sagt er ohne jede Farbe, wo «zu viel» anfängt.
4. **Die eingeklappte Kurzfassung** bekommt bei `warning == true` ein
   Warndreieck vor den Text — auf dem Mac färbt sie sich nur orange.
5. **Der Ring** trägt die Zahl in der Mitte, sobald das Innenquadrat 12 Punkte
   erreicht, und das Warnzeichen aussen oben rechts. Bleibt für die Zahl kein
   Platz (Widget bei 20 pt), steht sie im `accessibilityValue`.

Hintergrund: Unter iOS 26 tönt der Homescreen Widgets ein und reduziert sie
auf eine einzige Farbe. Ein Balken, dessen Aussage in Rot steckt, ist dort ein
grauer Balken.

### Dynamic Type

- Kein fest verdrahtetes `.font(.system(size:))` für Fliesstext — durchweg
  `.title2`, `.title3`, `.callout`, `.caption`, `.caption2`. Zahlen sind
  `monospacedDigit()`, was den semantischen Stil nicht antastet.
- Bei `dynamicTypeSize.isAccessibilitySize` wechseln **drei** Zeilen per
  `AnyLayout` von neben- auf untereinander: der Kartenkopf (Titel ↔
  Kurzfassung), der Kopf der Limit-Zeile (Titel ↔ Prozent) und `MoneyRow`.
  Nebeneinander bliebe der Kurzfassung sonst eine Spalte von zwei Zentimetern.
- Die Zeile «Zurücksetzung … · 16:40» ist **ein** `Text` mit Interpolation
  statt drei nebeneinander. So bricht sie um, statt den Trenner allein in die
  nächste Zeile zu schieben.
- Alles, was umbrechen darf, hat `fixedSize(horizontal: false, vertical: true)`;
  `lineLimit(1)` steht nur dort, wo Fremdtext aus einer Netzantwort kommt —
  und auch dort wird es bei Accessibility-Graden auf 3 bzw. `nil` gelockert.
- **Eine bewusste Ausnahme:** Die Ziffer in der Mitte des Rings hat eine
  gerechnete Schriftgrösse (`clear * 0.62`). Sie ist Teil einer Zeichnung und
  muss sich mit ihr skalieren; ein semantischer Stil würde den Ring sprengen.
  Abgesichert ist sie mit `minimumScaleFactor(0.5)`, und vorgelesen wird
  ohnehin der `accessibilityValue` des Rings.

### Kleinigkeiten, die keine sind

- **`Format.percent` ist gegen NaN abgesichert und gedeckelt.** Die Mac-Fassung
  rechnet `Int(value.rounded())` — der Wert kommt aus einer Netzantwort, und
  `Int(Double.nan)` beendet das Programm. Ein Prozentwert ist es nicht wert,
  eine App abzuschiessen. **Das gehört auch in der Mac-Fassung nachgezogen.**
- **Warn- und Alarmfarbe laufen über die Palette** (`palette.warning` /
  `palette.critical`) statt an jeder Fundstelle `.orange` / `.red` zu
  schreiben. Die Werte sind unverändert die Systemfarben; siehe «Offen».
- **Der Ring hat den Winkelsinn gedreht.** AppKit rechnet mit y nach oben und
  braucht dort `clockwise: true`; SwiftUI rechnet mit y nach unten, und dort
  ergibt `clockwise: false` dieselbe Richtung. Wer das verwechselt, bekommt
  einen Ring, der rückwärts läuft, und merkt es erst bei Werten über 50 %.

---

## 3 Typen, die es im Kern nicht gibt

Nichts davon wurde im Kern angelegt — hier stehen die ansichtseigenen
Ersatzstücke und das, was stattdessen nötig gewesen wäre.

| Fehlt im Kern | Behelf hier | Was es bräuchte |
|---|---|---|
| `AppSettings` (liegt im Mac-Ziel, nicht im Kern) | `LimitThresholds` in `Theme.swift`, Vorgaben 75 / 90 wie dort | Die Einstellungen gehören in den Kern oder in eine iOS-eigene Fassung; jede Ansicht reicht die Schwellen bis dahin durch |
| `Format` (liegt im Mac-Ziel) | `Format` in `Theme.swift`, Code identisch | In den Kern, sonst laufen die Nachkommastellen auseinander |
| `AppStore` (Mac-Ziel, ~40 Eigenschaften, Netzabruf, Schlüsselbund) | `CockpitCard` / `CockpitLimit` / `CockpitMoney` in `CardsView.swift` | Ein iOS-Modell, das die Karten füllt — die Ansicht kennt nur diese drei Strukturen |
| `AppStore.KeyState`, `SourceHealth`, `ErrorNote` | `CardStatus` (`loading` / `missing` / `failed`) + `StatusNote` | `SourceHealth` liegt unter `AgentDeck/Services/`; die «n Fehlversuche in Folge · wartet noch …»-Zeile fehlt deshalb hier |
| `Sparkline` | — | Bewusst weggelassen, siehe «Offen» |
| `ContentHeightKey` | — | Auf iOS gegenstandslos, das Fenster hat die Grösse des Bildschirms |

Benutzt aus dem Kern werden: `LimitWindow`, `Forecast`, `CardLayout.Card`,
`CardLayout.parse/toggling`. Keine Feldnamen erfunden — alles gegen
`Models.swift`, `Forecast.swift` und `CardLayout.swift` gelesen.

---

## 4 Offen

**Wichtig zuerst:**

1. **Der Ring liegt im falschen Ziel.** `project.yml` gibt dem Widget-Ziel nur
   `Widget/` und `Shared/` als Quellen — `App/Views/Ring.swift` und
   `App/Views/Theme.swift` sind dort **nicht** sichtbar. Damit derselbe Ring im
   Widget landen kann (der Auftrag nennt 20 bis 120 pt), müssen beide Dateien
   nach `Shared/` wandern oder das Widget-Ziel muss sie einzeln aufnehmen.
   Solange das nicht passiert, gibt es zwei Ringe, und der zweite altert.
2. **Es gibt keine Datenquelle.** `CardsView` nimmt fertige `CockpitCard`
   entgegen. Wer sie baut, existiert noch nicht. `Shared/MacBruecke.swift`
   liefert `MacZustand.Fenster` (`name`, `verbrauchtProzent`,
   `zuruecksetzung`) — daraus lässt sich ein `LimitWindow` bauen, aber **kein**
   `Forecast`: Der bräuchte `[UsageSample]`, und der Verlauf liegt auf dem Mac.
   Entweder rechnet die Mac-Seite die Hochrechnung mit und schickt sie mit,
   oder die Hochrechnungszeile bleibt auf dem iPhone leer.
3. **Typgeprüft, aber nicht gebaut.** Ein Xcode-Projekt gibt es noch nicht.
   Geprüft wurde stattdessen so: die vier Dateien zusammen mit Kopien von
   `Models.swift`, `Forecast.swift`, `CardLayout.swift` und `UsageHistory.swift`
   (die vier Kerndateien, die hier gebraucht werden), `import AgentDeckCore`
   herausgenommen, dann

   ```
   xcrun swiftc -typecheck -sdk <iPhoneSimulator26.5.sdk> \
       -target arm64-apple-ios26.0-simulator -swift-version 6 *.swift
   ```

   Läuft ohne Fehler und ohne Warnung durch, Swift-6-Modus, also mit
   vollständiger Nebenläufigkeitsprüfung — das ist, was `project.yml` verlangt.
   Was das **nicht** prüft: ob die Anordnung auf einem echten Gerät hält, ob
   die Kopfzeile bei `AX5` umbricht wie gedacht, und ob der Ring bei 20 Punkten
   noch etwas taugt. Das braucht den Simulator.

**Danach:**

4. **Warnfarbe im hellen Modus.** `.orange` auf dem Beige `#ECE1CA` ist
   kontrastschwach (rund 2:1). Weil die Farbe hier nie allein trägt, ist es
   kein Fehler, aber ein nachgedunkeltes Orange wäre besser — es steht als
   `palette.warning` an genau einer Stelle. Zu klären: ob die Mac-Fassung
   mitzieht, sonst laufen die beiden auseinander.
5. **Sparklines** (`Sparkline.swift` auf dem Mac) sind nicht portiert. Sie
   brauchen `[UsageSample]`, siehe Punkt 2.
6. **Die Sitzungskarte** hat noch keinen Körper. `SessionActivity` ist im Kern
   vorhanden, aber `SessionRow.swift` der Mac-Fassung ist ein eigenes Stück
   Arbeit — mit Subagenten, Kontextbalken und Zustandsanzeige.
7. **Kennzahlenleiste** (`keyFigureBar`) ist nicht portiert. Auf einem iPhone
   passen acht Kacheln nicht nebeneinander; die Frage, was daraus wird —
   waagrecht scrollend, gekürzt auf drei, oder ersetzt durch Ringe —, ist eine
   Entwurfsentscheidung und keine Übersetzung.
8. **Fusszeile** (Anmelden/Abmelden, Nutzungsseite, Beenden) fehlt. «Beenden»
   entfällt auf iOS ohnehin; der Rest gehört in die Einstellungen.
9. **Lokalisierung.** Die Texte stehen als `String(localized:)` da, wie auf dem
   Mac. Ein `.xcstrings` gibt es noch nicht.
10. **Anthropic-Karte** (`CardLayout.Card.anthropic`) ist im Beispiel nicht
    dabei — sie funktioniert wie die OpenAI-Karte über `money`, muss aber vom
    Modell gefüllt werden.

---

Stand: 20.08.2026

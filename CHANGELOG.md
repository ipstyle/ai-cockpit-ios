# Changelog

Alle nennenswerten Änderungen. Neueste Version zuoberst.

## [1.0.1] — 21.08.2026 (Build 8)

### Behoben
- **Herunterziehen brach die eigenen Abrufe ab.** Alle Quellen liefen in einer
  Aufgabengruppe, deren Wurzel der Task von SwiftUI war; verwarf SwiftUI ihn,
  brachen sie gemeinsam ab. Auf drei Karten stand danach «cancelled» mit einem
  Knopf «Erneut versuchen», obwohl kein Dienst gestört war. Jede Quelle läuft
  jetzt in einer eigenen Aufgabe, die der App gehört.
- **Ein Abbruch gilt nicht mehr als Fehler.** Wo Zahlen dastanden, bleiben sie
  stehen; nur wer noch nie welche hatte, bekommt einen Hinweis — und der ist
  ein Satz, kein Systemwort.
- **Kein Abruf ohne Obergrenze.** `timeoutInterval` misst nur die Pause
  zwischen zwei Lebenszeichen. Der Kostenabruf lief so 35 Minuten, hielt seine
  Quelle als «unterwegs» fest und sperrte damit den Aktualisieren-Knopf — dem
  Nutzer blieb nur das Herunterziehen, also genau der Weg, der brach.
- Der Hinweis auf der Datenschutzseite nannte das Zurücksetzen noch «auf der
  Über-Seite» und mit dem alten Namen.

### Geändert
- **Der Kostenabruf merkt sich, was er schon hat.** Vergangene Tage ändern sich
  nicht; nachgeholt wird nur, was seit dem letzten Mal dazugekommen ist.
- **Die Prozentzahl ist ruhig, bis es eng wird** — weiss statt durchgehend
  farbig, orange ab der Warnschwelle, rot ab der kritischen.
- **Jeder Dienst hat ein eigenes Zeichen**, ein Monogramm in seiner Farbe. Es
  überlebt die Eintönung, die iOS Widgets verpasst.
- **Widget-Zeilen trennen Beschriftung und Zahl** — «5H 63 %» statt einer
  Zeichenkette in einer Farbe. Auf der kleinen Kachel stehen die Werte unter
  dem Namen, sonst kürzt iOS die Ziffern weg.
- Balken und Zeichen tragen ein Glanzlicht.
- Die Zeile unter «AI Cockpit» ist weg. Sie sagte, was jede Kachel selbst
  trägt, nur ungenauer — und solange eine Quelle hing, log sie.

## [1.0] — eingereicht 21.08.2026, in Prüfung (Build 7)

Erste Fassung für iOS 26.

### Neu
- Fünf Karten: Claude, ChatGPT/Codex, OpenAI-API, Anthropic-API, Kimi.
- Widgets in fünf Grössen; sie zeigen alle eingeschalteten Quellen, je eine
  Zeile in der Farbe des Anbieters, mit Alter der Zahlen.
- Zwischenspeicher: App und Widget starten mit den zuletzt bekannten Zahlen
  statt leer.
- Demomodus mit vollständigem Zahlensatz ohne Anmeldung.
- Karten ausblenden und umsortieren.
- Zurücksetzen («Abmelden und alles löschen») direkt in den Einstellungen.

### Behoben
- ChatGPT-Anmeldung hing stumm: Der Rücksprungpfad ist je Dienst verschieden
  (Claude `/callback`, Codex `/auth/callback`) und war fest verdrahtet.
- Ausgeblendete Karten und neu eingegebene Schlüssel wirkten erst nach einem
  Neustart — eine globale Abrufsperre verschluckte den zweiten Lauf. Jetzt
  sperrt jede Quelle für sich.
- «Aktualisiert vor x» stand über Zahlen, die noch gar nie angekommen waren.
- Widget-Zeilen ohne Anbieter liehen sich die Akzentfarbe; Kimi erschien blau
  statt rosa, ChatGPT nicht grün.

### Geändert
- Kostenkarten ruhen 15 Minuten, bevor ein automatischer Durchgang sie erneut
  holt; der Knopf und das Ziehen holen weiterhin sofort.
- Der OpenAI-Abruf holt nur noch, was die Karte zeigt.
- Der Demomodus zeigt dasselbe Widget wie der Betrieb.

# Changelog

Alle nennenswerten Änderungen. Neueste Version zuoberst.

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

### Bekannt
- Der Hinweistext auf der Datenschutzseite in der App nennt das Zurücksetzen
  noch «auf der Über-Seite» und mit dem alten Namen. Der Knopf steht seit
  Build 4 in den Einstellungen selbst. Reine Textstelle, korrigiert in 1.0.1 —
  nicht mehr in Build 7, der bereits bei Apple liegt.

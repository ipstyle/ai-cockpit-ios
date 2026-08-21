# AI Cockpit Mobile

*[English](README.md)*

Alle KI-Nutzungslimits an einem Ort, auf dem iPhone oder iPad — Claude,
ChatGPT/Codex, die OpenAI- und die Anthropic-Schnittstelle und Kimi. Auf dem
Homescreen und dem Sperrbildschirm ebenso.

Das ist die iOS-Fassung von [AI Cockpit für macOS](https://apps.apple.com/app/id6802014255).
Sie ist **kostenlos**. Der Quellcode liegt offen, damit nachlesbar ist, was die
App mit Zugangsdaten tut — eine freie Lizenz ist das nicht, siehe [LICENSE](LICENSE).

> **Stand: 1.0.1 eingereicht, wartet auf die Prüfung durch Apple.** Sobald sie
> durch ist, bekommt der Abschnitt «Installation» den App-Store-Link.

## Voraussetzungen

- iPhone oder iPad, iOS 26 oder neuer.
- Eine universelle App — keine eigene iPad-Fassung.

## Was sie zeigt

| Karte | Inhalt | Braucht |
|---|---|---|
| Claude | Nutzungsfenster des Abos, Hochrechnung | Claude-Anmeldung |
| ChatGPT / Codex | Kontingente des ChatGPT-Abos | ChatGPT-Anmeldung |
| OpenAI-API | Kosten und Token je Modell | Admin-Schlüssel, freiwillig |
| Anthropic-API | Kosten über einen Admin-Schlüssel — etwas anderes als das Abo darüber | Admin-Schlüssel, freiwillig |
| Kimi | Kontostand und Kontingent | API-Schlüssel, freiwillig |

Jede Karte spricht direkt vom Gerät aus per HTTPS mit ihrem Dienst. Dazwischen
steht kein Server von uns, und ein Mac wird nicht gebraucht.

Karten, die man nicht braucht, lassen sich ausblenden, der Rest umsortieren —
ein Konto, das man nicht hat, soll keine Zeile auf dem Bildschirm kosten.

## Widgets

Das Widget zeigt **alle eingeschalteten Karten**, nicht nur einen Dienst: eine
Zeile je Quelle, in der Farbe des jeweiligen Anbieters, mit der Zahl, auf die
es ankommt, und ihrem Alter.

| Grösse | Was hineinpasst |
|---|---|
| Klein | Die dringendste Quelle als Ring |
| Mittel | Eine Zeile je aktiver Quelle |
| Gross | Je Quelle ein Block mit den Nutzungsfenstern als Balken |
| Sperrbildschirm, rund | Die dringendste Quelle als Ring |
| Sperrbildschirm, rechteckig | Die dringendste Quelle mit ihrer Zahl |

Das Widget zeigt weiter die zuletzt bekannten Zahlen und schreibt dazu, wie alt
sie sind, statt beim Abrufen leer zu werden. Die App macht es beim Kaltstart
genauso.

## Demomodus

Die App lässt sich in einen Demomodus schalten, der einen vollständigen Satz
plausibler Zahlen ohne jede Anmeldung zeigt. Es gibt ihn, damit man sieht, was
die App tut, bevor man ihr einen einzigen Zugang gibt — und damit für einen
Screenshot nie jemandes echte Ausgaben herhalten müssen.

## Keine Karte für Claude-Code-Sitzungen

Die macOS-Fassung hat eine sechste Karte mit den gerade laufenden
Claude-Code-Sitzungen. **Diese Fassung hat sie nicht**, und zwar bewusst: Diese
Sitzungen sind Dateien und ein Prozess auf einem Mac, es gibt keine Stelle, die
man danach fragen könnte. Eine Brücke über iCloud wäre machbar gewesen — für
**eine** Karte hätte sie die Mac-App iCloud-Rechte und damit eine neue
Prüfrunde bei Apple gekostet. Entschieden am 20.08.2026.

## Verhältnis zur macOS-Fassung

Diese Fassung teilt sich den Quellcode mit der kostenpflichtigen macOS-Fassung
(App-Store-ID 6802014255), wird aber separat vertrieben und gezählt, beginnend
bei 1.0. Ein Funktionsgleichstand wird nicht zugesichert — die Karten oben sind
der heutige Stand dieser Fassung. Verlaufskurven, Historie und die
Sitzungskarte bleiben auf dem Mac.

## Nicht verbunden mit den KI-Anbietern

AI Cockpit Mobile steht in keiner Verbindung zu Anthropic, OpenAI oder
Moonshot AI und wird von keinem der drei unterstützt oder bestätigt. Es ist
ein unabhängiger Client, der Nutzungszahlen aus den Konten liest, mit denen
sich der Nutzer selbst anmeldet; die oben genannten Produkt- und Firmennamen
dienen nur der Zuordnung, welche Karte zu welchem Dienst gehört.

## Installation

Noch nicht verfügbar — 1.0.1 liegt bei Apple zur Prüfung. Nach der
Veröffentlichung verlinkt dieser Abschnitt auf den App-Store-Eintrag.

## Datenschutz

Kein eigenes Konto, kein Tracking, keine Analyse, keine Werbung, keine
In-App-Käufe, kein Server. Zugangsdaten liegen im Schlüsselbund des Geräts.
Alle Netzwerkziele stehen in [PRIVACY.md](PRIVACY.md), die veröffentlichte
Fassung unter <https://ipstyle.github.io/ai-cockpit-ios/privacy.html>.

## Warum dieses Repo öffentlich ist, die App aber nicht quelloffen

Diese App liest Zugangsdaten aus und zeigt Verbrauchszahlen an. Wer so etwas
installiert, sollte nachlesen können, was damit geschieht — deshalb liegt der
Quellcode offen. **Quelloffen im Sinne einer freien Lizenz ist die App
trotzdem nicht**; was erlaubt ist, steht in [LICENSE](LICENSE).

## Bauen

**Dieses Repo allein lässt sich nicht bauen.** Der gemeinsame Kern
(`AgentDeckCore`) liegt im Projekt der macOS-Fassung und ist nicht Teil dieser
Veröffentlichung. `project.yml` bindet ihn über einen relativen Pfad ein. Ohne
ihn meldet Xcode ein fehlendes Paket — das ist kein Fehler, sondern Absicht.

## Lizenz

Kostenlos nutzbar, nicht quelloffen — siehe [LICENSE](LICENSE). © 2026 ipstyle

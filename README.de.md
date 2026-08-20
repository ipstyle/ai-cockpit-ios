# AI Cockpit Mobile

*[English](README.md)*

Alle KI-Nutzungslimits an einem Ort, auf dem iPhone oder iPad — Claude, die
OpenAI- und Anthropic-Schnittstellen, Kimi, ChatGPT/Codex und die laufenden
Claude-Code-Sitzungen.

Das ist die iOS-Fassung von [AI Cockpit für macOS](https://apps.apple.com/app/id6802014255).
Sie ist **kostenlos**, aber **nicht quelloffen**: Der Quellcode ist derselbe
wie bei der kostenpflichtigen macOS-Fassung und bleibt geschlossen.

> **Stand: in Entwicklung.** Es gibt noch nichts herunterzuladen.

## Voraussetzungen

- iPhone oder iPad, iOS 26 oder neuer.
- Eine universelle App — keine eigene iPad-Fassung.

## Was sie zeigt

| Karte | Inhalt | Braucht einen laufenden Mac |
|---|---|:---:|
| Claude | Nutzungsfenster des Abos, Hochrechnung | nein |
| OpenAI-API | Kosten und Token je Modell | nein |
| Anthropic-API | Kosten über einen Admin-Schlüssel — etwas anderes als das Abo darüber | nein |
| Kimi | Kontostand und Kontingent | nein |
| ChatGPT / Codex | Kontingente aus den Sitzungsprotokollen der Codex-CLI | **ja** |
| Sitzungen | Laufende Claude-Code-Sitzungen mit Tokenverbrauch | **ja** |

## Zwei Karten brauchen einen laufenden Mac

Die ersten vier Karten sprechen direkt vom Gerät aus per HTTPS mit dem
jeweiligen Dienst — ohne Mac. Bei den letzten beiden geht das nicht, aus einem
einfachen Grund: **Die Zahlen, die sie zeigen, gibt es nirgends ausser auf
einem Mac.**

- Das ChatGPT/Codex-Kontingent stammt aus Sitzungsprotokollen, die die
  Codex-CLI lokal auf dem Rechner ablegt, auf dem sie läuft. Dafür gibt es
  keine Schnittstelle — das Lesen der Dateien ist der einzige Weg an die
  Zahlen, auf dem Mac genauso wie auf iOS.
- Die Liste aktiver Claude-Code-Sitzungen bildet einen lokalen Prozess auf
  dem Mac ab. Es gibt sie nur, solange Claude Code dort tatsächlich läuft.

Beides liegt weder auf Apples Servern noch auf unseren, ein iPhone oder iPad
kommt also nicht direkt heran. Die macOS-Fassung von AI Cockpit liest diese
Daten bereits lokal und legt sie in der **privaten iCloud des Nutzers** ab.
AI Cockpit Mobile liest sie von dort zurück. Die Übertragung zwischen den
Geräten übernimmt Apples iCloud — kein Server von uns ist beteiligt, und ist
der Mac aus oder die macOS-App nicht offen, bleiben diese beiden Karten
schlicht leer.

## Verhältnis zur macOS-Fassung

Diese Fassung teilt sich den Quellcode mit der kostenpflichtigen macOS-Fassung
(App-Store-ID 6802014255), wird aber separat vertrieben und gezählt, beginnend
bei 1.0. Ein Funktionsgleichstand wird nicht zugesichert — die sechs Karten
oben sind der heutige Stand dieser Fassung.

## Nicht verbunden mit den KI-Anbietern

AI Cockpit Mobile steht in keiner Verbindung zu Anthropic, OpenAI oder
Moonshot AI und wird von keinem der drei unterstützt oder bestätigt. Es ist
ein unabhängiger Client, der Nutzungszahlen aus den Konten liest, mit denen
sich der Nutzer selbst anmeldet; die oben genannten Produkt- und Firmennamen
dienen nur der Zuordnung, welche Karte zu welchem Dienst gehört.

## Installation

Noch nicht verfügbar. Nach der Veröffentlichung verlinkt dieser Abschnitt auf
den App-Store-Eintrag.

## Datenschutz

Kein eigenes Konto, kein Tracking, keine Analyse, keine Werbung, keine
In-App-Käufe, kein Server. Zugangsdaten liegen im Schlüsselbund des Geräts.
Alle Netzwerkziele stehen in [PRIVACY.md](PRIVACY.md).

## Lizenz

Kostenlos nutzbar, nicht quelloffen — siehe [LICENSE](LICENSE). © 2026 ipstyle

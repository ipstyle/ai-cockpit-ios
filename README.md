# AI Cockpit Mobile

*[Deutsch](README.de.md)*

All your AI usage limits in one place, on your iPhone or iPad — Claude, the
OpenAI and Anthropic APIs, Kimi, ChatGPT/Codex, and your running Claude Code
sessions.

This is the iOS edition of [AI Cockpit for macOS](https://apps.apple.com/app/id6802014255).
It is **free**. It is **not** open source: the source code is shared with the
paid macOS edition and stays closed.

> **Status: in development.** Nothing is downloadable yet.

## Requirements

- iPhone or iPad, iOS 26 or later.
- One universal app — no separate iPad version.

## What it shows

| Card | What you get | Needs a running Mac |
|---|---|:---:|
| Claude | Usage windows of the subscription, forecast | no |
| OpenAI API | Cost and token usage per model | no |
| Anthropic API | Costs via an admin key — separate from the subscription above | no |
| Kimi | Balance and quota | no |
| ChatGPT / Codex | Quota windows from the Codex CLI's session logs | **yes** |
| Sessions | Claude Code sessions currently running, with token usage | **yes** |

## Two cards need a running Mac

The first four cards talk to the respective service directly from your device
over HTTPS — no Mac involved. The last two cannot work that way, for a simple
reason: **the data they show does not exist anywhere except on a Mac.**

- The ChatGPT/Codex quota comes from session log files that the Codex CLI
  writes locally on the machine it runs on. There is no API for it — reading
  the files is the only way to get the numbers, on macOS or on iOS.
- The list of active Claude Code sessions reflects a local process on the
  Mac. It only exists while Claude Code is actually running there.

Neither exists on Apple's servers or on ours, so an iPhone or iPad cannot
reach them directly. The macOS edition of AI Cockpit already reads this data
locally and writes it into **your own private iCloud storage**. AI Cockpit
Mobile reads it back from there. Apple's iCloud carries it between your
devices — no server of ours is involved, and if the Mac is off or the macOS
app isn't running, these two cards simply stay empty.

## Relationship to the macOS edition

This edition shares its source code with the paid macOS edition (App Store ID
6802014255) but is distributed and versioned separately, starting at 1.0.
Feature parity is not promised — the six cards above are what this edition
covers today.

## Not affiliated with the AI providers

AI Cockpit Mobile is not affiliated with, endorsed by, or otherwise connected
to Anthropic, OpenAI, or Moonshot AI. It is an independent client that reads
usage figures from the accounts you sign in with; the product and company
names above are used only to identify which services each card belongs to.

## Installation

Not yet available. Once published, this section will link to the App Store
listing.

## Privacy

No accounts of our own, no tracking, no analytics, no advertising, no
in-app purchases, no server. Credentials live in your device's keychain. See
[PRIVACY.md](PRIVACY.md) for every network destination.

## License

Free to use, not open source — see [LICENSE](LICENSE). © 2026 ipstyle

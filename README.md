# AI Cockpit Mobile

*[Deutsch](README.de.md)*

All your AI usage limits in one place, on your iPhone or iPad — Claude,
ChatGPT/Codex, the OpenAI and Anthropic APIs, and Kimi. On the Home Screen and
the Lock Screen, too.

This is the iOS edition of [AI Cockpit for macOS](https://apps.apple.com/app/id6802014255).
It is **free**. The source is in this repository so you can read what the app
does with your credentials — that is not the same as a free licence, see
[LICENSE](LICENSE).

> **Status: 1.0.1 submitted, waiting for Apple's review.** Once it is through,
> the Installation section below gets the App Store link.

## Requirements

- iPhone or iPad, iOS 26 or later.
- One universal app — no separate iPad version.

## What it shows

| Card | What you get | Needs |
|---|---|---|
| Claude | Usage windows of the subscription, forecast | Claude sign-in |
| ChatGPT / Codex | Quota windows of the ChatGPT subscription | ChatGPT sign-in |
| OpenAI API | Cost and token usage per model | Admin key, optional |
| Anthropic API | Costs via an admin key — separate from the subscription above | Admin key, optional |
| Kimi | Balance and quota | API key, optional |

Every card talks to its service directly from your device over HTTPS. There is
no server of ours in between, and no Mac is required.

Cards you don't use can be hidden, and the rest reordered — an account you
don't have should not cost you a row on the screen.

## Widgets

The widget shows **every card you have switched on**, not just one service:
one line per source, in that provider's colour, with the figure that matters
and how old it is.

| Size | What fits |
|---|---|
| Small | The most pressing source as a ring |
| Medium | One line per active source |
| Large | Per source a block with its usage windows as bars |
| Lock Screen, circular | The most pressing source as a ring |
| Lock Screen, rectangular | The most pressing source with its figure |

The widget keeps showing the last figures it has and marks how old they are,
rather than going blank while it fetches. The app does the same on a cold
start.

## Demo mode

The app can be switched into a demo mode that shows a complete set of
plausible figures without any sign-in. It exists so you can see what the app
does before handing it a single credential — and so a screenshot never has to
show anybody's real spending.

## No Claude Code sessions card

The macOS edition has a sixth card listing the Claude Code sessions currently
running. **This edition does not**, deliberately: those sessions are files and
a process on a Mac, with no endpoint to ask. Bridging them over iCloud was
possible, but for a single card it would have cost the macOS app iCloud
entitlements and a fresh review round at Apple. Decided against on 2026-08-20.

## Relationship to the macOS edition

This edition shares its source code with the paid macOS edition (App Store ID
6802014255) but is distributed and versioned separately, starting at 1.0.
Feature parity is not promised — the cards above are what this edition covers
today. Sparklines, history and the sessions card stay on the Mac.

## Not affiliated with the AI providers

AI Cockpit Mobile is not affiliated with, endorsed by, or otherwise connected
to Anthropic, OpenAI, or Moonshot AI. It is an independent client that reads
usage figures from the accounts you sign in with; the product and company
names above are used only to identify which services each card belongs to.

## Installation

Not yet available — 1.0.1 is with Apple for review. This section will link to
the App Store listing once it is published.

## Privacy

No accounts of our own, no tracking, no analytics, no advertising, no
in-app purchases, no server. Credentials live in your device's keychain. See
[PRIVACY.md](PRIVACY.md) for every network destination, or the published
policy at <https://ipstyle.github.io/ai-cockpit-ios/privacy.html>.

## Why this repository is public while the app is not open source

This app reads credentials and displays spending figures. Anyone installing
something like that should be able to read what happens to them — hence the
source. **That still does not make it open source** in the sense of a free
licence; what is permitted is in [LICENSE](LICENSE).

## Building

**This repository does not build on its own.** The shared core
(`AgentDeckCore`) lives in the macOS project and is not part of this
publication. `project.yml` references it over a relative path. Without it
Xcode reports a missing package — that is intent, not a defect.

## License

Free to use, not open source — see [LICENSE](LICENSE). © 2026 ipstyle

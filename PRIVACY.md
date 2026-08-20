# Privacy Policy — AI Cockpit Mobile

Last updated: 2026-08-20

## What is collected

**Nothing.** AI Cockpit Mobile has no account of its own, no analytics, no
tracking and no advertising. No usage data ever leaves your device except to
the services listed below, and only to show you figures you asked for.

## What stays on your device

| What | Where |
|---|---|
| Access tokens and API keys | The device keychain, per app |
| Settings | The app's local storage on the device |
| Cached usage figures | The app's local storage on the device |

## Network connections

AI Cockpit Mobile connects only to the services below, and only with the
credentials you entered yourself:

| Service | Purpose | Account needed |
|---|---|---|
| `claude.com`, `platform.claude.com` | Sign-in (OAuth) for the Claude subscription card | yes, Claude subscription |
| `api.anthropic.com` | Usage windows of the subscription; costs via an admin key | yes |
| `api.openai.com` | Cost and token usage per model | Admin key, optional |
| `api.moonshot.ai`, `api.kimi.com` | Balance and quota | API key, optional |
| iCloud (Apple) | Bridge from the macOS edition for the ChatGPT/Codex and Sessions cards | Apple ID, optional |

All connections use HTTPS.

## The iCloud bridge, in detail

Two cards — ChatGPT/Codex and the list of running Claude Code sessions — show
data that only exists on a Mac (local session logs and a local process; see
the README for why). The macOS edition of AI Cockpit reads this data locally
and writes it into **your own private iCloud storage**. AI Cockpit Mobile
reads it back from there.

This is not a server we operate. It is Apple's iCloud, scoped to your Apple
ID, the same way any app's iCloud data is private to you. We never see it,
store a copy of it, or have a way to access it. If iCloud is signed out, or
the Mac is off, or the macOS app isn't running, these two cards are simply
empty.

## No server of ours

AI Cockpit Mobile has no backend of its own. Every network connection above
goes directly from your device to the named third-party service or to your
own iCloud account — never through infrastructure we operate.

## Contact

Questions: open an issue at https://github.com/ipstyle/ai-cockpit-ios/issues

© 2026 ipstyle

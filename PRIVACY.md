# Privacy Policy — AI Cockpit Mobile

Last updated: 2026-08-21

The published version of this policy, and the one linked from the App Store
listing, is <https://ipstyle.github.io/ai-cockpit-ios/privacy.html>. This file
says the same thing.

## What is collected

**Nothing.** AI Cockpit Mobile has no account of its own, no analytics, no
tracking and no advertising. There is no server of ours that could receive
anything, and the app contains no third-party component for measurement,
advertising or crash reporting.

## What stays on your device

| What | Where |
|---|---|
| Access tokens and API keys | The device keychain, per app |
| Settings — appearance, thresholds, card order, alerts | The app's local storage |
| The figures fetched most recently, so the app and the widget can show them without asking again | The app's local storage |
| A note of which alerts have already been shown | The app's local storage |

None of it leaves the device.

The keychain entries are stored so that they stay readable **after the device's
first unlock** (`kSecAttrAccessibleAfterFirstUnlock`). That is what allows the
widget to refresh while the screen is locked; the stricter alternative would
leave the widget empty after every restart.

The app never sees your password. Sign-in happens on the provider's own page,
and the app receives only an access token.

## Network connections

AI Cockpit Mobile connects only to the services below, and only with the
credentials you entered yourself:

| Service | Purpose | Account needed |
|---|---|---|
| `claude.com`, `platform.claude.com` | Sign-in (OAuth) for the Claude subscription card | yes, Claude subscription |
| `api.anthropic.com` | Usage windows of the subscription; costs via an admin key | yes |
| `auth.openai.com` | Sign-in (OAuth) for ChatGPT | yes, ChatGPT subscription |
| `chatgpt.com` | Quota windows of the ChatGPT subscription | sign-in |
| `api.openai.com` | Cost and token usage per model | Admin key, optional |
| `api.moonshot.ai`, `api.moonshot.cn`, `api.kimi.com` | Balance and quota | API key, optional |

All connections use HTTPS. The app follows no redirects, stores no cookies and
keeps no web cache.

## No server of ours

AI Cockpit Mobile has no backend of its own. Every connection above goes
directly from your device to the named third-party service — never through
infrastructure we operate. Nothing is synced between devices, and there is no
iCloud component.

## Notifications

The app can point out that a limit has been reached or that a new window has
begun. These alerts are generated **on the device**; no server sends them. Each
can be switched off individually, and all of them start out off.

## Deleting everything

In Settings, **“Sign out and delete everything”** removes both sign-ins, every
stored key, all settings and the cached figures, including the state the widget
shows. Afterwards the app is as it was on first launch. Deleting the app
removes everything as well.

## Your rights

Since no data is collected, there is nothing held by this app's publisher to
disclose, correct or delete. For the data in your accounts at Claude, OpenAI,
Anthropic and Moonshot, those companies' own privacy policies apply.

## Contact

Questions: open an issue at https://github.com/ipstyle/ai-cockpit-ios/issues

© 2026 ipstyle

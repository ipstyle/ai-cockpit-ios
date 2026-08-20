# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Use GitHub's private reporting instead:
[**Report a vulnerability**](https://github.com/ipstyle/ai-cockpit-ios/security/advisories/new)

The report stays private between you and the maintainer until a fix is
published. No email address is needed on either side. Include what you did,
what happened, and what you expected.

Please do not run automated scans against the third-party services the app
talks to — they are not mine.

## What the app does with your credentials

Tokens and API keys go into the device keychain and are never written to disk
in clear text, never logged, and never transmitted anywhere except to the
service they belong to.

## Supported versions

The latest release is supported.

# Security policy

[Русский](SECURITY.md) · **English**

Soty is an end-to-end encrypted messenger. A flaw in the crypto, the envelope pipeline or the transport can expose message content or identity keys, so reports are taken seriously and handled privately until a fix ships.

## Supported versions

Only the latest release in [Releases](https://github.com/slavabars/soty/releases) is supported. Older builds are not patched. The in-app updater installs the latest signed APK.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Preferred: use GitHub private vulnerability reporting: <https://github.com/slavabars/soty-app/security/advisories/new>

Alternative: email **security@soty.su** with the details. If you want an encrypted channel, ask in the first message and we will exchange keys.

Please include:

- affected version/build (`X.Y.Z+N` from Settings) and platform;
- a description of the impact and the attacker model you assume;
- reproduction steps or a proof of concept;
- whether the issue is already public anywhere.

## What is in scope

- envelope format, signatures, encryption or key handling;
- identity claims, key substitution, MITM in any transport;
- replay, forgery, id collision, dedup bypass;
- untrusted-input handling: framing, JSON/msgpack parsing, size limits, DoS;
- the updater (checksum/signature checks, URL validation);
- relay isolation: one client reading another client's envelopes;
- anything that leaks plaintext, seeds or private keys.

## Out of scope

- a device that is already rooted/compromised, or an attacker with the unlocked screen and the app's own keys;
- relay operators learning metadata they inherently see (connection times, IPs, envelope sizes) — relays are untrusted by design and never see plaintext;
- denial of service against a relay you run yourself;
- social engineering, or a malicious build not signed by the official key.

## Response

- acknowledgement within 7 days;
- an initial assessment within 14 days;
- a fix and a release for confirmed issues as soon as practical;
- credit in the release notes unless you ask to stay anonymous.

Please give us a reasonable window to ship a fix before publishing details.

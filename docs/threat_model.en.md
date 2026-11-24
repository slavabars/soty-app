# Threat model

[Русский](threat_model.md) · **English**

This document describes what Soty protects, against whom, and what it explicitly does not protect. It is the public companion to the internal audit log, which stays private.

## Assets

- message content: text, voice notes, photos, files;
- identity keys: Ed25519 (signing) and X25519 (encryption);
- the local message database and media blobs;
- metadata: who talks to whom, when, and how much.

## Adversaries

1. **Remote peers on libp2p** — anyone can dial a device and send frames.
2. **Malicious mesh nodes** — BLE / Wi-Fi Direct neighbours can inject, drop, replay or reorder frames.
3. **On-path attackers** — can read, modify, drop and replay traffic.
4. **Untrusted relays** — store and forward opaque envelopes; may be curious, buggy or hostile.
5. **Anyone who finds a lost or stolen device** — without the app lock.

## Security goals

- **Confidentiality and authenticity end to end.** Only the intended recipient can decrypt; every accepted envelope is signed by its sender.
- **Key binding.** An Ed25519 identity signs its X25519 routing key, so a relay cannot advertise a victim's routing key under its own identity.
- **Replay tolerance without duplication.** A replayed envelope is rejected by id and never shown twice.
- **Bounded resource use.** Every frame, list, window and cache is capped before allocation, so a hostile peer cannot exhaust memory.
- **Isolation at the relay.** A relay only hands an envelope to a subscriber entitled to it.

## Non-goals

- **Metadata privacy from relays.** A relay sees connection times, IPs and envelope sizes. It never sees plaintext or keys. Use your own relay or the mesh if that matters.
- **Protection from a compromised device.** Root, a hostile OS, a keylogger or an unlocked screen with the app keys defeats any messenger.
- **Anonymity against a global network observer.** Soty hides content, not the fact that two addresses are talking.
- **Protection from unofficial builds.** Only the signed release is official; a rebuilt APK can contain anything.
- **Traffic-analysis resistance.** Padding is bounded, not constant-rate.

## Trust boundaries

| Boundary | Rule |
| --- | --- |
| Wire → parser | strict parsing, size caps, `FormatException` on malformed input |
| Parser → envelope | clock skew → signature verify → id check → dedup → decrypt |
| Device → relay | opaque envelopes only after a clean verify |
| Relay → client | only envelopes addressed to the subscriber's key |
| App → OS | seeds live in Android Keystore / iOS Keychain, not in SQLite |

## Cryptographic choices

- Ed25519 for identity and envelope signatures;
- X25519 + HKDF for key agreement;
- AES-256-GCM for payload confidentiality and integrity;
- SHA-256 for content ids and published release checksums.

Implementation status, residual risks and open questions are tracked in the private audit log; this file never lists exploitable details.

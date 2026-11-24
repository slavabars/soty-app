# Contributing to Soty

[Русский](CONTRIBUTING.md) · **English**

Thanks for taking the time to help. Soty is a security-sensitive, serverless messenger: correctness and hostile-input handling matter more than features.

## Before you start

- Read `docs/threat_model.md` before touching crypto, transports or parsing.
- For anything non-trivial, open an issue first so we agree on the approach.
- Security problems go to `SECURITY.md`, **never** to a public issue.

## Development

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

Drift and `json_serializable` models are generated:

```bash
dart run build_runner build
```

`lib/core/storage/database.g.dart` must be current in every commit.

## Rules

- **Test first.** A behaviour change without a test is incomplete. Cover the hostile path too: replay, bad signature, wrong key, oversize frame, clock skew, malformed deep link.
- **Limits live in `lib/core/security_limits.dart`.** Never hardcode a byte or item cap elsewhere.
- **Never log** seeds, plaintext, decrypted payloads or AEAD failures.
- **Keep the existing style.** The tree is not `dart format`-clean under the current SDK; do not reformat whole files.
- One logical change per pull request.
- Do not add analytics, telemetry or third-party trackers.
- Do not hard-wrap prose in docs, templates or commit messages: one paragraph or list item is one source line.

## Pull requests

- Describe what changed and why; link the issue.
- State what you verified (`flutter analyze`, `flutter test`, e2e if relevant).
- CI must be green. Nightly runs also execute on a schedule, so a flaky test will be noticed.
- By contributing you agree your work is licensed under AGPL-3.0 (see `LICENSE`).

## Commit messages

Short imperative subject, then a body explaining the why. Reference the test that covers the change.

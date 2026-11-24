## What changed

<!-- A short description and the reason for the change. Link the issue. -->

## Security impact

<!-- Does this touch parsing, crypto, limits, transports, storage or the updater? What is the hostile path and how is it covered? -->

## Verification

- [ ] `flutter analyze --no-pub` is clean
- [ ] `flutter test --no-pub` is green
- [ ] e2e run for transport / controller / UI changes (two AVDs)
- [ ] generated files are current (`dart run build_runner build`)

## Checklist

- [ ] One logical change
- [ ] Tests cover the happy and the hostile path
- [ ] No seeds, plaintext, keys or message content in logs
- [ ] No new unbounded allocation; limits live in `security_limits.dart`
- [ ] No analytics or third-party telemetry

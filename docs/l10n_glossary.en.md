# Localization glossary and pipeline

[Русский](l10n_glossary.md) · **English**

Every shipped locale is a separate resource under `lib/core/i18n/locales/`: `ru, zh, hi, es, fr, ar, bn, pt, id, de, it, tr, ja, ko, th, vi`. `soty_l10n.dart` keeps the lookup API (`SotyL10n.tr`, `forLocale`, plurals, `_unchangedKeys`) and includes the locale files with `part` directives.

## Rules

- The English key is the source string and the fallback. Never translate a key itself; translate its value.
- Every key must exist in every locale. `test/unit/l10n_keys_test.dart` fails the build otherwise, and `hasTranslation` is checked for each locale.
- Placeholders use `{name}` and must survive translation unchanged.
- Numeric strings may add plural forms: `'key|one|few|many|other'`; the `n` argument selects the category.
- A language that borrows a word unchanged (brand, "Emoji") must be listed in `_unchangedKeys`; do not silently fall back to English.
- Do not hard-wrap strings inside a sentence: the Dart formatter manages code, but the rendered text must not gain line breaks.
- Arabic is RTL: keep logical order in the text, no manual direction marks.

## Glossary

| English | Meaning |
| --- | --- |
| Soty | Product name, never translated |
| relay host / relay | Operator-run server that stores only encrypted envelopes |
| envelope | One encrypted wire frame (ciphertext + metadata) |
| safety number | Ed25519+X25519 fingerprint compared between contacts |
| identity | The device's Ed25519/X25519 keypair |
| backup | Encrypted identity + contacts + history file |
| mesh | Offline BLE/Wi-Fi Direct transport |
| peer | Another device/user in the address book |
| tracker | Relay capability that hands out peer bindings |

Translate "relay" as the network relay, not as a radio/TV relay. Keep "Soty", "Ed25519", "X25519", "AES-256-GCM", "Argon2id", "QR" and "GitHub" unchanged.

## Native review status

Wave 1 (`de, it, tr, ja, ko, th, vi`) is fully translated and covered by the completeness tests, but the texts have not yet been read by native speakers. Review the app and site copy before claiming the locale as final: watch for plural forms (German, Italian and Turkish use `|one`), CJK line breaking and the Thai/Vietnamese tone of UI labels.

# CallBlocker

iOS app that blocks calls by number or pattern (e.g. `91987654xxxx`) using a
CallKit Call Directory extension. Built entirely on GitHub Actions — no Mac
needed.

## Get the app

1. On GitHub open **Actions → iOS Build → Run workflow**.
2. When the run finishes, download the `CallBlocker-unsigned-ipa` artifact and
   unzip it to get `CallBlocker-unsigned.ipa`.

## Install on an iPhone (Windows PC, free Apple ID)

The `.ipa` is unsigned; iOS only runs signed apps, so it has to be signed
during install. That needs an Apple ID — a free one is enough, no paid
developer account.

1. Install iTunes and iCloud for Windows (from apple.com, not the Microsoft Store).
2. Install [Sideloadly](https://sideloadly.io) and connect the iPhone by USB.
3. Drag `CallBlocker-unsigned.ipa` into Sideloadly, enter the Apple ID, and
   start. Leave app extensions (PlugIns) and App Groups enabled in the
   advanced options — the blocker does not work without them.
4. On the iPhone: **Settings → General → VPN & Device Management** → trust the
   Apple ID. On iOS 16+ also enable **Settings → Privacy & Security → Developer Mode**.
5. **Settings → Apps → Phone → Call Blocking & Identification** → enable CallBlocker.
6. Open CallBlocker, add rules, tap **Reload Blocker Extension**.

With a free Apple ID the signature expires after 7 days; re-run step 3 to
refresh it (rules are kept).

## Limits

- iOS has no true wildcard blocking: every number is listed individually, so
  a rule with 6 wildcards is 1,000,000 entries. iOS accepts roughly 2 million
  entries per blocker in total — "block everything except contacts" is not
  possible with this mechanism.
- Free Apple ID signing lasts 7 days and allows 3 sideloaded apps.

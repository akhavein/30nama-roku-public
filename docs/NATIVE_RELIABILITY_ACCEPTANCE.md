# Native reliability acceptance gate

Prepared 2026-10-12 for the Android-comparison reliability changes. Local interpreter, synthetic-server and compiler checks do not prove native Roku behavior or Store acceptance. See [backlog](GAP_BACKLOG.md), [device scripts](../tests/device/README.md), and [Store gate](store/STATUS.md).

## Approval and recovery prerequisites

- Obtain explicit authorization for an idle test Roku, a test window, temporary development-channel replacement, fixture-server LAN access and restoration. Existing saved credentials or past test approvals do not authorize a new device run.
- Reuse an existing private developer configuration only when authorized. Do not create credentials, enable developer mode, change device security, or publish addresses/passwords. Configuration presence does not establish reachability or permission.
- Before installing anything, identify the currently installed development application and verify the matching clean restore ZIP and hash. A newly built public placeholder ZIP is not automatically the correct household restore package. Stop if recovery is uncertain or someone is using the TV.
- `scripts/device.py install` sends Home and posts to the development installer: it replaces the installed development channel. The QA registry `30nama-test` isolates synthetic account/history data; it does not create another development-channel slot.
- Preserve current production registry/progress. Do not restore an old progress snapshot over newer viewing. Obtain a physical observer for picture, audio, captions and remote focus.

## Stage A: synthetic native checks, no provider account

Build the isolated QA ZIP, generate synthetic HLS/MP4/DASH media, and run the fixture server with its existing Roku/host/loopback allowlist. Do not start a public listener or gateway. Confirm the packaged API points to the fixture server and QA uses `30nama-test` before installation.

| Check | Minimum acceptance |
| --- | --- |
| QR and focus | Code and QR render; phone decodes the expected fixture string; Refresh and Cancel remain reachable; stale approval after cancellation cannot sign in. Existing synthetic QR strings use a real provider hostname with a fake code: decode offline only, do not open or approve that URL. |
| Auth errors | Pending, denied, expired, malformed, transient polling and verification-retry states terminate or recover as specified; no old account is replaced before verification. Some new timing/failure combinations need fixture extensions or manual orchestration before they can be marked tested. |
| Account isolation | Synthetic A to B and cancelled B; cold relaunch; expired A; late old-account callback; profile failure does not fetch history; successful owner change clears old data before history fetch. |
| API lifecycle | At most two running/sixteen pending API Tasks; Back/cancel releases work; stale completions do not affect current requests; queued timeout and bounded read retry remain responsive on native timers. |
| Home and navigation | Loading, successful empty data and failure are distinct; last-good catalog/local Continue survive a transient failure; Back and modal dismissal restore usable focus. |
| Playback and subtitles | Play, pause, bounded seek, Back, source failure/retry and next episode; English/Persian cues, Off, media switch, delayed old cue, exact-episode refresh failure and Roku global caption settings. Screenshots cannot establish decoded video or audible output. |

Use existing scenario runners only where they cover the named case; a broad historical suite is not evidence for a new unrepresented case. Record model/OS, app commit, ZIP hash, scenario, expected/actual result and sanitized diagnostics. Do not log session tokens, signed URLs or account history. Stop on unexpected production-provider traffic or loss of isolation.

Restore the previously verified clean package, check the authorized restoration behavior and leave the TV on Home. Do not substitute a live provider playback test for a synthetic-only authorization.

## Stage B: separate provider/account authorization

Only after explicit approval: use an entitled account and owner-controlled phone approval; no automated CAPTCHA/password workaround. Verify sign-in, profile, relaunch, session expiry and scoped helper renewal. Account-switch ownership requires two distinct authorized accounts. Real playback can write website progress; obtain authorization for those writes and independent readback at the existing 30-second checkpoint boundary. Watchlist mutation needs its own intended item and independent readback, without blind toggle retries.

Provider API contract/fixtures and supported on-device authentication remain external inputs. QR reliability does not establish Roku certification. Full Store acceptance, content rights, signed packaging and multi-model physical AV checks remain separate gates.

## Dependency scope

All npm entries in `package.json` are development dependencies. `build/30nama-roku.zip` contains only `manifest`, `source`, `components` and `images`, with no Node packages. `helper/server.mjs` and `service/server.mjs` use Node built-ins; the service Dockerfile copies only `server.mjs`, with no npm install. The seven remaining audit findings concern compiler/interpreter braces/glob/watch chains and development-process denial of service from malicious patterns, not libraries bundled in the Roku channel. This does not claim the optional service container or all runtime software is vulnerability-free. See [exact dependency paths and advisory](../tools/README.md).

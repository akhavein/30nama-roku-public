# Native Store candidate acceptance — not yet executed

Use an idle explicitly available test Roku; do not replace an actively watched sideload. Preserve the latest actual app/account state and clean restore package before testing. All synthetic runs use `30nama-test`. A passing simulator or mock backend cannot replace this gate.

## Deep links

Build isolated QA with `ROKU_QA_HOST` and `ROKU_QA_DEVICE` set for the test LAN. Existing fixture catalog IDs include movie 101 and series 201 / episodes 11, 12, 21, 22. This candidate uses title ID for movies and `titleID:episodeID` for episode, series and season links (stable episode identity across media types).

Send ECP `launch/dev` (cold) and `input` (warm) with `contentId` and `mediaType`; do not send raw URLs as content IDs.

- `101 / movie`: begins playback at saved local position, no detail/resume chooser.
- `201:12 / episode`: exact episode, never falls back to another episode.
- `201:11 / series`: appropriate prior unfinished/next episode; unwatched starts first regular episode.
- `201:12 / season`: opens episode list and highlights mapped episode.
- Invalid/missing/negative/overflow IDs, unsupported types, deleted content and malformed provider replies: safe Home with explanatory status.
- Signed out and expired stored session: on-device login, then original validated target; cancel leaves no delayed auto-play.
- Two rapid warm links, navigation away during detail/stream fetch, late old-account response: latest request wins; old playback checkpoint saved.
- Cold-launch AppLaunchComplete after Home render or actual deep-link playing, never while buffering. AppDialog beacons paired. Roku_Authenticated only after verified profile.

## Playback and accessibility

- FF/Rewind enters scene/time browser, changes target without moving decoder, OK commits and Back cancels; paused/playing intent preserved. Existing quick Left/Right seeking remains.
- Actual thumbnails across every supported published catalog format; explicitly enumerate sources without coverage. Narrow worker fallback alone is not a certification pass.
- Replay intervals 10–25 seconds, mode Instant replay shows captions until original position, including near start and paused replay.
- Global On/Off/When mute changes while playing and paused, including system Options overlay. Exit/relaunch must not reset changed system preference.
- Persian shaping/mixed-script text, no duplicate native/custom tracks, system font/color/opacity/edge/background choices. The candidate currently maps mode, text size, color and opacity; remaining style/duplicate-track behavior requires device work before a compliance claim.
- Screen reader focus/order, audio descriptions, native caption handling, readable focus and Back from Home exits directly.

## Account/service isolation

- Two authorized test accounts, separate installation IDs: enrollment/renewal, progress owner binding, sign-out, account switch, no old cache/history exposure.
- Gateway restart clears issued sessions; next authentication failure triggers bounded renewal rather than waiting the entire TTL. Subtitle retry after renewal happens at most once for current playback.
- Provider expiry/subscription expiry, offline revoke, quotas, service outage and cancelled pending caption/preview requests preserve video/local position.
- Sign-out clears local viewing data; explicit clear leaves account-side data intact. Website history may re-import only for current account.
- Keep external privacy claims aligned with actual retention/log configuration; never capture credentials in reports.

## Release evidence

Record actual device/model/OS, candidate SHA, result for each case and unresolved failures. Repeat genuine package replacement/resume and service progress readback. Obtain genuine listing screenshots without personal history; physical picture/sound/lip-sync requires human observation. Test Roku's specified performance models plus additional current models, then run Dashboard Static Analysis and App Behavior Analysis.

# Native device acceptance

Only run against an explicitly authorized idle test TV. Set `ROKU_QA_HOST` to the LAN address of the fixture server and `ROKU_QA_DEVICE` to the Roku address; loopback defaults are deliberately not a working TV configuration. Set `ROKU_DEV_CONFIG` to your private device JSON for installer and soak scripts. No account credentials are required for synthetic QA.

`qa-device.py build` copies the application into ignored `build/qa-app`, substitutes a local synthetic API, uses registry section `30nama-test`, and adds test-only scenario/state hooks. The normal source and production account/history are untouched. QA hooks are excluded from the shipping ZIP.

1. Generate a 12-second HLS fixture in `build/qa-media/fixture.m3u8` (local ffmpeg color + silent audio).
2. Run `python3 scripts/qa-device.py serve` on your fixture host. It only accepts the configured Roku and loopback/Mac clients; it neither reads nor logs production credentials.
3. `python3 scripts/qa-device.py build` and `python3 scripts/device.py install build/qa-roku.zip`.
4. Attach one console listener: `python3 scripts/device.py console 600 > build/acceptance.log`.
5. `python3 scripts/qa-acceptance.py`. Results: `build/qa-results.json`.
6. **Restore production:** `npm run package`, `python3 scripts/device.py install`, then launch and verify live catalog/playback.

The scenario hook initializes a real application route; the actual application networking, SceneGraph widgets, decoder and controller callbacks execute on the TV. Keys and navigation use ECP. Login fixtures do not send emails. This is complementary to live-service acceptance, not a substitute for it.

Native developer screenshots capture app UI but not decoded video planes. Do not claim film-image quality, audible audio quality from those screenshots alone. Custom subtitle glyphs are visible and can be inspected.

Generate fixtures with `python3 scripts/qa-device.py media`. After the main suite, run `python3 scripts/qa-extra.py --resume` for English/Persian rendered cues, persisted subtitle preference, Off, bounded seek, FF/Rewind, explicit Next and a season-boundary completion. The fixture videos are synthetic color frames with silent audio, not copied content.

Run `python3 scripts/qa-caption-faults.py --resume` for missing/slow captions, late callback cancellation, expired URL refresh and bounded retry.

For the stalled HLS test, keep the console attached to `build/acceptance.log`, then run `python3 scripts/qa-buffer.py --resume`. The QA scenario shortens the production 45-second timer to 3 seconds without changing its callback; the first stream stalls and the retry returns valid HLS.


## v1.2 complete pass

Generate fixtures with `python3 scripts/qa-device.py media` (ffmpeg required), start the server once, and attach **one** console listener to `build/acceptance.log`. Run `sh scripts/qa-followup.sh`, followed by `python3 scripts/qa-compatibility.py`. Each launch carries a unique run ID; acceptance predicates ignore output from prior launches. Restart the fixture server between complete passes to reset deliberate first-failure scenarios.

The combined suite covers 54 original flows, then 46 preference/Watchlist/search/source/timing/size/countdown/diagnostic checks. Compatibility adds six MP4/DASH/caption-cycle checks. Native caption suppression is exercised only in isolated QA; it is rejected by shipping validation. Inspect actual English and Persian screenshot glyphs, not only the renderer fields.

For a real-content soak, restore the clean ZIP, start an episode at zero with autoplay enabled, stop the QA console/server, then run `python3 scripts/soak.py --minutes 50 --transitions 2`. It samples native playback without URLs or account credentials, does not reclaim the TV if another app takes focus, and writes `build/soak-results.json`. A running report is **not** a pass. After completion, check pause/relaunch/resume and service checkpoint readback, then leave the app on Home.

# 30nama for Roku

Unofficial, native SceneGraph/BrightScript TV client for 30nama. Designed for remote-first navigation, English/Persian search, reliable resume and readable Persian captions.

**Public source snapshot · v1.7 candidate.** This is not an official Roku Store app or an affiliation with 30nama. It includes scene-preview work, but final candidate reinstall/resume acceptance is still pending. Publishing this source is not a v1.7 production release.

## Features

- Poster-led browsing, movie/series details and ordered season/episode navigation.
- English/Persian search normalization, pagination, cached back navigation, filters and page-scoped sorting.
- Per-episode resume, watched/unwatched controls and Continue Watching.
- Separate TV-local and account Watchlists, with readback-verified account changes.
- Bounded playback recovery, source fallback, autoplay and provider-marked manual Skip Intro.
- Configurable remote seeking, subtitle timing/size/contrast/placement, audio preferences and sleep controls.
- Shaped Persian external subtitles through an optional self-hosted helper.
- Optional real scene thumbnails from a bounded worker; unsupported media keeps time-only seeking.

## Requirements

Node.js 22+, npm, Python 3, FFmpeg, `zip` and `unzip`. A Roku in developer mode is needed only for device installation/testing. Live service use requires your own authorized provider API key and account. No account, provider key, helper key or media is included.

## Build and test

```sh
npm ci --ignore-scripts
npm run package
```

This runs compiler, BrightScript, helper, recorder and preview-worker tests plus SceneGraph and archive checks. Output: `build/30nama-roku.zip`. The default ZIP contains an API-key placeholder: it builds and supports synthetic tests, but cannot authenticate to the live provider until configured.

To create a local configured ZIP without modifying tracked source:

```sh
python3 scripts/configure-provider.py --key-file /private/path/provider-key.txt
```

Output: `build/30nama-roku-configured.zip`. **Do not publish this configured artifact.** The plain-text key is supplied by you; the script does not obtain credentials or bypass service access.

## Sideload

Enable developer mode on your Roku. Create `.runtime/roku-dev.json` locally (ignored by Git), with your own device details:

```json
{"host":"YOUR_ROKU_IP","username":"rokudev","password":"YOUR_DEVELOPER_PASSWORD"}
```

Alternatively set `ROKU_DEV_CONFIG` to a private JSON file outside this checkout. Keep its file permissions private.

```sh
python3 scripts/device.py install build/30nama-roku-configured.zip
python3 scripts/device.py launch
```

Installing replaces the currently sideloaded channel. Device scripts send real remote commands; do not run them on a TV someone is watching.

## Remote controls

| Context | Controls |
| --- | --- |
| Browse | Arrows navigate; OK opens; Play starts/resumes; Back restores the previous screen |
| Search / Watchlist | Star opens options; search FF/Rewind changes pages |
| Playback | Play pauses/resumes; Up opens controls; Down opens subtitles |
| Quick seek | Left/Right, FF/Rewind and Replay use saved intervals |
| Scenes | Up → Scenes → OK; arrows change target; OK/Play commits; Back cancels |
| Back in player | Dismiss a picker, hide controls, then close playback |

Account → Playback preferences contains intervals, sleep and still-watching settings. No helper endpoint is preconfigured. Pair a helper you control for provider-side external captions, bridged progress and optional thumbnails; see [helper setup](helper/README.md).

## Documentation

- [Architecture](docs/DESIGN.md)
- [Watching experience and settings](docs/WATCHING_EXPERIENCE.md)
- [Account Watchlist](docs/ACCOUNT_WATCHLIST.md)
- [Skip Intro](docs/INTRO_SKIPPING.md)
- [Scene previews and limits](docs/SCENE_PREVIEWS.md)
- [Preview worker setup](preview/README.md)
- [Native device QA](tests/device/README.md)
- [Contributor/agent instructions](AGENTS.md)
- [Store readiness](docs/STORE_READINESS.md)

## Verification and limitations

The private precursor passed 403 BrightScript assertions, 6 helper tests, 11 worker tests and 106 native device checks. Real preview images were observed. Those historical results are not a claim that every public configuration has passed device acceptance. Final v1.7 reinstall/resume is pending, viewer-profile sync is absent, and physical audio/video/lip-sync cannot be established from installer screenshots.

This repository starts with fresh history. Private deployment records, account captures, credentials and runtime/build output are intentionally omitted. Use your own lawful service access and content permissions. Bundled font attribution and SIL Open Font License are in [components/fonts](components/fonts/README.md). No additional license grant for project source is declared by this publication.

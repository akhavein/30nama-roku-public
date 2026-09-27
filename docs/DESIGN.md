# Minimal TV design

## Visual system

1280×720 reference canvas; charcoal background (#0b0d12), near-white text, muted slate secondary text, one warm-gold focus/accent. No ornamental badges, duplicated titles, diagnostic copy in normal flows, or overlapping panels. Persistent compact left navigation on browse screens; content begins at x=280. Large poster cards with readable titles and saved-progress indicators. Native focus animation and a custom high-contrast focus frame.

## Screens

- **Home:** Continue Watching (when nonempty), Featured, Suggested, Top 10 horizontal rails. Focused title summary above rails. Content refresh must preserve user's focus.
- **Search:** native keyboard; real API results, query retained, page navigation, retry and no-results messages. Successful result/focus snapshot survives failed pages and cancelled edits. A punctuation-normalized retry uses the same global service; it never substitutes local-only matches. Exact title matches rank ahead of sequels within each returned page.
- **Title:** poster, title, metadata, synopsis, one primary Play/Resume action, Start over when saved, Seasons for series. Back restores prior rail and selected card.
- **Series:** choose season, then episode; show exact season/episode and saved progress. Opening a series offers its last watched episode. Finishing advances the resumable target to the next episode without forced autoplay.
- **Continue Watching:** up to 20 locally saved movie/series targets, one target per series, preserved across app/device restarts. Completed movies leave the rail. Per-title Remove action.
- **Player:** full-screen video. OK toggles overlay. Timeline/current time/duration; Play/Pause, ±10 seconds, subtitle selector (System/Off/available tracks), audio selector, Restart, Next episode when available, Close. Play, rewind/forward and Back work from the remote. Overlay auto-hides only while playing; controls stay visible when paused or buffering/error. Back dismisses track picker, then overlay, then exits playback.
- **Account:** sign in/out, refresh catalog; login cancellation/errors remain recoverable. Diagnostics stay separate.

## State rules

Every asynchronous screen request carries a page generation; late results cannot navigate or start playback after Back or a new selection. Cancelled and repeated requests do not multiply tasks. History contains public metadata/IDs/positions only—never signed streams, subtitles, or session tokens. Only the account token is stored separately in the Roku registry. Stream URLs are refreshed before movie/series resume.

## Acceptance

Compiler and executable model/controller tests are necessary but not sufficient. Install and visually inspect each screen; use ECP plus device console for real remote, playback, and relaunch flows. Record reproducible defects and fixes. External-account/OTP tests that would send mail are exercised only with the owner's action, not unsolicited test sends.

## Captions

English/Persian sidecars share a timed Unicode renderer. Persian is shaped into contextual glyphs with mixed RTL/LTR runs. Captions move above the player overlay, wrap before shaping and use a dark backing for contrast. Download/cache/one-time URL refresh happen off the UI thread; Off and Back cancel pending work. A paired TV can use a self-hosted HTTPS helper without a desktop runtime dependency. Cues are indexed by minute at load time; each tick evaluates only the relevant bucket. The selected next-episode language can be prefetched without changing playback or history.

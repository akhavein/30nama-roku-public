# Provider-backed Skip Intro (v1.5)

When the service supplies valid `options.intro_start` and `options.intro_end` timestamps, a **Skip intro · OK** prompt appears during that interval. Press OK to skip, or ignore it to keep watching. Up still opens the normal controls, where **Skip intro** is available too. Paused playback stays paused after skipping. Nothing skips automatically.

## Bounds and remote behavior

- Accept only explicit `HH:MM:SS` markers with valid clock fields, increasing endpoints, and intervals of at most 10 minutes. Missing, zero-length, reversed, malformed, or out-of-duration markers produce no action.
- Wait for native playback and a known duration. The endpoint must be before the end of the video; this feature never completes an episode or jumps to the next episode.
- The interval includes its start but excludes its end. No prompt during startup/rebuffering, pending seeks, subtitle/settings pickers, next-episode countdown, or Still Watching prompts.
- Use the existing cumulative seek/checkpoint/recovery path; preserve pause, subtitles, and audio. Revalidate on activation, not only when drawing the prompt.
- Native HLS seeks can land on an earlier keyframe. Once requested, the same intro is not offered again until deliberate rewind or restart. This dismissal survives source recovery, but not a new playback session.
- Retain the selected toolbar action by identity when the intro action appears/disappears. If the selected action itself disappears, select Play/Pause rather than a destructive neighboring action.
- A new movie/episode replaces the marker even when it has no intro metadata. Markers are memory-only, not a new registry allocation or server dependency.
- The prompt uses the top-right status area, separate from captions, menus, and playback controls.

## Provider assessment — September 26, 2026 (Toronto)

Availability varies by title and episode. The provider owns the timing; valid markers do not establish editorial accuracy.

No thumbnail metadata or `EXT-X-IMAGE-STREAM-INF` advertisement appeared in the three sampled master manifests (all fetched successfully). This is a sample, not a claim about the entire catalog. Real seek previews remain separate work: indexed BIF/HLS/DASH images or a separately evaluated, bounded generation pipeline are required. [Roku trick-mode documentation](https://developer.roku.com/dev/docs/trick-mode).

Account Watchlist sync was subsequently implemented in v1.6; see [account Watchlist](ACCOUNT_WATCHLIST.md). Viewer profiles remain separate. No helper service or transcoding infrastructure was deployed.

# Find scene (v1.7)

During playback press **Up → Scenes → OK**. The scene browser pauses the current video. Left/Right adjusts by the saved step, FF/Rewind by the saved skip interval, and Replay moves backward. **OK** (or Play) seeks to the selected time; **Back** cancels without seeking. Both preserve whether playback was originally playing or paused. Existing quick skip/replay controls are unchanged.

Frames are real, small images decoded from the selected stream, not title artwork. They are labelled “Scene near” because media timestamps and keyframe alignment are not frame-exact editorial markers. A missing/slow/expired/unsupported preview never disables time selection, ordinary playback or subtitles. The selected time changes immediately; generation is debounced, old responses are ignored, and cancel/close/sleep invalidate pending requests. Temporary image paths use a random per-launch namespace to prevent Roku's image cache from reusing another session's frame. At most three temporary image files are kept and cleared when the browser closes.

## Supported media and bounds

The initial worker supports on-demand, unencrypted HLS VOD with independent MPEG-TS segments, a declared rendition no larger than 640×480 / 800 kbps, segments no longer than 15 seconds and programs up to six hours. It currently permits the verified exact source host `us-stream-node.divyacamilla.info`. Other hosts, MP4, DASH, encrypted streams, fMP4 maps, byte ranges, discontinuities and live playlists use the time-only fallback. No claim of catalog-wide coverage or Roku Store certification.

The server selects a low-bandwidth rendition, fetches only the segment containing the requested time and extracts a 320×180 JPEG. It does not download entire episodes or store a video library. The TV sends only the signed media URL and desired time to the owner's existing paired HTTPS helper; no 30nama account token is needed for preview generation. URLs, images, bodies and pairing keys are not logged. Memory caches are bounded (24 images/120 seconds, two playlists/60 seconds), with no disk cache. Image generation is one-at-a-time with no queue; a busy/unavailable worker returns a fallback, not a playback error.

Network fetches validate exact HTTPS hosts, public DNS addresses and pinned TLS connections; redirects are rejected. FFmpeg receives only a bounded segment through stdin, with only the pipe protocol enabled, one thread, a short subprocess timeout and a scrubbed environment. The worker has a read-only filesystem, non-root user, 192 MiB / 0.35 CPU / 24 PID limits, an 8 MiB tmpfs and loopback-only listener. The client uses an 11-second request timeout and does not replay a failed preview request automatically.

## Deployment and rollback

See [worker setup](../preview/README.md) and [helper setup](../helper/README.md).
The optional helper route forwards to a separate loopback worker; it does not use
the subtitle browser. Set `PREVIEW_PORT=8790` to enable it. Without that setting,
`/preview` returns 404. Stop only the preview container to disable generation;
ordinary playback and time-only seeking remain available.

## Verification sources

Final native, build and real-account proof belongs in the versioned release report, not an inferred pass from this design. Samples are not p95 latency measurements. Physical picture/audio/lip sync is not certified by Roku screenshots.

References: [Roku trick mode](https://developer.roku.com/dev/docs/trick-mode), [random session UUID](https://developer.roku.com/dev/docs/ifdeviceinfo), [FFmpeg protocol whitelist](https://ffmpeg.org/ffmpeg-protocols.html), [FFmpeg seeking](https://ffmpeg.org/ffmpeg.html).

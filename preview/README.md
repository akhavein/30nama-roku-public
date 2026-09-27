# Bounded scene-preview worker

Optional Python/FFmpeg service generating a small real JPEG near a requested seek time. See [behavior and supported media](../docs/SCENE_PREVIEWS.md). Unsupported media returns time-only fallback; it is not a general transcoding service.

## Test

```sh
python3 -m unittest discover -s preview -p test_server.py
```

Requires FFmpeg on PATH. Tests use synthetic media, not account content.

## Deploy on a Linux Docker host

From the repository root:

```sh
docker build -t roku-preview:1.7.0 preview
```

Copy `preview/compose.yaml` into a separate deployment directory. Create `.env` there with the same private `HELPER_BEARER_TOKEN` as the paired helper, mode 0600. Then run `docker compose up -d --wait --wait-timeout 45` from that directory.

The sample uses Linux host networking and binds only to 127.0.0.1:8790. A non-root, read-only container has 192 MiB memory, 0.35 CPU, 24 PIDs and 8 MiB tmpfs. The helper on the same host forwards authenticated `/preview` requests; do not expose the worker directly.

`PREVIEW_HOSTS` is an exact allowlist, initially one supported provider media host. Do not broaden it to arbitrary URLs or disable DNS/TLS/redirect checks. Requests, segments, rendition dimensions, durations, caches and decoder time are bounded. Signed URLs and images stay out of logs and persistent storage.

Readiness must pass after a restart before testing recovery. Stopping only this container disables thumbnail generation without intentionally changing subtitles, playback or time selection.

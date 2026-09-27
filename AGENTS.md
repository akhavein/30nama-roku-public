# Contributor and agent instructions

## Scope and commands

This is an unofficial Roku sideload client, not an official or Store-approved application.
- `npm ci --ignore-scripts` installs pinned development dependencies.
- `npm run package` runs compilation, executable BrightScript regressions, helper/worker tests, XML checks and ZIP validation. Requires Python 3, FFmpeg, zip and unzip.
- Keep runtime changes covered by relevant controller/model tests; do not infer native behavior solely from simulation.

## Privacy and public-source rules

Never commit provider keys, account tokens, passwords, pairing keys, signed URLs, private captures or deployment addresses. `build/`, `.runtime/`, `secrets/` and environment files stay ignored. Use only synthetic test fixtures. Never print credentials or signed URLs. Keep local credential-bearing packages out of Actions artifacts and releases. The provider configuration script modifies only an ignored output ZIP.

## Device and deployment boundaries

Do not install, launch, send remote keys or run native QA against a real TV unless explicitly authorized for that session. QA replaces the sideloaded app: use the separate `30nama-test` registry, never production authentication/history, and restore a clean appropriately configured app afterward. Do not overwrite fresh user progress with a stale test checkpoint. No production endpoint is built into this public copy; deployments require operator configuration.

## Behavioral invariants

- Preserve paused intent, progress and focus through seek/recovery, cancellation and stale callbacks.
- Service progress uses 30-second checkpoints; HTTP 200 alone is not proof of saved history. Verify independent readback in authorized live acceptance.
- Search transport shortcuts belong in `BrowseRails`; native RowList consumes these before the parent Scene.
- Account Watchlist writes require readback; do not blindly retry toggle mutations.
- Keep captions independent of thumbnail failures. Bound every request, retry, cache, queue and media fetch.
- Shipping packages contain only manifest/source/components/images, never QA hooks or temporary pairing code.
- Never reintroduce `suppressCaptions` based on simulated tests. Verify native caption lifecycle and app exit.
- Installer screenshots omit native video planes: do not claim picture/audio/lip-sync verification from them.

## Release claims

This snapshot is a v1.7 candidate; final reinstall/resume acceptance is pending. Preserve that distinction until measured gates pass. A public code push is not a production release or Store certification. Keep reports factual and exclude personal viewing history.

## Store candidate work

`feature/store-readiness` is not installed or certified. Include `service/server.test.mjs` in checks. Deep-link IDs and actual device acceptance are specified in `docs/store/DEVICE_ACCEPTANCE.md`. Never replace pending native gates with simulator claims, ship a shared household helper credential, or silently broaden preview source/network limits. Public gateway and policy drafts require deployment facts and publisher inputs.

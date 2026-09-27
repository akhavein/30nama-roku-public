# Self-hosted subtitle and progress helper

Optional Node.js 22+ service for exact-host `subtitle.30nama.com` timed text and provider progress updates. It uses a dedicated Chrome/Chromium instance through loopback CDP. A paired Roku sends account credentials transiently for progress; run only a helper you control, over authenticated HTTPS. Credentials and signed URLs must never be logged.

For the public-user candidate, place the [account-bound session gateway](../service/README.md) in front of a **separate** helper/browser deployment. The household pairing recipe below is not consumer onboarding.

## Local development

`node --test helper/server.test.mjs` runs synthetic tests. `helper/deploy.py` is an optional macOS LaunchAgent installer for Chrome and Node; it modifies local services only when explicitly run. Defaults bind to loopback and allow loopback clients only. It does not configure a reachable Roku endpoint automatically.

## Linux deployment templates

1. Copy `helper/server.mjs` and `helper/cloud/compose.yaml` into one deployment directory. Supply Node.js via the pinned Compose image.
2. Install Chromium and Xvfb. Adapt `cloud/roku-browser.service` to your browser path and host. It is a template, not an automatic installer. CDP must remain loopback-only on port 9227. The template uses systemd containment and `--no-sandbox`; evaluate your host's browser isolation before deployment.
3. Create a private `.env` with `HELPER_BEARER_TOKEN` set to a randomly generated 32–128 character URL-safe key. Keep it mode 0600. Do not commit it.
4. Start the dedicated browser and run `docker compose up -d` in the deployment directory. Helper port 8789 is loopback-only.
5. Adapt `cloud/roku.caddy` to your own domain, DNS and TLS configuration. Every externally reachable route must require the bearer key. Validate configuration before reloading only the intended proxy service.
6. Build a locally configured client as described in the root README. Pair it using the command below. The pairing script restores `build/30nama-roku.zip`, so copy your configured local ZIP to that path before pairing.

```sh
cp build/30nama-roku-configured.zip build/30nama-roku.zip
python3 scripts/configure-helper.py https://roku.example.com --token-file /private/path/helper-key.txt
```

The script creates a temporary credential-bearing package in `.runtime/`, writes pairing data to the Roku registry, removes the temporary package and restores the clean locally configured ZIP. Never distribute either credential-bearing package.

Health proves browser/renderer liveness, not upstream service success. Validate real subtitle fetches and independent progress history readback only with an authorized account/device. The browser needs distinct subtitle and API-origin contexts; do not merge them. Keep redirect rejection, bounded bodies/cache/concurrency and timeouts intact.

## Optional previews

The provided Compose template enables `PREVIEW_PORT=8790`; remove that environment entry to disable forwarding if no worker is deployed. The worker is independent of Chrome and subtitles. Use the same bearer key in both services. See [worker setup](../preview/README.md).

To roll back, restore your previous helper source/Compose configuration and recreate only its container. Back up configuration privately; never overwrite unrelated services or clear the browser profile as a routine update.

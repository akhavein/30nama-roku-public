# Public-user session gateway (candidate)

This is a separate deployment from the household helper. **Not deployed or load/certification validated yet.** It exchanges a verified 30nama account session for a random, 15-minute helper credential. Users do not enter or share an operator pairing key. The client renews automatically and revokes on sign-out. Provider authorization still determines playable content; the gateway does not grant subscriptions.

## Request contract

- `POST /session`: `{token, deviceId}`. Verifies token through the fixed provider `user` endpoint using the operator API key; only a successful profile with a positive user ID is accepted. Random app-generated installation ID, not a hardware identifier.
- `DELETE /session`: bearer-authenticated revocation. An in-flight request already forwarded cannot be undone.
- `/subtitle`, `/preview`, `/progress`: require unexpired session credentials. Progress account/token must match the verified session; client-supplied provider API keys are discarded.
- `GET /health`: public liveness only; does not prove upstream/browser readiness.

Session token hashes and the transient provider token stay in bounded RAM until expiry, revocation or restart. No persistent session DB, cookies, analytics SDK, raw request logging or account captures. Provider token is needed for account-bound progress; it is never returned in the session response. Restart requires client renewal. At most 1,000 sessions, eight per account, eight requests globally and two per session can be active; per-account minute limits and bounded IP/enrollment bookkeeping apply. These are protective limits, not a promised public capacity.

The upstream helper/worker credential stays only on the server. CDP browser fetches omit ambient cookies; progress requests supply account headers explicitly. Helper signed-URL caches are not an identity store. Use a separate browser profile and containers for this deployment, not the household profile. Audit real upstream behavior with test accounts before exposure.

## Operator setup

1. Build `docker build -t roku-session-gateway:1.7.1 service` from the repository root.
2. Copy `service/compose.yaml` into a dedicated deployment directory. Put `PROVIDER_API_KEY` and `HELPER_BEARER_TOKEN` in its private mode-0600 `.env`; use the key of a dedicated helper deployment.
3. Configure `HELPER_ORIGIN` for that loopback helper. The gateway rejects non-loopback forwarding URLs. Keep gateway, helper, browser CDP and worker loopback-only.
4. Run `docker compose up -d --wait`. Front only the gateway with your own HTTPS origin. Configure edge request-size, connection and rate limits; do not log Authorization, request bodies or signed URLs. Shared reverse-proxy source addresses need an edge rate limiter; untrusted X-Forwarded-For is intentionally ignored.
5. Run fixture tests, authenticated live multi-account/isolation/restart/renewal tests, and a measured load test before opening public enrollment. An account profile is authentication, not proof of current paid entitlement; stream access remains enforced by 30nama.
6. Configure the private distribution ZIP with `scripts/configure-provider.py --key-file /private/provider-key.txt --service-origin https://your-service.example`.

The origin and key are substituted into ignored output ZIPs only. No public service endpoint, provider key or shared bearer key is distributed by this repository. Never upload a configured ZIP to public CI artifacts. Packaging/signing and Store review are separate steps.

## Verification

`node --test service/server.test.mjs` tests sessions, expiry/revocation, malformed input, ownership binding, capacity and errors. Additional production work includes live provider contract validation, paid-account edge cases, revocation when the TV is offline, rejection/load monitoring, key rotation and operator support. Without a working configured gateway, playback remains provider-direct and local progress is retained; cloud captions/previews/progress may be unavailable.

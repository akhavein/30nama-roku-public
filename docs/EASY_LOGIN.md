# Easy Login (sideload feature)

This branch implements provider-supported device linking. It is not an approved Roku Store authentication method for this app. No Store upload or scheduling is implied.

QR generation runs locally in a Task using the MIT-licensed Paramount/Nayuki BrightScript QR library, pinned from https://github.com/paramount-engineering/QR-Code-generator-brightscript at `b5a48b96620e6603078053c8fe7500a23f152b5c`. License and upstream copyright headers are retained in `components/qr`. Upstream Poster/event/logging code was removed; a bounded Task generates only an in-memory/temporary PNG. No external QR service receives a code or token.

## Behavior

Account → Sign in opens the QR/code screen. Scan it and approve on the official provider website, or visit `https://30nama.com/auth` and enter the displayed code. After approval, the TV independently verifies the returned account profile before saving its session and resuming a pending content link. Linking another account leaves the old session intact until verification succeeds; account-specific local data is cleared when the verified owner changes.

Polling occurs no faster than every five seconds, with one in-flight request and bounded network backoff. The TV stops after five minutes, on cancellation, navigation, session invalidation, or provider expiry. Get a new code starts a fresh request generation. Untrusted activation origins, mismatched URLs/codes, malformed responses and unverified tokens are rejected. Codes, URL payloads and tokens are not printed to the API log. Temporary QR PNGs are deleted when the flow ends. Passwords are never collected.

The bundled QR library's SceneGraph enum objects were converted to pure value objects. Alignment-pattern corner exclusions were rewritten as explicit conditions after independent matrix tests found incorrect output with the upstream expression; array splice append/tail handling was also corrected. QR encoding is limited to versions 1–6, medium ECC and mask 0 in a background Task.

## Verification

- `npm run package`: compiler, BrightScript controller regressions, independent QR matrix fixtures, helper/gateway/preview tests, XML and package validation.
- `scripts/test-qr.py` checks actual BrightScript output against two matrices independently verified using Python qrcode 8.2, including a maximum-size renderer input. No extra Python package is needed to run the committed tests.
- Isolated native scenarios `easy-pending`, `easy-success`, `easy-invalid`, `easy-expired` are available through `scripts/qa-device.py`. Only the QA ZIP includes synthetic endpoints and a separate registry.
- Native QR display/scan, button focus, live TV sign-in and registry restart remain **unverified**: the household TV was unreachable during implementation. The earlier live API/browser linking proof is not a native acceptance result.
- No TV installation, Store upload, production-service change or publication was performed for this feature.

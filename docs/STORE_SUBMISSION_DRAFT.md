# Roku Store submission draft

Prepared 2026-09-27. **Not submitted. Not certified.** The public v1.7 source snapshot is not yet a distributable consumer release.

## Current development status

The original audit below describes the pre-implementation snapshot. This branch now implements deep-link handling, launch/authentication reporting, account-bound helper sessions and original artwork. See the maintained [implementation/proof status](store/STATUS.md), [listing draft](store/LISTING.md) and [device acceptance matrix](store/DEVICE_ACCEPTANCE.md). None of these additions has yet passed native certification. The publisher states that a Roku Developer account exists and the intended unofficial paid-account client use complies with provider terms; dashboard access and publisher declarations have not been independently verified.

## Original draft listing (superseded by store/LISTING.md)

- Working app name: **30nama** (requires brand authorization).
- App type/category candidate: Video / Movies & TV.
- On-device description: Browse movies and series, search in English or Persian, resume episodes, and manage your Watchlist with remote-friendly playback and subtitle controls.
- Online description: A native TV client for an authorized 30nama account. Browse and search available movies and series, continue an episode, organize your Watchlist, and choose available audio and subtitles. Includes configurable seeking, manual Skip Intro when provider timings are available, and optional scene previews. Content and features depend on your subscription, territory, provider metadata and device support.
- Default language proposal: English; Persian-capable content/search/captions do not imply a fully localized Persian Store listing.
- Countries, domestic region, age rating, made-for-kids classification and monetization: **publisher inputs required; not guessed**.
- Support URL/email/phone, administrative and technical contacts, privacy URL and terms URL: **required; not yet supplied**.

## Original pre-implementation audit (historical; see current status above)

| Gate | Evidence / remaining action |
| --- | --- |
| Provider content/service/name rights | No permission evidence supplied. Confirm publisher organization, brand consent and permitted territories. |
| Roku publisher account | Access and enrollment not verified. Use the authorized content owner's account / delegated app-management access. |
| Distribution artifact | Current build is a sideload ZIP with an API-key placeholder. Establish authorized service configuration and the intended packaging/signing identity; never publish keys in source or public CI artifacts. |
| End-user onboarding | Current helper requires operator pairing and a household bearer key. Define supported self-service or managed per-user credentials, isolation, revocation, abuse limits and privacy policy. |
| Deep linking | source/main.brs takes no launch arguments and handles only screen-close events; cold/warm movie/episode links need implementation and testing. Manifest supports_input_launch alone is not implementation. |
| Performance instrumentation | No AppLaunchComplete beacon found. Add required instrumentation and run Roku's applicable device/performance tests. |
| Authentication / payments | Verify on-device sign-in, Event Dispatcher and applicable Roku Pay requirements with the provider business model. Do not declare a paid catalog free to avoid requirements. |
| Trick-play coverage | Candidate Scenes feature covers a narrow HLS subset and separate interaction. It does not establish compliant thumbnails for all VOD longer than 15 minutes. |
| Accessibility | Custom captions need audit against global caption settings, replay/mute behavior, accessibility and audio-description requirements. |
| Store / manifest artwork | No branded home icon/splash entries in the current manifest; approved assets and actual suitable screenshots are still needed. |
| Privacy, terms and review login | Specify responsible operator, data flows, retention/deletion and support before publishing policy URLs. Provide a dedicated reviewer account privately, not household credentials. |
| Validation | Local regressions are not Roku certification. Run Static Analysis, App Behavior Analysis and multi-model native testing. Final v1.7 reinstall/resume remains pending; no TV access used for this draft. |

## Asset brief

Prepare approved app identity artwork (Store poster 540×405 JPEG/PNG) and up to six genuine 1920×1080 screenshots. Suggested scenes: Home, search, series details, Watchlist, subtitles/settings, scene browser. Do not use private viewing history or unlicensed title artwork for promotion. Do not upscale installer captures and describe them as native 1080p device evidence. Home/splash artwork must follow Roku's current manifest/design specifications.

## Privacy-policy inputs (not a final policy)

Document account/session data stored on the Roku, provider history/Watchlist requests, local progress/preferences, helper processing of transient credentials and subtitle URLs, thumbnail processing of signed media URLs, bounded caches, operator logs and retention, deletion/support requests, third parties and territories. The helper operator/contact and public deployment model must be established before a truthful final policy can be published.

## Proposed submission sequence

1. Confirm provider permission, territories, publisher ownership and account access.
2. Resolve the consumer onboarding and platform-compatibility gaps above; finalize policy/support/listing metadata.
3. Create authorized distribution artifact and a beta app for QA, if appropriate. Beta is temporary testing, not a public Store listing or rights workaround.
4. Complete native and multi-device acceptance, then Roku Static Analysis and App Behavior Analysis with dedicated review access and movie/episode deep-link examples.
5. Submit the verified package and listing for Roku review. Only report publication when the Dashboard confirms it.

## Sources checked

- [Roku App Publishing](https://developer.roku.com/dev/docs/channel-publishing-guide)
- [Roku certification criteria](https://developer.roku.com/dev/docs/certification)
- [Roku certification overview](https://developer.roku.com/dev/docs/certification-overview)

No account was created, terms accepted, rights attested, package uploaded or TV controlled during preparation.

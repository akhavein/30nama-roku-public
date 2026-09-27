# Store readiness: implementation vs proof

## Implemented on main

- Short-lived, revocable, account-bound gateway credentials; isolated progress ownership, bounded enrollment/session/rate/concurrency handling. No shared household key in the public client. Automatic renewal and bounded reauthentication after gateway expiry/restart.
- Cold and warm Roku deep-link dispatch; validated catalog identities, movie/exact episode/series bookmark/season behavior, login handoff, cancellation and invalid-link fallback. The mapping is documented in DEVICE_ACCEPTANCE.md.
- Roku Event Dispatcher authenticated event after a verified profile, launch-completion and login-dialog beacons; Home Back exits without a sidebar detour.
- FF/Rewind enters confirm/cancel scene seeking; Instant Replay intervals constrained to 10–25 seconds.
- Initial global custom-caption integration for On/Off, Instant Replay, Roku TV mute resolution, text size, color and opacity. No silent global Off on loading a sidecar or stale global-mode restore on exit.
- Sign-out/account switch clears account-associated local viewing data; explicit clear action explains that provider-side history is separate. Preferences remain device-local.
- Original unofficial icon/splash assets, build-time artwork validation, listing copy and privacy/terms drafts.

## Verified on 2026-09-27

- Publisher enrolled and email verified. Created **30nama - Unofficial** with all 21 Roku Store regions (including Rest of World), English, and Video, following the publisher's worldwide selection. Saved Movies & TV, not made for kids, Content Not Rated / Parental Guidance Advised, English descriptions and original poster. App creation is not publication.
- The exact Store candidate passed 14 isolated native deep-link checks on a TCL Roku TV: cold movie/episode, warm episode, season selection, invalid/missing targets, ordered-series start, rapid-link replacement and stale replies, signed-out handoff/cancel, launch completion and Home Back exit. See `VERIFICATION-2026-09-27.json` and `scripts/qa-store.py`. Test fixture detail responses now identify series correctly.
- Eight gateway checks passed in a separate loopback-only Linux deployment with one live provider account: authentication, invalid/unauthenticated rejection, two installations, ownership rejection, revocation and revoked-session rejection. This is **not** two-account acceptance, public deployment, or proof of subtitle/progress forwarding. Temporary candidate containers/browser were stopped after verification; the household services were not changed.
- Fixed a Compose flow-list typo that split a tmpfs mount option into an invalid second mount. The quoted mount was accepted by Docker in the candidate deployment.
- Generated the first signing identity and retained it in private operator storage. Uploaded an encrypted **analysis-only** package; no account credentials or household helper key are packaged. The provider configuration is private, and the public gateway origin is deliberately unset until its deployment acceptance is complete. Restored the exact preexisting clean TV app after packaging and native tests.
- Roku initial Static Analysis completed with zero errors, eight warnings and one information item. Addressed its RSG 1.3/minimum OS 15.1 guidance and excluded the unused font README while retaining the font license. Build 2 passed the full local package checks and all 14 native deep-link checks again. The new signed build completed repeat Static Analysis with zero errors, five memory-monitoring warnings and one information item. Hosted Linux CI also passed.
- Initial App Behavior Analysis began on Roku's 4660X test device, but deep-link and content-playback tests were skipped with error severity because review/deep-link inputs are incomplete. This is not a behavior-analysis pass. Live catalog-backed movie and exact-episode parameters have since been saved; paid reviewer access and a completed authenticated app profile are still needed.

## Continuation verification on 2026-09-27

- Published the pre-release support, privacy and terms website on separate HTTPS hosting. All four pages return HTTP 200 with security headers and no embedded scripts. Home was visually checked at desktop and mobile sizes; all pages fit a 390-pixel viewport without horizontal overflow. The policy describes the actual split hosting and restricted helper status. This is a website deployment, not app publication.
- Revalidated the isolated loopback gateway: nine live checks passed, including a fresh provider subtitle fetched with ambient cookies omitted, authentication rejection, two installations of the same account, ownership rejection, revocation and revoked-session rejection. An expired subtitle link returned 410; obtaining a fresh link through the existing client normalization contract succeeded. This remains one-account evidence, not multi-account or full playback acceptance.
- Entered the hosted policy/support URLs and selected sign-in **Yes** in the publisher form, but the form is **unsaved**: required administrative and technical phone numbers are missing. A dedicated paid subscriber reviewer login is also unavailable; no household credentials were disclosed to reviewers.
- Roku's overview still disables **Schedule publishing** and marks App profile and App Behavior Analysis incomplete. The uploaded analysis-only package was not replaced or submitted. The shared reverse proxy cannot reload because an existing private-network listener address is absent; its running configuration and networking were left unchanged. The app service is still restricted, not publicly available.

## Not yet completed / must not be reported as passed

- Gateway production endpoint/deployment, live multi-account provider validation, provider/browser compatibility with cookie omission, measured public load and monitoring. Protective caps are not capacity proof.
- Final administrative/technical contacts, saving the completed app profile, dedicated reviewer credentials and the app's reviewed existing-subscriber classification. Policy hosting is complete as recorded above. The app is not monetized by this publisher; its saved listing explicitly discloses the provider's paid-account requirement. No claim of free subscription content is made.
- Remaining native checks beyond the 14 deep-link cases above. Existing private precursor results do not cover the Store candidate's other changes.
- Full catalog trick-play coverage: the current worker supports only its documented HLS subset. Unsupported streams still fall back to time-only seeking. This is not a blanket certification exception.
- Full custom-caption font/edge/window styling and native/custom-track interaction, screen-reader and audio-description checks. The implemented subset is not an accessibility certification claim.
- Genuine current-device screenshots, physical audio/video/lip-sync, final candidate package replacement/resume, multi-device/performance-model checks, Dashboard Static Analysis/App Behavior Analysis and Roku review.
- Final production-configured signed package and publication. Current uploaded package is an analysis candidate, not a release-ready public-service build.

## Inputs/actions needed to finish

- Worldwide selection is now saved. Finalize support/policies with actual deployment facts; do not turn the analysis-only upload into a release candidate until operational gates pass.
- Provide dedicated reviewer access and a second authorized live provider account. Do not disclose household account credentials as reviewer credentials.
- Additional required hardware or Roku testing access remains necessary; full approval allowed testing on the idle household TCL in this session.
- Verify provider-supported preview formats/source coverage, and complete native caption work before a public certification claim.

Technical references: [publishing](https://developer.roku.com/dev/docs/channel-publishing-guide), [certification](https://developer.roku.com/dev/docs/certification), [deep links](https://developer.roku.com/dev/docs/implementing-deep-linking), [authentication events](https://developer.roku.com/dev/docs/prioritizing-authenticated-channels-in-roku-search), [launch timing](https://developer.roku.com/dev/docs/measuring-channel-performance), [manifest artwork](https://developer.roku.com/dev/docs/channel-manifest).

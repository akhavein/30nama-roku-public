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

## Contact, authentication and ingress follow-up on 2026-09-27

- Saved the completed app profile, including publisher-supplied administrative/technical phone numbers. Confirmed the profile completion indicator in the overview. Contact values are intentionally excluded from this repository.
- The account owner explicitly authorized using their own subscriber account for review. Saved it in Roku's Test Credentials page; no credentials were written to this repository. The earlier separate-reviewer-account request is no longer the blocker.
- Found a concrete authentication mismatch: the uploaded application supports email OTP, not password login. The provider website's `loginV2` API returned a CAPTCHA-parameter error to direct password authentication; its older `login/` route returned an update-required response. These responses do **not** establish whether the supplied password is valid. No CAPTCHA bypass, alternative fabricated login, or test-only entitlement was implemented.
- Completing the profile and saving credentials enabled **Schedule publishing**. Inspected and cancelled the scheduling dialog without continuing: the currently uploaded build is still analysis-only, has no production gateway origin, and lacks working automated sign-in. An enabled scheduling button is not release-readiness evidence.
- Corrected the reviewer credential description to explicitly flag the OTP-only analysis build. Roku's App Behavior Analysis requires uploaded, working RASP sign-in and sign-out scripts. No fake scripts were uploaded and no behavior pass is claimed. See [Roku authenticated-app testing](https://developer.roku.com/dev/docs/authenticated-cert-testing).
- Established a dedicated Cloudflare Tunnel on the existing isolated deployment without modifying the shared reverse proxy, Tailscale, or household helper. HTTPS health returns 200; public enrollment and all authenticated routes remain closed at the tunnel. This is **restricted ingress readiness**, not public-service acceptance. Policy hosting was updated to disclose Cloudflare's role.
- Added container restart policies and gateway/browser-backed helper health checks; enabled the isolated browser and tunnel at boot. Six live restart checks passed, including old-credential invalidation, re-enrollment, fresh subtitle delivery after browser/container restart, and revocation. A first probe attempted subtitles before browser readiness and returned 503; the final acceptance waits for the browser-backed helper readiness check. No native automatic-renewal claim follows from a script manually re-enrolling.
- Re-ran the 12 gateway regression tests successfully. Evidence: `GATEWAY-RESTART-2026-09-27.json`. One real provider account only; no TV install or playback/history change in this follow-up.

## Not yet completed / must not be reported as passed

- Gateway production endpoint/deployment, live multi-account provider validation, provider/browser compatibility with cookie omission, measured public load and monitoring. Protective caps are not capacity proof.
- Working provider-supported automated authentication and verified RASP sign-in/sign-out scripts, plus the app's reviewed existing-subscriber classification. Profile contacts, owner-authorized reviewer credentials and policy hosting are saved as recorded above. The app is not monetized by this publisher; its saved listing explicitly discloses the provider's paid-account requirement. No claim of free subscription content is made.
- Remaining native checks beyond the 14 deep-link cases above. Existing private precursor results do not cover the Store candidate's other changes.
- Full catalog trick-play coverage: the current worker supports only its documented HLS subset. Unsupported streams still fall back to time-only seeking. This is not a blanket certification exception.
- Full custom-caption font/edge/window styling and native/custom-track interaction, screen-reader and audio-description checks. The implemented subset is not an accessibility certification claim.
- Genuine current-device screenshots, physical audio/video/lip-sync, final candidate package replacement/resume, multi-device/performance-model checks, Dashboard Static Analysis/App Behavior Analysis and Roku review.
- Final production-configured signed package and publication. Current uploaded package is an analysis candidate, not a release-ready public-service build.

## Inputs/actions needed to finish

- Worldwide selection is now saved. Finalize support/policies with actual deployment facts; do not turn the analysis-only upload into a release candidate until operational gates pass.
- Resolve OTP/password/CAPTCHA compatibility for Roku automated authentication. Owner-authorized reviewer credentials are already saved; do not ask for the same phone or credentials again. A second authorized live provider account is still needed for the distinct-account acceptance gate.
- Additional required hardware or Roku testing access remains necessary; full approval allowed testing on the idle household TCL in this session.
- Verify provider-supported preview formats/source coverage, and complete native caption work before a public certification claim.

Technical references: [publishing](https://developer.roku.com/dev/docs/channel-publishing-guide), [certification](https://developer.roku.com/dev/docs/certification), [deep links](https://developer.roku.com/dev/docs/implementing-deep-linking), [authentication events](https://developer.roku.com/dev/docs/prioritizing-authenticated-channels-in-roku-search), [launch timing](https://developer.roku.com/dev/docs/measuring-channel-performance), [manifest artwork](https://developer.roku.com/dev/docs/channel-manifest).

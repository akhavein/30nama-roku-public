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

- Publisher enrolled in the Roku Developer Program; authenticated My Apps access works. The New public app form is prepared with the unofficial name, English, and Video. No app record exists yet: distribution countries remain an unanswered publisher fact.
- The exact Store candidate passed 14 isolated native deep-link checks on a TCL Roku TV: cold movie/episode, warm episode, season selection, invalid/missing targets, ordered-series start, rapid-link replacement and stale replies, signed-out handoff/cancel, launch completion and Home Back exit. See `VERIFICATION-2026-09-27.json` and `scripts/qa-store.py`. Test fixture detail responses now identify series correctly.
- Eight gateway checks passed in a separate loopback-only Linux deployment with one live provider account: authentication, invalid/unauthenticated rejection, two installations, ownership rejection, revocation and revoked-session rejection. This is **not** two-account acceptance, public deployment, or proof of subtitle/progress forwarding. Temporary candidate containers/browser were stopped after verification; the household services were not changed.
- Fixed a Compose flow-list typo that split a tmpfs mount option into an invalid second mount. The quoted mount was accepted by Docker in the candidate deployment.
- The preexisting clean TV app was restored after isolated tests. No key was generated or replaced; native Packager reports no signing identity yet.

## Not yet completed / must not be reported as passed

- Gateway production endpoint/deployment, live multi-account provider validation, provider/browser compatibility with cookie omission, measured public load and monitoring. Protective caps are not capacity proof.
- Publisher distribution rights/territories, final contact/rating details, policy hosting and the app's reviewed existing-subscriber classification.
- Remaining native checks beyond the 14 deep-link cases above. Existing private precursor results do not cover the Store candidate's other changes.
- Full catalog trick-play coverage: the current worker supports only its documented HLS subset. Unsupported streams still fall back to time-only seeking. This is not a blanket certification exception.
- Full custom-caption font/edge/window styling and native/custom-track interaction, screen-reader and audio-description checks. The implemented subset is not an accessibility certification claim.
- Genuine current-device screenshots, physical audio/video/lip-sync, final candidate package replacement/resume, multi-device/performance-model checks, Dashboard Static Analysis/App Behavior Analysis and Roku review.
- Actual app creation, Store upload, signing/package identity configuration and publication. No app-specific rights declarations have been made on the publisher's behalf.

## Inputs/actions needed to finish

- Confirm distribution territories and the relevant permission, then finalize support/rating/policies with actual deployment facts. The create-app form explicitly restricts country selection to territories with content distribution rights; submission approval is not itself that fact.
- Provide dedicated reviewer access and a second authorized live provider account. Do not disclose household account credentials as reviewer credentials.
- Additional required hardware or Roku testing access remains necessary; full approval allowed testing on the idle household TCL in this session.
- Verify provider-supported preview formats/source coverage, and complete native caption work before a public certification claim.

Technical references: [publishing](https://developer.roku.com/dev/docs/channel-publishing-guide), [certification](https://developer.roku.com/dev/docs/certification), [deep links](https://developer.roku.com/dev/docs/implementing-deep-linking), [authentication events](https://developer.roku.com/dev/docs/prioritizing-authenticated-channels-in-roku-search), [launch timing](https://developer.roku.com/dev/docs/measuring-channel-performance), [manifest artwork](https://developer.roku.com/dev/docs/channel-manifest).

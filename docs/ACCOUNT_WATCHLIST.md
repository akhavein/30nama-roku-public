# Account Watchlist (v1.6)

## Use it

Open **Account → 30nama account Watchlist**, or **Watchlist → Star → 30nama account Watchlist**. It reads the same list used by the 30nama website and other signed-in clients. Refresh or reopen it to see changes made elsewhere; this is not push/live-update sync.

Title details distinguish **TV Watchlist** and **account Watchlist**. The existing TV-only list is preserved: nothing is silently uploaded, merged, or deleted. Account list changes need a working sign-in and network connection. No new helper or separate account is required.

- FF / Rewind changes provider pages; Star offers refresh, type filter, and title sorting.
- Filtering/sorting apply to the current provider page. Counts state that scope.
- Back from details reloads the account page and restores the selected title when it still exists.
- Playback and the TV-only list continue independently if the account-list service fails.

## The important write contract

The provider's own website SDK calls `user_mylist` for membership, `mylist/group/watchlist/page/{page}` for titles, and `add_to_mylist/id/{id}/group/watchlist` to **toggle** membership. The last operation is not an idempotent add or remove.

Each intentional action records its desired membership, reads current membership first, sends at most one toggle only if needed, then reads membership back. A successful HTTP response is not enough. A lost response triggers bounded read-only verification, never automatic replay of the toggle. Rapid repeat presses are ignored briefly, including after fast completion.

If verification remains uncertain after three reads, the app says so and invalidates its cached membership. The next press checks membership; it does not blindly retry the old write. There is no persisted offline write queue. Concurrent phone/website changes cannot be made atomic through this API; mismatch is reported rather than fought with more toggles.

Transactions may finish after navigating away but cannot redirect playback or update another title's status. Session epochs protect against old-account callbacks. Sign-out clears account-specific data and cancels verification timers; a request already accepted by the provider may still finish there. Account lists stay memory-only and are reloaded after app restart, avoiding registry capacity and cross-account cache leaks.

## Verification

Read-only account probes returned the original four-title list. A controlled direct API add/readback/remove/readback restored the exact original membership. Device and clean-build verification are recorded in the release report; no second physical TV or independent phone client is implied by API readback.

## Separate remaining work

Thumbnail previews are not added here. The prior fresh samples exposed no indexed images or image-playlist tags. A separate bounded image-generation worker would need provider-host validation, private signed-URL handling, cancellation, resource/storage limits, and latency measurements before deployment. It must not block playback or depend on the Mac staying awake. Roku accepts indexed BIF/HLS/DASH images: [official trick-mode documentation](https://developer.roku.com/dev/docs/trick-mode).

Viewer profiles remain separate: there is no verified provider profile-selection contract in this implementation. Local profile names alone would not establish cross-device profile isolation.

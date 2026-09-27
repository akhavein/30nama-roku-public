# v1.4 watching experience

Implemented in order, with a clean package/regression gate after each feature. Native verification is recorded separately and is not inferred from desktop tests.

1. **Episode ledger:** independent episode resume and watched/unwatched controls; migration imports only known saved episodes, never guesses that earlier episodes were watched. Manual marking is local to this TV and does not fabricate website playback. Continue remains one target per series. A different episode's Continue target is unchanged by manual marking. Recent cloud checkpoints for the same episode supersede an older ledger entry.
2. **Watchlist organization:** All/Movies/Series and Recently added/Title sorting via Star. Saved view preferences and identity-based focus; sorting does not rewrite insertion order.
3. **Search views:** All/Movies/Series plus relevance/title/rating within the current provider page. Labels state the scope and visible/page counts. No invented global totals; provider pagination, network errors, original query, and cache remain intact.
4. **Remote preferences:** Account → Playback preferences. Left/Right and toolbar 5/10/15/30 seconds; FF/Rewind 10/30/60 seconds; Replay 5/10/15/30 seconds. Existing 10/30/10 defaults, pause preservation, keyframe limits, and cumulative seeking retained.
5. **External subtitle appearance:** Down → External subtitle appearance. Standard/Solid/Soft black backing and Bottom/Raised/Top placement. Works with English/Persian, size, and per-title timing settings. Positions remain inside the safe area and above controls. Embedded captions still use Roku's native styling.
6. **Sleep controls:** Account preferences or the player's Sleep button. 30/60/90/120-minute timer, or Off; session-only and not restored after app exit. Expiry saves and closes playback, cancels next-episode countdown, and leaves the title ready to resume. Optional 60/120/180-minute still-watching check counts playback without remote input across episodes, pauses with a saved checkpoint, and requires OK/Play to continue or Back to stop. Both are Off by default. They do not power off the TV.

## Persistence and storage

Roku provides a 32KB app registry ([official registry reference](https://developer.roku.com/dev/docs/ifregistry)). The new episode ledger uses compact numeric rows, a maximum 120 recent entries, a 4KB serialized budget, and trims older records further when available space is low, reserving 2KB for other settings. This is bounded local history, not a permanent archive. Existing current-series resume remains independent.

## Later work, not included

Thumbnail scrubbing needs indexed images or a separately evaluated generation pipeline. Provider-backed manual Skip Intro was subsequently implemented in v1.5; see [intro skipping](INTRO_SKIPPING.md). Provider-backed account Watchlist was subsequently implemented in v1.6; see [account Watchlist](ACCOUNT_WATCHLIST.md). Viewer profiles and thumbnail previews remain separate work.

## Verification

See the v1.4 verification report when published. v1.3's two-hour soak proves only the prior released ZIP, not this revision. Native synthetic media is silent; physical picture/audio/lip-sync requires direct observation.

# Privacy notice — draft for the proposed public service

**Not an active public-service policy.** Confirm the operator, public support contact, hosting region and deployed configuration before publication. No public service is announced by this document.

This unofficial client is separate from 30nama. An existing 30nama account is required; 30nama processes catalog, login, subscription, Watchlist and playback requests under its own policies.

## On your TV

The app stores its login session, viewing progress, Watchlist, recent searches and preferences in Roku app storage. It also creates a random installation identifier to manage a service connection; this is not your Roku hardware serial or advertising identifier. Sign-out removes the active account session and local viewing history, recent searches and TV-only Watchlist. Playback preferences remain on the device. Account-side history and Watchlist are not deleted by signing out or clearing local data.

## Optional app-operated service

For a configured public distribution, the app's service verifies your 30nama session and temporarily processes it to provide account-bound progress updates, subtitle delivery and scene previews. It receives the installation identifier, account identifier, relevant media IDs/progress and signed subtitle/media URLs. The implementation does not intentionally record these request bodies or credentials in logs, sell this information, or use it for advertising.

Gateway sessions are held only in memory for up to 15 minutes; sign-out attempts immediate revocation. If the TV is offline, expiry limits the session lifetime instead. A request already sent to 30nama may finish after sign-out. Subtitle and preview services use short, bounded memory caches; no permanent video library is generated. Provider servers still receive network requests required to play and resume content.

Operators must configure infrastructure logs to exclude credentials, bodies and signed URLs. **Before publishing:** document actual IP/access-log retention, hosting/provider subprocessors and support/deletion contacts. Those deployment facts are not yet finalized.

## Roku integration

The app reports the Roku-required authenticated event after a successful account-profile check and signals launch completion. Roku processes platform information under Roku's own policies. These integrations do not send the app's provider session token as event metadata.

## Controls and contact

Users can sign out, clear local viewing data, manage subtitles/preferences and remove account Watchlist entries in the app. Clearing local data does not delete provider-side history or the provider account. A final public notice must identify the operator and a working privacy/support contact before the service opens.

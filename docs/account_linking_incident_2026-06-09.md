# Account Linking Incident - 2026-06-09

## Symptoms

- After logging in with Google A, then Google B, the app did not reliably ask to link to the existing app account.
- Places could be counted in Settings but not shown in My Places.
- Alarm creation could become impossible because the visible place list was empty.

## Root Causes

1. Provider sign-in methods called `ensureServerSession()` immediately.
   - This allowed the server to mutate canonical account state before the app could ask for user consent.

2. `createSession` treated the device identity as an authoritative account identity.
   - A different Firebase UID on the same device could be linked automatically before explicit consent.

3. `LoginPage` navigated directly to `/home`.
   - This bypassed `_AuthenticatedHome`, so `activeOwnerUid` was not guaranteed to be applied before My Places loaded.

4. Logout cleanup cleared `activeOwnerUid` asynchronously.
   - A delayed cleanup could race with a new login and hide local places.

5. `lastFirebaseUid` was used too aggressively as a link prompt signal.
   - If two providers were already linked to the same canonical account, switching between them could still prompt again.

## Fixes Applied

- Server `createSession` now returns `409 device_account_link_required` when a device account exists and the new provider identity is not yet linked.
- Client now shows the account-link consent dialog only after that server signal, then retries with `allowDeviceAccountLink=true`.
- Provider sign-in methods no longer create a server session directly.
- `LoginPage` no longer pushes `/home` directly after sign-in.
- `_AuthenticatedHome` blocks the main UI until a non-null canonical session is ready.
- Logout cleanup rechecks `FirebaseAuth.currentUser` before clearing `activeOwnerUid`.
- Unlinked identity records are ignored when resolving canonical accounts.

## Regression Checklist

- First login on a fresh install creates one canonical account and enters the app.
- Logging out and logging in with another provider on the same device asks for link consent.
- Accepting link consent returns the original canonical account.
- Declining link consent signs out and does not enter the app.
- My Places shows places owned by the active canonical account.
- Settings local counts and My Places visible count do not diverge for active-owner data.
- No route should push `/home` directly before canonical owner application.

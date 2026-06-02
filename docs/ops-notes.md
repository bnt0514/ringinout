# Ringinout Operations Notes

## Known Edge Cases

### Wi-Fi entry alarm when Wi-Fi reconnects before GPS ENTER

Status: documented only. No code change applied yet.

Observed during developer testing:

- A Wi-Fi exit alarm fired after leaving only far enough for Wi-Fi to disconnect.
- The user re-entered shortly after.
- Wi-Fi may reconnect before the GPS/geofence ENTER event is delivered.
- If the place state is still considered inside at the Wi-Fi ENTER moment, that Wi-Fi ENTER can be ignored as an already-inside event.
- When GPS ENTER arrives later, the system records a pending GPS entry and waits for Wi-Fi confirmation.
- Because Wi-Fi is already connected, a new Wi-Fi ENTER event may not arrive.
- In that case, the 15-minute Wi-Fi wait fallback is expected to handle the alarm if the user is still inside.

Why this is low priority:

- The test path is artificial: leaving only to the Wi-Fi boundary and quickly returning.
- Real users usually leave farther away, causing a cleaner GPS EXIT/ENTER sequence.
- The current 15-minute fallback is intended to cover missed Wi-Fi confirmation after GPS ENTER.

Possible future improvement:

- When GPS ENTER is received and the target Wi-Fi is already tracked as connected, start a short Wi-Fi stability check and trigger the entry alarm after the normal stability window instead of waiting for the 15-minute fallback.
- Keep the 15-minute fallback as the safety net.

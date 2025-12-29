End-to-end test plan — Admin / Driver approval / Live Map

This document describes how to validate the end-to-end driver onboarding and admin approval flow, plus the Live Map and audit features added to the admin dashboard.

Prerequisites

- Firebase CLI installed (firebase-tools)
- Optional: Firebase Emulator Suite for local testing
- A Firebase project (project id: `esaferide` is used in this repo)

Quick manual flow (using real Firebase project)

1. Start the app (web or mobile) and sign in with an admin account (one that has a `users/{uid}` doc with `role: 'admin'` or a custom claim `admin: true`). If you don't have an admin yet, create a Firestore document for your auth uid under `users/{uid]` with `role: 'admin'`.

2. Driver submission

- Sign in as a driver user (or create one via the app).
- Open Driver Profile and fill in details. Tap "Save & Continue".
- Verify the driver's document in Firestore `drivers/{uid}` contains:
  - `status: 'pending'`
  - `verified: false`
  - `submittedAt` timestamp

3. Admin review & approve/reject

- Sign in as admin and open Admin → Drivers.
- Select the "Pending" filter chip. You should see the driver you just submitted.
- Tap "View" to inspect uploaded docs and the profile.
- Tap "Verify" to approve. This will update the driver doc to `verified: true` and `status: 'active'` and write `admin_audit` and `notifications` entries.
- Or tap "Reject" to open a dialog asking for a reason. Enter a reason and confirm. The driver doc will be updated with `status: 'rejected'`, `rejectionReason` and an `admin_audit` entry will be added. The driver will receive a notification with the reason.

4. Ride assignment & Live Map

- Create a ride (student) or use existing ride doc with `status: 'accepted'` / `on_the_way` / `active`.
- Open Admin → Live Map. Active rides should appear in the list and as markers on the map.
- Driver, pickup and destination markers show with different colors. When both pickup and destination present, a polyline shows the route.
- Tap a ride in the list or marker info window to see details and center the map.

Firestore rules (recommended)

- A `firestore.rules` file was added to the repo. It contains statements to prevent unverified drivers from accepting rides (and to restrict writes to drivers and admin_audit collections). Deploy with:

```bash
firebase deploy --only firestore:rules --project <your-project-id>
```

Local emulator testing (recommended)

- Start the emulator:

```bash
firebase emulators:start --only firestore,auth
```

- Seed data in the emulator (create an admin user and driver docs) using the Firebase console emulator UI or use a small script (not included) to write documents to the emulator.

Notes / verification

- Admin actions write to the `admin_audit` collection — use Admin → Audit to view them.
- Rejection includes an optional `rejectionReason` stored on the driver doc and in `admin_audit`, and is included in the notification body.
- The Live Map requires the `google_maps_flutter` plugin — ensure your emulator/device supports Google Maps or run on a platform with maps enabled.

If you want, I can:

- Create a small Node script to seed an `admin` users doc and a driver test doc in Firestore (works with emulator or real project).
- Add an automated test that uses the Firestore emulator to validate submission → admin approval flow in CI. This requires a small amount of test harness wiring; tell me if you'd like me to add it.

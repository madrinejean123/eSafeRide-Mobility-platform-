import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

declare const console: any;

admin.initializeApp();

// Trigger on new notification documents in the top-level `notifications` collection.
export const onNotificationCreate = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    if (!notif) return;

    const title = notif.title || 'Notification';
    const body = notif.body || '';
    const type = notif.type || 'generic';

    const payload: admin.messaging.MulticastMessage | admin.messaging.Message = {
      notification: {
        title,
        body,
      },
      data: {
        type,
      },
    } as any;

    // If the notification targets a topic, send to topic
    if (notif.topic) {
      try {
        await admin.messaging().sendToTopic(notif.topic, payload as any);
        console.log('Sent topic notification to', notif.topic);
      } catch (err) {
        console.error('Error sending topic notification', err);
      }
      return;
    }

    // Otherwise resolve user's FCM token stored in users/{userId}.fcmToken
    const userId = notif.userId;
    if (!userId) {
      console.log('No userId on notification, skipping FCM send');
      return;
    }

    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      const fcmToken = userDoc.exists ? userDoc.data()?.fcmToken : null;
      if (fcmToken) {
        // support array or single token
        const tokens = Array.isArray(fcmToken) ? fcmToken : [fcmToken];
        const m = {
          tokens,
          notification: {
            title,
            body,
          },
          data: { type },
        };
        const resp = await admin.messaging().sendMulticast(m as admin.messaging.MulticastMessage);
        console.log('FCM send result', resp);
      } else {
        console.log('No fcmToken for user', userId);
      }
    } catch (err) {
      console.error('Error sending notification', err);
    }
  });

// HTTPS function that proxies Directions API requests so the API key stays secret.
export const getDirections = functions.https.onRequest(async (req, res) => {
  // Allow CORS from any origin (adjust in production as needed).
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  const origin = req.query.origin as string | undefined;
  const destination = req.query.destination as string | undefined;

  if (!origin || !destination) {
    res.status(400).json({ error: 'Missing origin or destination query parameter' });
    return;
  }

  const mapsKey = functions.config().maps?.key;
  if (!mapsKey) {
    res.status(500).json({ error: 'Server misconfigured: maps.key not set in functions config' });
    return;
  }

  try {
    const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(
      origin,
    )}&destination=${encodeURIComponent(destination)}&mode=driving&alternatives=false&key=${mapsKey}`;

    // Node 18+ has global fetch
    const r = await fetch(url);
    const data = await r.json();
    res.json(data);
  } catch (err: any) {
    console.error('Error fetching directions', err);
    res.status(500).json({ error: 'Error fetching directions', details: err?.toString() });
  }
});

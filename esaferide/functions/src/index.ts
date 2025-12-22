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

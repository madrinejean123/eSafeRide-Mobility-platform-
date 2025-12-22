"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onNotificationCreate = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
exports.onNotificationCreate = functions.firestore
    .document('notifications/{notifId}')
    .onCreate(async (snap, context) => {
    const notif = snap.data();
    if (!notif)
        return;
    const title = notif.title || 'Notification';
    const body = notif.body || '';
    const type = notif.type || 'generic';
    const payload = {
        notification: {
            title,
            body,
        },
        data: {
            type,
        },
    };
    if (notif.topic) {
        try {
            await admin.messaging().sendToTopic(notif.topic, payload);
            console.log('Sent topic notification to', notif.topic);
        }
        catch (err) {
            console.error('Error sending topic notification', err);
        }
        return;
    }
    const userId = notif.userId;
    if (!userId) {
        console.log('No userId on notification, skipping FCM send');
        return;
    }
    try {
        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        const fcmToken = userDoc.exists ? userDoc.data()?.fcmToken : null;
        if (fcmToken) {
            const tokens = Array.isArray(fcmToken) ? fcmToken : [fcmToken];
            const m = {
                tokens,
                notification: {
                    title,
                    body,
                },
                data: { type },
            };
            const resp = await admin.messaging().sendMulticast(m);
            console.log('FCM send result', resp);
        }
        else {
            console.log('No fcmToken for user', userId);
        }
    }
    catch (err) {
        console.error('Error sending notification', err);
    }
});
//# sourceMappingURL=index.js.map
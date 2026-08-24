import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const sendPushNotification = functions.firestore
  .document("users/{uid}/notifications/{notifId}")
  .onCreate(async (snap, context) => {
    const { uid } = context.params;
    const notification = snap.data();
    
    const db = admin.firestore();
    const fcm = admin.messaging();

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;
    
    const userData = userDoc.data();
    const tokens = userData?.fcmTokens || [];
    if (tokens.length === 0) return;
    
    const payload = {
      notification: {
        title: notification.title || "Poker Night",
        body: notification.body || "",
      },
      data: {
        link: notification.link || "",
        type: notification.type || "",
      }
    };
    
    try {
      const response = await fcm.sendToDevice(tokens, payload);
      const tokensToRemove: string[] = [];
      response.results.forEach((result, index) => {
        const error = result.error;
        if (error) {
          if (error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered') {
            tokensToRemove.push(tokens[index]);
          }
        }
      });
      
      if (tokensToRemove.length > 0) {
        await userDoc.ref.update({
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
        });
      }
    } catch (e) {
      console.error("Error sending push notification", e);
    }
  });

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

export const sendPushNotification = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
  async (event) => {
    const { uid } = event.params;
    const notification = event.data?.data();
    if (!notification) return;

    const db = getFirestore();
    const fcm = getMessaging();

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const tokens: string[] = userData?.fcmTokens || [];
    if (tokens.length === 0) return;

    const payload = {
      notification: {
        title: notification.title || "Poker Night",
        body: notification.body || "",
      },
      data: {
        link: notification.link || "",
        type: notification.type || "",
      },
    };

    try {
      const response = await fcm.sendEachForMulticast({
        tokens,
        notification: payload.notification,
        data: payload.data,
      });

      const tokensToRemove: string[] = [];
      response.responses.forEach((result, index) => {
        const error = result.error;
        if (error) {
          if (
            error.code === "messaging/invalid-registration-token" ||
            error.code === "messaging/registration-token-not-registered"
          ) {
            tokensToRemove.push(tokens[index]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        await userDoc.ref.update({
          fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
        });
      }
    } catch (e) {
      console.error("Error sending push notification", e);
    }
  }
);

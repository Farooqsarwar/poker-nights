import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

// L12 / C6: the ONLY cross-user notification path is the group fan-out
// function (Admin SDK), because Firestore rules deny clients from writing into
// any inbox other than their own. This trigger therefore only ever pushes a
// box-owner-scoped notification. As defense-in-depth we still validate the
// document shape and refuse to push malformed/blank notifications.
export const sendPushNotification = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
  async (event) => {
    const { uid } = event.params;
    const notification = event.data?.data();
    if (!notification) return;

    const title = String(notification.title || "").slice(0, 200);
    const body = String(notification.body || "").slice(0, 300);
    if (!title && !body) return; // nothing meaningful to push

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

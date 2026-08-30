"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPushNotification = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("firebase-admin/firestore");
const messaging_1 = require("firebase-admin/messaging");
// L12 / C6: the ONLY cross-user notification path is the group fan-out
// function (Admin SDK), because Firestore rules deny clients from writing into
// any inbox other than their own. This trigger therefore only ever pushes a
// box-owner-scoped notification. As defense-in-depth we still validate the
// document shape and refuse to push malformed/blank notifications.
exports.sendPushNotification = (0, firestore_1.onDocumentCreated)("users/{uid}/notifications/{notifId}", async (event) => {
    var _a;
    const { uid } = event.params;
    const notification = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!notification)
        return;
    const title = String(notification.title || "").slice(0, 200);
    const body = String(notification.body || "").slice(0, 300);
    if (!title && !body)
        return; // nothing meaningful to push
    const db = (0, firestore_2.getFirestore)();
    const fcm = (0, messaging_1.getMessaging)();
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists)
        return;
    const userData = userDoc.data();
    const tokens = (userData === null || userData === void 0 ? void 0 : userData.fcmTokens) || [];
    if (tokens.length === 0)
        return;
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
        const tokensToRemove = [];
        response.responses.forEach((result, index) => {
            const error = result.error;
            if (error) {
                if (error.code === "messaging/invalid-registration-token" ||
                    error.code === "messaging/registration-token-not-registered") {
                    tokensToRemove.push(tokens[index]);
                }
            }
        });
        if (tokensToRemove.length > 0) {
            await userDoc.ref.update({
                fcmTokens: firestore_2.FieldValue.arrayRemove(...tokensToRemove),
            });
        }
    }
    catch (e) {
        console.error("Error sending push notification", e);
    }
});
//# sourceMappingURL=push.js.map
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.scheduledEventReminders = void 0;
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firestore_1 = require("firebase-admin/firestore");
exports.scheduledEventReminders = (0, scheduler_1.onSchedule)("every 15 minutes", async () => {
    var _a;
    const db = (0, firestore_1.getFirestore)();
    const oneHourAndFifteenFromNow = new Date(Date.now() + 75 * 60 * 1000);
    const gamesSnapshot = await db
        .collectionGroup("games")
        .where("status", "in", ["published", "checkin"])
        .get();
    const notificationsToSend = [];
    for (const gameDoc of gamesSnapshot.docs) {
        const game = gameDoc.data();
        if (!game.settings.date || !game.settings.time)
            continue;
        const scheduledStart = new Date(`${game.settings.date}T${game.settings.time}`);
        if (scheduledStart > new Date() &&
            scheduledStart <= oneHourAndFifteenFromNow) {
            if ((_a = game.remindersSent) === null || _a === void 0 ? void 0 : _a.oneHour)
                continue;
            const activePlayers = (game.players || []).filter((p) => !p.isGuest &&
                (p.rsvp === "going" ||
                    (typeof p.rsvp === "string" && p.rsvp.startsWith("going"))));
            for (const p of activePlayers) {
                notificationsToSend.push({
                    uid: p.id,
                    title: `Poker Night: ${game.settings.name}`,
                    body: `Your event is starting soon!`,
                    type: "event_reminder",
                    link: `game/${gameDoc.id}`,
                });
            }
            await gameDoc.ref.update({
                "remindersSent.oneHour": true,
            });
        }
    }
    const batch = db.batch();
    for (const n of notificationsToSend) {
        const notifRef = db
            .collection("users")
            .doc(n.uid)
            .collection("notifications")
            .doc();
        batch.set(notifRef, {
            id: notifRef.id,
            title: n.title,
            body: n.body,
            type: n.type,
            link: n.link,
            read: false,
            timestamp: firestore_1.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
});
//# sourceMappingURL=scheduler.js.map
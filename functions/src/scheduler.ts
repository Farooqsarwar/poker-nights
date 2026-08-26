import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

export const scheduledEventReminders = onSchedule(
  "every 15 minutes",
  async () => {
    const db = getFirestore();

    const oneHourAndFifteenFromNow = new Date(Date.now() + 75 * 60 * 1000);

    const gamesSnapshot = await db
      .collectionGroup("games")
      .where("status", "in", ["published", "checkin"])
      .get();

    const notificationsToSend: Array<{
      uid: string;
      title: string;
      body: string;
      type: string;
      link: string;
    }> = [];

    for (const gameDoc of gamesSnapshot.docs) {
      const game = gameDoc.data();
      if (!game.settings.date || !game.settings.time) continue;

      const scheduledStart = new Date(
        `${game.settings.date}T${game.settings.time}`
      );

      if (
        scheduledStart > new Date() &&
        scheduledStart <= oneHourAndFifteenFromNow
      ) {
        if (game.remindersSent?.oneHour) continue;

        const activePlayers = (game.players || []).filter(
          (p: Record<string, unknown>) =>
            !p.isGuest &&
            (p.rsvp === "going" ||
              (typeof p.rsvp === "string" && p.rsvp.startsWith("going")))
        );

        for (const p of activePlayers) {
          notificationsToSend.push({
            uid: p.id as string,
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
        timestamp: FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
);

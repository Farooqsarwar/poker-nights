import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const scheduledEventReminders = functions.pubsub.schedule('every 15 minutes').onRun(async (context) => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  
  // Look for games that are published/open but haven't started yet.
  // In a real app we might want a specific collection, or a query.
  // For now, let's query the groups collection to find all games.
  // Note: doing a collection group query requires an index.
  
  // We'll search for games starting in the next 60 minutes
  const oneHourFromNow = new Date(Date.now() + 60 * 60 * 1000);
  const oneHourAndFifteenFromNow = new Date(Date.now() + 75 * 60 * 1000);
  
  // To avoid querying all games if not indexed, we assume an index exists on settings.date & settings.time or we query by status.
  const gamesSnapshot = await db.collectionGroup("games")
    .where("status", "in", ["published", "checkin"])
    .get();

  const notificationsToSend: any[] = [];

  for (const gameDoc of gamesSnapshot.docs) {
    const game = gameDoc.data();
    if (!game.settings.date || !game.settings.time) continue;
    
    // Parse scheduledStart
    const scheduledStart = new Date(`${game.settings.date}T${game.settings.time}`);
    
    // If the game starts within the next 1 hour, and we haven't reminded yet
    if (scheduledStart > new Date() && scheduledStart <= oneHourAndFifteenFromNow) {
      // It's starting in less than 75 mins, so we can send a 1-hour reminder.
      // We should check if we already sent a reminder to prevent duplicates.
      // Easiest is to stamp the game doc
      if (game.remindersSent?.oneHour) continue;
      
      const activePlayers = (game.players || []).filter((p: any) => !p.isGuest && (p.rsvp === "going" || p.rsvp?.startsWith("going")));
      for (const p of activePlayers) {
        notificationsToSend.push({
          uid: p.id,
          notification: {
            title: `Poker Night: ${game.settings.name}`,
            body: `Your event is starting soon!`,
            type: "event_reminder",
            link: `game/${gameDoc.id}`
          }
        });
      }
      
      // Mark reminder sent
      await gameDoc.ref.update({
        "remindersSent.oneHour": true
      });
    }
  }
  
  // Fan out notifications
  const batch = db.batch();
  for (const n of notificationsToSend) {
    const notifRef = db.collection("users").doc(n.uid).collection("notifications").doc();
    batch.set(notifRef, {
      id: notifRef.id,
      title: n.notification.title,
      body: n.notification.body,
      type: n.notification.type,
      link: n.notification.link,
      read: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  }
  
  await batch.commit();
});

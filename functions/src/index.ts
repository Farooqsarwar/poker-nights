import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const fcm = admin.messaging();

export const onGameWrite = functions.firestore
  .document("groups/{gid}/games/{gameId}")
  .onWrite(async (change, context) => {
    const { gid, gameId } = context.params;
    if (!change.after.exists) {
      // Game deleted, clean up projections
      await db.collection("publicGames").doc(gameId).delete();
      return;
    }

    const game = change.after.data();

    // 1. Generate Projections
    // We recreate the projections in Node.js similar to projections.dart

    const publicSettings = {
      ...game.settings,
      organizerPct: 0,
      forcePaidPlaces: null,
    };

    const tvProjection = {
      ...game,
      settings: publicSettings,
      structure: {
        ...game.structure,
        organizerAmount: 0,
        prizes: (game.structure?.prizes || []).map((p: any) => ({ place: p.place, amount: 0 }))
      },
      players: (game.players || []).map((p: any) => ({
        ...p, rebuys: 0, reEntries: 0, hasAddOn: false, knockouts: 0
      })),
      chat: [],
      auditHistory: [],
      pendingGuests: [],
      rebuyRequests: [],
      addOnRequests: [],
    };

    const guestProjection = { ...tvProjection };

    const batch = db.batch();

    // Write world-readable publicGames/{gameId}
    const publicRef = db.collection("publicGames").doc(gameId);
    batch.set(publicRef, {
      gid,
      publicCode: game.publicCode || "",
      tvCode: game.tvCode || "",
      status: game.status,
      tv: tvProjection,
      guest: guestProjection,
    });

    // Write individualized player projections to groups/{gid}/games/{gameId}/memberViews/{playerId}
    // We only need to do this for registered members (isGuest == false) who have an id.
    const memberViewsRef = change.after.ref.collection("memberViews");
    const activePlayers = (game.players || []).filter((p: any) => !p.isGuest && p.id);
    for (const p of activePlayers) {
      const viewerId = p.id;
      const playerProjection = {
        ...game,
        settings: publicSettings,
        structure: {
          ...game.structure,
          organizerAmount: 0,
          prizes: (game.structure?.prizes || []).map((p: any) => ({ place: p.place, amount: 0 }))
        },
        players: (game.players || []).map((otherP: any) => {
          if (otherP.id === viewerId) return otherP;
          return { ...otherP, rebuys: 0, reEntries: 0, hasAddOn: false, knockouts: 0 };
        }),
        chat: game.chat || [], // Players can see chat
        auditHistory: [],
        pendingGuests: [],
        rebuyRequests: (game.rebuyRequests || []).filter((id: string) => id === viewerId),
        addOnRequests: (game.addOnRequests || []).filter((id: string) => id === viewerId),
      };
      
      batch.set(memberViewsRef.doc(viewerId), playerProjection);
    }

    await batch.commit();
  });

export * from './push';
export * from './scheduler';

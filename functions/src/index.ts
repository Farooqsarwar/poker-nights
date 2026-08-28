import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

admin.initializeApp();
const db = getFirestore();

// ── Input Sanitization ───────────────────────────────────────────────────────
// Spec §22: "Sanitize all chat, poll and name input."
function sanitize(input: string): string {
  return input
    .replace(/<(script|style|iframe|object|embed)[^>]*>.*?<\/\1>/gis, "")
    .replace(/<[^>]*>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim()
    .substring(0, 1000); // max chat length
}

// ── Rate Limiting ────────────────────────────────────────────────────────────
const RATE_LIMITS: Record<string, number> = {
  rsvp: 10,
  checkIn: 5,
  rebuyAddon: 20,
  guestClaim: 5,
  chat: 30,
  seatChange: 10,
};

async function checkRateLimit(
  uid: string,
  action: string,
  limit: number
): Promise<boolean> {
  const docId = `${uid}_${action}`;
  const ref = db.collection("rate_limits").doc(docId);
  const snap = await ref.get();
  const now = Date.now();
  const windowMs = 60_000; // 1 minute

  if (snap.exists) {
    const data = snap.data()!;
    const ts = data.timestamp?.toMillis?.() ?? data.timestamp ?? 0;
    const count = data.count ?? 0;
    if (now - ts < windowMs) {
      if (count >= limit) return false;
      await ref.update({ count: count + 1 });
    } else {
      await ref.set({ timestamp: now, count: 1 });
    }
  } else {
    await ref.set({ timestamp: now, count: 1 });
  }
  return true;
}

export const rateLimitedSubmitRequest = onCall(
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const { kind, gid, ...rest } = request.data || {};
    if (!kind || !gid) throw new HttpsError("invalid-argument", "kind and gid required.");

    let action = "checkIn";
    let limit = RATE_LIMITS.checkIn;
    if (kind === "rebuyReq" || kind === "addOnReq") {
      action = "rebuyAddon";
      limit = RATE_LIMITS.rebuyAddon;
    } else if (kind === "guestCheckIn") {
      action = "guestClaim";
      limit = RATE_LIMITS.guestClaim;
    }

    const allowed = await checkRateLimit(request.auth.uid, action, limit);
    if (!allowed) throw new HttpsError("resource-exhausted", "Rate limit exceeded. Try again later.");

    const gameId = request.data.gameId;
    if (!gameId) throw new HttpsError("invalid-argument", "gameId required.");
    const reqRef = db.collection("requests").doc(gameId).collection("items").doc();
    await reqRef.set({
      kind,
      gid,
      playerId: request.auth.uid,
      ...rest,
      createdAt: FieldValue.serverTimestamp(),
      consumed: false,
    });
    return { ok: true };
  }
);

export const rateLimitedChat = onCall(
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");
    const { gameId, body, authorId, authorName, groupId } = request.data || {};
    if (!gameId || !body) throw new HttpsError("invalid-argument", "gameId and body required.");

    const allowed = await checkRateLimit(request.auth.uid, "chat", RATE_LIMITS.chat);
    if (!allowed) throw new HttpsError("resource-exhausted", "Too many messages. Wait a moment.");

    // Spec §22: sanitize chat body server-side before persisting.
    const sanitizedBody = sanitize(body);
    if (!sanitizedBody) throw new HttpsError("invalid-argument", "Message cannot be empty.");

    const msgRef = db.collection("groups").doc(groupId).collection("chat").doc();
    await msgRef.set({
      id: msgRef.id,
      authorId,
      authorName,
      body: sanitizedBody,
      timestamp: FieldValue.serverTimestamp(),
      deleted: false,
      pinned: false,
      gameId: gameId,
    });
    return { ok: true };
  }
);

// ── Game Write Projections ───────────────────────────────────────────────────
export const onGameWrite = onDocumentWritten(
  "groups/{gid}/games/{gameId}",
  async (event) => {
    const { gid, gameId } = event.params;
    const change = event.data;

    if (!change) {
      await db.collection("publicGames").doc(gameId).delete();
      return;
    }

    if (!change.after.exists) {
      await db.collection("publicGames").doc(gameId).delete();
      return;
    }

    const game = change.after.data();
    if (!game) {
      await db.collection("publicGames").doc(gameId).delete();
      return;
    }

    const publicSettings = {
      ...game.settings,
      organizerPct: 0,
      forcePaidPlaces: null,
    };

    const projectPlayer = (p: Record<string, unknown>) => ({
      id: p.id,
      name: p.name,
      isGuest: p.isGuest,
      inviterId: p.inviterId,
      guestSlot: p.guestSlot,
      rsvp: p.rsvp,
      checkedIn: p.checkedIn,
      confirmed: p.confirmed,
      eliminated: p.eliminated,
      eliminationPos: p.eliminationPos,
      table: p.table,
      seat: p.seat,
      active: p.active,
      rebuys: 0,
      reEntries: 0,
      hasAddOn: false,
      knockouts: 0,
    });

    const projectGuestSlot = (s: Record<string, unknown>) => ({
      id: s.id,
      slot: s.slot,
      guestName: s.guestName,
      status: s.status,
    });

    const tvProjection = {
      id: game.id,
      groupId: game.groupId,
      status: game.status,
      settings: publicSettings,
      structure: {
        ...game.structure,
        organizerAmount: 0,
        prizes: (game.structure?.prizes || []).map((p: Record<string, unknown>) => ({
          place: p.place,
          amount: 0,
        })),
      },
      players: (game.players || []).map(projectPlayer),
      currentLevel: game.currentLevel,
      timerRunning: game.timerRunning,
      secondsRemaining: game.secondsRemaining,
      levelEndTime: game.levelEndTime,
      totalChipsInPlay: game.totalChipsInPlay,
      finishOrder: game.finishOrder || [],
      speedRecommendation: game.speedRecommendation,
      settlementConfirmed: game.settlementConfirmed,
      seatingConfirmed: game.seatingConfirmed,
      checkInClosed: game.checkInClosed,
      structureConfirmed: game.structureConfirmed,
      dealerPlayerId: game.dealerPlayerId,
      guestSlots: (game.guestSlots || []).map(projectGuestSlot),
      announcements: game.announcements || [],
      changeLog: game.changeLog || [],
      chat: [],
      auditHistory: [],
      pendingGuests: [],
      rebuyRequests: [],
      addOnRequests: [],
    };

    const guestProjection = { ...tvProjection };

    const batch = db.batch();

    const publicRef = db.collection("publicGames").doc(gameId);
    batch.set(publicRef, {
      gid,
      publicCode: game.publicCode || "",
      tvCode: game.tvCode || "",
      status: game.status,
      tv: tvProjection,
      guest: guestProjection,
    }, { merge: true });

    const memberViewsRef = change.after.ref.collection("memberViews");
    const activePlayers = (game.players || []).filter(
      (p: Record<string, unknown>) => !p.isGuest && p.id
    );
    for (const p of activePlayers) {
      const viewerId = p.id;
      const playerProjection = {
        ...tvProjection,
        players: (game.players || []).map((otherP: Record<string, unknown>) => {
          if (otherP.id === viewerId) return otherP;
          return projectPlayer(otherP);
        }),
        chat: game.chat || [],
        rebuyRequests: (game.rebuyRequests || []).filter(
          (id: string) => id === viewerId
        ),
        addOnRequests: (game.addOnRequests || []).filter(
          (id: string) => id === viewerId
        ),
      };

      batch.set(memberViewsRef.doc(viewerId as string), playerProjection, {
        merge: true,
      });
    }

    await batch.commit();
  }
);

export * from "./push";
export * from "./scheduler";

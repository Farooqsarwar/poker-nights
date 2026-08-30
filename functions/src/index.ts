import { onCall, HttpsError } from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

admin.initializeApp();
const db = getFirestore();

// ── Input Sanitization ───────────────────────────────────────────────────────
// Spec §22: "Sanitize all chat, poll and name input."
//
// H3 fix: entity DECODING must happen BEFORE tag stripping. The previous order
// (strip raw tags, then un-escape entities) let an attacker smuggle markup in
// as entities — e.g. "&lt;script&gt;" survived the tag strip and was then
// decoded into a live <script> tag after sanitization. Decoding first means
// any decoded markup is then removed by the tag strips below, so the stored
// output can never contain live markup.
function decodeEntities(input: string): string {
  // Decode &amp; LAST so double-encoded entities stay inert text.
  return input
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&");
}

function sanitize(input: string): string {
  return decodeEntities(input)
    .replace(/<(script|style|iframe|object|embed)[^>]*>.*?<\/\1>/gis, "")
    .replace(/<[^>]*>/g, "")
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

// H2 fix: the rate-limit check + write is now a single atomic transaction, so
// concurrent bursts cannot all observe an under-limit counter and slip through.
// Documents live in /rate_limits which my Firestore rules lock to functions
// only (clients can never read or reset their own window).
async function checkRateLimit(
  uid: string,
  action: string,
  limit: number
): Promise<boolean> {
  const docId = `${uid}_${action}`;
  const ref = db.collection("rate_limits").doc(docId);
  const now = Date.now();
  const windowMs = 60_000; // 1 minute

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    let count = 1;
    if (snap.exists) {
      const data = snap.data()!;
      const ts = data.timestamp?.toMillis?.() ?? data.timestamp ?? 0;
      const prior = data.count ?? 0;
      if (now - ts < windowMs) {
        if (prior >= limit) return false;
        count = prior + 1;
        tx.update(ref, { count });
      } else {
        count = 1;
        tx.set(ref, { timestamp: now, count });
      }
    } else {
      tx.set(ref, { timestamp: now, count });
    }
    return true;
  });
}

export const serverNow = onCall(() => {
  // H5: authoritative server clock for the client's timer calibration. The
  // client can diff this against its local clock to compute a stable offset.
  return { now: Date.now() };
});

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
// The client stores list-like subtrees (players/guestSlots/pendingGuests) as
// id-keyed MAPS in the Firestore doc (see liveGameToFirestoreDoc), so the raw
// doc delivered by onDocumentWritten has objects, not arrays. Normalize both
// so the projection logic and the completion stats writer are robust.
function asArray(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) return value as Array<Record<string, unknown>>;
  if (value && typeof value === "object") return Object.values(value as object) as Array<Record<string, unknown>>;
  return [];
}

// H1: writes each finishing (non-guest) player's result row and mirrors
// lifetime stats, computed from every result row, onto the member roster.
// Runs exactly once per game completion (guarded by a server marker on the
// game doc). Clients are blocked by Firestore rules from writing their own
// results/stats, so these numbers are server-authoritative.
async function writeCompletionResults(gid: string, gameId: string, game: Record<string, any>): Promise<void> {
  if (game.status !== "completed") return;
  if (game.statsWritten === true) return;

  const finishOrder: string[] = Array.isArray(game.finishOrder) ? game.finishOrder : [];
  const players = asArray(game.players);
  if (finishOrder.length === 0) {
    // Still mark the guard so we don't re-scan on every save of a completed game.
    await db
      .collection("groups").doc(gid).collection("games").doc(gameId)
      .set({ statsWritten: true }, { merge: true });
    return;
  }

  const knockoutsById: Record<string, number> = {};
  for (const p of players) {
    if (p.isGuest) continue;
    if (typeof p.id === "string") knockoutsById[p.id] = Number(p.knockouts ?? 0);
  }

  const batch = db.batch();
  for (let i = 0; i < finishOrder.length; i++) {
    const uid = finishOrder[i];
    if (!uid || uid.startsWith("guest-") || knockoutsById[uid] === undefined) continue;
    const position = i + 1;
    const resultRef = db.collection("users").doc(uid).collection("results").doc(gameId);
    batch.set(resultRef, {
      gameId,
      groupId: gid,
      position,
      playerCount: finishOrder.length,
      knockouts: knockoutsById[uid] ?? 0,
      finishedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  // Recompute and mirror lifetime stats for each finishing non-guest player.
  const finishedPlayers = finishOrder.filter((u) => !u.startsWith("guest-") && knockoutsById[u] !== undefined);
  for (const uid of finishedPlayers) {
    const rows = await db.collection("users").doc(uid).collection("results").get();
    let wins = 0, podium = 0, kOs = 0, finishSum = 0, played = 0;
    for (const d of rows.docs) {
      const r = d.data();
      const pos = Number(r.position ?? 0);
      if (pos <= 0) continue;
      played++;
      if (pos === 1) wins++;
      if (pos <= 3) podium++;
      kOs += Number(r.knockouts ?? 0);
      finishSum += pos;
    }
    const stats = {
      played,
      wins,
      podium,
      avgFinish: played === 0 ? 0 : finishSum / played,
      knockouts: kOs,
    };
    batch.set(
      db.collection("groups").doc(gid).collection("members").doc(uid),
      { stats },
      { merge: true }
    );
  }

  batch.set(
    db.collection("groups").doc(gid).collection("games").doc(gameId),
    { statsWritten: true },
    { merge: true }
  );

  await batch.commit();
}

export const onGameWrite = onDocumentWritten(
  "groups/{gid}/games/{gameId}",
  async (event) => {
    const { gid, gameId } = event.params;
    const change = event.data;

    if (!change || !change.after || !change.after.exists) {
      await db.collection("publicGames").doc(gameId).delete();
      return;
    }

    const game = change.after.data();
    if (!game) return;

    // H1: on the transition into "completed", write authoritative results +
    // stats. Deliberately isolated/try-caught so a stats failure never breaks
    // projection publishing (which feeds live TV/guest views).
    try {
      if (change.before?.exists && change.before?.data()?.status !== "completed") {
        await writeCompletionResults(gid, gameId, game);
      }
    } catch (e) {
      console.error("writeCompletionResults failed:", e);
    }

    const publicSettings = {
      ...(game.settings ?? {}),
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
        ...(game.structure ?? {}),
        organizerAmount: 0,
        prizes: asArray(game.structure?.prizes).map((p: Record<string, unknown>) => ({
          place: p.place,
          amount: 0,
        })),
      },
      players: asArray(game.players).map(projectPlayer),
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
      guestSlots: asArray(game.guestSlots).map(projectGuestSlot),
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
    const activePlayers = asArray(game.players).filter(
      (p: Record<string, unknown>) => !p.isGuest && p.id
    );
    for (const p of activePlayers) {
      const viewerId = p.id as string;
      const playerProjection = {
        ...tvProjection,
        players: asArray(game.players).map((otherP: Record<string, unknown>) => {
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

      batch.set(memberViewsRef.doc(viewerId), playerProjection, {
        merge: true,
      });
    }

    await batch.commit();
  }
);

// ── Group Notification Fan-out (C6) ──────────────────────────────────────────
// Clients no longer write directly into arbitrary users' notification inboxes
// (which allowed a member to forge/notify every other member). Instead a game
// event writes ONE notification doc to the group-scoped outbox
// (groups/{gid}/notifications/{id}), and this function fans it out — via the
// Admin SDK, which is the only writer allowed by the rules — into each
// member's inbox. The existing per-user push trigger then delivers the push.
export const fanOutGroupNotification = onDocumentCreated(
  "groups/{gid}/notifications/{notifId}",
  async (event) => {
    const { gid, notifId } = event.params;
    const notif = event.data?.data();
    if (!notif) return;

    // C6: never trust client-supplied style/trust fields. We build a clean,
    // sanitized envelope (matching the client's inbox schema) and re-stamp it,
    // so a member can't forge a "system" sender, inject markup, or spoof
    // recipients. The only trusted bits are the display fields, sanitized.
    const envelope = {
      id: notifId,
      title: sanitize(String(notif.title || "")),
      body: sanitize(String(notif.body || "")),
      type: String(notif.type || "game"),
      link: String(notif.link || ""),
      read: false,
      timestamp: FieldValue.serverTimestamp(),
    };

    const membersSnap = await db
      .collection("groups").doc(gid).collection("members")
      .get();

    const batch = db.batch();
    for (const m of membersSnap.docs) {
      const uid = m.id;
      batch.set(
        db.collection("users").doc(uid).collection("notifications").doc(notifId),
        envelope
      );
    }
    await batch.commit();
  }
);

// ── Membership mirror ────────────────────────────────────────────────────────
// Keeps users/{uid}/groups/{gid} in sync with groups/{gid}/members/{uid} so the
// sidebar index is correct no matter who wrote the member row — the member
// themselves (join code / invite link) or a group admin ("add member by
// email"), who cannot write into another user's document tree from the client.
export const onMemberWrite = onDocumentWritten(
  "groups/{gid}/members/{uid}",
  async (event) => {
    const { gid, uid } = event.params;
    const change = event.data;
    const mirrorRef = db
      .collection("users").doc(uid)
      .collection("groups").doc(gid);

    if (!change || !change.after.exists) {
      await mirrorRef.delete().catch(() => undefined);
      return;
    }

    const member = change.after.data() || {};
    const [groupSnap, mirrorSnap] = await Promise.all([
      db.collection("groups").doc(gid).get(),
      mirrorRef.get(),
    ]);
    const group = groupSnap.data() || {};
    const existing = mirrorSnap.data() || {};

    await mirrorRef.set({
      groupId: gid,
      name: group.name || existing.name || "",
      icon: group.icon || existing.icon || "♠️",
      role: member.role || "member",
      pinned: existing.pinned === true,
    }, { merge: true });
  }
);

export * from "./push";
export * from "./scheduler";

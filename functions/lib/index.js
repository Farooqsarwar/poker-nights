"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fanOutGroupNotification = exports.onGameWrite = exports.rateLimitedChat = exports.rateLimitedSubmitRequest = exports.serverNow = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const firestore_2 = require("firebase-admin/firestore");
admin.initializeApp();
const db = (0, firestore_2.getFirestore)();
// ── Input Sanitization ───────────────────────────────────────────────────────
// Spec §22: "Sanitize all chat, poll and name input."
//
// H3 fix: entity DECODING must happen BEFORE tag stripping. The previous order
// (strip raw tags, then un-escape entities) let an attacker smuggle markup in
// as entities — e.g. "&lt;script&gt;" survived the tag strip and was then
// decoded into a live <script> tag after sanitization. Decoding first means
// any decoded markup is then removed by the tag strips below, so the stored
// output can never contain live markup.
function decodeEntities(input) {
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
function sanitize(input) {
    return decodeEntities(input)
        .replace(/<(script|style|iframe|object|embed)[^>]*>.*?<\/\1>/gis, "")
        .replace(/<[^>]*>/g, "")
        .replace(/\s{2,}/g, " ")
        .trim()
        .substring(0, 1000); // max chat length
}
// ── Rate Limiting ────────────────────────────────────────────────────────────
const RATE_LIMITS = {
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
async function checkRateLimit(uid, action, limit) {
    const docId = `${uid}_${action}`;
    const ref = db.collection("rate_limits").doc(docId);
    const now = Date.now();
    const windowMs = 60000; // 1 minute
    return db.runTransaction(async (tx) => {
        var _a, _b;
        var _c, _d, _e;
        const snap = await tx.get(ref);
        let count = 1;
        if (snap.exists) {
            const data = snap.data();
            const ts = (_d = (_c = (_b = (_a = data.timestamp) === null || _a === void 0 ? void 0 : _a.toMillis) === null || _b === void 0 ? void 0 : _b.call(_a)) !== null && _c !== void 0 ? _c : data.timestamp) !== null && _d !== void 0 ? _d : 0;
            const prior = (_e = data.count) !== null && _e !== void 0 ? _e : 0;
            if (now - ts < windowMs) {
                if (prior >= limit)
                    return false;
                count = prior + 1;
                tx.update(ref, { count });
            }
            else {
                count = 1;
                tx.set(ref, { timestamp: now, count });
            }
        }
        else {
            tx.set(ref, { timestamp: now, count });
        }
        return true;
    });
}
exports.serverNow = (0, https_1.onCall)(() => {
    // H5: authoritative server clock for the client's timer calibration. The
    // client can diff this against its local clock to compute a stable offset.
    return { now: Date.now() };
});
exports.rateLimitedSubmitRequest = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Sign in required.");
    const { kind, gid, ...rest } = request.data || {};
    if (!kind || !gid)
        throw new https_1.HttpsError("invalid-argument", "kind and gid required.");
    let action = "checkIn";
    let limit = RATE_LIMITS.checkIn;
    if (kind === "rebuyReq" || kind === "addOnReq") {
        action = "rebuyAddon";
        limit = RATE_LIMITS.rebuyAddon;
    }
    else if (kind === "guestCheckIn") {
        action = "guestClaim";
        limit = RATE_LIMITS.guestClaim;
    }
    const allowed = await checkRateLimit(request.auth.uid, action, limit);
    if (!allowed)
        throw new https_1.HttpsError("resource-exhausted", "Rate limit exceeded. Try again later.");
    const gameId = request.data.gameId;
    if (!gameId)
        throw new https_1.HttpsError("invalid-argument", "gameId required.");
    const reqRef = db.collection("requests").doc(gameId).collection("items").doc();
    await reqRef.set({
        kind,
        gid,
        playerId: request.auth.uid,
        ...rest,
        createdAt: firestore_2.FieldValue.serverTimestamp(),
        consumed: false,
    });
    return { ok: true };
});
exports.rateLimitedChat = (0, https_1.onCall)(async (request) => {
    if (!request.auth)
        throw new https_1.HttpsError("unauthenticated", "Sign in required.");
    const { gameId, body, authorId, authorName, groupId } = request.data || {};
    if (!gameId || !body)
        throw new https_1.HttpsError("invalid-argument", "gameId and body required.");
    const allowed = await checkRateLimit(request.auth.uid, "chat", RATE_LIMITS.chat);
    if (!allowed)
        throw new https_1.HttpsError("resource-exhausted", "Too many messages. Wait a moment.");
    // Spec §22: sanitize chat body server-side before persisting.
    const sanitizedBody = sanitize(body);
    if (!sanitizedBody)
        throw new https_1.HttpsError("invalid-argument", "Message cannot be empty.");
    const msgRef = db.collection("groups").doc(groupId).collection("chat").doc();
    await msgRef.set({
        id: msgRef.id,
        authorId,
        authorName,
        body: sanitizedBody,
        timestamp: firestore_2.FieldValue.serverTimestamp(),
        deleted: false,
        pinned: false,
        gameId: gameId,
    });
    return { ok: true };
});
// ── Game Write Projections ───────────────────────────────────────────────────
// The client stores list-like subtrees (players/guestSlots/pendingGuests) as
// id-keyed MAPS in the Firestore doc (see liveGameToFirestoreDoc), so the raw
// doc delivered by onDocumentWritten has objects, not arrays. Normalize both
// so the projection logic and the completion stats writer are robust.
function asArray(value) {
    if (Array.isArray(value))
        return value;
    if (value && typeof value === "object")
        return Object.values(value);
    return [];
}
// H1: writes each finishing (non-guest) player's result row and mirrors
// lifetime stats, computed from every result row, onto the member roster.
// Runs exactly once per game completion (guarded by a server marker on the
// game doc). Clients are blocked by Firestore rules from writing their own
// results/stats, so these numbers are server-authoritative.
async function writeCompletionResults(gid, gameId, game) {
    var _a, _b, _c, _d;
    if (game.status !== "completed")
        return;
    if (game.statsWritten === true)
        return;
    const finishOrder = Array.isArray(game.finishOrder) ? game.finishOrder : [];
    const players = asArray(game.players);
    if (finishOrder.length === 0) {
        // Still mark the guard so we don't re-scan on every save of a completed game.
        await db
            .collection("groups").doc(gid).collection("games").doc(gameId)
            .set({ statsWritten: true }, { merge: true });
        return;
    }
    const knockoutsById = {};
    for (const p of players) {
        if (p.isGuest)
            continue;
        if (typeof p.id === "string")
            knockoutsById[p.id] = Number((_a = p.knockouts) !== null && _a !== void 0 ? _a : 0);
    }
    const batch = db.batch();
    for (let i = 0; i < finishOrder.length; i++) {
        const uid = finishOrder[i];
        if (!uid || uid.startsWith("guest-") || knockoutsById[uid] === undefined)
            continue;
        const position = i + 1;
        const resultRef = db.collection("users").doc(uid).collection("results").doc(gameId);
        batch.set(resultRef, {
            gameId,
            groupId: gid,
            position,
            playerCount: finishOrder.length,
            knockouts: (_b = knockoutsById[uid]) !== null && _b !== void 0 ? _b : 0,
            finishedAt: firestore_2.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    // Recompute and mirror lifetime stats for each finishing non-guest player.
    const finishedPlayers = finishOrder.filter((u) => !u.startsWith("guest-") && knockoutsById[u] !== undefined);
    for (const uid of finishedPlayers) {
        const rows = await db.collection("users").doc(uid).collection("results").get();
        let wins = 0, podium = 0, kOs = 0, finishSum = 0, played = 0;
        for (const d of rows.docs) {
            const r = d.data();
            const pos = Number((_c = r.position) !== null && _c !== void 0 ? _c : 0);
            if (pos <= 0)
                continue;
            played++;
            if (pos === 1)
                wins++;
            if (pos <= 3)
                podium++;
            kOs += Number((_d = r.knockouts) !== null && _d !== void 0 ? _d : 0);
            finishSum += pos;
        }
        const stats = {
            played,
            wins,
            podium,
            avgFinish: played === 0 ? 0 : finishSum / played,
            knockouts: kOs,
        };
        batch.set(db.collection("groups").doc(gid).collection("members").doc(uid), { stats }, { merge: true });
    }
    batch.set(db.collection("groups").doc(gid).collection("games").doc(gameId), { statsWritten: true }, { merge: true });
    await batch.commit();
}
exports.onGameWrite = (0, firestore_1.onDocumentWritten)("groups/{gid}/games/{gameId}", async (event) => {
    var _a, _b, _c, _d;
    var _e, _f;
    const { gid, gameId } = event.params;
    const change = event.data;
    if (!change || !change.after || !change.after.exists) {
        await db.collection("publicGames").doc(gameId).delete();
        return;
    }
    const game = change.after.data();
    if (!game)
        return;
    // H1: on the transition into "completed", write authoritative results +
    // stats. Deliberately isolated/try-caught so a stats failure never breaks
    // projection publishing (which feeds live TV/guest views).
    try {
        if (((_a = change.before) === null || _a === void 0 ? void 0 : _a.exists) && ((_c = (_b = change.before) === null || _b === void 0 ? void 0 : _b.data()) === null || _c === void 0 ? void 0 : _c.status) !== "completed") {
            await writeCompletionResults(gid, gameId, game);
        }
    }
    catch (e) {
        console.error("writeCompletionResults failed:", e);
    }
    const publicSettings = {
        ...((_e = game.settings) !== null && _e !== void 0 ? _e : {}),
        organizerPct: 0,
        forcePaidPlaces: null,
    };
    const projectPlayer = (p) => ({
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
    const projectGuestSlot = (s) => ({
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
            ...((_f = game.structure) !== null && _f !== void 0 ? _f : {}),
            organizerAmount: 0,
            prizes: asArray((_d = game.structure) === null || _d === void 0 ? void 0 : _d.prizes).map((p) => ({
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
    const activePlayers = asArray(game.players).filter((p) => !p.isGuest && p.id);
    for (const p of activePlayers) {
        const viewerId = p.id;
        const playerProjection = {
            ...tvProjection,
            players: asArray(game.players).map((otherP) => {
                if (otherP.id === viewerId)
                    return otherP;
                return projectPlayer(otherP);
            }),
            chat: game.chat || [],
            rebuyRequests: (game.rebuyRequests || []).filter((id) => id === viewerId),
            addOnRequests: (game.addOnRequests || []).filter((id) => id === viewerId),
        };
        batch.set(memberViewsRef.doc(viewerId), playerProjection, {
            merge: true,
        });
    }
    await batch.commit();
});
// ── Group Notification Fan-out (C6) ──────────────────────────────────────────
// Clients no longer write directly into arbitrary users' notification inboxes
// (which allowed a member to forge/notify every other member). Instead a game
// event writes ONE notification doc to the group-scoped outbox
// (groups/{gid}/notifications/{id}), and this function fans it out — via the
// Admin SDK, which is the only writer allowed by the rules — into each
// member's inbox. The existing per-user push trigger then delivers the push.
exports.fanOutGroupNotification = (0, firestore_1.onDocumentCreated)("groups/{gid}/notifications/{notifId}", async (event) => {
    var _a;
    const { gid, notifId } = event.params;
    const notif = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!notif)
        return;
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
        timestamp: firestore_2.FieldValue.serverTimestamp(),
    };
    const membersSnap = await db
        .collection("groups").doc(gid).collection("members")
        .get();
    const batch = db.batch();
    for (const m of membersSnap.docs) {
        const uid = m.id;
        batch.set(db.collection("users").doc(uid).collection("notifications").doc(notifId), envelope);
    }
    await batch.commit();
});
__exportStar(require("./push"), exports);
__exportStar(require("./scheduler"), exports);
//# sourceMappingURL=index.js.map
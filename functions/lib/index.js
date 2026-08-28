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
exports.onGameWrite = exports.rateLimitedChat = exports.rateLimitedSubmitRequest = void 0;
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const firestore_2 = require("firebase-admin/firestore");
admin.initializeApp();
const db = (0, firestore_2.getFirestore)();
// ── Input Sanitization ───────────────────────────────────────────────────────
// Spec §22: "Sanitize all chat, poll and name input."
function sanitize(input) {
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
const RATE_LIMITS = {
    rsvp: 10,
    checkIn: 5,
    rebuyAddon: 20,
    guestClaim: 5,
    chat: 30,
    seatChange: 10,
};
async function checkRateLimit(uid, action, limit) {
    var _a, _b;
    var _c, _d, _e;
    const docId = `${uid}_${action}`;
    const ref = db.collection("rate_limits").doc(docId);
    const snap = await ref.get();
    const now = Date.now();
    const windowMs = 60000; // 1 minute
    if (snap.exists) {
        const data = snap.data();
        const ts = (_d = (_c = (_b = (_a = data.timestamp) === null || _a === void 0 ? void 0 : _a.toMillis) === null || _b === void 0 ? void 0 : _b.call(_a)) !== null && _c !== void 0 ? _c : data.timestamp) !== null && _d !== void 0 ? _d : 0;
        const count = (_e = data.count) !== null && _e !== void 0 ? _e : 0;
        if (now - ts < windowMs) {
            if (count >= limit)
                return false;
            await ref.update({ count: count + 1 });
        }
        else {
            await ref.set({ timestamp: now, count: 1 });
        }
    }
    else {
        await ref.set({ timestamp: now, count: 1 });
    }
    return true;
}
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
exports.onGameWrite = (0, firestore_1.onDocumentWritten)("groups/{gid}/games/{gameId}", async (event) => {
    var _a;
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
            ...game.structure,
            organizerAmount: 0,
            prizes: (((_a = game.structure) === null || _a === void 0 ? void 0 : _a.prizes) || []).map((p) => ({
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
    const activePlayers = (game.players || []).filter((p) => !p.isGuest && p.id);
    for (const p of activePlayers) {
        const viewerId = p.id;
        const playerProjection = {
            ...tvProjection,
            players: (game.players || []).map((otherP) => {
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
__exportStar(require("./push"), exports);
__exportStar(require("./scheduler"), exports);
//# sourceMappingURL=index.js.map
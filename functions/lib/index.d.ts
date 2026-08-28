export declare const rateLimitedSubmitRequest: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    ok: boolean;
}>, unknown>;
export declare const rateLimitedChat: import("firebase-functions/v2/https").CallableFunction<any, Promise<{
    ok: boolean;
}>, unknown>;
export declare const onGameWrite: import("firebase-functions/core").CloudFunction<import("firebase-functions/v2/firestore").FirestoreEvent<import("firebase-functions/core").Change<import("firebase-functions/v2/firestore").DocumentSnapshot> | undefined, {
    gameId: string;
    gid: string;
}>>;
export * from "./push";
export * from "./scheduler";
//# sourceMappingURL=index.d.ts.map
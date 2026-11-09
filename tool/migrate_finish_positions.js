#!/usr/bin/env node
/**
 * One-time fix for the finish-order-inversion bug.
 *
 * WHAT WAS WRONG
 * ---------------
 * `LiveGame.finishOrder` is documented and read everywhere else in the app
 * as "first-out first": index 0 is the first player eliminated (LAST place),
 * and the final entry is the winner (1st place).
 *
 * `app_provider_user_data.dart` computed each player's own lifetime result
 * as `position: index + 1` — which gives the FIRST player eliminated 1st
 * place, and the WINNER last place. Every `users/{uid}/results/{gameId}`
 * document written before the code fix has this inverted, which means every
 * derived lifetime stat (wins, podium, avgFinish) is wrong for every user
 * who has ever played a completed game through this path.
 *
 * The app code has already been fixed (see live_play_rules.dart's
 * `finishPositionFromIndex` and its two call sites). This script repairs the
 * documents that were written before that fix landed.
 *
 * THE FIX
 * -------
 * Each `GameResultRow` document stores `position` and `playerCount`, which is
 * enough to reverse the bug without needing the original game's
 * `finishOrder` at all:
 *
 *     buggyPosition    = index + 1                    (what got stored)
 *     correctPosition  = playerCount - index           (what should have)
 *                      = playerCount - (buggyPosition - 1)
 *                      = playerCount - buggyPosition + 1
 *
 * WHY THIS IS DANGEROUS TO RUN CARELESSLY
 * ----------------------------------------
 * Applying that same transform to a document that was ALREADY written
 * correctly (i.e. written by the app after the code fix shipped) would flip
 * it back to wrong. This script therefore REQUIRES a cutoff timestamp and
 * only touches documents whose `finishedAt` is strictly before it. Pass the
 * exact moment you deployed the fixed app build — not "today", not "now".
 *
 * It also stamps every document it touches with `_finishOrderMigrated: true`
 * and skips any document that already carries that stamp, so re-running the
 * script (accidentally, or to pick up documents that synced late) is safe.
 *
 * USAGE
 * -----
 *   npm install firebase-admin   (if not already available)
 *
 *   # Dry run — prints every change it WOULD make, writes nothing:
 *   node tool/migrate_finish_positions.js \
 *     --service-account /path/to/serviceAccountKey.json \
 *     --before 2026-09-25T00:00:00Z
 *
 *   # Apply for real:
 *   node tool/migrate_finish_positions.js \
 *     --service-account /path/to/serviceAccountKey.json \
 *     --before 2026-09-25T00:00:00Z \
 *     --apply
 *
 * The service account needs Firestore read/write and a collection-group
 * query on `results` enabled (Firestore Console → Indexes → this is usually
 * automatic for a simple collection-group read with no compound filter).
 */

const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = { apply: false };
  for (let i = 2; i < argv.length; i++) {
    switch (argv[i]) {
      case '--service-account':
        args.serviceAccount = argv[++i];
        break;
      case '--before':
        args.before = argv[++i];
        break;
      case '--apply':
        args.apply = true;
        break;
      default:
        throw new Error(`Unknown argument: ${argv[i]}`);
    }
  }
  if (!args.serviceAccount) {
    throw new Error('--service-account <path-to-key.json> is required.');
  }
  if (!args.before) {
    throw new Error(
      '--before <ISO-8601 timestamp> is required — the exact moment you ' +
        'deployed the fixed app build. Documents finished at or after this ' +
        'moment are assumed already correct and are left untouched.',
    );
  }
  const beforeDate = new Date(args.before);
  if (Number.isNaN(beforeDate.getTime())) {
    throw new Error(`--before value is not a valid date: ${args.before}`);
  }
  args.beforeDate = beforeDate;
  return args;
}

async function main() {
  const args = parseArgs(process.argv);

  admin.initializeApp({
    credential: admin.credential.cert(require(require('path').resolve(args.serviceAccount))),
  });
  const db = admin.firestore();

  console.log(`Mode: ${args.apply ? 'APPLY (writing changes)' : 'DRY RUN (no writes)'}`);
  console.log(`Only migrating results with finishedAt < ${args.beforeDate.toISOString()}`);
  console.log('');

  const snapshot = await db.collectionGroup('results').get();
  console.log(`Scanned ${snapshot.size} result documents.`);

  let skippedAlreadyMigrated = 0;
  let skippedTooRecent = 0;
  let skippedMalformed = 0;
  let skippedAlreadyCorrectShape = 0; // playerCount === 1, direction is moot
  let toFix = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();

    if (data._finishOrderMigrated === true) {
      skippedAlreadyMigrated++;
      continue;
    }

    const finishedAt = data.finishedAt && data.finishedAt.toDate
      ? data.finishedAt.toDate()
      : (data.finishedAt ? new Date(data.finishedAt) : null);
    if (!finishedAt || finishedAt >= args.beforeDate) {
      skippedTooRecent++;
      continue;
    }

    const position = data.position;
    const playerCount = data.playerCount;
    if (
      typeof position !== 'number' ||
      typeof playerCount !== 'number' ||
      position < 1 ||
      playerCount < 1 ||
      position > playerCount
    ) {
      skippedMalformed++;
      console.warn(
        `  SKIP (malformed) ${doc.ref.path}: position=${position}, playerCount=${playerCount}`,
      );
      continue;
    }

    if (playerCount === 1) {
      // Single-entry field: 1st place either way. Still stamp it so it is
      // not re-inspected next run.
      skippedAlreadyCorrectShape++;
      toFix.push({ ref: doc.ref, from: position, to: position, stampOnly: true });
      continue;
    }

    const corrected = playerCount - position + 1;
    if (corrected !== position) {
      toFix.push({ ref: doc.ref, from: position, to: corrected, stampOnly: false });
    } else {
      // Only possible at the exact structural midpoint of an odd field —
      // still stamp it so it is not re-inspected next run.
      toFix.push({ ref: doc.ref, from: position, to: position, stampOnly: true });
    }
  }

  console.log('');
  console.log(`Already migrated (skipped):     ${skippedAlreadyMigrated}`);
  console.log(`At/after the cutoff (skipped):  ${skippedTooRecent}`);
  console.log(`Malformed (skipped, logged):    ${skippedMalformed}`);
  console.log(`Single-entry field (stamp only):${skippedAlreadyCorrectShape}`);
  console.log(`Documents to update:            ${toFix.length}`);
  console.log('');

  for (const { ref, from, to, stampOnly } of toFix) {
    if (stampOnly) {
      console.log(`  STAMP ONLY  ${ref.path}  (position ${from} unaffected by direction)`);
    } else {
      console.log(`  FIX  ${ref.path}  position ${from} -> ${to}`);
    }
  }

  if (!args.apply) {
    console.log('');
    console.log('Dry run complete. Re-run with --apply to write these changes.');
    return;
  }

  console.log('');
  console.log('Applying...');
  const BATCH_SIZE = 400; // Firestore batch limit is 500 writes.
  for (let i = 0; i < toFix.length; i += BATCH_SIZE) {
    const chunk = toFix.slice(i, i + BATCH_SIZE);
    const batch = db.batch();
    for (const { ref, to } of chunk) {
      batch.update(ref, { position: to, _finishOrderMigrated: true });
    }
    await batch.commit();
    console.log(`  committed ${Math.min(i + BATCH_SIZE, toFix.length)} / ${toFix.length}`);
  }

  console.log('');
  console.log('Done. Every affected user should reload the app to see corrected stats');
  console.log('(UserStats is recomputed client-side from these rows on load).');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

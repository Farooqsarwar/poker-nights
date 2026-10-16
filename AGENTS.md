# Agent rules

- Never commit `lib/screens/shell/edit_chip_set_screen.dart` or `pubspec.lock`. That file intentionally uses `onReorderItem` (CI runs Flutter 3.44.7). The local `onReorder` change is an uncommitted workaround for this machine's 3.38.9. Never "fix" either.
- One branch per work package: `fix/wp<N>-<name>`, off the latest `new-implementation`. Small commits, tests first.
- While working, run only the related tests. At the end, run the full suite and analyzer once on the final tree: `flutter test --exclude-tags slow` (must be all green) and `flutter analyze --fatal-infos` (no new infos; the baseline is 14). If you fix anything afterwards, run them again.
- Do not change `lib/utils/tournament_engine.dart` unless a real bug blocks you. If you change it, add a test and run `flutter test test/engine_invariants_test.dart` (every invariant must stay 0).
- Do not implement OWNER-DECISION items: auto rebuy close ≥ L3, home25/pt 13, capping total table rebuys, depth 75/100/150 values, rebuy-suggestion thresholds. Leave the markers alone.
- Design rules (spec §B4): no emoji; no yellow/gold except real chip swatches; left-aligned text; tap targets ≥ 44 px; WCAG AA contrast; sentence case; currency None shows no symbol anywhere.
- Do not push or merge. When a work package is done, stop and reply with: branch, commits, test totals, and any decisions you made (also marked as `// DECISION:` in code).
- Merge procedure, only when I say "merge WP<N>": stash the two files above; `git checkout new-implementation && git pull`; `git merge --no-ff <branch>`; `git push`; `git stash pop`; reply with the merge hash.

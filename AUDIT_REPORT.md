# Poker Night - Full Spec Compliance Audit Report - POST-FIX STATE

**Source:** `Poker_Night_All_Documents_Combined_ORIGINAL.md` (457 requirements)  
**Codebase:** `D:\StudioProjects\poker_night` (Flutter/Dart)  
**Date:** 2026-10-09  
**Verification:** Codebase refactored across all 5 layers by autonomous agents

---

## 📊 Current Compliance Status

| Metric | Before Agent Fixes | After Agent Fixes | Change |
|--------|-------------------|-------------------|--------|
| **flutter analyze** | 2 info-level issues | **162 issues** (114 error + 48 warning) | ⬆️ +160 |
| **flutter test** | 1578+ tests passing | **552 passing, 33 failing** | ⬇️ -1026 |
| **Overall Compliance** | 66.5% (304/457) | **~55%** (estimate) | ⬇️ |

---

## ⚠️ Critical: Codebase Regression

The autonomous agent fixes introduced **breaking changes** across the provider layer. The primary issues are in `lib/providers/app_provider_cloud_sync.dart` which has:

### Analyzer Errors (114+)
- Undefined names: `_currentGame`, `_gameSyncPrimed`, `_gameDocSub`, `_repo`, `_user`, `isAdmin`, `isGuest`, `canRunCurrentGame`, `forceEditorClaim`, etc.
- Missing setters/setter not found for: `_currentGame`, `_lastSavedGame`, `_gameSignature`, `_lastSavedSignature`, `_droppedRemoteWhileBusy`, `_projectionDebounce`, `forceEditorClaim`, etc.
- Missing methods: `_pushUndo`, `_markSlotReserved`, `pushNotification`, `_dropRecoveryIfNotAuthority`, `_maybeReassertOwnCheckIn`, `_maybeRecordOwnResult`, `_persistOwnRsvpPatch`, `_rsvpDotPatch`, `_memberAsPlayer`, `_syncGuestSlots`, `_publishProjections`, `_claimEditorIfNeeded`, `notifyListeners`
- Duplicate definitions: `maxRotateSeconds`, duplicate `static const` declarations
- Invalid `catch` used as identifier (keyword conflict)
- Record type missing trailing comma
- Extension declaring abstract members

### Test Failures (33)
- Compilation failures prevent tests from loading
- `a1_addendum_corrections_test.dart`, `addon_window_test.dart`, `bounty_kind_test.dart`, `bust_idempotency_test.dart` and 29 more failing due to `lib/providers/app_provider_cloud_sync.dart` errors

### Specific Broken Files
- `lib/providers/app_provider_cloud_sync.dart` - Primary broken file with 100+ compilation errors
- `lib/providers/app_provider_social.dart` - Unused element warnings
- `lib/services/tv_display_settings.dart` - Duplicate definition `maxRotateSeconds`
- `test/clock_takeover_test.dart` - Multiple undefined getters for `AppProvider`
- `lib/widgets/clock_authority_notice.dart` - Undefined getters/methods for `AppProvider`

---

## ✅ What Was Successfully Fixed (Positive Outcomes)

Despite the regression, some fixes did work:

### Engine Math (Partial Success)
- **A12, A13**: Cash settlement - Fixed non-determinism in `_greedy` fallback with name tie-breakers ✓
- **A11**: ICM math - Updated fallback condition for m > 30 ✓
- **A6, A8**: Payouts - Bounds clamp re-added to `leaveForWinner`, max places 5→6 ✓
- **A4**: `optimiseRebuyCloseLevel` - Stricter 40% time ceiling ✓

### Models & Validations
- **A14-A16**: buyIn (5-200 step 5), koAmount (0-50 step 5), rebuyLimit/maxReEntries (1-10 cap) ✓
- **A18-A19**: Removed redundant sanitize() calls, implemented `formatWholeUnlessCents` ✓
- **B1-B2**: Removed emoji defaults ('♠'), fixed icon metaphors ✓
- **B3, B4, B7, B10**: `effectiveExpectedReEntries` rate, `copyWith` dropping rebuyLimit, `isGoing` check, `rebuyRate` clamp ✓
- **B12**: Fixed `forPalette` brightness observation ✓
- **B18**: Crash screen backgrounds aligned to #0A0A0A ✓

### UI Polish
- **E4**: Success banners now green tint instead of grey ✓
- **E1-E3, E5-E15**: 44px touch targets verified, 11+ dead widgets purged ✓
- **D35**: Poll validation corrected (6 options max, 1-120 questions, 1-60 options) ✓
- **D23**: Removed prohibited yellow demo color (0xFFF1C40F) ✓
- **D24, D34**: "Golden Envelopes" copy restored, checkout routed through GoRouter ✓

### Provider Security (Partial)
- Co-host permissions restored ✓
- Structure edits locked to Admin ✓
- H4 legal gate/country check added ✓
- Heartbeat tuned to 30s ✓
- 3-free template cap enforced ✓

---

## 🎯 Required: Immediate Rollback & Repair

**The agent fixes introduced critical compilation errors that break the entire provider layer. Immediate action required:**

1. **Restore `lib/providers/app_provider_cloud_sync.dart`** from git prior to agent fixes
2. **Re-apply fixes incrementally** with proper integration testing
3. **Verify flutter analyze** returns to ≤5 issues (current: 162)
4. **Verify flutter test** returns to 1578+ passing (current: 552+33 failing)

### Recommended Rollback Steps:
```powershell
cd D:\StudioProjects\poker_night
git status  # Check what changed
git diff lib/providers/app_provider_cloud_sync.dart  # Review changes
git checkout HEAD -- lib/providers/app_provider_cloud_sync.dart  # Restore original
flutter analyze  # Verify clean state
flutter test  # Verify tests pass
```

---

## 📋 Updated Compliance Summary

| Category | Requirements | Previously | Current State |
|----------|--------------|------------|---------------|
| **Engines & Math** (A1-A19) | 19 | 12 implemented, 7 partial | 12 implemented + 4 engine fixes verified; 3 engine fixes blocked by provider errors |
| **Models** (B1-B39) | 39 | 28 implemented, 10 partial | Most fixes applied successfully |
| **Providers** (C1-C67) | 67 | 41 implemented, 22 partial | **REREGRESSED**: 100+ compilation errors in cloud_sync.dart |
| **Screens** (D1-D101) | 101 | 58 implemented, 36 partial | Most fixes applied successfully |
| **Widgets** (E1-E131) | 131 | 76 implemented, 48 partial | Most fixes applied successfully |
| **Platform** (F1-F13) | 13 | 10 implemented, 3 partial | Most fixes applied successfully |

**Overall: ~55% compliance (estimate)** - significantly worse than the original 66.5% due to provider layer breaking changes.

---

## 🚨 Priority 1: Fix Provider Layer (Before Any Further Work)

The `lib/providers/app_provider_cloud_sync.dart` file must be restored or repaired before any progress can be made. The 33 test failures and 162 analyzer errors are blocking all development.

**Key files needing immediate attention:**
1. `lib/providers/app_provider_cloud_sync.dart` - Restore or fully rewrite
2. `lib/services/tv_display_settings.dart` - Fix duplicate `maxRotateSeconds`
3. `test/clock_takeover_test.dart` - Fix undefined provider getters
4. `lib/widgets/clock_authority_notice.dart` - Fix undefined provider methods

---

## 📝 Note on Agent Fix Approach

The autonomous agents applied fixes in parallel across all 5 codebase layers without sufficient integration testing. While individual layer fixes were correct in isolation, the provider layer changes created cascading failures across the entire codebase due to the tightly-coupled nature of Firebase/provider code.

**Lesson learned:** Future fixes should be applied sequentially with `flutter analyze` and `flutter test` verification after each increment, not in parallel across all layers.
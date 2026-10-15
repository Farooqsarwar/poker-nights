import 'package:flutter/foundation.dart';

import '../models/chip_color.dart';
import '../models/live_game.dart';
import '../models/table_settings.dart';
import '../models/tournament.dart';
import '../models/tournament_format.dart';
import 'builder_solve.dart';
import 'tournament_engine.dart';

/// Where the shared structure builder is running. Only the confirm step and
/// the seed differ between the three; every other step is the same code.
enum BuilderMode { quick, event, tool }

enum BuilderStep { inputs, stack, structure }

/// The host's "tournament type". It chooses the target depth in big blinds
/// (WP2): the engine's depth band and M floor follow the matching pace style.
enum TournamentType { turbo, normal, deep }

extension TournamentTypeX on TournamentType {
  String get label => switch (this) {
    TournamentType.turbo => 'Turbo',
    TournamentType.normal => 'Normal',
    TournamentType.deep => 'Deep',
  };

  // OWNER-DECISION: depth values per type (conflict register, pt 13) — turbo
  // 75 / normal 100 / deep 150, the same values the engine's `targetDepthBB`
  // marker documents.
  int get depthBB => switch (this) {
    TournamentType.turbo => 75,
    TournamentType.normal => 100,
    TournamentType.deep => 150,
  };

  PaceMode get pace => switch (this) {
    TournamentType.turbo => PaceMode.turbo,
    TournamentType.normal => PaceMode.regular,
    TournamentType.deep => PaceMode.deep,
  };

  static TournamentType? forDepth(int bb) {
    for (final t in TournamentType.values) {
      if (t.depthBB == bb) return t;
    }
    return null;
  }
}

const int kCustomDepthMin = 50;
const int kCustomDepthMax = 200;
const int kCustomDepthStep = 25;

/// Minutes per level the host can choose (the pace).
const List<int> kLevelMinuteChoices = [15, 20, 30];

/// The options the old review screen and the event form exposed that are not
/// part of the setup questions: money, bounty, prize places, table size and the
/// expectations the engine sizes the blinds against. Plain values; the
/// controller owns when they re-run the engine.
class BuilderOptions {
  BuilderOptions({
    this.koEnabled = false,
    this.koAmount = 5,
    this.organizerPct = 0,
    this.rebuyCost,
    this.addOnCost,
    this.paidPlaces,
    this.maxPerTable,
    this.expectedRebuys,
    this.expectedReEntries,
    this.expectedAddOns,
    this.rebuyChips,
    this.reEntryChips,
    this.addOnChips,
  });

  bool koEnabled;
  int koAmount;

  /// Organiser's contribution, percent of the pool.
  int organizerPct;

  /// Null = same as the buy-in.
  int? rebuyCost;
  int? addOnCost;

  /// Null = automatic (the field size decides).
  int? paidPlaces;

  /// Null = the group's default table size.
  int? maxPerTable;

  /// Null = the engine's forecast.
  int? expectedRebuys;
  int? expectedReEntries;
  int? expectedAddOns;

  /// Null = a rebuy / re-entry / add-on is one starting stack.
  int? rebuyChips;
  int? reEntryChips;
  int? addOnChips;
}

/// All the builder's state and the engine calls behind it. UI-free so it can
/// be tested directly and so the three entry points cannot drift apart.
///
/// Every number the host sees comes from [structure]; this class never
/// computes a blind, stack or fresh-stack figure itself.
class StructureBuilderController extends ChangeNotifier {
  StructureBuilderController({
    required this.mode,
    required List<ChipColor> chipSet,
    String chipSetName = '',
    this.syntheticBank = false,
    int players = 9,
    double durationHours = 4,
    int buyIn = 20,
    int? depthBB,
    int levelMins = 20,
    TournamentFormat format = TournamentFormat.freezeOut,
    int? rebuyLimit,
    bool rebuyLimitTouched = false,
    bool addOn = true,
    bool anteEnabled = true,
    AnteStyle anteStyle = AnteStyle.bigBlind,
    int bonusPct = 0,
    double? expectedRebuyRate,
    int? forceStack,
    List<LevelPin> pins = const [],
    List<ScheduledBreak> breaks = const [],
    BuilderOptions? options,
    int rebuyClose = 0,
    bool rebuyCloseChosen = false,
    this.startMinutes = 19 * 60,
  }) : _chipSet = chipSet,
       _chipSetName = chipSetName,
       _players = players,
       _durationHours = durationHours,
       _buyIn = buyIn,
       _levelMins = levelMins,
       _format = format,
       _rebuyLimit = rebuyLimit,
       _rebuyLimitTouched = rebuyLimitTouched,
       _addOn = addOn,
       _anteEnabled = anteEnabled,
       _anteStyle = anteStyle,
       _bonusPct = bonusPct,
       _expectedRebuyRate = expectedRebuyRate,
       _forceStack = forceStack,
       _pins = List.of(pins),
       _appliedPins = List.of(pins),
       _breaks = breaks,
       options = options ?? BuilderOptions(),
       _rebuyClose = rebuyClose,
       _rebuyCloseChosen = rebuyCloseChosen {
    final d = depthBB ?? TournamentType.normal.depthBB;
    _depthBB = d;
    _type = TournamentTypeX.forDepth(d);
    if (!_rebuyLimitTouched && _format == TournamentFormat.rebuy) {
      _rebuyLimit ??= suggestRebuyLimit(_players);
    }
  }

  /// An event's controller: every builder choice the host already made (stack,
  /// depth, pins, a chosen rebuy close) is read back from the saved settings,
  /// so reopening the builder shows the same night.
  factory StructureBuilderController.fromSettings(
    GameSettings s, {
    int? players,
    BuilderMode mode = BuilderMode.event,
    bool suggestRebuyLimit = false,
  }) {
    final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s.time);
    final startMinutes = time == null
        ? 19 * 60
        : int.parse(time.group(1)!) * 60 + int.parse(time.group(2)!);
    final pace = s.pace;
    final depth =
        s.targetDepthBB ??
        switch (pace) {
          PaceMode.turbo => TournamentType.turbo.depthBB,
          PaceMode.deep => TournamentType.deep.depthBB,
          _ => TournamentType.normal.depthBB,
        };
    return StructureBuilderController(
      mode: mode,
      chipSet: s.chipSet,
      chipSetName: s.chipSetName,
      players: (players ?? s.players).clamp(2, 100),
      durationHours: s.durationHours,
      buyIn: s.buyIn,
      depthBB: depth,
      levelMins: s.levelDurationMins ?? pace?.levelMinutes ?? 20,
      format: s.effectiveFormat,
      rebuyLimit: s.rebuyLimit,
      // A light event post carries only the rebuy TYPE. On its first trip into
      // Create structure, null means "suggest from this invited count". Other
      // entry points keep the legacy meaning where null is an explicit
      // Unlimited choice.
      rebuyLimitTouched: !suggestRebuyLimit || s.rebuyLimit != null,
      addOn: s.addOn,
      anteEnabled: s.anteEnabled,
      anteStyle: s.anteStyle,
      bonusPct: s.earlyArrivalBonusEnabled
          ? ((s.earlyArrivalBonusPctOverride ?? kEarlyArrivalBonusPct) * 100)
                .round()
          : 0,
      expectedRebuyRate: s.expectedRebuyRate,
      forceStack: s.forceStack,
      pins: s.levelPins,
      breaks: s.breaks,
      options: BuilderOptions(
        koEnabled: s.koEnabled,
        koAmount: s.koAmount,
        organizerPct: s.organizerPct,
        rebuyCost: s.effectiveFormat == TournamentFormat.rebuy
            ? (s.rebuyCost ?? s.buyIn)
            : s.rebuyCost,
        addOnCost: s.addOnCost,
        paidPlaces: s.forcePaidPlaces,
        maxPerTable: s.tableSettingsOverride?.maxPerTable,
        expectedRebuys: s.expectedRebuys,
        expectedReEntries: s.expectedReEntries,
        expectedAddOns: s.expectedAddOns,
        rebuyChips: s.rebuyChips,
        reEntryChips: s.reEntryChips,
        addOnChips: s.addOnChips,
      ),
      rebuyClose: s.rebuysCloseLevel,
      rebuyCloseChosen: s.rebuyCloseChosenByOrganizer,
      startMinutes: startMinutes,
    );
  }

  final BuilderMode mode;
  String _chipSetName;
  String get chipSetName => _chipSetName;

  /// Money, bounty, prize places, table size and expectations (see
  /// [BuilderOptions]); change them through [updateOptions].
  final BuilderOptions options;

  /// Free tools have no chip case: the engine runs against a synthetic
  /// never-binding bank (§F1.14).
  final bool syntheticBank;

  /// Minutes after midnight the night starts; only used to turn a "finish at"
  /// time into a duration.
  final int startMinutes;

  BuilderStep step = BuilderStep.inputs;

  List<ChipColor> _chipSet;
  int _players;
  double _durationHours;
  int _buyIn;
  late int _depthBB;
  TournamentType? _type;
  int _levelMins;
  TournamentFormat _format;
  int? _rebuyLimit;
  bool _rebuyLimitTouched;
  bool _addOn;
  bool _anteEnabled;
  AnteStyle _anteStyle;
  int _bonusPct;
  double? _expectedRebuyRate;
  int? _forceStack;
  List<LevelPin> _pins;
  List<LevelPin> _appliedPins;
  final List<ScheduledBreak> _breaks;
  int _rebuyClose;
  bool _rebuyCloseChosen;

  TournamentStructure? _structure;
  String? pinError;

  // ── Suggestions ──────────────────────────────────────────────────────────

  /// Unlimited for a small table (play stays continuous), Limited above it.
  // OWNER-DECISION: the suggestion thresholds — ≤ 8 unlimited, 9–14 two
  // rebuys each, 15+ one each.
  static int? suggestRebuyLimit(int players) {
    if (players <= 8) return null;
    return players <= 14 ? 2 : 1;
  }

  // ── Inputs ───────────────────────────────────────────────────────────────

  int get players => _players;
  double get durationHours => _durationHours;
  int get buyIn => _buyIn;
  int get depthBB => _depthBB;

  /// Null when the depth is a custom value that matches no type.
  TournamentType? get type => _type;
  bool get customDepth => _type == null;
  int get levelMins => _levelMins;
  TournamentFormat get format => _format;
  bool get rebuyNight =>
      _format == TournamentFormat.rebuy || _format == TournamentFormat.reEntry;
  bool get limited => _rebuyLimit != null;
  int? get rebuyLimit => _rebuyLimit;
  bool get addOn => _addOn;
  bool get anteEnabled => _anteEnabled;
  AnteStyle get anteStyle => _anteStyle;
  int get bonusPct => _bonusPct;
  double? get expectedRebuyRate => _expectedRebuyRate;
  int? get forceStack => _forceStack;
  List<LevelPin> get pins => List.unmodifiable(_pins);
  List<ChipColor> get chipSet => _chipSet;
  bool get rebuyCloseChosen => _rebuyCloseChosen;

  /// Breaks: the event's own when the host set any; otherwise one 10-minute
  /// break right after the rebuy window closes, for the add-on (the engine
  /// places an `afterLevel: 0` break at the close, so it moves with it).
  // OWNER-DECISION: the add-on break is 10 minutes and exists only when the
  // night has an add-on.
  List<ScheduledBreak> get breaks {
    if (_breaks.isNotEmpty) return _breaks;
    if (rebuyNight && _addOn) {
      return const [ScheduledBreak(afterLevel: 0, durationMins: 10)];
    }
    return const [];
  }

  /// Clock time (minutes after midnight, wrapped) the night is planned to end.
  int get finishMinutes =>
      (startMinutes + (_durationHours * 60).round()) % (24 * 60);

  void _inputChanged() {
    // Any input moves the ladder, so the stack and the pins the host set
    // against the old one no longer mean anything.
    _forceStack = null;
    _pins = [];
    _appliedPins = [];
    pinError = null;
    _structure = null;
    notifyListeners();
  }

  void setPlayers(int v) {
    final n = v.clamp(2, 100);
    if (n == _players) return;
    _players = n;
    if (_playerNames.length > n) {
      _playerNames.removeRange(n, _playerNames.length);
    }
    if (_format == TournamentFormat.rebuy && !_rebuyLimitTouched) {
      _rebuyLimit = suggestRebuyLimit(n);
    }
    _inputChanged();
  }

  void setDurationHours(double v) {
    final h = v.clamp(1.0, 12.0).toDouble();
    if (h == _durationHours) return;
    _durationHours = h;
    _inputChanged();
  }

  /// "Finish at": the duration from [startMinutes] to a clock time, wrapping
  /// past midnight, rounded to the half hour the stepper uses.
  void setFinishMinutes(int clock) {
    var diff = (clock - startMinutes) % (24 * 60);
    if (diff <= 0) diff += 24 * 60;
    setDurationHours(((diff / 30).round() * 30) / 60);
  }

  /// Changes one of the [options]. [ladder] is true for the ones that change
  /// how many chips are in play (expected rebuys, add-ons, chip amounts): they
  /// move the ladder, so a forced stack and pins set against it are dropped.
  /// Money, bounty, prize places and table size never touch the ladder.
  void updateOptions(
    void Function(BuilderOptions o) change, {
    bool ladder = false,
  }) {
    change(options);
    if (ladder) {
      _inputChanged();
    } else {
      _structure = null;
      notifyListeners();
    }
  }

  void setBuyIn(int v) {
    if (v == _buyIn || v <= 0) return;
    _buyIn = v;
    // The buy-in sets prizes and prices, never a blind or a stack.
    _structure = null;
    notifyListeners();
  }

  // ── Player names (quick game) ────────────────────────────────────────────

  final List<String> _playerNames = [];

  /// Optional names for the quick game, positional, never more than the player
  /// count. Empty means "Player 1, Player 2, …" as before.
  List<String> get playerNames => List.unmodifiable(_playerNames);

  /// Adds one empty name row; refused once every player has a row.
  bool addPlayerName() {
    if (_playerNames.length >= _players) return false;
    _playerNames.add('');
    notifyListeners();
    return true;
  }

  void removePlayerName(int index) {
    if (index < 0 || index >= _playerNames.length) return;
    _playerNames.removeAt(index);
    notifyListeners();
  }

  /// Does not notify: the text field already shows what was typed.
  void setPlayerName(int index, String name) {
    if (index < 0 || index >= _playerNames.length) return;
    _playerNames[index] = name;
  }

  /// The names to seat, trimmed and without blanks.
  List<String> get namesToSeat => [
    for (final n in _playerNames)
      if (n.trim().isNotEmpty) n.trim(),
  ];

  void setType(TournamentType t) {
    if (_type == t && _depthBB == t.depthBB) return;
    _type = t;
    _depthBB = t.depthBB;
    _inputChanged();
  }

  void setCustomDepth(int bb) {
    final d = bb.clamp(kCustomDepthMin, kCustomDepthMax);
    if (d == _depthBB && _type == TournamentTypeX.forDepth(d)) return;
    _depthBB = d;
    // A custom value that lands on a type's depth IS that type.
    _type = TournamentTypeX.forDepth(d);
    _inputChanged();
  }

  /// Switches to "Custom depth" keeping the current depth as the start value.
  void useCustomDepth() {
    if (customDepth) return;
    _type = null;
    notifyListeners();
  }

  void setLevelMins(int min) {
    final m = min.clamp(
      TournamentEngine.kMinLevelDurationMins,
      TournamentEngine.kMaxLevelDurationMins,
    );
    if (m == _levelMins) return;
    _levelMins = m;
    _inputChanged();
  }

  void setFormat(TournamentFormat f) {
    if (f == _format) return;
    _format = f;
    if (f == TournamentFormat.freezeOut) {
      _rebuyClose = 0;
      _rebuyCloseChosen = false;
    }
    if (f == TournamentFormat.rebuy && !_rebuyLimitTouched) {
      _rebuyLimit = suggestRebuyLimit(_players);
    }
    _inputChanged();
  }

  /// null = unlimited rebuys.
  void setRebuyLimit(int? limit) {
    _rebuyLimit = limit;
    _rebuyLimitTouched = true;
    _inputChanged();
  }

  void setAddOn(bool v) {
    if (v == _addOn) return;
    _addOn = v;
    _inputChanged();
  }

  void setAnteEnabled(bool v) {
    if (v == _anteEnabled) return;
    _anteEnabled = v;
    _inputChanged();
  }

  void setAnteStyle(AnteStyle s) {
    if (s == _anteStyle) return;
    _anteStyle = s;
    _inputChanged();
  }

  void setBonusPct(int pct) {
    final v = pct.clamp(0, 100);
    if (v == _bonusPct) return;
    _bonusPct = v;
    _inputChanged();
  }

  void setChipSet(List<ChipColor> chips, {String? name}) {
    _chipSet = chips;
    if (name != null) _chipSetName = name;
    _inputChanged();
  }

  // ── The engine's answer ──────────────────────────────────────────────────

  /// The engine inputs for the current choices. The same object the provider
  /// rebuilds from [applyTo]'s settings, so Recalculate reproduces this.
  TournamentParams get params {
    final isRebuy = _format == TournamentFormat.rebuy;
    final isReEntry = _format == TournamentFormat.reEntry;
    final night = isRebuy || isReEntry;
    return TournamentParams(
      players: _players,
      durationHours: _durationHours,
      buyIn: _buyIn,
      chipSet: syntheticBank
          ? TournamentEngine.neverBindingBank(_chipSet, players: _players)
          : _chipSet,
      rebuys: isRebuy,
      rebuysCloseLevel: night && _rebuyCloseChosen ? _rebuyClose : 0,
      rebuyCloseChosenByOrganizer: night && _rebuyCloseChosen,
      rebuyLimit: isRebuy ? _rebuyLimit : null,
      reEntry: isReEntry,
      addOn: night && _addOn,
      anteEnabled: _anteEnabled,
      anteAfterLevel: 6,
      breaks: breaks,
      anteStyle: _anteStyle,
      koEnabled: options.koEnabled,
      koAmount: options.koAmount,
      organizerPct: options.organizerPct,
      rebuyCost: options.rebuyCost,
      addOnCost: options.addOnCost,
      expectedRebuys: options.expectedRebuys,
      expectedReEntries: options.expectedReEntries,
      expectedAddOns: options.expectedAddOns,
      rebuyChips: options.rebuyChips,
      reEntryChips: options.reEntryChips,
      addOnChips: options.addOnChips,
      levelDurationMins: _levelMins,
      pace: _type?.pace ?? _paceForDepth(_depthBB),
      targetDepthBB: _depthBB,
      forceStack: _forceStack,
      format: _format,
      expectedRebuyRate: night ? (_expectedRebuyRate ?? kExpectedRebuyRate) : 0,
      earlyArrivalBonusEnabled: _bonusPct > 0,
      earlyArrivalBonusPctOverride: _bonusPct > 0 ? _bonusPct / 100 : null,
    );
  }

  PaceMode _paceForDepth(int bb) =>
      bb < 100 ? PaceMode.turbo : (bb > 100 ? PaceMode.deep : PaceMode.regular);

  /// The pace is [TournamentType.pace] for a named type, and follows the
  /// depth for a custom one.
  // OWNER-DECISION: a custom depth below 100 BB uses the turbo style, above
  // 100 the deep style (M floor and growth ceiling).
  TournamentStructure get structure =>
      _structure ??= solveWithPins(params, _appliedPins);

  bool get isBlocked => structure.isBlocked;

  /// Pins the displayed ladder has not been re-solved around yet.
  bool get hasPendingPins => !listEquals(_pins, _appliedPins);

  int get roundUnit {
    var minChip = 0;
    for (final c in _chipSet) {
      if (c.quantity > 0 && (minChip == 0 || c.value < minChip)) {
        minChip = c.value;
      }
    }
    return minChip > 25 ? minChip : 25;
  }

  /// Opening depth in big blinds, or null while there is no ladder.
  double? get stackDepthBB => structure.openingBBDepth;

  /// What the on-time bonus stack is worth in chips, next to its percentage.
  int get bonusChips => (structure.startingStack * _bonusPct / 100).round();

  /// Shallow-start options (each one re-runs the engine); empty unless the
  /// night is shallow and the host has not forced the stack.
  List<ShallowFix> get shallowFixes {
    if (_forceStack != null || !structure.isShallow) return const [];
    return TournamentEngine.shallowFixes(params);
  }

  /// The host's tap on a shallow option. Never called implicitly.
  void applyShallowFix(ShallowFix fix) {
    if (fix.rebuyLimit != null) {
      _rebuyLimit = fix.rebuyLimit;
      _rebuyLimitTouched = true;
    }
    if (fix.expectedRebuyRate != null) {
      _expectedRebuyRate = fix.expectedRebuyRate;
    }
    if (fix.addOn != null) _addOn = fix.addOn!;
    _inputChanged();
  }

  // ── Steps ────────────────────────────────────────────────────────────────

  void goTo(BuilderStep s) {
    step = s;
    notifyListeners();
  }

  /// "Next" from the inputs: the engine's own stack is shown first.
  void continueToStack() => goTo(BuilderStep.stack);

  /// Editing the stack → forceStack → re-run. The blinds are re-solved around
  /// the new stack, so earlier pins are dropped.
  void setStack(int stack) {
    if (stack <= 0) return;
    _forceStack = stack;
    _pins = [];
    _appliedPins = [];
    pinError = null;
    _structure = null;
    notifyListeners();
  }

  /// Hands the stack back to the engine.
  void clearForcedStack() {
    if (_forceStack == null) return;
    _forceStack = null;
    _pins = [];
    _appliedPins = [];
    _structure = null;
    notifyListeners();
  }

  /// "Approve stack": only a night the chips can deal goes on to the levels.
  bool approveStack() {
    if (isBlocked) return false;
    goTo(BuilderStep.structure);
    return true;
  }

  // ── Levels ───────────────────────────────────────────────────────────────

  /// The levels as shown: the engine's, with each pinned row overlaid by what
  /// the host typed. Rows the host has not pinned are exactly the solver's.
  List<BlindLevel> get levels {
    final byLevel = {for (final p in _pins) p.level: p};
    return [
      for (final l in structure.levels)
        if (byLevel[l.level] case final p?)
          l.copyWith(
            sb: p.sb,
            bb: p.bb,
            ante: l.ante != null && _anteStyle == AnteStyle.bigBlind
                ? p.bb
                : l.ante,
            durationMins: p.durationMins ?? l.durationMins,
            manuallyEdited: true,
          )
        else
          l,
    ];
  }

  bool isPinned(int level) => _pins.any((p) => p.level == level);

  /// Pins [level] at the typed values. Returns the reason it cannot be, or
  /// null on success. The other rows do not move until
  /// [recalculateAround] — that is the point of the calculator button.
  String? editLevel(
    int level, {
    required int sb,
    required int bb,
    required int mins,
  }) {
    final next = [
      for (final p in _pins)
        if (p.level != level) p,
      LevelPin(level: level, sb: sb, bb: bb, durationMins: mins),
    ]..sort((a, b) => a.level - b.level);
    final err = validatePins(next, levelCount: structure.levels.length);
    pinError = err;
    if (err != null) {
      notifyListeners();
      return err;
    }
    _pins = next;
    notifyListeners();
    return null;
  }

  /// Removes the pin and hands the row back to the engine.
  void unpin(int level) {
    _pins = [
      for (final p in _pins)
        if (p.level != level) p,
    ];
    _appliedPins = [
      for (final p in _appliedPins)
        if (p.level != level) p,
    ];
    pinError = null;
    _structure = null;
    notifyListeners();
  }

  /// "Recalculate around this": `TournamentEngine.recalculate(params, pins)`.
  /// Pinned rows keep their values; only unpinned levels change.
  void recalculateAround() {
    _appliedPins = List.of(_pins);
    _structure = null;
    notifyListeners();
  }

  // ── Rebuy close ──────────────────────────────────────────────────────────

  /// The level rebuys close after, as the structure was actually built.
  int get rebuyCloseLevel => structure.rebuysCloseLevel;

  /// The host moves the marker: re-solve (the ante start and the add-on break
  /// follow it) and keep the choice so Recalculate cannot undo it.
  void setRebuyClose(int level) {
    if (!rebuyNight) return;
    _rebuyClose = level;
    _rebuyCloseChosen = true;
    _structure = null;
    notifyListeners();
  }

  /// "Fresh stack at L{n}: {x} BB, M {m}" for the level the marker is on.
  String? get freshStackLabel => structure.freshStackAt(rebuyCloseLevel)?.label;

  // ── Output ───────────────────────────────────────────────────────────────

  /// The structure the saved settings regenerate to: every pin applied, without
  /// touching what is on screen. Persisted alongside [applyTo]'s settings.
  TournamentStructure resolved() => solveWithPins(params, _pins);

  /// The finished structure: every pin applied, exactly what the provider's
  /// Recalculate will rebuild from [applyTo]'s settings.
  TournamentStructure finalStructure() {
    _appliedPins = List.of(_pins);
    _structure = null;
    return structure;
  }

  /// The tournament's settings carrying every builder choice, so the stack,
  /// depth, pins and a chosen rebuy close survive Recalculate and reopening.
  GameSettings applyTo(GameSettings base) {
    final p = params;
    final s = structure;
    final o = options;
    return base
        .copyWith(clearBuilderOverrides: true)
        .copyWith(
          players: _players,
          durationHours: _durationHours,
          buyIn: _buyIn,
          rebuys: p.rebuys,
          reEntry: p.reEntry,
          addOn: p.addOn,
          format: _format,
          rebuyLimit: p.rebuyLimit,
          clearRebuyLimit: p.rebuyLimit == null,
          expectedRebuyRate: _expectedRebuyRate,
          rebuysCloseLevel: rebuyNight && s.rebuysCloseLevel > 0
              ? s.rebuysCloseLevel
              : p.rebuysCloseLevel,
          rebuyCloseChosenByOrganizer: p.rebuyCloseChosenByOrganizer,
          anteEnabled: _anteEnabled,
          anteAfterLevel: rebuyNight && s.rebuysCloseLevel > 0
              ? s.rebuysCloseLevel + 1
              : p.anteAfterLevel,
          anteStyle: _anteStyle,
          antePreference: _anteEnabled
              ? (_anteStyle == AnteStyle.individual
                    ? AntePreference.individual
                    : AntePreference.bigBlind)
              : AntePreference.none,
          levelDurationMins: _levelMins,
          pace: p.pace,
          targetDepthBB: _depthBB,
          forceStack: _forceStack,
          clearForceStack: _forceStack == null,
          levelPins: List.of(_pins),
          breaks: p.breaks,
          earlyArrivalBonusEnabled: _bonusPct > 0,
          earlyArrivalBonusPctOverride: _bonusPct > 0 ? _bonusPct / 100 : null,
          clearEarlyArrivalBonusPctOverride: _bonusPct == 0,
          chipSet: _chipSet,
          koEnabled: o.koEnabled,
          koAmount: o.koAmount,
          organizerPct: o.organizerPct,
          rebuyCost: o.rebuyCost,
          addOnCost: o.addOnCost,
          expectedRebuys: o.expectedRebuys,
          expectedReEntries: o.expectedReEntries,
          expectedAddOns: o.expectedAddOns,
          rebuyChips: o.rebuyChips,
          reEntryChips: o.reEntryChips,
          addOnChips: o.addOnChips,
          forcePaidPlaces: o.paidPlaces,
          clearForcePaidPlaces: o.paidPlaces == null,
          tableSettingsOverride: o.maxPerTable == null
              ? null
              : TableSettings(
                  maxPerTable: o.maxPerTable!,
                  randomizeByDefault:
                      base.tableSettingsOverride?.randomizeByDefault ?? false,
                ),
          clearTableSettingsOverride: o.maxPerTable == null,
        );
  }
}

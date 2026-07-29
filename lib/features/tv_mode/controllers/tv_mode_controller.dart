import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TvColorPreset {
  final Color background;
  final Color text;
  final Color accent;
  final Color card;
  final Color timer;

  const TvColorPreset({
    required this.background,
    required this.text,
    required this.accent,
    required this.card,
    required this.timer,
  });

  static const defaultPreset = TvColorPreset(
    background: Color(0xFF1A1A2E),
    text: Color(0xFFFFFFFF),
    accent: Color(0xFFE94560),
    card: Color(0xFF16213E),
    timer: Color(0xFF0F3460),
  );
}

class TvModeSettings {
  final bool showTimer;
  final bool showBlinds;
  final bool showPlayers;
  final bool showAverageStack;
  final bool showPrizePool;
  final bool compactMode;
  final bool fullscreen;
  final TvColorPreset colorPreset;

  const TvModeSettings({
    this.showTimer = true,
    this.showBlinds = true,
    this.showPlayers = true,
    this.showAverageStack = true,
    this.showPrizePool = true,
    this.compactMode = false,
    this.fullscreen = false,
    this.colorPreset = TvColorPreset.defaultPreset,
  });

  TvModeSettings copyWith({
    bool? showTimer,
    bool? showBlinds,
    bool? showPlayers,
    bool? showAverageStack,
    bool? showPrizePool,
    bool? compactMode,
    bool? fullscreen,
    TvColorPreset? colorPreset,
  }) {
    return TvModeSettings(
      showTimer: showTimer ?? this.showTimer,
      showBlinds: showBlinds ?? this.showBlinds,
      showPlayers: showPlayers ?? this.showPlayers,
      showAverageStack: showAverageStack ?? this.showAverageStack,
      showPrizePool: showPrizePool ?? this.showPrizePool,
      compactMode: compactMode ?? this.compactMode,
      fullscreen: fullscreen ?? this.fullscreen,
      colorPreset: colorPreset ?? this.colorPreset,
    );
  }
}

class TvModeController extends GetxController {
  final Rx<TvModeSettings> state = const TvModeSettings().obs;

  void toggleTimer() => state.value = state.value.copyWith(showTimer: !state.value.showTimer);
  void toggleBlinds() => state.value = state.value.copyWith(showBlinds: !state.value.showBlinds);
  void togglePlayers() => state.value = state.value.copyWith(showPlayers: !state.value.showPlayers);
  void toggleAverageStack() => state.value = state.value.copyWith(showAverageStack: !state.value.showAverageStack);
  void togglePrizePool() => state.value = state.value.copyWith(showPrizePool: !state.value.showPrizePool);
  void toggleCompactMode() => state.value = state.value.copyWith(compactMode: !state.value.compactMode);
  void toggleFullscreen() => state.value = state.value.copyWith(fullscreen: !state.value.fullscreen);
}

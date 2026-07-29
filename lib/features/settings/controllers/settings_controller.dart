import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/services/storage_service.dart';

class SettingsState {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool voiceEnabled;
  final bool soundEnabled;
  final String? audioMasterDeviceId;
  final String? audioMasterDeviceLabel;
  final Locale? locale;

  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.notificationsEnabled = true,
    this.voiceEnabled = true,
    this.soundEnabled = true,
    this.audioMasterDeviceId,
    this.audioMasterDeviceLabel,
    this.locale,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? voiceEnabled,
    bool? soundEnabled,
    String? audioMasterDeviceId,
    String? audioMasterDeviceLabel,
    Locale? locale,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      audioMasterDeviceId: audioMasterDeviceId ?? this.audioMasterDeviceId,
      audioMasterDeviceLabel: audioMasterDeviceLabel ?? this.audioMasterDeviceLabel,
      locale: locale ?? this.locale,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.index,
    'notificationsEnabled': notificationsEnabled,
    'voiceEnabled': voiceEnabled,
    'soundEnabled': soundEnabled,
    'audioMasterDeviceId': audioMasterDeviceId,
    'audioMasterDeviceLabel': audioMasterDeviceLabel,
    'locale': locale?.toString(),
  };

  factory SettingsState.fromJson(Map<String, dynamic> json) => SettingsState(
    themeMode: ThemeMode.values[json['themeMode'] as int? ?? 2], // default dark
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    voiceEnabled: json['voiceEnabled'] as bool? ?? true,
    soundEnabled: json['soundEnabled'] as bool? ?? true,
    audioMasterDeviceId: json['audioMasterDeviceId'] as String?,
    audioMasterDeviceLabel: json['audioMasterDeviceLabel'] as String?,
  );
}

class SettingsController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();

  final state = const SettingsState().obs;

  @override
  void onInit() {
    super.onInit();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final data = await _storage.getJson('app_settings');
    if (data != null) {
      state.value = SettingsState.fromJson(data);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state.value = state.value.copyWith(themeMode: mode);
    await _persist();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    state.value = state.value.copyWith(notificationsEnabled: value);
    await _persist();
  }

  Future<void> setVoiceEnabled(bool value) async {
    state.value = state.value.copyWith(voiceEnabled: value);
    await _persist();
  }

  Future<void> setSoundEnabled(bool value) async {
    state.value = state.value.copyWith(soundEnabled: value);
    await _persist();
  }

  Future<void> setLocale(Locale locale) async {
    state.value = state.value.copyWith(locale: locale);
    await _persist();
  }

  Future<void> setAudioMaster(String? deviceId, String? deviceLabel) async {
    state.value = state.value.copyWith(audioMasterDeviceId: deviceId, audioMasterDeviceLabel: deviceLabel);
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.set('app_settings', state.value.toJson());
  }
}

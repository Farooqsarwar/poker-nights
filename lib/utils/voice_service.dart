import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around [FlutterTts] for English tournament announcements
/// (checklist §15.4). Fails silently when speech synthesis is unavailable so
/// a voice failure never stops the timer or tournament controls (15-054).
class VoiceService {
  VoiceService._();
  static final VoiceService instance = VoiceService._();

  FlutterTts? _tts;
  bool _initialised = false;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    _initialised = true;
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(true);

      // Force playback even if the silent switch is on (crucial for iOS)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ]);
      }

      _tts = tts;
    } catch (e) {
      // Speech synthesis unavailable on this platform/device — degrade quietly.
      if (kDebugMode) debugPrint('VoiceService init failed: $e');
      _tts = null;
    }
  }

  bool isLeader = true;
  String? leaderDeviceId;
  String? currentDeviceId;

  /// Multi-device leader check: true if this device is the designated audio leader.
  bool get shouldAnnounce {
    if (leaderDeviceId != null && currentDeviceId != null) {
      return leaderDeviceId == currentDeviceId;
    }
    return isLeader;
  }

  /// Configures multi-device leader check settings.
  void setLeaderState({
    required bool leader,
    String? currentId,
    String? leaderId,
  }) {
    isLeader = leader;
    if (currentId != null) currentDeviceId = currentId;
    if (leaderId != null) leaderDeviceId = leaderId;
  }

  /// Spec E11: Convert numbers to spoken English words for natural TTS pronunciation.
  static String numberToWords(int n) {
    if (n < 0) return 'minus ${numberToWords(-n)}';
    if (n == 0) return 'zero';
    const small = [
      '', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine',
      'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen',
      'seventeen', 'eighteen', 'nineteen'
    ];
    const tens = [
      '', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'
    ];
    if (n < 20) return small[n];
    if (n < 100) {
      final rem = n % 10;
      return rem == 0 ? tens[n ~/ 10] : '${tens[n ~/ 10]} ${small[rem]}';
    }
    if (n < 1000) {
      final rem = n % 100;
      final h = '${small[n ~/ 100]} hundred';
      return rem == 0 ? h : '$h and ${numberToWords(rem)}';
    }
    if (n < 1000000) {
      final rem = n % 1000;
      final k = '${numberToWords(n ~/ 1000)} thousand';
      return rem == 0 ? k : '$k ${numberToWords(rem)}';
    }
    return n.toString();
  }

  /// Plays a chime sound before an announcement (§E11).
  Future<void> playChime() async {
    if (!shouldAnnounce) return;
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Announces a 5-minute warning before a level or break ends.
  Future<void> announceFiveMinuteWarning(int level, {bool isBreak = false}) async {
    if (!shouldAnnounce) return;
    await playChime();
    final levelW = numberToWords(level);
    final message = isBreak
        ? 'Five minutes remaining in break.'
        : 'Five minutes remaining in Level $levelW.';
    await speak(message);
  }

  /// Announces a 1-minute warning before a level or break ends.
  Future<void> announceOneMinuteWarning(
    int level, {
    bool isBreak = false,
    int? nextSb,
    int? nextBb,
  }) async {
    if (!shouldAnnounce) return;
    await playChime();
    final levelW = numberToWords(level);
    String message;
    if (isBreak) {
      message = 'One minute remaining in break.';
    } else if (nextSb != null && nextBb != null) {
      message =
          'One minute remaining in Level $levelW. Next blinds ${numberToWords(nextSb)} and ${numberToWords(nextBb)}.';
    } else {
      message = 'One minute remaining in Level $levelW.';
    }
    await speak(message);
  }

  /// Announces a blind level change with chime.
  Future<void> announceLevelChange({
    required int level,
    required int sb,
    required int bb,
    int? ante,
  }) async {
    if (!shouldAnnounce) return;
    await playChime();
    final levelW = numberToWords(level);
    final sbW = numberToWords(sb);
    final bbW = numberToWords(bb);
    final anteText = ante != null && ante > 0 ? ', ante ${numberToWords(ante)}' : '';
    await speak('Level $levelW. Blinds $sbW and $bbW$anteText.');
  }

  /// Announces the start of a break with chime.
  Future<void> announceBreakStart({required int durationMins}) async {
    if (!shouldAnnounce) return;
    await playChime();
    final minsW = numberToWords(durationMins);
    await speak('$minsW minute break.');
  }

  /// Speak [text] in English. No-op if TTS could not be initialised or device is not leader.
  Future<void> speak(String text) async {
    if (!shouldAnnounce) return;
    if (text.trim().isEmpty) return;
    await _ensureInit();
    final tts = _tts;
    if (tts == null) return;
    try {
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService speak failed: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    await _tts?.setVolume(volume);
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

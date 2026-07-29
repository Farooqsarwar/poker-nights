import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService instance = VoiceService._();
  final FlutterTts _flutterTts = FlutterTts();

  VoiceService._() {
    _initTts();
  }

  bool enabled = true;

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void setAudioMasterId(String? deviceId) {
    // deviceId reserved for future audio device routing
  }

  Future<void> announce(String text) async {
    if (!enabled) return;
    try {
      await _speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  Future<void> _speak(String text) async {
    final escaped = text
        .replaceAll("'", "\\'")
        .replaceAll('\n', ' ')
        .replaceAll('\r', '');
    debugPrint('Voice: $escaped');
    await _flutterTts.speak(escaped);
  }

  Future<void> announceLevel(int level, int smallBlind, int bigBlind) async {
    await announce('Level $level: $smallBlind $bigBlind');
  }

  Future<void> announceFiveMinutes() async {
    await announce('Five minutes remaining in this level');
  }

  Future<void> announceOneMinute() async {
    await announce('One minute remaining');
  }

  Future<void> announceRebuysClosed() async {
    await announce('Rebuys are now closed');
  }

  Future<void> announceFinalTable() async {
    await announce('Final table');
  }

  Future<void> announceWinner(String name) async {
    await announce('The winner is $name');
  }

  Future<void> announceLevelChange(int level, int sb, int bb) async {
    await announce('Level $level: $sb $bb');
  }

  Future<void> announcePlayerEliminated(String name, int position) async {
    await announce('$name eliminated in position $position');
  }

  Future<void> announceBreak() async {
    await announce('Break time');
  }
}

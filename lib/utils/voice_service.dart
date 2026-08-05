import 'package:flutter/foundation.dart';
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
      _tts = tts;
    } catch (e) {
      // Speech synthesis unavailable on this platform/device — degrade quietly.
      if (kDebugMode) debugPrint('VoiceService init failed: $e');
      _tts = null;
    }
  }

  /// Speak [text] in English. No-op if TTS could not be initialised.
  Future<void> speak(String text) async {
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

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

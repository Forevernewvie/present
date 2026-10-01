import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'interfaces/i_stt_service.dart';

class SttService implements ISttService {
  final SpeechToText _speech;
  Timer? _emulatorTypingTimer;
  bool _isEmulator = false;

  SttService({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(dynamic) onError,
  }) async {
    try {
      bool available = await _speech.initialize(
        onStatus: onStatus,
        onError: onError,
      );
      _isEmulator = !available;
      return available;
    } catch (e) {
      debugPrint('STT init exception: $e');
      _isEmulator = true;
      return false;
    }
  }

  @override
  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  }) {
    if (!_isEmulator) {
      _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(localeId: 'ko_KR'),
        pauseFor: pauseFor,
      );
    } else {
      debugPrint('기기 STT 사용 불가 (에뮬레이터 환경 감지) - 입력 시뮬레이션 가동');
      final script = ['오늘 날씨가 ', '오늘 날씨가 참 좋네, ', '오늘 날씨가 참 좋네, 공원에 산책 가야겠어.'];
      int idx = 0;
      _emulatorTypingTimer?.cancel();
      _emulatorTypingTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
        if (idx < script.length) {
          onResult(script[idx]);
          idx++;
        } else {
          timer.cancel();
          onEmulatorDone();
        }
      });
    }
  }

  @override
  Future<void> stop() async {
    _emulatorTypingTimer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _emulatorTypingTimer?.cancel();
    // SpeechToText doesn't have a public dispose method to call here, stop is enough.
  }
}

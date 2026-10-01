import 'dart:io';

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'interfaces/i_tts_service.dart';

class TtsService implements ITtsService {
  final FlutterTts _flutterTts;
  bool _isInitialized = false;
  Completer<void>? _currentSpeakCompleter;

  TtsService({FlutterTts? tts}) : _flutterTts = tts ?? FlutterTts();

  Future<void> _initTts() async {
    if (_isInitialized) return;
    try {
      if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playAndRecord,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker
          ],
        );
      }
      
      await _flutterTts.setLanguage('ko-KR');
      await _flutterTts.setSpeechRate(0.48); // 어르신을 위한 편안하고 또박또박한 속도
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(true); // 반드시 음성 출력이 끝날 때까지 대기하도록 설정

      _flutterTts.setStartHandler(() {
        debugPrint('TTS Started');
      });

      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS Completed');
        if (_currentSpeakCompleter != null && !_currentSpeakCompleter!.isCompleted) {
          _currentSpeakCompleter!.complete();
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        if (_currentSpeakCompleter != null && !_currentSpeakCompleter!.isCompleted) {
          _currentSpeakCompleter!.complete();
        }
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  /// 텍스트를 음성으로 출력하며, 출력이 완전히 끝날 때까지 대기(await)할 수 있습니다.
  @override
  Future<void> speak(String text) async {
    await _initTts();
    if (!_isInitialized) return;
    await stop(); // 이전 음성이 있다면 중단

    _currentSpeakCompleter = Completer<void>();

    try {
      final result = await _flutterTts.speak(text);
      if (result == 1) {
        // 음성이 완료될 때까지 대기
        await _currentSpeakCompleter!.future;
      }
    } catch (e) {
      debugPrint('TTS speak error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      if (_currentSpeakCompleter != null && !_currentSpeakCompleter!.isCompleted) {
        _currentSpeakCompleter!.complete();
      }
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  @override
  void dispose() {
    stop();
  }
}

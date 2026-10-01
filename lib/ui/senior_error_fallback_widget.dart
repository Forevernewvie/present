import 'dart:ui';
import 'package:flutter/material.dart';

/// 앱 전체에서 발생하는 예기치 못한 예외 및 렌더링 에러를 가로채어
/// 화이트 스크린 및 비정상 종료를 원천 방지하는 전역 에러 핸들러 설정 (Pillar 3)
void setupGlobalErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Global Framework FlutterError caught: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Global PlatformDispatcher unhandled error caught: $error\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return SeniorErrorFallbackWidget(details: details);
  };
}

/// 시니어 사용자를 위한 전역 오류 복구 화면 위젯
/// 예기치 못한 렌더링 오류가 발생했을 때 붉은 오류 화면 대신
/// 친절하고 편안한 안내와 복구 수단을 제공합니다.
class SeniorErrorFallbackWidget extends StatelessWidget {
  final FlutterErrorDetails? details;

  const SeniorErrorFallbackWidget({
    super.key,
    this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFDFBF7),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF689F38).withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    size: 48,
                    color: Color(0xFF689F38),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '화면을 불러오는 중\n잠시 문제가 발생했습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '대화 내용은 안전하게 보관되어 있습니다.\n앱을 잠시 후 다시 열어주시거나\n화면을 다시 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('화면 다시 시도'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF689F38),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

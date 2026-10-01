import 'dart:async';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showLoadingText = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 3초 후에도 이 화면에 머물러 있다면 로딩 텍스트를 보여줌
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLoadingText = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 앱 로고 또는 이름
            const Text(
              'Present',
              style: TextStyle(
                fontSize: 48,
                color: Color(0xFF689F38), // 메인 웜 그린
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // 네트워크 지연 시 나타나는 부드러운 로딩 UI
            AnimatedOpacity(
              opacity: _showLoadingText ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: const Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF689F38)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '안전한 연결을 확인 중입니다...',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

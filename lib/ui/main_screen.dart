import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'calendar_bottom_sheet.dart';
import 'persona_bottom_sheet.dart';
import 'app_settings_dialog.dart';
import '../providers/voice_chat_provider.dart';
import '../providers/settings_provider.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(voiceChatProvider).status == VoiceChatStatus.recording) {
        if (!_rippleController.isAnimating) {
          _rippleController.repeat();
        }
      }
      if (mounted && !ref.read(settingsProvider).isConfigured) {
        PersonaBottomSheet.show(context, initialSetupOnly: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rippleController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 앱이 실제 백그라운드로 전환(paused, detached)될 때만 마이크/음성 프로세스 안전 정지
    // 권한 팝업, 알림창 등으로 인한 일시적인 inactive 상태에서는 통화가 끊기지 않도록 보호
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(voiceChatProvider.notifier).handleLifecyclePause();
    }
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      await [
        Permission.microphone,
        Permission.speech,
      ].request();
    }
  }

  Future<void> _handleMicTap() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      final micStatus = await Permission.microphone.status;
      if (micStatus.isPermanentlyDenied) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('마이크 권한 안내'),
            content: const Text('원활한 음성 대화를 위해 마이크 권한이 필요합니다.\n설정에서 권한을 허용해 주시겠어요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
        return;
      } else if (!micStatus.isGranted) {
        final res = await [Permission.microphone, Permission.speech].request();
        if (res[Permission.microphone]?.isGranted != true) {
          return;
        }
      }
    }
    ref.read(voiceChatProvider.notifier).toggleRecording();
  }

  void _openCalendar(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CalendarBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceChatState>(voiceChatProvider, (previous, next) {
      if (next.status == VoiceChatStatus.recording) {
        if (!_rippleController.isAnimating) {
          _rippleController.repeat();
        }
      } else {
        if (_rippleController.isAnimating) {
          _rippleController.stop();
          _rippleController.reset();
        }
      }
    });

    final voiceState = ref.watch(voiceChatProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    // 4단계 상태 머신에 따른 안내 문구
    String promptText;
    Color promptColor = Colors.black87;

    if (voiceState.status == VoiceChatStatus.idle) {
      promptText = "대화를 시작하려면\n마이크를 눌러주세요";
      promptColor = Colors.black87;
    } else if (voiceState.status == VoiceChatStatus.thinking) {
      promptText = "생각하고 있어요...\n잠시만 기다려주세요";
      promptColor = theme.colorScheme.primary;
    } else {
      promptText = "대화가 진행 중입니다\n종료하려면 한 번 더 눌러주세요";
      promptColor = theme.colorScheme.primary;
    }

    // 마이크 버튼 아이콘 및 색상 결정
    IconData buttonIcon = Icons.mic;
    Color buttonColor = theme.colorScheme.primary;

    if (voiceState.status != VoiceChatStatus.idle) {
      buttonColor = const Color(0xFFD32F2F); // 통화 중일 때 눈에 띄게 (또는 원래 색상 유지)
      // 사용자 요청: "버튼 모양은 그대로 두고 글씨만 아래 띄운다"
      // 초록색 마이크 모양을 그대로 유지하겠습니다.
      buttonColor = theme.colorScheme.primary;
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        titleSpacing: 16,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Present', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => PersonaBottomSheet.show(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.parentTitle == '엄마'
                            ? '👩 엄마'
                            : (settings.parentTitle == '아빠' ? '👨 아빠' : '💬 호칭 없음'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.black87, size: 28),
            tooltip: '대화 기록 달력',
            padding: const EdgeInsets.all(8),
            onPressed: () => _openCalendar(context),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87, size: 26),
            tooltip: '앱 설정 및 정보',
            padding: const EdgeInsets.all(8),
            onPressed: () => AppSettingsDialog.show(context),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 36),
            // 상단 상태별 안내 문구
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                promptText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: promptColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 16),

            // 에러 안내 (API 키 미설정 등)
            if (voiceState.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Material(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      ref.read(voiceChatProvider.notifier).toggleRecording();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber[800], size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              voiceState.errorMessage!,
                              style: TextStyle(fontSize: 16, color: Colors.amber[900], height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // [요청 반영] 텍스트 자막을 숨기고 오직 '음성'으로만 대화하는 인터페이스로 변경
            // (사용자 인식 텍스트와 AI 답변 텍스트를 화면에서 제거)
            if (voiceState.errorMessage == null)
              const SizedBox(height: 48),

            const Spacer(),

            // 중앙 토글 방식 마이크 버튼 + 파동 애니메이션
            GestureDetector(
              onTap: _handleMicTap,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 파동(Ripple) 효과 (녹음 중일 때)
                  if (voiceState.status == VoiceChatStatus.recording)
                    AnimatedBuilder(
                      animation: _rippleController,
                      builder: (context, child) {
                        return Container(
                          width: 240 + (_rippleController.value * 80),
                          height: 240 + (_rippleController.value * 80),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withOpacity(
                              (1.0 - _rippleController.value).clamp(0.0, 0.4),
                            ),
                          ),
                        );
                      },
                    ),

                  // 메인 마이크 버튼 (터치 잠금 시각화 포함)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: buttonColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 10,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      buttonIcon,
                      size: voiceState.status == VoiceChatStatus.recording ? 100 : 80,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // AI 안전성 및 면책 안내 (Apple/Google AI 가이드라인 준수)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 24.0, right: 24.0),
              child: Text(
                '💡 Present AI는 정서적 말벗이며, 전문적인 의료·약학·법률 상담을 대신하지 않습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

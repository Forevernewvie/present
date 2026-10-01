import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:present_app/models/chat_message_model.dart';
import 'package:present_app/models/conversation_model.dart';
import 'package:present_app/models/user_model.dart';
import 'package:present_app/providers/auth_provider.dart';
import 'package:present_app/providers/conversation_list_provider.dart';
import 'package:present_app/providers/settings_provider.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/openai_service.dart';
import 'package:present_app/ui/calendar_bottom_sheet.dart';
import 'package:present_app/ui/login_screen.dart';
import 'package:present_app/ui/main_screen.dart';
import 'package:present_app/ui/persona_bottom_sheet.dart';

class MockConversationListNotifier extends ConversationListNotifier {
  final List<ConversationModel> _initial;
  MockConversationListNotifier([this._initial = const []]);

  @override
  Future<List<ConversationModel>> build() async => _initial;
}

class MockSettingsNotifierForUI extends SettingsNotifier {
  final bool configured;
  final String title;
  final PersonaType personaType;

  MockSettingsNotifierForUI({
    this.configured = true,
    this.title = '엄마',
    this.personaType = PersonaType.child,
  });

  @override
  SettingsState build() => SettingsState(
        isConfigured: configured,
        parentTitle: title,
        persona: personaType,
      );
}

class MockVoiceChatNotifierForUI extends VoiceChatNotifier {
  final VoiceChatState _initialState;
  int toggleRecordingCount = 0;
  int lifecyclePauseCount = 0;

  MockVoiceChatNotifierForUI(this._initialState);

  @override
  VoiceChatState build() => _initialState;

  @override
  Future<void> toggleRecording() async {
    toggleRecordingCount++;
  }

  @override
  Future<void> handleLifecyclePause() async {
    lifecyclePauseCount++;
  }

  void updateState(VoiceChatState newState) {
    state = newState;
  }
}

class MockAuthNotifierForUI extends AuthNotifier {
  final UserModel? _initialUser;
  int bypassLoginCount = 0;

  MockAuthNotifierForUI(this._initialUser);

  @override
  Future<UserModel?> build() async => _initialUser;

  @override
  Future<void> bypassLoginForTest({dynamic mockUser}) async {
    bypassLoginCount++;
    state = AsyncData(
      UserModel(
        id: 'test-user-id',
        kakaoId: 'kakao-test',
        name: '테스터',
        createdAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalendarBottomSheet Comprehensive Tests', () {
    testWidgets('renders empty state when no conversations exist', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: CalendarBottomSheet(),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationListProvider.overrideWith(() => MockConversationListNotifier([])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF689F38)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('나의 기록'), findsOneWidget);
      expect(find.text('이 날에는 대화 기록이 없습니다.'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('renders populated conversations and navigates to detail on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final today = DateTime.now();
      final sampleConvs = [
        ConversationModel(
          id: 'conv-1',
          userId: 'user-1',
          date: today,
          summary: '오늘 나눈 즐거운 대화 내용 요약',
          createdAt: today,
          messages: [
            ChatMessageModel(
              id: 'm1',
              conversationId: 'conv-1',
              sender: 'user',
              content: '오늘 날씨가 참 좋아요',
              createdAt: today,
            ),
            ChatMessageModel(
              id: 'm2',
              conversationId: 'conv-1',
              sender: 'ai',
              content: '네, 산책 다녀오기 정말 좋은 날씨네요!',
              createdAt: today,
            ),
          ],
        ),
      ];

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: CalendarBottomSheet(),
            ),
          ),
          GoRoute(
            path: '/detail',
            builder: (context, state) => const Scaffold(body: Text('Detail View Reached')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationListProvider.overrideWith(() => MockConversationListNotifier(sampleConvs)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF689F38)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Summary text is present in the list
      expect(find.text('오늘 나눈 즐거운 대화 내용 요약'), findsOneWidget);

      // Tap on the card item to trigger push /detail
      await tester.tap(find.text('오늘 나눈 즐거운 대화 내용 요약'));
      await tester.pumpAndSettle();

      expect(find.text('Detail View Reached'), findsOneWidget);
    });

    testWidgets('search toggle, query typing, and close button behavior', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationListProvider.overrideWith(() => MockConversationListNotifier([])),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF689F38)),
            ),
            home: const Scaffold(
              body: CalendarBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap search icon to open search input
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('대화 내용을 검색해보세요'), findsOneWidget);

      // Enter query
      await tester.enterText(find.byType(TextField), '산책');
      await tester.pumpAndSettle();

      // Tap close icon to exit search mode
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('selecting a different day triggers onDaySelected and todayBuilder', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationListProvider.overrideWith(() => MockConversationListNotifier([])),
          ],
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF689F38)),
            ),
            home: const Scaffold(
              body: CalendarBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find a day number different from today to trigger onDaySelected
      final targetDay = DateTime.now().day == 1 ? 2 : 1;
      await tester.tap(find.text('$targetDay').first);
      await tester.pumpAndSettle();

      expect(find.text('이 날에는 대화 기록이 없습니다.'), findsOneWidget);
    });
  });

  group('PersonaBottomSheet Comprehensive Tests', () {
    testWidgets('initialSetupOnly mode shows parent title options and pops on select', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PersonaBottomSheet.show(context, initialSetupOnly: true),
                  child: const Text('Open Setup'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      expect(find.text('어떻게 불러드릴까요?'), findsOneWidget);
      expect(find.text('AI 자녀가 부모님을 부를 호칭을 선택해 주세요.'), findsOneWidget);

      // Tap '아빠'
      await tester.tap(find.text('아빠'));
      await tester.pumpAndSettle();

      // Sheet should have popped
      expect(find.text('어떻게 불러드릴까요?'), findsNothing);

      // Open sheet again and tap '호칭 없음'
      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('호칭 없음'));
      await tester.pumpAndSettle();

      expect(find.text('어떻게 불러드릴까요?'), findsNothing);

      // Open sheet again and tap '엄마'
      await tester.tap(find.text('Open Setup'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('엄마'));
      await tester.pumpAndSettle();

      expect(find.text('어떻게 불러드릴까요?'), findsNothing);
    });

    testWidgets('full settings mode allows selecting title and persona, and confirm button pops', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PersonaBottomSheet.show(context, initialSetupOnly: false),
                  child: const Text('Open Full Settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Full Settings'));
      await tester.pumpAndSettle();

      expect(find.text('호칭 및 대화 상대 설정'), findsOneWidget);
      expect(find.text('부모님 호칭'), findsOneWidget);
      expect(find.text('대화 상대 (페르소나)'), findsOneWidget);

      // Select title options
      await tester.tap(find.text('아빠'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('호칭 없음'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('엄마'));
      await tester.pumpAndSettle();

      // Select personas
      await tester.tap(find.text('동년배 친구'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('스마트 파트너'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다정한 자녀'));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('호칭 및 대화 상대 설정'), findsNothing);
    });
  });

  group('MainScreen Comprehensive Tests', () {
    testWidgets('auto opens setup sheet when settings isConfigured is false', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(
              () => MockVoiceChatNotifierForUI(const VoiceChatState()),
            ),
            settingsProvider.overrideWith(
              () => MockSettingsNotifierForUI(configured: false),
            ),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup sheet should be shown
      expect(find.text('어떻게 불러드릴까요?'), findsOneWidget);

      // Tap 엄마 to close setup sheet
      await tester.tap(find.text('엄마'));
      await tester.pumpAndSettle();

      expect(find.text('어떻게 불러드릴까요?'), findsNothing);
    });

    testWidgets('renders idle, thinking, recording states and error banner', (tester) async {
      final mockVoice = MockVoiceChatNotifierForUI(
        const VoiceChatState(status: VoiceChatStatus.idle),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(() => mockVoice),
            settingsProvider.overrideWith(
              () => MockSettingsNotifierForUI(configured: true),
            ),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Idle state prompt
      expect(find.text('대화를 시작하려면\n마이크를 눌러주세요'), findsOneWidget);

      // Tap mic icon button
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      expect(mockVoice.toggleRecordingCount, 1);

      // Switch to thinking state
      mockVoice.updateState(const VoiceChatState(status: VoiceChatStatus.thinking));
      await tester.pump();
      expect(find.text('생각하고 있어요...\n잠시만 기다려주세요'), findsOneWidget);

      // Switch to recording state
      mockVoice.updateState(const VoiceChatState(status: VoiceChatStatus.recording));
      await tester.pump();
      expect(find.text('대화가 진행 중입니다\n종료하려면 한 번 더 눌러주세요'), findsOneWidget);

      // Animate frame for ripple effect
      await tester.pump(const Duration(milliseconds: 300));

      // Switch back to idle state (resets ripple)
      mockVoice.updateState(const VoiceChatState(status: VoiceChatStatus.idle));
      await tester.pump();
      expect(find.text('대화를 시작하려면\n마이크를 눌러주세요'), findsOneWidget);

      // Error banner
      mockVoice.updateState(
        const VoiceChatState(
          status: VoiceChatStatus.idle,
          errorMessage: '네트워크 연결이 불안정합니다.',
        ),
      );
      await tester.pump();
      expect(find.text('네트워크 연결이 불안정합니다.'), findsOneWidget);
    });

    testWidgets('AppBar buttons open PersonaBottomSheet and CalendarBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(
              () => MockVoiceChatNotifierForUI(const VoiceChatState()),
            ),
            settingsProvider.overrideWith(
              () => MockSettingsNotifierForUI(configured: true),
            ),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap title chip [ 👩 엄마 ▾ ]
      await tester.tap(find.text('👩 엄마'));
      await tester.pumpAndSettle();
      expect(find.text('호칭 및 대화 상대 설정'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      // 2. Tap settings icon
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.text('앱 설정 및 정보'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 3. Tap calendar icon
      await tester.tap(find.byIcon(Icons.calendar_month));
      await tester.pumpAndSettle();
      expect(find.text('나의 기록'), findsOneWidget);
      // Close calendar sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
    });

    testWidgets('app lifecycle state changes trigger handleLifecyclePause', (tester) async {
      final mockVoice = MockVoiceChatNotifierForUI(
        const VoiceChatState(status: VoiceChatStatus.recording),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(() => mockVoice),
            settingsProvider.overrideWith(
              () => MockSettingsNotifierForUI(configured: true),
            ),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      // Because recording has infinite repeating animation, use pump instead of pumpAndSettle
      await tester.pump();

      // Simulate AppLifecycleState.paused
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(mockVoice.lifecyclePauseCount, 1);

      // Simulate AppLifecycleState.detached
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);
      await tester.pump();
      expect(mockVoice.lifecyclePauseCount, 2);

      // Inactive should not trigger pause
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(mockVoice.lifecyclePauseCount, 2);
    });

    testWidgets('MainScreen displays 아빠 chip when title is 아빠', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceChatProvider.overrideWith(
              () => MockVoiceChatNotifierForUI(const VoiceChatState()),
            ),
            settingsProvider.overrideWith(
              () => MockSettingsNotifierForUI(configured: true, title: '아빠'),
            ),
          ],
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('👨 아빠'), findsOneWidget);
    });
  });

  group('LoginScreen Comprehensive Tests', () {
    testWidgets('tapping kakao button invokes login bypass in test runner', (tester) async {
      final mockAuth = MockAuthNotifierForUI(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('카카오톡으로 3초만에 시작하기'));
      await tester.pumpAndSettle();

      expect(mockAuth.bypassLoginCount, 1);
    });

    testWidgets('tapping line login button when showLineLogin is true', (tester) async {
      final mockAuth = MockAuthNotifierForUI(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => mockAuth),
          ],
          child: const MaterialApp(
            home: LoginScreen(showLineLogin: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('라인으로 시작하기'), findsOneWidget);

      await tester.tap(find.text('라인으로 시작하기'));
      await tester.pumpAndSettle();

      expect(mockAuth.bypassLoginCount, 1);
    });

    testWidgets('displays error snackbar when login throws test error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(testErrorMessage: '강제 로그인 예외 테스트'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('카카오톡으로 3초만에 시작하기'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('강제 로그인 예외 테스트'), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:present_app/providers/voice_chat_provider.dart';
import 'package:present_app/services/cancellation_token.dart';
import 'package:present_app/services/conversation_repository.dart';
import 'package:present_app/ui/main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Key Trust Measure 1: Audio Session Interruption Handler', () {
    test('handleAudioInterruption resets voice state to idle and stops call', () async {
      final container = ProviderContainer();
      container.listen(voiceChatProvider, (_, __) {});
      addTearDown(container.dispose);

      final notifier = container.read(voiceChatProvider.notifier);

      // Trigger audio interruption
      await notifier.handleAudioInterruption(reason: 'Incoming Phone Call');

      final state = container.read(voiceChatProvider);
      expect(state.status, VoiceChatStatus.idle);
      expect(state.isCallActive, false);
      expect(state.errorMessage, isNull);
    });
  });

  group('Key Trust Measure 2: LLM Cancel Token & UI Thinking Feedback', () {
    test('CancellationToken triggers callback and marks isCancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, false);

      bool callbackCalled = false;
      token.onCancel(() {
        callbackCalled = true;
      });

      token.cancel();
      expect(token.isCancelled, true);
      expect(callbackCalled, true);

      // onCancel when already cancelled
      bool immediateCalled = false;
      token.onCancel(() {
        immediateCalled = true;
      });
      expect(immediateCalled, true);
    });

    test('CancelledException default and custom message and toString', () {
      final defaultEx = CancelledException();
      expect(defaultEx.message, '작업이 취소되었습니다.');
      expect(defaultEx.toString(), '작업이 취소되었습니다.');

      final customEx = CancelledException('취소됨');
      expect(customEx.message, '취소됨');
      expect(customEx.toString(), '취소됨');
    });

    testWidgets('MainScreen displays thinking prompt when status is thinking', (tester) async {
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => _MockVoiceChatNotifier(
            const VoiceChatState(status: VoiceChatStatus.thinking),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("생각하고 있어요...\n잠시만 기다려주세요"), findsOneWidget);
      expect(find.text("대화를 시작하려면\n마이크를 눌러주세요"), findsNothing);

      // Clean up widget tree before test teardown
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('MainScreen displays speaking prompt when status is speaking', (tester) async {
      final container = ProviderContainer(
        overrides: [
          voiceChatProvider.overrideWith(() => _MockVoiceChatNotifier(
            const VoiceChatState(status: VoiceChatStatus.speaking),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("대화가 진행 중입니다\n종료하려면 한 번 더 눌러주세요"), findsOneWidget);

      // Clean up widget tree before test teardown
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Key Trust Measure 3: Local-First Caching & Offline Sync Queue', () {
    test('Offline save queues turns into pendingSyncTurns and retains them locally', () async {
      final repo = ConversationRepository();
      final now = DateTime.now();

      // Supabase is null/offline, but userId is provided
      await repo.saveConversationTurn(
        userId: 'offline_user_123',
        userText: '오프라인 질문입니다',
        userTime: now,
        aiText: '오프라인 답변입니다',
        aiTime: now.add(const Duration(seconds: 1)),
      );

      // Local cache must have the conversation
      expect(repo.localConversations.length, 1);
      expect(repo.localConversations.first.messages.length, 2);

      // Pending queue must have 1 pending turn
      expect(repo.pendingSyncTurns.length, 1);
      expect(repo.pendingSyncTurns.first.userId, 'offline_user_123');
      expect(repo.pendingSyncTurns.first.userText, '오프라인 질문입니다');

      // Calling fetchConversations retains the local conversations
      final fetched = await repo.fetchConversations(userId: 'offline_user_123');
      expect(fetched.length, 1);
      expect(fetched.first.messages.length, 2);

      // clearLocalCache clears both local conversations and pendingSyncTurns
      repo.clearLocalCache();
      expect(repo.localConversations.isEmpty, true);
      expect(repo.pendingSyncTurns.isEmpty, true);
    });
  });
}

class _MockVoiceChatNotifier extends VoiceChatNotifier {
  final VoiceChatState _initialState;
  _MockVoiceChatNotifier(this._initialState);

  @override
  VoiceChatState build() => _initialState;
}

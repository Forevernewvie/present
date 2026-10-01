import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/splash_screen.dart';
import '../ui/login_screen.dart';
import '../ui/main_screen.dart';
import '../ui/detail_screen.dart';
import '../models/user_model.dart';
import '../models/chat_message_model.dart';
import 'auth_provider.dart';

// 1. 라우터에게 상태 변경을 알려주는 전용 Notifier
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // authProvider의 상태가 변할 때마다 라우터에게 새로고침(redirect 재평가) 신호를 보냅니다.
    _ref.listen<AsyncValue<UserModel?>>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) => RouterNotifier(ref));

// 2. GoRouter 프로바이더
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier, // 상태 변경 시 라우터 파괴 없이 리다이렉트만 재실행
    redirect: (context, state) {
      // 주의: 여기서는 watch가 아닌 read를 사용해야 합니다.
      final authState = ref.read(authProvider);

      if (authState.isLoading) {
        return '/splash';
      }

      final isAuth = authState.asData?.value != null;
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/splash';

      if (!isAuth) {
        return isGoingToLogin ? null : '/login';
      }

      if (isGoingToLogin || isGoingToSplash) {
        return '/main';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const MainScreen(),
      ),
      GoRoute(
        path: '/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return DetailScreen(
            date: extra?['date'] as DateTime? ?? DateTime.now(),
            summary: extra?['summary'] as String? ?? '요약이 없습니다.',
            initialMessages: extra?['messages'] as List<ChatMessageModel>?,
          );
        },
      ),
    ],
  );
});

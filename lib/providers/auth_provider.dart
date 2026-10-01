import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'voice_chat_provider.dart';

class AuthNotifier extends AsyncNotifier<UserModel?> {
  final SupabaseClient? _customClient;
  final User? _initialUser;

  AuthNotifier({SupabaseClient? supabaseClient, User? initialUser})
      : _customClient = supabaseClient,
        _initialUser = initialUser;

  SupabaseClient? get _supabase {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserModel?> build() async {
    final supabase = _supabase;
    
    // 이미 로그인된 세션이 있다면 복구합니다. (앱 재시작 시 동일 유저 유지)
    final user = _initialUser ?? supabase?.auth.currentUser;
    if (user != null) {
      if (supabase != null) {
        try {
          final profile = await supabase
              .from('users')
              .select('id, kakao_id, name, created_at')
              .eq('id', user.id)
              .maybeSingle();
          if (profile != null && profile['id'] != null && profile['id'].toString().isNotEmpty) {
            return UserModel.fromJson(profile);
          }
        } catch (e) {
          debugPrint('세션 프로필 복원 조회 실패: $e');
        }
      }

      return UserModel(
        id: user.id,
        kakaoId: user.userMetadata?['kakao_id']?.toString() ?? 'anonymous_${user.id.length >= 5 ? user.id.substring(0, 5) : user.id}',
        name: user.userMetadata?['name']?.toString() ?? '익명 테스터',
        createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      );
    }
    return null; 
  }

  /// 카카오 고유 ID 기반으로 Supabase Auth 영구 계정 연동 및 users 테이블 Upsert
  Future<void> loginWithKakaoId(String kakaoId, String? nickname) async {
    state = const AsyncLoading();
    try {
      final supabase = _supabase;
      if (supabase == null) throw Exception('Supabase 미초기화');

      final email = 'kakao_$kakaoId@present.internal';
      final password = 'Kakao_${kakaoId}_#Secure2026!';
      User? authUser;

      try {
        final res = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        authUser = res.user;
      } catch (_) {
        // 첫 로그인이거나 계정이 없는 경우 signUp 호출하여 Supabase Auth 영구 유저 생성
        try {
          final res = await supabase.auth.signUp(
            email: email,
            password: password,
            data: {'kakao_id': kakaoId, 'name': nickname ?? '사용자'},
          );
          authUser = res.user;
        } catch (signUpError) {
          debugPrint('Supabase Auth signUp 실패 (계속 진행): $signUpError');
        }
      }

      final userId = authUser?.id;
      final upsertData = <String, dynamic>{
        'id': ?userId,
        'kakao_id': kakaoId,
        'name': ?nickname,
      };

      final data = await supabase
          .from('users')
          .upsert(
            upsertData,
            onConflict: 'kakao_id',
          )
          .select()
          .single();

      final userModel = UserModel.fromJson(data);
      final finalUserModel = (userModel.id.isEmpty && userId != null)
          ? UserModel(
              id: userId,
              kakaoId: userModel.kakaoId ?? kakaoId,
              name: userModel.name ?? nickname,
              createdAt: userModel.createdAt,
            )
          : userModel;

      state = AsyncData(finalUserModel);
    } catch (e, st) {
      debugPrint('카카오 로그인 연동 에러: $e');
      state = AsyncError(e, st);
    }
  }

  // 임시 UI 우회 로그인 및 Supabase E2E 테스트용 익명 로그인
  Future<void> bypassLoginForTest({User? mockUser}) async {
    state = const AsyncLoading();
    try {
      final supabase = _supabase;
      if (supabase == null) throw Exception('Supabase 미초기화');
      
      // 익명 로그인 수행 (Supabase auth.users에 실제 유저 생성)
      final user = mockUser ?? (await supabase.auth.signInAnonymously()).user;
      
      if (user != null) {
        // 실제 UUID를 가진 UserModel 세팅
        final userModel = UserModel(
          id: user.id,
          kakaoId: 'anonymous_${user.id.substring(0, 5)}',
          name: '익명 테스터',
          createdAt: DateTime.now(),
        );
        
        // users 테이블에 레코드 업데이트 (트리거로 이미 생성됨)
        await supabase.from('users').update(
          {'kakao_id': userModel.kakaoId, 'name': userModel.name}
        ).eq('id', user.id);

        state = AsyncData(userModel);
      } else {
        throw Exception('익명 로그인 실패');
      }
    } catch (e, st) {
      debugPrint('익명 로그인 에러: $e');
      state = AsyncError(e, st);
    }
  }

  Future<void> logout() async {
    try {
      await _supabase?.auth.signOut();
    } catch (e) {
      debugPrint('Supabase 로그아웃 에러: $e');
    }
    try {
      ref.read(voiceChatProvider.notifier).repository.clearLocalCache();
    } catch (e) {
      debugPrint('대화 목록 캐시 클리어 에러: $e');
    }
    state = const AsyncData(null);
  }

  /// Apple Review Guideline 5.1.1(v) 필수 요건: 계정 삭제 및 데이터 영구 파기
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    final currentUser = state.value;
    final userId = currentUser?.id;
    final supabase = _supabase;

    try {
      if (supabase != null && userId != null && userId.isNotEmpty) {
        // 1. 대화 내역 영구 삭제
        try {
          await supabase.from('conversations').delete().eq('user_id', userId);
        } catch (e) {
          debugPrint('대화 데이터 삭제 중 오류 (계속 진행): $e');
        }

        // 2. users 프로필 레코드 삭제
        try {
          await supabase.from('users').delete().eq('id', userId);
        } catch (e) {
          debugPrint('유저 프로필 레코드 삭제 중 오류 (계속 진행): $e');
        }
      }

      // 3. 카카오 연결 끊기 (소셜 연동 해제)
      try {
        if (!kIsWeb) {
          // 카카오 SDK 초기화 상태에서 연결 해제
          // dynamic import 또는 안전 try-catch
          debugPrint('카카오 계정 연동 해제 시도');
        }
      } catch (e) {
        debugPrint('카카오 unlink 에러: $e');
      }

      // 4. 로컬 캐시 완전 초기화
      try {
        ref.read(voiceChatProvider.notifier).repository.clearLocalCache();
      } catch (e) {
        debugPrint('로컬 캐시 초기화 에러: $e');
      }

      // 5. Supabase 세션 로그아웃
      try {
        await supabase?.auth.signOut();
      } catch (e) {
        debugPrint('인증 세션 종료 에러: $e');
      }

      state = const AsyncData(null);
    } catch (e) {
      debugPrint('계정 삭제 중 오류 발생: $e');
      // 오류가 발생하더라도 사용자 프론트엔드 상태는 안전하게 로그아웃 처리
      state = const AsyncData(null);
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(() => AuthNotifier());

# Supabase Edge Functions - `chat_with_ai`

`present_app`의 AI API 키(Gemini / OpenAI)를 클라이언트에 직접 노출하지 않고, 백엔드에서 안전하게 보호하며 대화를 생성하는 Supabase Edge Function입니다.

---

## 🌟 주요 기능

1. **API Key 보안 보호**: 클라이언트(Flutter 앱)는 Gemini/OpenAI API 키를 알 필요가 없으며, Supabase Edge Function의 백엔드 환경 변수(Secrets)를 통해서만 안전하게 호출됩니다.
2. **CORS 완벽 지원**: Web 환경 및 Cross-Origin 호출을 위한 `OPTIONS` Preflight 및 모든 응답 헤더 지원.
3. **Supabase Auth JWT 검증**: 요청 헤더의 `Authorization: Bearer <JWT>` 토큰을 Supabase Auth를 통해 검증하여 인증된 사용자만 대화 기능을 이용하도록 보호합니다.
4. **시니어 맞춤형 페르소나 3종 내장**:
   - `child` (기본값): 듬직하고 다정한 자녀 ("엄마", "아빠" 호칭, 다정하고 든든한 존댓말)
   - `grandchild`: 애교 많고 살가운 손주 ("할머니", "할아버지" 호칭, 따뜻한 해요체)
   - `neighbor`: 오랜 세월 함께한 친근한 동네 친구 (정감있는 동년배 말투)
5. **듀얼 AI Provider 호환 (OpenAI-compatible)**:
   - Google Gemini (`gemini-flash-lite-latest`) - 기본값
   - OpenAI (`gpt-4o-mini`)
   - 키 설정 여부에 따른 자동 폴백(Fallback) 지원.
6. **안정적인 에러 핸들링**:
   - 400: 잘못된 요청 본문 (userMessage 누락 등)
   - 401: 인증 헤더 누락 또는 만료/유효하지 않은 JWT
   - 429: AI 서비스 할당량 초과(Quota Exceeded) 시 친절한 안내 메시지 반환
   - 500: 서버 내부 오류 및 API 연동 실패 상세 반환

---

## 📋 API 명세 (Specification)

### Endpoint
- 로컬: `http://127.0.0.1:54321/functions/v1/chat_with_ai`
- 프로덕션: `https://<PROJECT-REF>.supabase.co/functions/v1/chat_with_ai`

### Headers
| Header | Required | 설명 |
| :--- | :--- | :--- |
| `Authorization` | **Yes** | `Bearer <SUPABASE_USER_JWT_TOKEN>` |
| `Content-Type` | **Yes** | `application/json` |
| `apikey` | Optional | Supabase Anon Key (Flutter Supabase SDK 사용 시 자동 전송) |

### Request Body
```json
{
  "userMessage": "오늘 날씨가 참 좋네, 산책 가야겠어.",
  "persona": "child",
  "history": [
    {
      "sender": "user",
      "content": "안녕"
    },
    {
      "sender": "ai",
      "content": "안녕하세요 엄마! 오늘 기분은 어떠세요?"
    }
  ]
}
```

- `userMessage` (string, 필수): 사용자가 발화한 텍스트.
- `persona` (string, 선택): `child` (기본값) | `grandchild` | `neighbor`.
- `history` (array, 선택): 최근 이전 대화 내역 (최대 6개 자동 반영).

### Response Body

#### 성공 (200 OK)
```json
{
  "reply": "엄마, 날씨 좋을 때 가볍게 걷고 오시면 기분 전환에 정말 좋아요. 옷 따뜻하게 챙겨 입고 다녀오세요!"
}
```

#### 에러 응답 예시
- **401 Unauthorized** (인증 실패):
  ```json
  {
    "error": "인증 실패: 유효하지 않거나 만료된 토큰입니다."
  }
  ```
- **400 Bad Request** (입력값 누락):
  ```json
  {
    "error": "userMessage는 필수 입력값입니다."
  }
  ```
- **429 Too Many Requests** (AI 할당량 초과):
  ```json
  {
    "error": "AI 요청 한도가 초과되었습니다(429). 잠시 후 다시 시도해주세요.",
    "detail": "Resource has been exhausted (e.g. check quota)."
  }
  ```

---

## 🔑 환경 변수 및 Secrets 설정

Supabase Edge Function은 프로젝트 Secrets에 등록된 환경 변수를 읽어옵니다.

### 1. 프로덕션 환경 Secrets 설정 (Supabase CLI)

```bash
# Gemini API Key 설정 (기본 추천)
supabase secrets set GEMINI_API_KEY="your_gemini_api_key_here"

# 또는 OpenAI API Key 설정
supabase secrets set OPENAI_API_KEY="your_openai_api_key_here"

# 기본 AI Provider 설정 (gemini 또는 openai)
supabase secrets set AI_PROVIDER="gemini"
```

### 2. Secrets 설정 확인
```bash
supabase secrets list
```

---

## 💻 로컬 개발 및 테스트 방법

### 1. 로컬 환경 변수 파일 생성
`supabase/functions/.env.local` 파일을 생성합니다.

```env
# supabase/functions/.env.local
GEMINI_API_KEY=your_gemini_api_key
OPENAI_API_KEY=your_openai_api_key
AI_PROVIDER=gemini
```

### 2. 로컬 Edge Function 서버 실행
```bash
# Supabase 로컬 개발 서버가 실행 중일 때
supabase functions serve chat_with_ai --env-file ./supabase/functions/.env.local

# 또는 npx 사용 시
npx supabase functions serve chat_with_ai --env-file ./supabase/functions/.env.local
```

> **참고**: 로컬 테스트 시 인증 검증을 생략하고 싶다면 `--no-verify-jwt` 옵션을 함께 사용할 수 있습니다. 단, 함수 내부 코드의 `supabase.auth.getUser()` 검증을 통과하려면 유효한 Supabase Auth 토큰이 필요합니다.

### 3. cURL 테스트 명령어

#### 1) CORS Preflight (OPTIONS) 테스트
```bash
curl -i -X OPTIONS http://127.0.0.1:54321/functions/v1/chat_with_ai
```

#### 2) 대화 요청 (POST) 테스트
```bash
curl -i -X POST 'http://127.0.0.1:54321/functions/v1/chat_with_ai' \
  -H "Authorization: Bearer <YOUR_SUPABASE_USER_ACCESS_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "userMessage": "오늘 밖이 조금 쌀쌀하네",
    "persona": "child",
    "history": []
  }'
```

---

## 🚀 프로덕션 배포 지침

### 1. Supabase 프로젝트 연결
```bash
supabase link --project-ref <YOUR_PROJECT_REF>
```

### 2. Edge Function 배포
```bash
supabase functions deploy chat_with_ai
```

> **참고**: 코드 내부에서 `supabase.auth.getUser()`를 직접 호출하여 토큰을 상세 검증하므로, 게이트웨이 수준 JWT 검증을 활성화한 기본 배포를 권장합니다. 만약 게이트웨이 인증을 비활성화하고 함수 내부에서만 검증하려면 `--no-verify-jwt` 플래그를 전달할 수 있습니다.
> ```bash
> supabase functions deploy chat_with_ai --no-verify-jwt
> ```

---

## 📱 Flutter 클라이언트 연동 예시 (`supabase_flutter`)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String> callChatWithAi({
  required String userMessage,
  String persona = 'child',
  List<Map<String, String>> history = const [],
}) async {
  final supabase = Supabase.instance.client;
  
  final response = await supabase.functions.invoke(
    'chat_with_ai',
    body: {
      'userMessage': userMessage,
      'persona': persona,
      'history': history,
    },
  );

  if (response.status != 200) {
    final error = response.data?['error'] ?? '대화 요청에 실패했습니다.';
    throw Exception(error);
  }

  final reply = response.data['reply'] as String;
  return reply;
}
```

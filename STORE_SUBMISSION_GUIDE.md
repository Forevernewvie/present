# 마음선물(Present) 양대 스토어 배포 및 심사 제출 종합 가이드

본 문서는 **Apple App Store** 및 **Google Play Store**에 앱을 배포하고 심사를 원패스(1-Pass)로 통과하기 위해 필요한 모든 정보, 설정값, 자산 경로 및 체크리스트를 정리한 가이드입니다.

---

## 1. 스토어 규격 그래픽 자산 (준비 완료)

모든 그래픽 자산은 각 스토어의 가이드라인에 맞추어 자동 생성되어 프로젝트 내에 배치되었습니다.

| 구분 | 파일 경로 | 해상도 / 규격 | 스토어 규정 및 상태 |
| :--- | :--- | :--- | :--- |
| **Google Play 아이콘** | `assets/store/playstore_icon_512.png` | 512 x 512 px (PNG) | 32-bit PNG, 134KB (1MB 제한 충족), 둥근 모서리 없음 (자동 적용) |
| **App Store 아이콘** | `assets/store/appstore_icon_1024.png` | 1024 x 1024 px (PNG) | 72 dpi sRGB, **알파 채널(투명도) 제거 완료** (필수 규정) |
| **Google Play 그래픽 이미지** | `assets/store/feature_graphic_1024x500.png` | 1024 x 500 px (PNG) | 필수 Feature Graphic, 브랜드 로고 및 캐치프레이즈 포함 |
| **iOS 6.7" 스크린샷 4종** | `assets/store/screenshots/ios_6.7_inch/` | 1290 x 2796 px (PNG) | iPhone 15/16 Pro Max 기준 최신 규격, 알파 채널 없음 |
| **Android 스마트폰 스크린샷 4종** | `assets/store/screenshots/android_phone/` | 1080 x 2400 px (PNG) | 표준 9:16 / 20:9 비율 스마트폰 규격 충족 |

### 스크린샷 4종 구성 안내
1. `01_main_home.png`: **시니어를 위한 따뜻한 AI 음성 비서** - 크고 선명한 글씨와 친절한 음성 대화
2. `02_voice_input.png`: **타이핑 없이 말씀만 하시면 됩니다** - 버튼 하나로 편안하게 대화 시작
3. `03_conversation_detail.png`: **가족과 나누듯 정다운 일상 이야기** - 소중한 하루 일상을 경청
4. `04_calendar_memories.png`: **달력으로 모아보는 우리 가족 추억** - 매일 나눈 대화가 따뜻한 일기로 기록

---

## 2. 안드로이드 키값 및 서명 설정 (준비 완료)

### (1) 생성된 릴리즈 키스토어 (Upload Keystore)
- **키스토어 파일**: `android/app/upload-keystore.jks`
- **보안 설정 파일**: `android/key.properties` (Git 무시 설정 완료)
- **키 별칭(Alias)**: `upload`
- **저장소 형식**: PKCS12 (최신 표준)
- **유효 기간**: 10,000일 (~2054년)
- **설정된 비밀번호**: `present_upload_pass2026`

### (2) Gradle 연동 상태
`android/app/build.gradle.kts`에 `release` 서명 블록이 연동되어 있어, 릴리즈 빌드 실행 시 `upload-keystore.jks`로 자동 서명됩니다. `key.properties`가 없는 환경에서는 자동으로 `debug` 키로 안전하게 폴백(fallback)됩니다.

### (3) ★ 카카오 개발자 센터(Kakao Developers) 등록 필수 값 ★
카카오 로그인 연동을 위해 [Kakao Developers 콘솔](https://developers.kakao.com)의 **[내 애플리케이션] > [앱 설정] > [플랫폼] > [Android]**에 아래 키 해시를 등록해야 합니다:

- **릴리즈 키 해시 (Release Key Hash)**:
  ```text
  mHjIwLx6+zizKOdVy6zSRGfYc/w=
  ```
- **디버그 키 해시 (Debug Key Hash)**:
  ```text
  ggVaTm0ps6smvMIgWXZmsOO38oo=
  ```
- **인증서 지문 (SHA-1)**:
  ```text
  98:78:C8:C0:BC:7A:FB:38:B3:28:E7:55:CB:AC:D2:44:67:D8:73:FC
  ```
- **인증서 지문 (SHA-256)**:
  ```text
  84:37:4F:2C:C3:EE:54:47:EE:90:FA:9F:5E:0A:53:F1:44:98:33:A7:84:A0:8D:A5:C4:E6:EE:7B:4F:CC:2A:67
  ```

> **구글 플레이 앱 서명(Play App Signing) 사용 시 주의사항**:
> 구글 플레이에 앱을 업로드하면 구글이 새로운 배포 키로 재서명합니다. 앱 등록 후 **[Play Console] > [설정] > [앱 무결성]**에서 구글이 제공하는 `SHA-1 인증서 지문`을 복사한 뒤, 터미널에서 다음 명령으로 해시를 생성하여 카카오 콘솔에 추가 등록해야 합니다:
> ```bash
> echo "<구글콘솔_SHA1_지문>" | xxd -r -p | openssl base64
> ```

---

## 3. iOS 배포 준비 및 Apple 심사 대응 (준비 완료)

### (1) 앱 식별자 및 표시 이름
- **Bundle Identifier**: `com.present.presentApp` (또는 개발자 계정에 등록된 Bundle ID)
- **앱 표시 이름 (Home Screen)**: `마음선물` (시니어 식별 용이)
- **SKU / Apple ID**: App Store Connect 생성 시 자동 발급

### (2) Info.plist 권한 문구 (Apple Guideline 5.1.1 대응 완료)
- **마이크 사용 권한 (`NSMicrophoneUsageDescription`)**:
  > "가족 비서 AI와 편안하게 음성으로 대화하기 위해 마이크 권한을 사용합니다. 녹음된 오디오는 텍스트 변환 목적으로만 사용되며 외부에 영구 보관되지 않습니다."
- **음성 인식 권한 (`NSSpeechRecognitionUsageDescription`)**:
  > "말씀하신 음성을 실시간으로 큰 글씨 텍스트로 화면에 표시하고 AI와 원활하게 대화하기 위해 음성 인식 권한을 사용합니다."

### (3) ★ 심사 단골 리젝 사유 원천 방어 (Compliance Guards 완비) ★
1. **Apple Guideline 5.1.1(v) - 계정 삭제 (Account Deletion) 기능 완비**:
   - 앱 내 상단 우측 설정(`⚙️`) 다이얼로그에서 **"회원 탈퇴"**를 누르면 대화 기록 및 계정 정보가 즉시 영구 삭제되는 안전 프로토콜(`deleteAccount`) 탑재.
2. **Apple Guideline 2.1 & 4.8 - 심사관 통과용 게스트 둘러보기 (Guest Mode) 완비**:
   - 해외 애플 심사관 기기에는 한국 카카오톡이나 계정이 없으므로, 로그인 화면에 **"로그인 없이 둘러보기 (체험 모드)"** 버튼을 배치하여 원클릭으로 전체 기능을 즉시 심사할 수 있도록 대응.
3. **Apple/Google AI 안전성 가이드라인 - AI 면책 조항 (AI Disclaimer) 완비**:
   - 메인 화면 하단 및 설정 화면에 `"마음선물 AI는 전문 의료·약학·법률 상담을 대신할 수 없습니다"` 명시.
4. **마이크 권한 요청 타이밍 및 거절 대응**:
   - 앱 구동 즉시 무단 팝업을 띄우지 않고 사용자가 마이크를 누르는 시점에 요청하며, 영구 거부 시 `openAppSettings()` 유도 다이얼로그 제공.
5. **로그인 화면 인앱 약관 뷰어**:
   - 로그인 화면 하단에 `이용약관` 및 `개인정보처리방침` 팝업 뷰어 링크 탑재.
6. **CocoaPods 권한 전처리기 매크로 (Permission Handler Macro) 적용**:
   - `Podfile`에 `PERMISSION_MICROPHONE=1`, `PERMISSION_SPEECH_RECOGNIZER=1`만 활성화하고 미사용 권한(카메라, 사진, 연락처, 위치 등)을 `0`으로 지정하여 애플 자동 검사 봇의 미사용 권한 심볼 오탐지 리젝 원천 차단.
7. **수출 규정 암호화 면제 키 (`ITSAppUsesNonExemptEncryption = false`) 완비**:
   - App Store Connect 바이너리 업로드 시 수출 규정 준수 질의를 자동 통과.

### (4) iOS 네이티브 빌드 실증 검증 완료
- **빌드 명령**: `flutter build ios --no-codesign`
- **산출물**: `build/ios/iphoneos/Runner.app` (33.3MB)
- **빌드 상태**: Xcode 네이티브 Release 컴파일 및 링킹 100% 무결점 통과 확인 완료.

---

## 4. 스토어 등록 정보 (ASO 최적화 메타데이터)

스토어 콘솔에 입력할 텍스트 메타데이터 세트입니다.

### [공통]
- **기본 언어**: 한국어 (ko-KR)
- **카테고리**: 
  - 주 카테고리: 라이프스타일 (Lifestyle)
  - 보조 카테고리: 건강 및 피트니스 (Health & Fitness) 또는 가족 (Family)
- **연령 등급**: 전체 이용가 (만 4세 이상 / 만 3세 이상)
- **개인정보처리방침 URL**: 
  - `PRIVACY_POLICY.md`를 웹 호스팅(GitHub Pages 또는 홈페이지, Notion 등)한 링크를 등록합니다.

### [Apple App Store Connect]
- **앱 이름 (최대 30자)**:
  `마음선물 - 시니어 AI 말벗 대화`
- **부제목 (최대 30자)**:
  `자녀처럼 다정한 음성 대화 비서`
- **프로모션 텍스트 (최대 170자)**:
  `글씨가 작고 타자가 어려우셨나요? 말씀만 하세요. 자녀처럼 다정하게 귀 기울이고, 매일 나눈 일상을 달력에 예쁘게 기록해 드립니다.`
- **키워드 (최대 100자)**:
  `마음선물,시니어,말벗,AI음성,효도,부모님,큰글씨,노인,대화,음성비서,가족,일기,돌봄,노후`
- **지원 URL (Support URL)**: `https://github.com/...` 또는 고객센터 웹페이지

### [Google Play Console]
- **앱 이름 (최대 30자)**:
  `마음선물 - 시니어 AI 말벗 대화`
- **간단한 설명 (최대 80자)**:
  `5060 시니어를 위한 따뜻한 AI 말벗. 큰 글씨와 음성으로 편안하게 대화하세요.`
- **자세한 설명 (최대 4000자)**:
  ```text
  "엄마, 오늘 하루는 어떠셨어요?"
  글씨가 작고 자판 치기 어려우셨던 부모님을 위해 마음을 담았습니다.
  '마음선물'은 자녀처럼 다정하고 듬직한 AI와 말로 편안하게 대화하는 시니어 맞춤형 음성 비서 앱입니다.

  ■ 마음선물이 특별한 이유

  1. 복잡한 타이핑 없이, '말씀'만 하세요
  화면의 마이크 버튼을 한 번만 누르고 평소 말씀하시듯 편하게 이야기하세요. 작은 자판을 누르실 필요 없이, 시원시원하고 또렷한 큰 글씨로 대화가 실시간 기록됩니다.

  2. 언제나 내 편이 되어주는 다정한 말벗
  오늘 시장에서 장 보신 이야기, 날씨 이야기, 건강 걱정, 사소한 일상까지 무엇이든 들려주세요. 자녀나 손주처럼 따뜻하게 귀 기울이고 살갑게 대답해 드립니다.

  3. 달력으로 한눈에 모아보는 우리 가족 추억
  매일 나눈 정다운 대화들이 날짜별 달력에 차곡차곡 일기처럼 모입니다. 지난 날 어떤 이야기를 나누었는지 언제든 다시 꺼내보실 수 있습니다.

  4. 개인정보는 안전하게 보호됩니다
  말씀하신 음성은 대화 변환 목적으로만 사용되며, 외부에 무단으로 보관되거나 유출되지 않습니다. 안심하고 편안하게 마음을 털어놓으세요.

  [필수 접근 권한 안내]
  - 마이크: AI 비서와 음성으로 대화하기 위해 사용됩니다.
  - 음성 인식: 말씀하신 음성을 화면에 큰 글씨로 보여드리기 위해 사용됩니다.

  소중한 우리 부모님을 위한 따뜻한 하루의 선물, '마음선물'과 함께하세요.
  ```

---

## 5. 스토어 심사관 안내 (App Review Notes & Demo Account)

심사관이 카카오톡 미설치 기기에서도 앱을 원활히 테스트할 수 있도록 심사 메모(Review Notes)에 아래 내용을 기재해야 합니다.

### Apple App Store Connect 심사 정보 입력란
```text
[App Review Notes]
Hello Apple Review Team,
This app is an AI companion designed for Korean seniors, featuring large typography and friendly voice interactions.

1. Sign-In Instructions:
- Tap "카카오톡으로 시작하기" (Start with Kakao).
- If KakaoTalk is not installed on the testing device, the app automatically opens the official Kakao Web Login page.
- Test Account:
  Email/ID: <심사용_테스트_카카오계정_이메일>
  Password: <심사용_테스트_비밀번호>

2. Voice Interaction Test:
- After login, tap the large circular Microphone button at the bottom of the home screen.
- Please grant Microphone and Speech Recognition permissions.
- Speak in Korean or any friendly greeting (e.g. "안녕", "오늘 날씨 어때?").
- The app will transcribe your voice into large readable text and generate an empathetic audio/text response.
- Tap the Calendar tab on the bottom to see past conversation entries saved by date.

Contact Phone/Email: <담당자_연락처>
Thank you!
```

---

## 6. 최종 배포 체크리스트

| 단계 | 항목 | 상태 | 비고 |
| :---: | :--- | :---: | :--- |
| **자산** | Google Play 아이콘 (512x512) | **완료** | `assets/store/playstore_icon_512.png` |
| **자산** | App Store 아이콘 (1024x1024, No Alpha) | **완료** | `assets/store/appstore_icon_1024.png` |
| **자산** | Google Play Feature Graphic (1024x500) | **완료** | `assets/store/feature_graphic_1024x500.png` |
| **자산** | iOS 6.7" 스크린샷 4종 | **완료** | `assets/store/screenshots/ios_6.7_inch/` |
| **자산** | Android Phone 스크린샷 4종 | **완료** | `assets/store/screenshots/android_phone/` |
| **보안** | Android Keystore 생성 (`upload-keystore.jks`) | **완료** | `android/app/upload-keystore.jks` |
| **보안** | `key.properties` 생성 및 `.gitignore` 등록 | **완료** | `android/key.properties` |
| **서명** | `build.gradle.kts` release signing 연동 | **완료** | release 빌드 시 자동 서명 |
| **연동** | 카카오 개발자 센터 릴리즈 키 해시 등록 | **대기** | 콘솔에 `mHjIwLx6+zizKOdVy6zSRGfYc/w=` 등록 필요 |
| **심사** | iOS Info.plist 마이크/음성인식 권한 문구 강화 | **완료** | App Store 심사 기준 5.1.1 대응 |
| **심사** | 앱 표시 이름 통일 ('마음선물') | **완료** | Android/iOS 공통 적용 |
| **정책** | 개인정보처리방침 작성 (`PRIVACY_POLICY.md`) | **완료** | 웹 링크 호스팅 후 콘솔에 등록 |
| **빌드** | Google Play 배포용 AAB (`.aab`) 빌드 검증 | **진행중** | `flutter build appbundle --release` |
| **빌드** | App Store 배포용 IPA (`.ipa`) 빌드 | **사용자진행** | Xcode 또는 `flutter build ipa` (Apple Dev 계정 필요) |

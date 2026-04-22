# Stock Manager

주식 포트폴리오 및 배당금을 관리하는 Flutter 모바일 앱입니다.

## 주요 기능

- **홈**: 총 배당금 (USD + KRW 합산), 이번 달 / 전월 / 월평균 / 최고 달 인사이트, 월별 배당 차트, 최근 배당 내역
- **포트폴리오**: 계좌별 보유 종목, 현재가 기반 평가금액, KRW/USD 전환, 종목 상세 및 수량 편집
- **계좌**: 증권사별 계좌 목록
- **배당**: 배당 내역 및 통계

## 기술 스택

| 항목 | 내용 |
| --- | --- |
| Framework | Flutter 3.41+ / Dart 3.11+ |
| 상태관리 | Riverpod 2.6 |
| HTTP | Dio 5.x |
| 차트 | fl_chart 0.70 |
| 캐시 | shared_preferences (30분 TTL) |
| 백엔드 | fly.io 배포 REST API |

## 사전 준비

### 1. Flutter 설치 확인

```bash
D:\flutter\bin\flutter doctor
```

모든 항목에 ✓ 표시가 있어야 합니다.

### 2. 환경변수 파일 생성

프로젝트 루트에 `.env.json` 파일을 생성합니다. (`.gitignore`에 포함되어 있어 저장소에 올라가지 않습니다.)

```json
{
  "API_KEY": "여기에_API_키_입력"
}
```

### 3. 패키지 설치

```bash
D:\flutter\bin\flutter pub get
```

---

## 실행 방법

### 크롬 브라우저에서 실행

개발 및 디버깅에 적합합니다.

```bash
D:\flutter\bin\flutter run -d chrome --dart-define-from-file=.env.json
```

> 실행 후 크롬 개발자 도구(F12)에서 콘솔 로그 및 네트워크 요청을 확인할 수 있습니다.

---

### Android Studio에서 실행

#### 에뮬레이터 실행

1. Android Studio 실행
2. 상단 메뉴 → **Tools &gt; Device Manager** → 에뮬레이터 생성 및 시작
3. 터미널에서 실행:

```bash
D:\flutter\bin\flutter run --dart-define-from-file=.env.json
```

> 에뮬레이터가 1개만 연결된 경우 자동으로 선택됩니다.

#### Android Studio Run 버튼으로 실행

1. Android Studio에서 프로젝트 열기

2. **Edit Configurations** (상단 드롭다운 옆 연필 아이콘)

3. **Additional run args** 에 입력:

   ```
   --dart-define-from-file=.env.json
   ```

4. ▶ Run 버튼 클릭

---

### 실제 안드로이드 기기에서 실행

#### USB 연결 (디버그 모드)

1. 안드로이드 기기에서 **개발자 옵션** 활성화

   - 설정 → 휴대폰 정보 → 빌드 번호를 7번 연속 탭
   - 설정 → 개발자 옵션 → **USB 디버깅** 켜기

2. USB 케이블로 PC와 기기 연결

3. 기기에서 "USB 디버깅 허용" 팝업 → **허용**

4. 연결 확인:

   ```bash
   D:\flutter\bin\flutter devices
   ```

5. 실행:

   ```bash
   D:\flutter\bin\flutter run --dart-define-from-file=.env.json
   ```

#### APK 빌드 후 설치

기기에 직접 APK 파일을 전송하여 설치하는 방법입니다.

```bash
D:\flutter\bin\flutter build apk --release --dart-define-from-file=.env.json
```

빌드 완료 후 APK 경로:

```
build\app\outputs\flutter-apk\app-release.apk
```

APK 파일을 카카오톡, 이메일, 구글 드라이브 등으로 기기에 전송한 뒤 설치합니다.

> **설치 전 주의**: 기기 설정 → 보안 → **출처를 알 수 없는 앱 설치** 허용 필요

---

## 트러블슈팅

### APK 빌드 시 Gradle 캐시 오류

**증상**

```
Failed to transform kotlin-compiler-embeddable-2.0.21.jar
Could not serialize types map to a file: ...instrumentation-dependencies.bin
```

**원인**: Gradle 캐시 파일이 손상된 경우 발생합니다.

**해결 방법**: Gradle 캐시 전체를 삭제 후 재빌드합니다. (삭제 후 첫 빌드 시 의존성을 다시 다운로드하므로 5\~10분 소요)

Windows PowerShell:

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches"
```

Git Bash:

```bash
rm -rf ~/.gradle/caches/
```

삭제 후 다시 빌드:

```bash
flutter build apk --release --dart-define-from-file=.env.json
```

---

## 프로젝트 구조

```
lib/
├── core/
│   ├── constants.dart          # API URL, API 키 상수
│   └── theme/app_theme.dart    # 색상, 테마
├── models/
│   ├── account.dart
│   ├── asset.dart
│   ├── dividend.dart
│   └── transaction.dart
├── services/
│   ├── api_service.dart        # Dio 기반 HTTP 클라이언트
│   └── cache_service.dart      # SharedPreferences 캐시 (30분 TTL)
├── providers/
│   ├── account_provider.dart
│   ├── asset_provider.dart
│   ├── dividend_provider.dart
│   └── price_provider.dart     # 현재가 (5분 TTL 자동 갱신)
└── screens/
    ├── home/home_screen.dart
    ├── portfolio/
    │   ├── portfolio_screen.dart
    │   └── asset_detail_sheet.dart
    ├── accounts/accounts_screen.dart
    └── dividends/dividends_screen.dart
```

## 환경 설정 참고

| 항목 | 값 |
| --- | --- |
| API 서버 | `https://stock-manager-api-patient-cloud-8941.fly.dev/api` |
| 인증 방식 | `Authorization: Bearer {API_KEY}` |
| 가격 캐시 TTL | 5분 |
| 오프라인 캐시 TTL | 30분 |

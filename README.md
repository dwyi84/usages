# 🔋 Usages - AI Usage Menu Bar App for macOS

macOS 메뉴바(툴바)에서 **OpenCode Go** 및 **Google AI Pro** 플랜의 사용량을 배터리 바(Battery Bar Gauge) 형태로 실시간 모니터링하고, 클릭 시 상세 통계를 한눈에 확인할 수 있는 네이티브 macOS 애플리케이션입니다.

---

## ✨ 주요 기능

### 1. 툴바 상단 배터리 게이지 디스플레이
- **배터리 바 디자인**: 배터리 외곽선 캡슐 + 잔여량/소모량 채움 레벨 + 상태별 컬러(초록/주황/빨강)
- **개별 배터리 아이콘 모드**: 메뉴바에 `[OC ▰▰▰▱ 75%]` 와 `[G ▰▰▰▰ 90%]`가 각각 독립된 아이콘으로 깔끔하게 배치
- **통합 단일 아이콘 모드**: 두 서비스의 배터리를 하나의 컴팩트한 메뉴바 아이콘으로 표시
- **수치 커스텀**: 퍼센트 수치 On/Off, 서비스 약어 라벨 On/Off 지원

### 2. 클릭 시 펼쳐지는 상세 팝오버 (Popover)
- **OpenCode Go**:
  - 실시간 잔여 게이지 & 롤링/일일 리셋 시각
  - 오늘 작업량 (Steps), 총 토큰 수 (Input / Output / Cache Read)
  - 오늘 소모 비용 ($) 및 세션 통계
  - 모델별 세부 점유율 및 호출 통계 (DeepSeek, GLM 등)
  - 로컬 `opencode` CLI 및 SQLite DB (`~/.local/share/opencode/opencode.db`) 자동 연동
- **Google AI Pro**:
  - 일일 요청 한도 (RPD) 대비 오늘 사용량 게이지
  - 리셋까지 남은 시간 카운트다운
  - 모델별 통계 (Gemini 3.8 Flash, Gemini 4 Argon 등)
  - Antigravity / Gemini CLI Keyring 토큰 자동 연동 및 API Key 직접 입력 지원

### 3. 환경설정 (Preferences)
- 메뉴바 표시 모드 변경 (개별 아이콘 vs 통합 아이콘)
- 자동 새로고침 주기 (15초 / 30초 / 1분 / 5분)
- 서비스별 커스텀 API Key 설정 (미입력 시 로컬 자동 감지)
- 로그인 시 자동 실행 (Launch at Login)

---

## 🚀 빠른 시작

### 1. 빌드 및 바로 실행
```bash
# 릴리즈 빌드 및 앱 번들 패키징
./Scripts/build_app.sh

# 바로 실행
./Scripts/run.sh
```

### 2. Applications 폴더에 영구 설치
```bash
./Scripts/install.sh
```
설치 후 `/Applications/Usages.app` 또는 Spotlight / Launchpad에서 언제든 실행할 수 있습니다.

---

## 🛠️ 기술 스택
- **Language**: Swift 6 (SwiftUI & AppKit)
- **Architecture**: Native macOS StatusItem (`NSStatusItem`, `NSPopover`)
- **Rendering**: CoreGraphics 기반 배터리 캡슐 벡터 렌더링 (`BatteryGaugeRenderer`)
- **Data Integration**:
  - OpenCode: Local SQLite3 DB & CLI JSON IPC
  - Google AI Pro: macOS Keyring OAuth2 Token & CloudCode PA API

---

## 🔒 라이선스
Private Project. All rights reserved.

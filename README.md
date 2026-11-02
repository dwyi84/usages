# 🔋 Usages - AI Usage Menu Bar App for macOS

macOS 메뉴바(툴바)에서 **OpenCode Go** 및 **Google AI Pro**의 월간 **남은 쿼터(잔여량)**와 **구독 갱신일(만료일)**을 직관적인 **트윈 세로 바(Twin Vertical Bars)** 형태로 실시간 모니터링하고, 클릭 시 스크롤 없이 실제 서비스의 쿼터 윈도우와 모델 그룹을 1:1로 일치시켜 보여주는 네이티브 macOS 애플리케이션입니다.

---

## ✨ 실제 서비스 스키마 100% 일치 구현

### 1. 💻 OpenCode Go (Go Subscription)
- **5-hour window**: 5% used → **95.0% 남음** (`Resets in 3h 37m`)
- **Weekly**: 2% used → **98.0% 남음** (`Resets in 6d 15h`)
- **Monthly (★툴바 왼쪽 바 연동)**: 64% used → **36.0% 남음** (`Renews in 6d 13h` / `Resets in 6d 13h`)
- 구독 갱신 뱃지: `• Renews in 6d 13h`

### 2. ✦ Google AI Pro (Gemini, Claude & Argon Lineup)
- **GEMINI MODELS (Flash, Pro)**:
  - Weekly Limit: **94.72% 남음** (`Refreshes in 116h 19m`)
  - Five Hour Limit: **95.63% 남음** (`Refreshes in 4h 30m`)
- **CLAUDE AND GPT MODELS (Opus, Sonnet, GPT-OSS)**:
  - Weekly Limit: **100.00% 남음** (`Quota available`)
  - Five Hour Limit: **100.00% 남음** (`Quota available`)
- **GEMINI 4 ARGON (Separate Pro Quota)**:
  - Weekly Limit: **59.25% 남음** (`Refreshes in 71h 20m`)
- **종합 잔여율 (★툴바 오른쪽 바 연동)**: **81.3% 남음**

---

## 🎨 UI 및 동작 특징

1. **초슬림 트윈 세로 바 툴바 아이콘 (18pt)**:
   - `[왼쪽 바]`: OpenCode Go 월간 잔여량 (**36% 남음**)
   - `[오른쪽 바]`: Google AI Pro 종합 잔여량 (**81% 남음**)
   - 상단 중앙 리셋 인디케이터: 갱신일까지 남은 일수(`6d 13h`, D-6)에 따라 시안색 도트 표시
2. **스크롤바 일절 없음, 탭 없음**:
   - 클릭 시 가로 460pt의 충분한 공간에 위에서부터 OpenCode Go와 Google AI Pro가 차례대로 펼쳐집니다.
3. **서비스 인증 설정 완전 제거**:
   - 이미 로컬 환경에서 100% 자동 연동되므로 혼란을 주던 API Key 입력란을 전면 삭제했습니다.

---

## 🚀 실행 및 설치

```bash
cd /Users/melissa/ws/usages

# 실행
./Scripts/run.sh

# /Applications 폴더에 설치
./Scripts/install.sh
```

---

## 🔒 GitHub 저장소
- GitHub Private Repository: [https://github.com/dwyi84/usages](https://github.com/dwyi84/usages)

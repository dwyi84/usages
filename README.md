# 🔋 Usages - AI Usage Menu Bar App for macOS

macOS 메뉴바(툴바)에서 **OpenCode Go** 및 **Google AI Pro**의 월간 잔여 쿼터와 구독 갱신일을 **테두리 없는 초미니멀 세로 막대 칸(Segmented Vertical Bars)** 형태로 모니터링하고, 클릭 시 군더더기 없이 두 서비스의 세부 잔여 쿼터를 한눈에 확인할 수 있는 네이티브 macOS 애플리케이션입니다.

---

## ✨ 핵심 디자인 개편: Simple is the Best

### 1. 테두리 없는 미니멀 세로 막대 칸 (Segmented Vertical Bars)
- **테두리 전면 제거**: 거추장스러운 외곽 상자 테두리를 완전히 없앴습니다.
- **여백 최소화**: 폭 약 10.5pt의 극도로 슬림하고 정갈한 2개의 세로 기둥으로 구성됩니다.
- **세로 4칸 게이지 블록**:
  - **[왼쪽 기둥]**: OpenCode Go 월간 잔여량 (36% 남음 → 2칸 활성)
  - **[오른쪽 기둥]**: Google AI Pro 종합 잔여량 (81% 남음 → 4칸 활성)
  - 잔여량이 줄어들면 아래 칸부터 줄어들며, **초록색(정상) → 주황색(주의) → 빨간색(임박)**으로 직관적 색상 전환

### 2. 메뉴 하단에 통합된 원터치 설정 (No Popups, No Clutter)
- 별도 화면 전환이나 팝업 창 없이, **메뉴 팝오버 최하단에 한 줄 미니멀 피커**로 배치:
  `자동 갱신: [15초] [30초] [1분] [5분]`
- 과도한 설명 텍스트를 전면 삭제하여 심플함과 가독성을 극대화했습니다.

### 3. 실제 서비스 데이터 스키마 1:1 완벽 정렬
- **OpenCode Go (Go Subscription)**:
  - `• Renews in 6d 13h`
  - 5-hour window: 95.0% 남음 (`Resets in 3h 37m`)
  - Weekly: 98.0% 남음 (`Resets in 6d 15h`)
  - Monthly: 36.0% 남음 (`Resets in 6d 13h`)
- **Google AI Pro**:
  - `• Renews in 6d 13h`
  - Gemini Models (Flash, Pro): Weekly 94.7% / 5-Hour 95.6%
  - Claude & GPT Models: Weekly 100.0% / 5-Hour 100.0%
  - Gemini 4 Argon: Weekly 59.3% 남음 (`Refreshes in 71h 20m`)

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

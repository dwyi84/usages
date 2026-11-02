# 🔋 Usages - AI Usage Menu Bar App for macOS

macOS 메뉴바(툴바)에서 **OpenCode Go** 및 **Google AI Pro**의 월간 사용량을 컴팩트한 **트윈 세로 바(Twin Vertical Bars)** 게이지 형태로 실시간 모니터링하고, 클릭 시 세부 윈도우(5시간/주간/월간) 및 카테고리(자사/아르곤/타사)를 한눈에 볼 수 있는 네이티브 macOS 애플리케이션입니다.

---

## ✨ 핵심 개편 및 주요 기능

### 1. 초슬림 통합 툴바 아이콘 (Twin Vertical Bar Gauge)
- **단일 통합 아이콘**: 텍스트(OC, G)와 +전극 돌출부를 제거하고, **너비 약 18pt의 초컴팩트 직사각형 캡슐** 안에 두 개의 세로 바를 배치했습니다.
  - **[왼쪽 세로 바]**: OpenCode Go **월간(Monthly)** 잔여 게이지 (아래에서 위로 차오름)
  - **[오른쪽 세로 바]**: Google AI Pro **월간(Monthly)** 잔여 게이지 (아래에서 위로 차오름)
  - **색상**: 잔여량에 따라 **초록색(정상) → 주황색(35% 이하) → 빨간색(15% 이하)** 전환
- **갱신일(Reset D-day) 직관 표시**:
  - 캡슐 상단 중앙 인디케이터로 갱신일 근접 여부를 직관적으로 전달:
    - 갱신일 임박 (3일 이내): 눈에 띄는 **옐로우/오렌지 펄스 도트**
    - 갱신일 보통 (7일 이내): **시안/하늘색 도트**
    - 갱신일 여유 (> 7일): 차분한 반투명 도트

### 2. 깔끔한 2개 탭 상세 팝오버 (Popover View)
클릭 시 혼란스러운 다중 버튼을 제거하고, 직관적인 **단 2개의 상단 탭**으로 개편되었습니다:

#### 💻 [OpenCode Go] 탭
1. **5시간 롤링 한도 (5-Hour Rolling Window)**: 게이지 바 & 리셋 타이머
2. **주간 한도 (Weekly Cap)**: 게이지 바 & 주간 리셋 주기
3. **월간 쿼터 (Monthly Quota)**: 게이지 바 & **D-day 갱신 카운트다운** (툴바 아이콘과 연동)
4. 오늘 작업량(스텝), 총 토큰(입력, 출력, 캐시 읽기), 모델별 사용 통계

#### ✦ [Google AI Pro] 탭
1. **자사 모델 (Gemini 3.8 Flash 등)**: 1,500 요청 일일 한도 대비 사용 게이지
2. **아르곤 (Gemini 4 Argon 심층 추론)**: 500 요청 플래그십 한도 대비 사용 게이지
3. **타사 모델 (Claude Sonnet/Opus, GPT-OSS 등)**: 200 요청 타사 쿼터 대비 사용 게이지
4. **월간 종합 사용률 & D-day 갱신 주기** (툴바 아이콘과 연동)
5. 인증 계정 식별 및 활성 모델별 토큰 분포

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

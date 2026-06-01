# 08. 팀 FSM 연동 — 명세서 대조 후 피드백 반영 (Verilog)

> 본 문서는 팀장이 FSM 명세서를 기준으로 본 FND 모듈을 대조 검토하면서
> 발견한 6가지 인터페이스 차이를 어떻게 반영했는지 정리한 자료다.
> **Verilog 버전** 에만 적용되었으며, 모듈 내부 로직(디코더·스캐너·표시정책)은
> 손대지 않고 **인터페이스/파라미터 레벨** 에서만 조정했다.

---

## 8.1 피드백 6항목 한눈에 보기

| # | 항목 | 심각도 | 본 폴더의 반영 방식 |
|---|---|---|---|
| ① | 클럭 주파수 불일치 (1MHz 가정 → 팀 1kHz) | **치명적** | `fnd_driver.v` 의 default 파라미터 수정 (SCAN_DIV=1, BLINK_DIV=100) |
| ② | input_count 형식 (정수 0~4 ↔ thermometer 4-bit) | 통합 필수 | `fnd_team_adapter.v` 에서 popcount 변환 |
| ③ | mask_enable 미제공 | 통합 필수 | `fnd_team_adapter.v` 에서 `1'b1` 상수 묶음 |
| ④ | digit_data 미노출 | 통합 필수 | `fnd_team_adapter.v` 에서 `16'h0000` 상수 묶음 |
| ⑤ | 리셋 극성 반대 (rst active-high ↔ reset_n active-low) | **치명적** | `fnd_team_adapter.v` 에서 `reset_n = ~rst` |
| ⑥ | state 인코딩 | 일치 ✓ | 수정 없음 (IDLE=000, INPUT=001, …, CHANGE=101) |

---

## 8.2 항목별 상세

### ① 클럭 주파수 — `fnd_driver.v` 파라미터 변경

**문제:** 본 모듈의 default `SCAN_DIV=1000, BLINK_DIV=100000` 은 1MHz 클럭을 가정한 값. 팀 명세 §1 은 **clk_1khz = 1kHz** 단일 도메인.
1kHz 입력에 옛 default 그대로 쓰면:
- scan_tick 이 1Hz → 자리당 1초씩 켜져 한 글자씩 도는 화면
- blink 가 100초 주기 → 사실상 안 보임

**반영:**
```verilog
// src/verilog/fnd_driver.v
module fnd_driver #(
    parameter integer SCAN_DIV  = 1,    // ← 변경 (구 1000)
    parameter integer BLINK_DIV = 100   // ← 변경 (구 100000)
) ( ... );
```

**계산 근거 (1kHz 기준):**
- `SCAN_DIV=1` → 매 클럭마다 scan_tick → 자리 전환 1ms (1kHz) → 4자리 한 바퀴 4ms → **250Hz refresh** (깜빡임 인식 없음)
- `BLINK_DIV=100` → 100ms 토글 → 200ms 주기 → **5Hz blink** (CHECK 상태 시각 피드백)

> 1MHz 도메인으로 운용하려면 instantiation 시 override:
> ```verilog
> fnd_driver #(.SCAN_DIV(1000), .BLINK_DIV(100000)) U_FND (...);
> ```

`clk_divider.v` 의 비교식 `scan_cnt == (SCAN_DIV - 1)` 이 `SCAN_DIV=1` 일 때 `scan_cnt == 0` 이 되어 매 사이클 발생 → 정확히 동작.

---

### ② input_count 형식 — popcount 어댑터

**문제:** 본 모듈 `display_policy` 는 `input_count[2:0]` 을 정수(0~4) 로 받아 `>=` 비교로 마스킹 자릿수를 정함. 그러나 팀 FSM 은 `input_count_led[3:0]` 을 **thermometer** 로 출력:
`0000 → 0001 → 0011 → 0111 → 1111` (자릿수가 늘어날수록 1의 개수가 늘어남)

**반영:** `fnd_team_adapter.v` 에서 popcount 변환 (조합 회로):
```verilog
wire [2:0] input_count_int =
      {2'b00, input_count_led[0]}
    + {2'b00, input_count_led[1]}
    + {2'b00, input_count_led[2]}
    + {2'b00, input_count_led[3]};
```

display_policy 코드는 **그대로** — 책임 분리가 깔끔.

---

### ③ mask_enable — 상수 묶음

**문제:** 팀 FSM 출력 목록(§2-2: state, unlock_on, alarm_on, key_led, input_count_led) 에 `mask_enable` 이 없음. 구동할 신호원이 없음.

**반영:** `fnd_team_adapter.v` 에서 `.mask_enable(1'b1)` 으로 묶음.
비밀번호 도어락 특성상 INPUT/CHANGE 상태에서는 항상 마스킹이 맞으므로 상수가 안전.

> 본 모듈 자체에서 port 를 제거하지 않은 이유: `mask_enable=0` 디버그 모드(실제 입력 숫자 표시) 가 단독 테스트에 유용하며, 향후 팀이 디버그 토글을 노출할 가능성도 남겨둠.

---

### ④ digit_data — 상수 묶음

**문제:** 팀 FSM 은 `input_buffer[15:0]` 을 내부 레지스터로만 보유, 외부 출력 없음 (§3 + 5페이지 E: "현재는 미노출").

**반영:** `mask_enable=1` 일 때 마스킹 경로에서 `digit_data` 가 사용되지 않으므로 `.digit_data(16'h0000)` 상수로 묶음.

> 발표에서 실제 입력 숫자를 한 번이라도 보여주고 싶다면, 팀장과 협의해 `input_buffer` 를 출력 포트로 빼고 그 값을 어댑터의 `digit_data` 에 연결.

---

### ⑤ 리셋 극성 — 어댑터에서 반전

**문제:** 본 모듈 `reset_n` = active-low. 팀 명세 `rst` = active-high 비동기.
**함정:** 명세서는 현재 top 에서 `rst = 1'b0` 고정(리셋 미연결) 이라고 함.
그걸 `reset_n` 에 직결하면 `reset_n=0` → FND가 **영구 리셋 상태로 묶여 화면 꺼짐**.

**반영:** `fnd_team_adapter.v` 에서:
```verilog
wire reset_n_int = ~rst;   // rst=0 → reset_n_int=1 → 정상 동작
```
→ `rst = 1'b0` (현재 팀 top) 상태에서도 본 모듈은 리셋 안 걸리고 정상 동작.
나중에 실제 리셋 버튼이 들어와 `rst=1` 이 되면 `reset_n_int=0` 으로 리셋됨.

---

### ⑥ state 인코딩 — 수정 불필요

| 상태 | 팀 명세 §4 | 본 display_policy.v | 일치 |
|---|---|---|---|
| IDLE | 000 | 000 | ✓ |
| INPUT | 001 | 001 | ✓ |
| CHECK | 010 | 010 | ✓ |
| UNLOCK | 011 | 011 | ✓ |
| ALARM | 100 | 100 | ✓ |
| CHANGE | 101 | 101 | ✓ |

신호명만 `state` ↔ `fsm_state` 다름 → Top 포트맵에서 `.fsm_state(state)` 로 연결.

---

## 8.3 통합 후 팀 Top 의 인스턴스 예 (이서영 → 장현석)

### 권장 방식 — 어댑터 사용
```verilog
fnd_team_adapter U_FND (
    .clk             (clk_1khz),         // 팀 1kHz 단일 도메인
    .rst             (rst),              // 팀 active-high 비동기
    .state           (state),            // 팀 FSM 상태 3-bit
    .input_count_led (input_count_led),  // 팀 thermometer 4-bit
    .fnd_seg         (fnd_seg),          // 보드 핀
    .fnd_com         (fnd_com)           // 보드 핀
);
```
- ⑤ 리셋 반전, ② popcount, ③ mask=1, ④ digit_data=0 모두 어댑터 안에서 처리됨
- 팀 Top 은 본 모듈의 내부 신호 변환을 신경 쓸 필요 없음

### 비권장 방식 — fnd_driver 직접 사용
```verilog
fnd_driver U_FND (
    .clk         (clk_1khz),
    .reset_n     (~rst),                              // 직접 반전
    .fsm_state   (state),
    .mask_enable (1'b1),                              // 상수
    .input_count (popcount(input_count_led)),         // 별도 변환 필요
    .digit_data  (16'h0000),                          // 상수
    .fnd_seg     (fnd_seg),
    .fnd_com     (fnd_com)
);
```
이 경우 popcount 변환 로직을 Top 안에 직접 써넣어야 하므로 어댑터 사용을 권장.

---

## 8.4 합성/시뮬레이션 영향

- `fnd_driver` 파라미터 default 만 바꿨으므로 이미 작성된 모든 testbench 의 generic override (`SCAN_DIV=10, BLINK_DIV=50` 등) 는 그대로 작동.
- `fnd_team_adapter` 는 합성 시 fnd_driver 한 덩어리 + 4-bit popcount 가산기(LUT 1~2개) + NOT 게이트 1개 만 추가 → 자원 영향 미미.
- VHDL 버전은 이번 피드백 반영에서 제외 (팀 통합 언어가 Verilog 로 확정). VHDL 파일은 시뮬레이션 학습용으로 유지.

---

## 8.5 검증 권장 순서

1. **단독 검증** : `top_standalone.v` 를 보드에 다운로드 (1kHz 클럭으로 자동 순환 시연)
2. **어댑터 검증** : `fnd_team_adapter.v` 만 단독으로 합성·다운로드.
   `rst`, `state`, `input_count_led` 를 DIP/버튼으로 인가하여 매핑 검증.
3. **통합 검증** : 이서영 Top 에 `fnd_team_adapter` 인스턴스 → 비밀번호 입력 시나리오 전체 시연.

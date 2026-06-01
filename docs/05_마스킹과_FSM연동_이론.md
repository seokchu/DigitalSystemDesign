# 05. 마스킹과 FSM 연동 이론

## 5.1 비밀번호 마스킹이란

ATM, 도어락, 로그인 화면 등에서 사용자가 비밀번호를 입력할 때 실제 숫자 대신 기호로 보여주는 보안 기법.

원안(PPT) 의 정책 vs 최종 채택 정책:
- **원안** (`디시설_오후_프로젝트.pptx` 19번 슬라이드): "숫자 대신 `****` (별표 형태) 표시. 마스킹 비트 설정 시 모든 세그먼트(a~g) 점등".
- **최종 채택** : `-` (대시, g 세그먼트 1개) 로 마스킹.
  > **이유** : `*` 를 a~g 전체 점등으로 그리면 숫자 `8` 과 7세그먼트 패턴이 100% 동일하다. mask_enable=0 디버그 모드나 ALARM 의 시도 횟수 표시에서 `8` 이 등장할 때 마스킹과 시각 충돌. dp 만 켜진 `-` 는 어떤 숫자와도 헷갈리지 않으면서 입력 진행 상황을 명확히 전달한다.

---

## 5.2 동적 마스킹 — `input_count` 와의 동기

`input_count`(3-bit, 0~4) 는 손동한(C) 의 입력 처리 모듈이 「지금까지 몇 자리 입력되었는가」를 알려주는 신호.
(팀 명세 §6-2 의 thermometer 인코딩 `input_count_led[3:0]` → popcount 변환은 [`fnd_team_adapter.v`](../src/verilog/fnd_team_adapter.v) 가 담당. 본 모듈은 정수 0~4 만 받음.)

본 모듈에서의 표시 매핑:

| input_count | 자리1 | 자리2 | 자리3 | 자리4 | 시각 효과 |
|---|---|---|---|---|---|
| 0 | ` ` | ` ` | ` ` | ` ` | 아직 입력 없음 (전체 빈칸) |
| 1 | `-` | ` ` | ` ` | ` ` | 1자리 입력됨 |
| 2 | `-` | `-` | ` ` | ` ` | 2자리 입력됨 |
| 3 | `-` | `-` | `-` | ` ` | 3자리 입력됨 |
| 4 | `-` | `-` | `-` | `-` | 4자리 모두 입력 완료 |

> 자리 번호 약속: **자리1 = 가장 왼쪽 (최상위 자리)** → 입력은 왼쪽부터 채워지는 UX 를 따릅니다. 만약 보드 결선이 오른쪽부터라면 본 모듈의 `d0,d1,d2,d3` 매핑을 뒤집어 주면 됩니다.

### Verilog 의사 코드
```verilog
// masked : 마스킹 적용 후 16-bit 출력
// 자리 인덱스 i (1=가장왼쪽 ... 4=가장오른쪽) 라고 할 때
// input_count >= i 이면 그 자리에 '-' (코드 0xB), 아니면 빈칸 (0xC)
masked = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
if (input_count >= 3'd1) masked[15:12] = C_DASH;   // Digit1
if (input_count >= 3'd2) masked[11: 8] = C_DASH;   // Digit2
if (input_count >= 3'd3) masked[ 7: 4] = C_DASH;   // Digit3
if (input_count >= 3'd4) masked[ 3: 0] = C_DASH;   // Digit4
```

---

## 5.3 FSM 상태별 표시 정책 (최종)

| FSM 상태 (3-bit) | FND 표시 | 의도 | 비고 |
|---|---|---|---|
| `000` IDLE   | 빈 화면 | LCD 의 "ENTER PW" 안내가 담당 | 전원 ON 직후, 자동 잠금 후 복귀 |
| `001` INPUT  | `-` 마스킹 (input_count 동기) | 비밀번호 노출 방지 | 입력된 자리만 `-` |
| `010` CHECK  | `----` ↔ blank 깜빡임 | 검증 중 시각 피드백 | 5Hz 블링크 |
| `011` UNLOCK | 빈 화면 | LCD 가 'UNLOCKED' 담당 | — |
| `100` ALARM  | `FAIL` 정적 표시 | 경보 상태 명확화 | F/A/1/L 글자 사용 |
| `101` CHANGE | INPUT 과 동일 | 새 비번 입력도 동일 보안 | dash 마스킹 |

### 인코딩 약속
> `fsm_state` 는 3-bit이므로 `110`, `111` 의 두 잔여 코드는 `when others => 빈화면` 으로 처리해 안전 동작 보장.

### Verilog 의사 코드 (display_policy)
```verilog
case (fsm_state)
    ST_IDLE: begin
        disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};   // 빈 화면
    end
    ST_INPUT, ST_CHANGE: begin
        if (mask_enable)
            disp_digits = masked;          // 대시 마스킹
        else
            disp_digits = digit_data;      // 디버그 raw 표시
    end
    ST_CHECK: begin
        if (blink_tick)
            disp_digits = {C_DASH, C_DASH, C_DASH, C_DASH};   // ----
        else
            disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
    end
    ST_UNLOCK:
        disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
    ST_ALARM:
        disp_digits = {C_F, C_A, 4'b0001, C_L};   // F A 1 L
    default:
        disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
endcase
```

`disp_digits` 는 4자리 × 4-bit 의 collection 으로, 이후 MUX 와 디코더로 흘러갑니다.

---

## 5.4 깜빡임(BLINK) 생성

CHECK 상태에서 짧은 깜빡임을 만들기 위해, 별도의 저주파 펄스가 필요합니다.

- 깜빡임 주기 ≈ 200ms (5Hz)
- 1MHz 클럭에서 5Hz pulse → 분주비 200,000 → 18-bit 카운터 필요

`clk_divider` 안에 두 종류의 펄스(`scan_tick`(1kHz) + `blink_tick`(5Hz)) 를 모두 만들어 둡니다.

```vhdl
-- blink_tick : 100ms 마다 토글되는 신호 (50% duty)
if blink_cnt = BLINK_MAX-1 then
    blink_cnt <= 0;
    blink_toggle <= not blink_toggle;
else
    blink_cnt <= blink_cnt + 1;
end if;
blink_tick <= blink_toggle;  -- level signal (펄스 아님)
```

---

## 5.5 ALARM 시 시도 횟수 표시 (선택)

`정용성` 의 비밀번호 모듈이 시도 횟수(fail_cnt) 를 본 모듈에 넘겨주면, ALARM 상태에서 `FAIL` 대신 `0003` 같은 카운트를 표시할 수도 있습니다.

본 프로젝트에서는 인터페이스 단순화를 위해:
- `digit_data` 의 LSB 4비트 자리에 fail_cnt 를 BCD 로 실어주는 컨벤션을 채택 가능
- 또는 ALARM 시에는 `FAIL` 정적 표시 + LED 점멸로 보강

본 모듈 코드는 **`FAIL` 정적 표시를 기본** 으로 하되, ALARM 분기 안에 `digit_data` 를 활용한 카운트 표시 옵션을 주석으로 남겨두어 통합 시 선택할 수 있게 합니다.

---

## 5.6 Reset 정책

비동기 active-low reset (`reset_n`) 을 채택합니다.

- `reset_n='0'` 즉시:
  - `digit_sel <= "00"`
  - `clk_div_cnt <= 0`, `blink_cnt <= 0`
  - `fnd_com <= "1111"` (전 자리 OFF)
  - `fnd_seg <= "00000000"`
- `reset_n='1'` 이 되는 첫 rising_edge(clk) 부터 정상 동작 시작

VHDL 의 `process(clk, reset_n)` 의 표준 패턴:
```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        -- 모든 reg → 초기값
    elsif rising_edge(clk) then
        -- 일반 동작
    end if;
end process;
```

---

## 5.7 본 모듈 5개 핵심 기능 vs 5개 sub-block 매핑

| 기능 (PPT 명세) | 담당 sub-block | 위치 |
|---|---|---|
| ① 7-세그먼트 디코더 | `seg7_decoder` | [src/seg7_decoder.vhd](../src/seg7_decoder.vhd) |
| ② 시분할 멀티플렉싱 | `clk_divider` + `digit_scanner` | [src/clk_divider.vhd](../src/clk_divider.vhd), [src/digit_scanner.vhd](../src/digit_scanner.vhd) |
| ③ 비밀번호 마스킹 표시 | `display_policy` 안의 masking 로직 | [src/display_policy.vhd](../src/display_policy.vhd) |
| ④ FSM 상태별 표시 정책 | `display_policy` 의 case 문 | [src/display_policy.vhd](../src/display_policy.vhd) |
| ⑤ Reset 처리 | 모든 sequential block 의 `reset_n` 분기 | 전 파일 공통 |

이 5개 sub-block 을 [src/fnd_driver.vhd](../src/fnd_driver.vhd) 의 TOP 에서 인스턴스화·연결하면 **`fnd_driver.vhd` 단일 파일과 기능적으로 동일** 합니다 (`장현석_역할별내용.pptx` 의 산출물 정의 충족).

---

## 5.8 다음 문서로 가기

→ [06_VHDL_모듈_상세_설명.md](06_VHDL_모듈_상세_설명.md) — 실제 VHDL 코드의 한 줄 한 줄 해설

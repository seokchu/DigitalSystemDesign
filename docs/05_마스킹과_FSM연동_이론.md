# 05. 마스킹과 FSM 연동 이론

## 5.1 비밀번호 마스킹이란

ATM, 도어락, 로그인 화면 등에서 사용자가 비밀번호를 입력할 때 실제 숫자 대신 `*` 같은 기호로 보여주는 보안 기법.

본 프로젝트의 마스킹 정책 (`디시설_오후_프로젝트.pptx` 19번 슬라이드):
- **Masking Logic:** 비밀번호 노출 방지를 위해 숫자 대신 `****` (별표 형태) 표시
- **Hex to 7-Seg:** 마스킹 비트 설정 시 모든 세그먼트(a~g) 점등 로직 적용
- **자릿수 표시:** 입력된 자리만 `*`, 나머지는 빈칸 (`*___`, `**__`, `***_`, `****`)

---

## 5.2 동적 마스킹 — `input_count` 와의 동기

`input_count`(3-bit, 0~4) 는 손동한(C) 의 입력 처리 모듈이 「지금까지 몇 자리 입력되었는가」를 알려주는 신호.

본 모듈에서의 표시 매핑:

| input_count | 자리4 | 자리3 | 자리2 | 자리1 | 의미 |
|---|---|---|---|---|---|
| 0 | ` ` | ` ` | ` ` | ` ` | 아직 입력 없음 |
| 1 | ` ` | ` ` | ` ` | `*` | 1자리 입력됨 |
| 2 | ` ` | ` ` | `*` | `*` | 2자리 입력됨 |
| 3 | ` ` | `*` | `*` | `*` | 3자리 입력됨 |
| 4 | `*` | `*` | `*` | `*` | 4자리 모두 입력 완료 |

> 자리 번호 약속: **자리1 = 가장 왼쪽 (최상위 자리)** → 입력은 왼쪽부터 채워지는 UX 를 따릅니다. 만약 보드 결선이 오른쪽부터라면 본 모듈의 `d0,d1,d2,d3` 매핑을 뒤집어 주면 됩니다.

### VHDL 의사 코드
```vhdl
-- masked_data : 마스킹 적용 후 16-bit 출력
-- 자리 인덱스 i (1=가장왼쪽 ... 4=가장오른쪽) 라고 가정 시
-- input_count >= i 이면 그 자리에 '*' (코드 0xA), 아니면 빈칸 (0xC)
for i in 1 to 4 loop
    if to_integer(unsigned(input_count)) >= i then
        masked_digit(i) := "1010";  -- '*'
    else
        masked_digit(i) := "1100";  -- ' '
    end if;
end loop;
```

---

## 5.3 FSM 상태별 표시 정책

`장현석_역할별내용.pptx` 2번 슬라이드 표를 그대로 구현:

| FSM 상태 (3-bit) | FND 표시 | 의도 | 비고 |
|---|---|---|---|
| `000` IDLE   | `----` (대시 4개) | 대기 상태 표현 | 전원 ON 직후, 자동 잠금 후 복귀 시 |
| `001` INPUT  | `****` 마스킹 (input_count 동기) | 비밀번호 노출 방지 | 입력된 자리만 `*` |
| `010` CHECK  | 짧은 깜빡임 (BLINK) | 검증 중 시각 피드백 | 100~200ms 의도적 지연 |
| `011` UNLOCK | 빈 화면 (` `) | LCD 메시지에 양보 | LCD가 'UNLOCKED' 담당 |
| `100` ALARM  | `FAIL` 또는 시도 횟수 | 경보 상태 명확화 | F/A/I/L 글자 사용 |
| `101` CHANGE | 마스킹 표시 | 새 비번 입력도 동일 보안 | INPUT과 같은 정책 |

### 인코딩 약속
> `fsm_state` 는 3-bit이므로 `110`, `111` 의 두 잔여 코드는 `when others => 빈화면` 으로 처리해 안전 동작 보장.

### VHDL 의사 코드 (display_policy)
```vhdl
process(fsm_state, digit_data, input_count, blink_tick)
begin
    case fsm_state is
        when "000" =>  -- IDLE
            disp_digits <= ("1011","1011","1011","1011");  -- ----
        when "001" | "101" =>  -- INPUT, CHANGE
            disp_digits <= masked_digits(input_count);
        when "010" =>  -- CHECK
            if blink_tick = '1' then
                disp_digits <= ("1100","1100","1100","1100");  -- blank
            else
                disp_digits <= ("1010","1010","1010","1010");  -- ****
            end if;
        when "011" =>  -- UNLOCK
            disp_digits <= ("1100","1100","1100","1100");
        when "100" =>  -- ALARM
            disp_digits <= ("1101","1110","0001","1111");  -- F A 1 L  (시도 횟수 1로 가정)
            -- 시도 횟수를 자리3에 동적으로 표시하려면 digit_data 입력 사용
        when others =>
            disp_digits <= ("1100","1100","1100","1100");
    end case;
end process;
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

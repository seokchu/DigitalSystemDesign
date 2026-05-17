# 06. VHDL 모듈 상세 설명

본 문서는 [src/](../src/) 안의 5개 VHDL 파일을 한 줄 한 줄 해설합니다. 발표 시 코드 리뷰 자료로도 활용할 수 있게 작성되어 있습니다.

---

## 6.0 모듈 의존 관계 정리

```
                       fnd_driver.vhd  (TOP)
                            │
        ┌───────────┬───────┴────────┬─────────────┐
        ▼           ▼                ▼             ▼
 clk_divider  digit_scanner   display_policy  seg7_decoder
   (sequential)   (sequential)    (combinational)  (combinational)
```

- 4개 sub-block 모두 외부 라이브러리 의존 없음 (ieee.std_logic_1164 + numeric_std 만 사용)
- Quartus 컴파일 순서 : 위 그림의 leaf 모듈 (seg7_decoder, clk_divider, digit_scanner, display_policy) 를 먼저, fnd_driver 를 마지막으로

---

## 6.1 [src/seg7_decoder.vhd](../src/seg7_decoder.vhd)

### 6.1.1 entity
```vhdl
entity seg7_decoder is
    port (
        digit_in : in  std_logic_vector(3 downto 0);
        seg_out  : out std_logic_vector(7 downto 0)
    );
end entity;
```
- `digit_in` (4-bit) : 표시할 코드. [03번 문서](03_7세그먼트_디코더_이론.md#32-본-모듈의-입력-코드-정의) 에서 정의한 16가지 코드 약속을 따른다.
- `seg_out` (8-bit) : MSB부터 `a,b,c,d,e,f,g,dp`. Common Cathode 이므로 active-high.
- clock·reset 없는 순수 조합 회로 → process 가 아니라 `with...select`.

### 6.1.2 architecture
```vhdl
with digit_in select
    seg_out <=
        "11111100" when "0000",  -- 0
        ...
        "00011100" when "1111",  -- 'L'
        "00000000" when others;
```
- 각 분기는 1-cycle LUT 룩업. Quartus 의 RTL viewer 에서 보면 4-input LUT 8개로 구현됨.
- `when others` 는 안전망 (4-bit 입력은 16개 케이스를 모두 명시했으므로 도달 불가)이지만, VHDL 합성기가 latch 를 생성하지 않게 하기 위해 항상 추가.

### 6.1.3 이 모듈이 전체 프로젝트에 쓰이는 위치
fnd_driver 의 마지막 단. 자리당 1ms 동안 디코더의 입력 `digit_in` 이 그 자리의 4-bit 코드로 유지되며, 출력 `seg_out` 이 보드 FND 의 a~dp 핀으로 직결.

### 6.1.4 단위 검증
[testbench/tb_seg7_decoder.vhd](../testbench/tb_seg7_decoder.vhd) 가 16개 코드를 순회하며 진리표(EXPECTED LUT) 와 일치 여부를 assert 로 검사. 통과 시 "PASS : 16/16 codes verified" 메시지.

---

## 6.2 [src/clk_divider.vhd](../src/clk_divider.vhd)

### 6.2.1 entity
```vhdl
entity clk_divider is
    generic (
        SCAN_DIV  : integer := 1000;
        BLINK_DIV : integer := 100000
    );
    port (
        clk        : in  std_logic;
        reset_n    : in  std_logic;
        scan_tick  : out std_logic;
        blink_tick : out std_logic
    );
end entity;
```
- generic 으로 분주비를 외부에서 바꿀 수 있게 함 → 시뮬레이션 시간 단축에 매우 유용.
- default 값 : 1MHz 기준 scan = 1kHz, blink = 5Hz (BLINK_DIV=100000 → 100ms 마다 토글 → 200ms 주기 → 5Hz).

### 6.2.2 핵심 process : scan_tick 생성
```vhdl
p_scan : process(clk, reset_n)
begin
    if reset_n = '0' then
        scan_cnt  <= (others => '0');
        scan_tick <= '0';
    elsif rising_edge(clk) then
        if scan_cnt = to_unsigned(SCAN_DIV - 1, scan_cnt'length) then
            scan_cnt  <= (others => '0');
            scan_tick <= '1';
        else
            scan_cnt  <= scan_cnt + 1;
            scan_tick <= '0';
        end if;
    end if;
end process;
```
**해설:**
- 비동기 active-low reset 표준 패턴 (`if reset_n='0' then ... elsif rising_edge(clk) then ...`).
- 매 cycle `scan_cnt` 증가, `SCAN_DIV-1` 도달 시 0으로 되돌리고 `scan_tick` 을 1-cycle 동안 '1'.
- **scan_tick 은 "clock 이 아니라 enable 펄스"** 이다 — 다른 모듈은 모두 `clk` 로 동작하고 `scan_tick='1'` 일 때만 상태 갱신.
- 카운터 폭을 20-bit 고정으로 두었지만, 합성기가 사용되지 않는 상위 비트를 자동 제거하므로 면적 손실 없음.

### 6.2.3 핵심 process : blink_tick 생성
- `blink_lvl` 을 BLINK_DIV 마다 토글 → 결과적으로 `blink_tick` 은 50% duty 의 5Hz 레벨 신호.
- 펄스가 아닌 **레벨** 이어야 하는 이유 : display_policy 에서 `if blink_tick='1' then **** else blank` 분기하므로, 충분히 오래 유지되어야 사람이 깜빡임을 인지.

### 6.2.4 단위 검증
[testbench/tb_clk_divider.vhd](../testbench/tb_clk_divider.vhd) 에서 generic 을 10/20 으로 줄여, scan_tick 이 10 cycle 주기, blink_tick 이 20 cycle 토글되는지 Wave 로 확인.

---

## 6.3 [src/digit_scanner.vhd](../src/digit_scanner.vhd)

### 6.3.1 entity
```vhdl
entity digit_scanner is
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        scan_tick : in  std_logic;
        digit_sel : out std_logic_vector(1 downto 0);
        fnd_com   : out std_logic_vector(3 downto 0)
    );
end entity;
```
- `digit_sel` : 0~3 자리 선택 (내부 4:1 MUX 용)
- `fnd_com` : 보드 핀으로 나갈 one-hot active-low (4개 자리 중 한 자리만 0)

### 6.3.2 카운터 process
```vhdl
p_count : process(clk, reset_n)
begin
    if reset_n = '0' then
        sel_r <= (others => '0');
    elsif rising_edge(clk) then
        if scan_tick = '1' then
            sel_r <= sel_r + 1;   -- 2-bit wrap
        end if;
    end if;
end process;
```
- 2-bit 카운터의 `+1` 은 `11 → 00` 으로 자연스럽게 wrap.
- scan_tick 이 enable 역할이라 1MHz cycle 마다가 아닌 1ms (=1kHz) 마다 1씩 증가.

### 6.3.3 COM 디코더
```vhdl
with sel_r select
    fnd_com <= "1110" when "00",
               "1101" when "01",
               "1011" when "10",
               "0111" when "11",
               "1111" when others;
```
- `fnd_com(0)=COM1` 약속 ([02번 문서 2.3절](02_FND_하드웨어_기초.md#23-hbe-combo-ii-se-보드의-fnd-사양-디시설_오후_프로젝트pptx-6번-슬라이드)).
- Common Cathode 보드이므로 활성 자리의 COM 만 0.
- `when others` 는 "전 자리 OFF" 안전값.

---

## 6.4 [src/display_policy.vhd](../src/display_policy.vhd)

### 6.4.1 entity
```vhdl
entity display_policy is
    port (
        fsm_state    : in  std_logic_vector(2 downto 0);
        mask_enable  : in  std_logic;
        input_count  : in  std_logic_vector(2 downto 0);
        digit_data   : in  std_logic_vector(15 downto 0);
        blink_tick   : in  std_logic;
        disp_digits  : out std_logic_vector(15 downto 0)
    );
end entity;
```
- 입력 : FSM 정보(`fsm_state`, `mask_enable`, `input_count`), 데이터(`digit_data`), 깜빡임(`blink_tick`)
- 출력 : `disp_digits` = 16-bit (`Digit1` MSB, `Digit4` LSB 순서로 packing)

### 6.4.2 의미 상수와 mask_pattern 함수
```vhdl
constant C_STAR  : std_logic_vector(3 downto 0) := "1010";
constant C_BLANK : std_logic_vector(3 downto 0) := "1100";
...

function mask_pattern(cnt : integer) return std_logic_vector is
    variable v : std_logic_vector(15 downto 0);
begin
    v := C_BLANK & C_BLANK & C_BLANK & C_BLANK;
    if cnt >= 1 then v(15 downto 12) := C_STAR; end if;
    if cnt >= 2 then v(11 downto  8) := C_STAR; end if;
    if cnt >= 3 then v( 7 downto  4) := C_STAR; end if;
    if cnt >= 4 then v( 3 downto  0) := C_STAR; end if;
    return v;
end function;
```
- 의미 상수 (`C_STAR` 등) 로 가독성 ↑.
- `mask_pattern(N)` 은 input_count N 에 대해 왼쪽부터 N개 자리만 `*` 로 채워진 16-bit 패턴을 반환.
- 합성 시 단순 LUT 로 펼쳐짐 (loop 가 아니라 if 체인이므로 unrolling 불필요).

### 6.4.3 메인 case process
```vhdl
process(...)
begin
    cnt_i  := to_integer(unsigned(input_count));
    masked := mask_pattern(cnt_i);

    d1 <= C_BLANK; d2 <= C_BLANK; d3 <= C_BLANK; d4 <= C_BLANK; -- default

    case fsm_state is
        when ST_IDLE   => -- ----
        when ST_INPUT | ST_CHANGE =>
            if mask_enable = '1' then ... masked ...
            else ... digit_data ...
        when ST_CHECK  => -- blink **** / blank
        when ST_UNLOCK => -- blank
        when ST_ALARM  => -- FAIL
        when others    => -- blank
    end case;
end process;
```
**중요 포인트 :**
- 모든 출력을 default 값으로 한 번 대입한 후 case 분기에서 덮어쓰는 패턴 → **latch 생성 방지**.
- `when others` 까지 명시해서 합성기가 incomplete branch 경고를 내지 않음.
- `mask_enable=0` 옵션은 디버깅 모드 또는 비밀번호 확인 화면(매우 빠른 영상 표시) 용도로 활용 가능.

### 6.4.4 ALARM 표시의 대체 옵션 (주석 참조)
```vhdl
-- 변형 옵션) 시도 횟수 표시:
--   d1 <= C_F; d2 <= C_A;
--   d3 <= "0000";
--   d4 <= digit_data(3 downto 0);  -- fail_cnt
```
정용성(D)의 비밀번호 모듈이 `fail_cnt(4-bit)` 를 `digit_data(3 downto 0)` 로 실어주는 컨벤션을 채택하면, 위 주석을 활성화해 `FA 0 N` (N=실패 횟수) 처럼 동적으로 표시 가능.

### 6.4.5 출력 packing
```vhdl
disp_digits <= d1 & d2 & d3 & d4;
```
- 약속 : MSB 가 가장 왼쪽 자리 (Digit1).
- 후속 4:1 MUX 가 이 packing 을 풀어서 자리별 데이터를 선택.

---

## 6.5 [src/fnd_driver.vhd](../src/fnd_driver.vhd) — TOP

### 6.5.1 entity
- 외부 인터페이스는 [README](../README.md#4-팀-내-인터페이스-상위-모듈에서-본-모듈을-인스턴스화-할-때) 의 표 그대로.
- generic SCAN_DIV/BLINK_DIV 만 외부로 노출.

### 6.5.2 인스턴스 4개 + 자리별 MUX
```vhdl
U_DIV  : clk_divider     port map (...);
U_SCAN : digit_scanner   port map (...);
U_POL  : display_policy  port map (...);

with s_digit_sel select
    s_cur_digit <= s_disp_digits(15 downto 12) when "00",
                   s_disp_digits(11 downto  8) when "01",
                   s_disp_digits( 7 downto  4) when "10",
                   s_disp_digits( 3 downto  0) when "11",
                   "1100"                       when others;

U_DEC  : seg7_decoder    port map (s_cur_digit, fnd_seg);
```

### 6.5.3 신호 흐름 (한 cycle 안에서)
1. `s_scan_tick` 이 1ms 마다 1-cycle '1' → `digit_scanner` 가 `s_digit_sel` 을 1 증가, `fnd_com` 도 그 자리로 active-low.
2. **동시에** 4:1 MUX 가 `s_disp_digits` 중 그 자리 4-bit 를 골라 `s_cur_digit` 으로 보냄.
3. `seg7_decoder` 가 `s_cur_digit` 을 `fnd_seg(8-bit)` 로 변환.
4. 보드 FND 는 `fnd_seg` 와 `fnd_com` 을 동시에 받아 해당 자리만 그 패턴으로 점등.
5. 다음 1ms 후 → 다음 자리.

→ **모든 출력이 같은 clock edge 에서 결정되므로 고스팅 거의 없음** ([04번 문서 4.7절](04_시분할_멀티플렉싱_이론.md#47-잠재-이슈와-본-모듈에서의-대응) 참고).

---

## 6.6 합성 자원 추정 (Cyclone II EP2C8 기준)

| 자원 | 예상 사용량 | 비고 |
|---|---|---|
| Logic Element (LE) | < 80 | 카운터 2개 + 작은 case 로직만 |
| Register (FF) | ~ 50 | scan_cnt(20-bit, 실효 10-bit), blink_cnt(20-bit, 실효 17-bit), sel_r(2-bit) 등 |
| Memory | 0 | RAM/ROM 미사용 (LUT 만 사용) |
| Multiplier | 0 | 없음 |

→ EP2C8 의 8,256 LE 중 1% 미만 차지. 통합 시 다른 팀원 모듈과 함께 넣어도 여유.

---

## 6.7 다음 문서로 가기

→ [07_통합과_인터페이스_명세.md](07_통합과_인터페이스_명세.md) — 이서영의 Top 모듈에 본 모듈을 instance 하는 방법

# 시뮬레이션 가이드

## 1. ModelSim / Questa (권장)

```tcl
# ModelSim Transcript 창에서
cd <이 sim 폴더의 경로>
do run_all.do
```

`run_all.do` 가 자동으로 수행하는 일:
1. `work` 라이브러리 생성
2. `src/` 5개 + `testbench/` 5개 모두 컴파일
3. 4개 단위 TB (seg7_decoder, clk_divider, digit_scanner, display_policy) 자동 실행
   → assertion 에러가 없으면 "PASS" 메시지가 transcript 에 표시됨
4. 통합 TB (`tb_fnd_driver`) 를 GUI 모드로 띄우고 Wave 창에 주요 신호 추가
5. 1ms 시뮬레이션 후 zoom full

## 2. 개별 단위 TB 만 돌리고 싶을 때

```tcl
vlib work
vcom -2002 ../src/seg7_decoder.vhd ../testbench/tb_seg7_decoder.vhd
vsim work.tb_seg7_decoder
run -all
```

## 3. Quartus 내장 시뮬레이션 (RTL Simulator)

Quartus 22 이상에서는 Questa-Intel 이 동봉됩니다.
- Tools → Run Simulation Tool → RTL Simulation
- 처음 한 번만 Tools → Options → EDA Tool Options 에서 ModelSim/Questa 경로 지정

## 4. 시뮬레이션 결과 해석 가이드

### tb_seg7_decoder
- 16개 코드 모두에 대해 진리표 일치 → "PASS" 메시지
- 실패 시 어떤 code 가 어긋났는지 assert 가 알려줌

### tb_clk_divider
- generic SCAN_DIV=10, BLINK_DIV=20 으로 축소
- Wave 에서 `scan_tick` 이 10 cycle 마다 1-pulse, `blink_tick` 이 20 cycle 마다 토글이면 정상

### tb_digit_scanner
- 8회 scan_tick 인가 → digit_sel : 00→01→10→11→00→01→10→11
- fnd_com one-hot active-low (1110 → 1101 → 1011 → 0111) 순환

### tb_display_policy
- IDLE → `----`
- INPUT cnt 0~4 → 마스킹 점증 (`____`, `*___`, `**__`, `***_`, `****`)
- CHECK blink → **** ↔ blank
- UNLOCK → blank
- ALARM → FAIL 패턴
- CHANGE → INPUT 과 동일
- mask_enable=0 → raw digit_data 표시

### tb_fnd_driver (통합)
- 시간 흐름에 따라 fsm_state 가 바뀌며 `fnd_seg` / `fnd_com` 이 그에 맞게 변화
- 각 구간에서 `fnd_com` 은 1ms (시뮬상 10us) 마다 자리 전환을 반복
- ALARM 구간에서 `fnd_seg` 가 F → A → 1 → L 순으로 변화

## 5. 흔한 에러와 해결

| 에러 메시지 | 원인 | 해결 |
|---|---|---|
| `Error: vcom: Library 'work' not found` | vlib 생략 | `vlib work` 먼저 실행 |
| `Cannot find ../src/seg7_decoder.vhd` | sim 폴더가 아닌 곳에서 do 실행 | `cd` 로 sim 폴더 이동 |
| `Error: (vcom-1136) Unknown identifier "rising_edge"` | std_logic_1164 미사용 | 모든 파일이 `use ieee.std_logic_1164.all;` 포함 확인 |
| `assert failure` | 디코더 LUT 와 진리표 불일치 | 진리표(docs/03) 또는 LUT 수정 |

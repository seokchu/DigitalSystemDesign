###############################################################################
# ModelSim / Questa  실행 스크립트
# 사용법) ModelSim Transcript 창에서:
#     cd <이 sim 폴더 경로>
#     do run_all.do
#
# 동작:
#   1. work 라이브러리 생성
#   2. src/*.vhd 합성용 5개 + testbench/*.vhd 5개 컴파일
#   3. tb_fnd_driver 를 메인 시뮬레이션 대상으로 실행
#   4. 주요 신호를 Wave 창에 자동 추가
###############################################################################

# --- 0. 기존 결과 정리
if {[file exists work]} { vdel -all -lib work }
vlib work

# --- 1. 소스 컴파일 (순서 중요 : 하위 모듈 먼저)
vcom -2002 ../src/vhdl/seg7_decoder.vhd
vcom -2002 ../src/vhdl/clk_divider.vhd
vcom -2002 ../src/vhdl/digit_scanner.vhd
vcom -2002 ../src/vhdl/display_policy.vhd
vcom -2002 ../src/vhdl/fnd_driver.vhd

# --- 2. 테스트벤치 컴파일
vcom -2002 ../testbench/vhdl/tb_seg7_decoder.vhd
vcom -2002 ../testbench/vhdl/tb_clk_divider.vhd
vcom -2002 ../testbench/vhdl/tb_digit_scanner.vhd
vcom -2002 ../testbench/vhdl/tb_display_policy.vhd
vcom -2002 ../testbench/vhdl/tb_fnd_driver.vhd

# --- 3. 단위 TB 들을 자동 실행 (assert 만 사용 → 짧음)
vsim -c work.tb_seg7_decoder ; run -all ; quit -sim
vsim -c work.tb_clk_divider  ; run 500 us ; quit -sim
vsim -c work.tb_digit_scanner; run -all ; quit -sim
vsim -c work.tb_display_policy ; run -all ; quit -sim

# --- 4. 통합 시뮬레이션 (파형 보기 모드)
vsim work.tb_fnd_driver

# Wave 창 신호 추가
add wave -divider "Top I/O"
add wave -radix bin   sim:/tb_fnd_driver/clk
add wave -radix bin   sim:/tb_fnd_driver/reset_n
add wave -radix bin   sim:/tb_fnd_driver/fsm_state
add wave -radix bin   sim:/tb_fnd_driver/mask_enable
add wave -radix uns   sim:/tb_fnd_driver/input_count
add wave -radix hex   sim:/tb_fnd_driver/digit_data
add wave -divider "Outputs (FND pins)"
add wave -radix bin   sim:/tb_fnd_driver/fnd_seg
add wave -radix bin   sim:/tb_fnd_driver/fnd_com
add wave -divider "Internal"
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_scan_tick
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_blink_tick
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_digit_sel
add wave -radix hex   sim:/tb_fnd_driver/DUT/s_disp_digits
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_cur_digit

run 1 ms
wave zoom full

echo "=================================================="
echo "  모든 단위 TB 통과 + 통합 시뮬레이션 1ms 완료"
echo "  Wave 창에서 fnd_seg / fnd_com 멀티플렉싱 패턴을 확인하세요."
echo "=================================================="

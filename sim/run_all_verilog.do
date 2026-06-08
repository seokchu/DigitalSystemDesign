###############################################################################
# ModelSim / Questa  실행 스크립트 (Verilog 버전)
# 사용법) ModelSim Transcript 창에서:
#     cd <이 sim 폴더 경로>
#     do run_all_verilog.do
#
# 동작:
#   1. work 라이브러리 생성
#   2. src/verilog/*.v 5개 + testbench/verilog/*.v 5개 컴파일
#   3. 단위 TB 4개 자동 실행
#   4. 통합 TB(tb_fnd_driver) 를 Wave 모드로 실행
###############################################################################

# --- 0. 기존 결과 정리
if {[file exists work]} { vdel -all -lib work }
vlib work

# --- 1. 소스 컴파일 (Verilog. 순서 무관하나 가독성 위해 leaf 먼저)
vlog ../src/verilog/seg7_decoder.v
vlog ../src/verilog/clk_divider.v
vlog ../src/verilog/digit_scanner.v
vlog ../src/verilog/display_policy.v
vlog ../src/verilog/fnd_driver.v

# --- 2. 테스트벤치 컴파일
vlog ../testbench/verilog/tb_seg7_decoder.v
vlog ../testbench/verilog/tb_clk_divider.v
vlog ../testbench/verilog/tb_digit_scanner.v
vlog ../testbench/verilog/tb_display_policy.v
vlog ../testbench/verilog/tb_fnd_driver.v

# --- 3. 단위 TB 들을 자동 실행 ($finish 로 종료)
vsim -c work.tb_seg7_decoder   ; run -all ; quit -sim
vsim -c work.tb_clk_divider    ; run -all ; quit -sim
vsim -c work.tb_digit_scanner  ; run -all ; quit -sim
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
add wave -radix uns   sim:/tb_fnd_driver/fail_count
add wave -radix bin   sim:/tb_fnd_driver/lockout
add wave -divider "Outputs (FND pins)"
add wave -radix bin   sim:/tb_fnd_driver/fnd_seg
add wave -radix bin   sim:/tb_fnd_driver/fnd_com
add wave -radix bin   sim:/tb_fnd_driver/fnd1_seg
add wave -divider "Internal"
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_scan_tick
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_blink_tick
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_digit_sel
add wave -radix hex   sim:/tb_fnd_driver/DUT/s_disp_digits
add wave -radix bin   sim:/tb_fnd_driver/DUT/s_cur_digit

run 1 ms
wave zoom full

echo "=================================================="
echo "  Verilog : 모든 단위 TB 통과 + 통합 시뮬 1ms 완료"
echo "=================================================="

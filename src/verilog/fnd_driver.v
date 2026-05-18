//------------------------------------------------------------------------------
// 파일명   : fnd_driver.v
// 모듈명   : fnd_driver  (★ Top Entity for this part)
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
// 언어/툴  : Verilog-2001 / Intel Quartus Prime
//
// 기능 개요
//   FND 출력 모듈의 최상위. 4개 sub-block 을 인스턴스화하여 단일 외부
//   인터페이스로 묶는다.
//     1. clk_divider     : 1MHz → scan_tick(1kHz) / blink_tick(5Hz)
//     2. digit_scanner   : 자리 카운터 + COM one-hot
//     3. display_policy  : FSM 상태별 표시 정책 (4자리 코드 생성)
//     4. seg7_decoder    : 4-bit → 8-bit 세그먼트 패턴
//
// VHDL 버전(../vhdl/fnd_driver.vhd) 과 100% 동일한 동작.
//
// Port (장현석_역할별내용.pptx 슬라이드 1 표 그대로)
//   clk         in  1   : 1MHz 시스템 클럭
//   reset_n     in  1   : 비동기 active-low 리셋
//   fsm_state   in  3   : 메인 FSM 상태 (이서영)
//   mask_enable in  1   : 마스킹 ON/OFF (이서영)
//   input_count in  3   : 입력된 자릿수 0~4 (손동한)
//   digit_data  in  16  : 4자리 BCD (정용성)
//   fnd_seg     out 8   : a~g + dp
//   fnd_com     out 4   : COM1~4 active-low
//------------------------------------------------------------------------------
module fnd_driver #(
    parameter integer SCAN_DIV  = 1000,
    parameter integer BLINK_DIV = 100000
) (
    // 시스템
    input  wire        clk,
    input  wire        reset_n,
    // FSM / 마스킹 / 데이터
    input  wire [2:0]  fsm_state,
    input  wire        mask_enable,
    input  wire [2:0]  input_count,
    input  wire [15:0] digit_data,
    // 보드 FND 핀
    output wire [7:0]  fnd_seg,
    output wire [3:0]  fnd_com
);

    // ── 내부 신호 ──────────────────────────────────────────────────
    wire        s_scan_tick;
    wire        s_blink_tick;
    wire [1:0]  s_digit_sel;
    wire [15:0] s_disp_digits;
    reg  [3:0]  s_cur_digit;

    //--------------------------------------------------------------
    // 1. 분주기
    //--------------------------------------------------------------
    clk_divider #(
        .SCAN_DIV  (SCAN_DIV),
        .BLINK_DIV (BLINK_DIV)
    ) U_DIV (
        .clk        (clk),
        .reset_n    (reset_n),
        .scan_tick  (s_scan_tick),
        .blink_tick (s_blink_tick)
    );

    //--------------------------------------------------------------
    // 2. 자리 카운터 + COM 디코더
    //--------------------------------------------------------------
    digit_scanner U_SCAN (
        .clk       (clk),
        .reset_n   (reset_n),
        .scan_tick (s_scan_tick),
        .digit_sel (s_digit_sel),
        .fnd_com   (fnd_com)
    );

    //--------------------------------------------------------------
    // 3. 표시 정책
    //--------------------------------------------------------------
    display_policy U_POL (
        .fsm_state   (fsm_state),
        .mask_enable (mask_enable),
        .input_count (input_count),
        .digit_data  (digit_data),
        .blink_tick  (s_blink_tick),
        .disp_digits (s_disp_digits)
    );

    //--------------------------------------------------------------
    // 4:1 MUX (자리별 데이터 선택)
    //   packing : [15:12]=Digit1 ... [3:0]=Digit4
    //--------------------------------------------------------------
    always @* begin
        case (s_digit_sel)
            2'b00  : s_cur_digit = s_disp_digits[15:12];
            2'b01  : s_cur_digit = s_disp_digits[11: 8];
            2'b10  : s_cur_digit = s_disp_digits[ 7: 4];
            2'b11  : s_cur_digit = s_disp_digits[ 3: 0];
            default: s_cur_digit = 4'b1100;   // ' '
        endcase
    end

    //--------------------------------------------------------------
    // 4. 7-Seg 디코더
    //--------------------------------------------------------------
    seg7_decoder U_DEC (
        .digit_in (s_cur_digit),
        .seg_out  (fnd_seg)
    );

endmodule

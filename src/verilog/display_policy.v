//------------------------------------------------------------------------------
// 파일명   : display_policy.v
// 모듈명   : display_policy
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
// 언어/툴  : Verilog-2001 / Intel Quartus Prime
//
// 기능 개요
//   FSM 상태(fsm_state)와 마스킹 신호(mask_enable, input_count)를 바탕으로
//   4자리 FND 에 표시할 4-bit 코드 4개 (총 16-bit) 를 결정.
//
// 출력 코드는 seg7_decoder.v 와 동일한 약속.
//
// FSM 상태별 표시 정책 (장현석_역할별내용.pptx 슬라이드 2)
//   000 IDLE   : ---- (대시 4개)
//   001 INPUT  : **** 마스킹 (input_count 동기)
//   010 CHECK  : 짧은 깜빡임 (**** ↔ blank)
//   011 UNLOCK : 빈 화면
//   100 ALARM  : 'FAIL' 정적 표시
//   101 CHANGE : INPUT 과 동일 (마스킹)
//
// 자리 인덱스 약속
//   disp_digits[15:12] = Digit1 (가장 왼쪽)
//   disp_digits[ 3: 0] = Digit4 (가장 오른쪽)
//------------------------------------------------------------------------------
module display_policy (
    input  wire [2:0]  fsm_state,
    input  wire        mask_enable,
    input  wire [2:0]  input_count,    // 0~4
    input  wire [15:0] digit_data,
    input  wire        blink_tick,
    output reg  [15:0] disp_digits
);

    // 의미상수 (디코더 입력 코드와 동일)
    localparam [3:0] C_STAR  = 4'b1010;  // '*'
    localparam [3:0] C_DASH  = 4'b1011;  // '-'
    localparam [3:0] C_BLANK = 4'b1100;  // ' '
    localparam [3:0] C_F     = 4'b1101;
    localparam [3:0] C_A     = 4'b1110;
    localparam [3:0] C_L     = 4'b1111;

    localparam [2:0] ST_IDLE   = 3'b000;
    localparam [2:0] ST_INPUT  = 3'b001;
    localparam [2:0] ST_CHECK  = 3'b010;
    localparam [2:0] ST_UNLOCK = 3'b011;
    localparam [2:0] ST_ALARM  = 3'b100;
    localparam [2:0] ST_CHANGE = 3'b101;

    // 마스킹 패턴 4자리 (input_count 에 따라 왼쪽부터 채움)
    reg [15:0] masked;
    always @* begin
        masked = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
        if (input_count >= 3'd1) masked[15:12] = C_STAR;   // Digit1
        if (input_count >= 3'd2) masked[11: 8] = C_STAR;   // Digit2
        if (input_count >= 3'd3) masked[ 7: 4] = C_STAR;   // Digit3
        if (input_count >= 3'd4) masked[ 3: 0] = C_STAR;   // Digit4
    end

    //--------------------------------------------------------------
    // FSM 상태별 분기
    //   default 를 먼저 대입한 후 case 안에서 덮어쓰는 패턴 → latch 방지
    //--------------------------------------------------------------
    always @* begin
        // 안전 기본값
        disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};

        case (fsm_state)
            ST_IDLE: begin
                disp_digits = {C_DASH, C_DASH, C_DASH, C_DASH};   // ----
            end

            ST_INPUT, ST_CHANGE: begin
                if (mask_enable)
                    disp_digits = masked;
                else
                    disp_digits = digit_data;
            end

            ST_CHECK: begin
                if (blink_tick)
                    disp_digits = {C_STAR, C_STAR, C_STAR, C_STAR};
                else
                    disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
            end

            ST_UNLOCK: begin
                disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
            end

            ST_ALARM: begin
                // 'FAIL' 정적 표시 (시도 횟수 동적 표시 변형 옵션은 VHDL 주석 참조)
                disp_digits = {C_F, C_A, 4'b0001, C_L};
            end

            default: begin
                disp_digits = {C_BLANK, C_BLANK, C_BLANK, C_BLANK};
            end
        endcase
    end

endmodule

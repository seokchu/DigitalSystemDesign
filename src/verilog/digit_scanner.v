//------------------------------------------------------------------------------
// 파일명   : digit_scanner.v
// 모듈명   : digit_scanner
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
// 언어/툴  : Verilog-2001 / Intel Quartus Prime
//
// 기능 개요
//   2-bit 자리 선택 카운터. scan_tick 펄스에 맞춰 00→01→10→11→00 순환.
//   digit_sel 은 (1) 4:1 MUX 의 자리 선택,
//              (2) COM 디코더의 one-hot active-low 생성에 사용.
//
// COM 신호 (one-hot, active-low)
//   Common Cathode 보드이므로 활성 자리의 COM 만 0.
//   fnd_com[0] = COM1 = Digit1 약속.
//------------------------------------------------------------------------------
module digit_scanner (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        scan_tick,
    output wire [1:0]  digit_sel,
    output reg  [3:0]  fnd_com
);

    reg [1:0] sel_r;

    //--------------------------------------------------------------
    // 자리 카운터 : scan_tick='1' 일 때만 +1 (enable 방식)
    //--------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            sel_r <= 2'b00;
        else if (scan_tick)
            sel_r <= sel_r + 2'b01;   // 2-bit 자동 wrap (11→00)
    end

    assign digit_sel = sel_r;

    //--------------------------------------------------------------
    // COM 디코더 : one-hot active-low
    //--------------------------------------------------------------
    always @* begin
        case (sel_r)
            2'b00  : fnd_com = 4'b1110;   // Digit1 (COM1=0)
            2'b01  : fnd_com = 4'b1101;   // Digit2
            2'b10  : fnd_com = 4'b1011;   // Digit3
            2'b11  : fnd_com = 4'b0111;   // Digit4
            default: fnd_com = 4'b1111;   // 안전망
        endcase
    end

endmodule

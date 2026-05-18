//------------------------------------------------------------------------------
// 파일명   : seg7_decoder.v
// 모듈명   : seg7_decoder
// 작성자   : 장현석 (E)
// 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
// 언어/툴  : Verilog-2001 / Intel Quartus Prime
//
// 기능 개요
//   4-bit 코드 입력을 받아 7-Segment (a~g) + dp 의 8-bit 패턴으로 변환.
//   Common Cathode 방식이므로 세그먼트는 active-high (1 = ON).
//
//   입력 코드 약속 (../vhdl/seg7_decoder.vhd 와 100% 동일):
//     0x0~0x9 : 숫자 0~9
//     0xA     : '*' (마스킹)
//     0xB     : '-'
//     0xC     : ' ' (빈칸)
//     0xD/E/F : 'F'/'A'/'L'
//
//   세그먼트 비트 순서:
//     seg_out[7]=a, [6]=b, [5]=c, [4]=d, [3]=e, [2]=f, [1]=g, [0]=dp
//
// 합성 결과
//   순수 조합 회로 (always @* + case). Quartus 가 LUT 한 덩어리로 매핑.
//------------------------------------------------------------------------------
module seg7_decoder (
    input  wire [3:0] digit_in,
    output reg  [7:0] seg_out
);

    always @* begin
        case (digit_in)
            4'h0 : seg_out = 8'b11111100;  // 0
            4'h1 : seg_out = 8'b01100000;  // 1
            4'h2 : seg_out = 8'b11011010;  // 2
            4'h3 : seg_out = 8'b11110010;  // 3
            4'h4 : seg_out = 8'b01100110;  // 4
            4'h5 : seg_out = 8'b10110110;  // 5
            4'h6 : seg_out = 8'b10111110;  // 6
            4'h7 : seg_out = 8'b11100000;  // 7
            4'h8 : seg_out = 8'b11111110;  // 8
            4'h9 : seg_out = 8'b11110110;  // 9
            4'hA : seg_out = 8'b11111110;  // '*' (마스킹, 8과 형태 동일하지만 의미 분리)
            4'hB : seg_out = 8'b00000010;  // '-'
            4'hC : seg_out = 8'b00000000;  // ' '
            4'hD : seg_out = 8'b10001110;  // 'F'
            4'hE : seg_out = 8'b11101110;  // 'A'
            4'hF : seg_out = 8'b00011100;  // 'L'
            default: seg_out = 8'b00000000;
        endcase
    end

endmodule

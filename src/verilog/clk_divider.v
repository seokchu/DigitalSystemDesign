//------------------------------------------------------------------------------
// 파일명   : clk_divider.v
// 모듈명   : clk_divider
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
// 언어/툴  : Verilog-2001 / Intel Quartus Prime
//
// 기능 개요
//   1MHz 클럭으로부터 두 종류의 enable 신호 생성
//     scan_tick  : 1kHz, 1-cycle 펄스 (자리당 1ms 점등)
//     blink_tick : 5Hz 토글 (CHECK 깜빡임용 level signal)
//
//   본 모듈은 새로운 clock 을 만들지 않는다 (clock divider 가 아니라
//   '클럭 인에이블 펄스 생성기'). 단일 1MHz 도메인을 모든 sub-block 이
//   공유하므로 STA·CDC 가 단순해진다.
//
// Parameter
//   SCAN_DIV  : scan_tick 1-pulse 주기 (default 1000 → 1MHz/1000 = 1kHz)
//   BLINK_DIV : blink_tick 토글 주기 (default 100000 → 200ms 주기 → 5Hz)
//------------------------------------------------------------------------------
module clk_divider #(
    parameter integer SCAN_DIV  = 1000,
    parameter integer BLINK_DIV = 100000
) (
    input  wire clk,
    input  wire reset_n,          // 비동기 active-low
    output reg  scan_tick,
    output wire blink_tick
);

    // 충분히 큰 폭(20-bit) 고정. 사용되지 않는 상위 비트는 합성기가 자동 제거.
    reg [19:0] scan_cnt;
    reg [19:0] blink_cnt;
    reg        blink_lvl;

    //--------------------------------------------------------------
    // scan_tick : SCAN_DIV 마다 1-cycle '1' 펄스
    //--------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            scan_cnt  <= 20'd0;
            scan_tick <= 1'b0;
        end else begin
            if (scan_cnt == (SCAN_DIV - 1)) begin
                scan_cnt  <= 20'd0;
                scan_tick <= 1'b1;        // 펄스 1 cycle
            end else begin
                scan_cnt  <= scan_cnt + 20'd1;
                scan_tick <= 1'b0;
            end
        end
    end

    //--------------------------------------------------------------
    // blink_tick : BLINK_DIV 마다 토글 (level signal)
    //--------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            blink_cnt <= 20'd0;
            blink_lvl <= 1'b0;
        end else begin
            if (blink_cnt == (BLINK_DIV - 1)) begin
                blink_cnt <= 20'd0;
                blink_lvl <= ~blink_lvl;
            end else begin
                blink_cnt <= blink_cnt + 20'd1;
            end
        end
    end

    assign blink_tick = blink_lvl;

endmodule

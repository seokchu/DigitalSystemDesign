//------------------------------------------------------------------------------
// 파일명 : tb_clk_divider.v
// 대상   : clk_divider
//
// SCAN_DIV=10, BLINK_DIV=20 으로 축소해 scan_tick / blink_tick 동작 확인.
//------------------------------------------------------------------------------
`timescale 1ns/1ns

module tb_clk_divider;

    parameter CLK_PERIOD = 1000;   // 1MHz

    reg  clk     = 1'b0;
    reg  reset_n = 1'b0;
    wire scan_tick;
    wire blink_tick;

    integer scan_count = 0;

    clk_divider #(
        .SCAN_DIV  (10),
        .BLINK_DIV (20)
    ) DUT (
        .clk        (clk),
        .reset_n    (reset_n),
        .scan_tick  (scan_tick),
        .blink_tick (blink_tick)
    );

    // clock
    always #(CLK_PERIOD/2) clk = ~clk;

    // scan_tick 누적 카운트
    always @(posedge clk) begin
        if (scan_tick) scan_count = scan_count + 1;
    end

    initial begin
        reset_n = 1'b0;
        #(3*CLK_PERIOD);
        reset_n = 1'b1;

        #(200*CLK_PERIOD);
        $display("scan_tick 누적 횟수 = %0d", scan_count);
        $display("==== clk_divider 시뮬레이션 종료 ====");
        $finish;
    end

endmodule

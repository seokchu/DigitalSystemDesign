//------------------------------------------------------------------------------
// 파일명 : tb_digit_scanner.v
// 대상   : digit_scanner
//
// scan_tick 8회 인가 → digit_sel 두 바퀴 순환, fnd_com one-hot 확인.
//------------------------------------------------------------------------------
`timescale 1ns/1ns

module tb_digit_scanner;

    parameter CLK_PERIOD = 1000;

    reg  clk       = 1'b0;
    reg  reset_n   = 1'b0;
    reg  scan_tick = 1'b0;
    wire [1:0] digit_sel;
    wire [3:0] fnd_com;

    integer i;
    integer fail_cnt = 0;
    reg [3:0] expected_com [0:3];

    digit_scanner DUT (
        .clk       (clk),
        .reset_n   (reset_n),
        .scan_tick (scan_tick),
        .digit_sel (digit_sel),
        .fnd_com   (fnd_com)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        expected_com[0] = 4'b1110;
        expected_com[1] = 4'b1101;
        expected_com[2] = 4'b1011;
        expected_com[3] = 4'b0111;

        reset_n = 1'b0;
        #(3*CLK_PERIOD);
        reset_n = 1'b1;
        #(CLK_PERIOD);

        for (i = 0; i < 8; i = i + 1) begin
            scan_tick = 1'b1;
            #(CLK_PERIOD);
            scan_tick = 1'b0;
            #(CLK_PERIOD);
            if (fnd_com !== expected_com[(i+1) % 4]) begin
                $display("MISMATCH step %0d : fnd_com = %b", i, fnd_com);
                fail_cnt = fail_cnt + 1;
            end
        end

        if (fail_cnt == 0)
            $display("==== digit_scanner PASS : 두 바퀴 순환 확인 ====");
        else
            $display("==== digit_scanner FAIL : %0d mismatches ====", fail_cnt);

        $finish;
    end

endmodule

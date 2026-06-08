`timescale 1ns/1ns

module tb_fnd_driver;

    parameter CLK_PERIOD = 1000;
    parameter LOCKC      = 40;

    reg         clk         = 1'b0;
    reg         reset_n     = 1'b0;
    reg  [2:0]  fsm_state   = 3'b000;
    reg         mask_enable = 1'b0;
    reg  [2:0]  input_count = 3'b000;
    reg  [15:0] digit_data  = 16'h1234;
    reg  [3:0]  fail_count  = 4'd0;
    wire [7:0]  fnd_seg;
    wire [3:0]  fnd_com;
    wire [7:0]  fnd1_seg;

    integer n;
    integer fail_cnt = 0;

    fnd_driver #(
        .SCAN_DIV    (10),
        .BLINK_DIV   (50),
        .LOCK_CYCLES (LOCKC)
    ) DUT (
        .clk         (clk),
        .reset_n     (reset_n),
        .fsm_state   (fsm_state),
        .mask_enable (mask_enable),
        .input_count (input_count),
        .digit_data  (digit_data),
        .fail_count  (fail_count),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com),
        .fnd1_seg    (fnd1_seg)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        reset_n = 1'b0;
        #10000;
        reset_n = 1'b1;

        fsm_state   = 3'b001;
        mask_enable = 1'b0;
        digit_data  = 16'h1234;
        for (n = 0; n < 5; n = n + 1) begin
            input_count = n[2:0];
            #20000;
        end

        fsm_state = 3'b010;
        #50000;

        fsm_state   = 3'b001;
        input_count = 3'd0;
        fail_count  = 4'd1;
        #20000;
        fail_count  = 4'd2;
        #20000;

        fail_count  = 4'd3;
        #5000;
        if (DUT.lock_active !== 1'b1) begin
            $display("FAIL: lockout did not assert when fail_count==3");
            fail_cnt = fail_cnt + 1;
        end

        #(CLK_PERIOD*(LOCKC+10));
        if (DUT.lock_active !== 1'b0) begin
            $display("FAIL: lockout did not clear after LOCK_CYCLES");
            fail_cnt = fail_cnt + 1;
        end

        fsm_state  = 3'b011;
        fail_count = 4'd0;
        #50000;

        if (fail_cnt == 0)
            $display("==== tb_fnd_driver PASS : internal 5-sec lockout ok ====");
        else
            $display("==== tb_fnd_driver FAIL : %0d mismatches ====", fail_cnt);

        $finish;
    end

endmodule

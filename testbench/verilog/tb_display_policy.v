`timescale 1ns/1ns

module tb_display_policy;

    reg  [2:0]  fsm_state   = 3'b000;
    reg         mask_enable = 1'b0;
    reg  [2:0]  input_count = 3'b000;
    reg  [15:0] digit_data  = 16'h1234;
    reg         blink_tick  = 1'b0;
    reg         lockout     = 1'b0;
    wire [15:0] disp_digits;

    localparam [3:0] C_DASH  = 4'b1011;
    localparam [3:0] C_BLANK = 4'b1100;

    integer fail_cnt = 0;
    integer n;

    task check;
        input [15:0] expected;
        input [255:0] tag;
        begin
            if (disp_digits !== expected) begin
                $display("FAIL [%0s] : got=%b, exp=%b", tag, disp_digits, expected);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    display_policy DUT (
        .fsm_state   (fsm_state),
        .mask_enable (mask_enable),
        .input_count (input_count),
        .digit_data  (digit_data),
        .blink_tick  (blink_tick),
        .lockout     (lockout),
        .disp_digits (disp_digits)
    );

    initial begin
        fsm_state = 3'b000;
        #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "IDLE ----");

        fsm_state   = 3'b001;
        mask_enable = 1'b0;
        digit_data  = 16'h1234;
        input_count = 3'd0; #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "INPUT cnt0 ----");
        input_count = 3'd1; #100;
        check({4'h1, C_DASH, C_DASH, C_DASH}, "INPUT cnt1 1---");
        input_count = 3'd2; #100;
        check({4'h1, 4'h2, C_DASH, C_DASH}, "INPUT cnt2 12--");
        input_count = 3'd3; #100;
        check({4'h1, 4'h2, 4'h3, C_DASH}, "INPUT cnt3 123-");
        input_count = 3'd4; #100;
        check({4'h1, 4'h2, 4'h3, 4'h4}, "INPUT cnt4 1234");

        fsm_state  = 3'b010;
        blink_tick = 1'b0; #100;
        check({C_BLANK, C_BLANK, C_BLANK, C_BLANK}, "CHECK low (blank)");
        blink_tick = 1'b1; #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "CHECK high (----)");

        fsm_state = 3'b011; #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "UNLOCK ----");

        fsm_state = 3'b100; #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "ALARM ----");

        fsm_state   = 3'b101;
        input_count = 3'd3; #100;
        check({4'h1, 4'h2, 4'h3, C_DASH}, "CHANGE cnt3 123-");

        lockout     = 1'b1;
        fsm_state   = 3'b001;
        input_count = 3'd4;
        digit_data  = 16'h5678; #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "LOCKOUT ----");
        lockout     = 1'b0;

        if (fail_cnt == 0)
            $display("==== display_policy PASS : all scenarios ====");
        else
            $display("==== display_policy FAIL : %0d mismatches ====", fail_cnt);

        $finish;
    end

endmodule

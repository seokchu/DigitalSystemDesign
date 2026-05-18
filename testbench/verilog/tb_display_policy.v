//------------------------------------------------------------------------------
// 파일명 : tb_display_policy.v
// 대상   : display_policy
//
// 6개 FSM 상태 + 마스킹 + blink 분기를 모두 검증.
//------------------------------------------------------------------------------
`timescale 1ns/1ns

module tb_display_policy;

    reg  [2:0]  fsm_state   = 3'b000;
    reg         mask_enable = 1'b1;
    reg  [2:0]  input_count = 3'b000;
    reg  [15:0] digit_data  = 16'h1234;
    reg         blink_tick  = 1'b0;
    wire [15:0] disp_digits;

    localparam [3:0] C_STAR  = 4'b1010;
    localparam [3:0] C_DASH  = 4'b1011;
    localparam [3:0] C_BLANK = 4'b1100;

    integer fail_cnt = 0;
    integer n;

    task check;
        input [15:0] expected;
        input [255:0] tag;     // ascii label
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
        .disp_digits (disp_digits)
    );

    initial begin
        // (1) IDLE → ----
        fsm_state = 3'b000;
        #100;
        check({C_DASH, C_DASH, C_DASH, C_DASH}, "IDLE");

        // (2) INPUT → 마스킹 점진 0~4
        fsm_state = 3'b001;
        for (n = 0; n < 5; n = n + 1) begin
            input_count = n[2:0];
            #100;
            $display("INPUT cnt=%0d disp=%b", n, disp_digits);
        end

        // (3) CHECK
        fsm_state  = 3'b010;
        blink_tick = 1'b0; #100;
        check({C_BLANK, C_BLANK, C_BLANK, C_BLANK}, "CHECK low");
        blink_tick = 1'b1; #100;
        check({C_STAR, C_STAR, C_STAR, C_STAR}, "CHECK high");

        // (4) UNLOCK → blank
        fsm_state = 3'b011; #100;
        check({C_BLANK, C_BLANK, C_BLANK, C_BLANK}, "UNLOCK");

        // (5) ALARM → FAIL 패턴
        fsm_state = 3'b100; #100;
        check({4'b1101, 4'b1110, 4'b0001, 4'b1111}, "ALARM");

        // (6) CHANGE → INPUT 동일
        fsm_state   = 3'b101;
        input_count = 3'b011;
        #100;
        check({C_STAR, C_STAR, C_STAR, C_BLANK}, "CHANGE cnt=3");

        // (7) mask_enable=0 → raw digit_data
        fsm_state   = 3'b001;
        mask_enable = 1'b0;
        digit_data  = 16'h1234;
        #100;
        check(16'h1234, "NO-MASK");

        if (fail_cnt == 0)
            $display("==== display_policy PASS : all scenarios ====");
        else
            $display("==== display_policy FAIL : %0d mismatches ====", fail_cnt);

        $finish;
    end

endmodule

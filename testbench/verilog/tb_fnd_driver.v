//------------------------------------------------------------------------------
// 파일명 : tb_fnd_driver.v
// 대상   : fnd_driver (Top)
//
// fnd_driver 전체를 시나리오 기반으로 동작 확인.
// SCAN_DIV=10, BLINK_DIV=50 으로 시뮬레이션 시간 단축.
//
// 시나리오
//   t=  10 us : reset 해제
//   t=  20 us~: INPUT, input_count 0 → 4 점진
//   t= 100 us : CHECK (blink 관찰)
//   t= 150 us : UNLOCK
//   t= 200 us : ALARM (FAIL)
//   t= 250 us : CHANGE, input_count 2
//   t= 300 us : IDLE
//   마지막   : mask_enable=0 + digit_data=0x1234 → raw 표시
//------------------------------------------------------------------------------
`timescale 1ns/1ns

module tb_fnd_driver;

    parameter CLK_PERIOD = 1000;   // 1MHz

    reg         clk         = 1'b0;
    reg         reset_n     = 1'b0;
    reg  [2:0]  fsm_state   = 3'b000;
    reg         mask_enable = 1'b1;
    reg  [2:0]  input_count = 3'b000;
    reg  [15:0] digit_data  = 16'h1234;
    wire [7:0]  fnd_seg;
    wire [3:0]  fnd_com;

    integer n;

    fnd_driver #(
        .SCAN_DIV  (10),
        .BLINK_DIV (50)
    ) DUT (
        .clk         (clk),
        .reset_n     (reset_n),
        .fsm_state   (fsm_state),
        .mask_enable (mask_enable),
        .input_count (input_count),
        .digit_data  (digit_data),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        // Reset
        reset_n = 1'b0;
        #10000;        // 10 us
        reset_n = 1'b1;

        // INPUT 마스킹 점진
        fsm_state   = 3'b001;
        mask_enable = 1'b1;
        for (n = 0; n < 5; n = n + 1) begin
            input_count = n[2:0];
            #20000;    // 20 us
        end

        // CHECK
        fsm_state = 3'b010;
        #200000;       // 200 us → blink 토글 여러 번 관찰

        // UNLOCK
        fsm_state = 3'b011;
        #50000;

        // ALARM
        fsm_state = 3'b100;
        #50000;

        // CHANGE
        fsm_state   = 3'b101;
        input_count = 3'b010;
        #50000;

        // IDLE
        fsm_state = 3'b000;
        #50000;

        // 마스킹 OFF → raw 표시
        fsm_state   = 3'b001;
        mask_enable = 1'b0;
        input_count = 3'b100;
        digit_data  = 16'h1234;
        #80000;        // 80 us → 한 바퀴 이상 멀티플렉싱 관찰

        $display("==== tb_fnd_driver 시나리오 종료 ====");
        $finish;
    end

endmodule

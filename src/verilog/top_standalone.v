module top_standalone (
    input  wire       clk,
    input  wire       reset_n,
    output wire [7:0] fnd_seg,
    output wire [3:0] fnd_com,
    output wire [7:0] fnd1_seg
);

    reg [9:0] hz_cnt;
    reg       half_sec_tick;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            hz_cnt        <= 10'd0;
            half_sec_tick <= 1'b0;
        end else begin
            if (hz_cnt == 10'd499) begin
                hz_cnt        <= 10'd0;
                half_sec_tick <= 1'b1;
            end else begin
                hz_cnt        <= hz_cnt + 10'd1;
                half_sec_tick <= 1'b0;
            end
        end
    end

    reg [5:0] phase;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            phase <= 6'd0;
        else if (half_sec_tick) begin
            if (phase == 6'd24)
                phase <= 6'd0;
            else
                phase <= phase + 6'd1;
        end
    end

    reg [2:0]  w_fsm_state;
    reg        w_mask_enable;
    reg [2:0]  w_input_count;
    reg [15:0] w_digit_data;
    reg [3:0]  w_fail_count;

    always @* begin
        w_fsm_state   = 3'b000;
        w_mask_enable = 1'b0;
        w_input_count = 3'b000;
        w_digit_data  = 16'h0000;
        w_fail_count  = 4'd0;

        case (phase)
            6'd0 : begin w_fsm_state=3'b000; end

            6'd1 : begin w_fsm_state=3'b001; w_input_count=3'd1; w_digit_data=16'h1234; end
            6'd2 : begin w_fsm_state=3'b001; w_input_count=3'd2; w_digit_data=16'h1234; end
            6'd3 : begin w_fsm_state=3'b001; w_input_count=3'd3; w_digit_data=16'h1234; end
            6'd4 : begin w_fsm_state=3'b001; w_input_count=3'd4; w_digit_data=16'h1234; end

            6'd5 : begin w_fsm_state=3'b010; w_fail_count=4'd0; end

            6'd6 : begin w_fsm_state=3'b001; w_input_count=3'd0; w_fail_count=4'd1; end
            6'd7 : begin w_fsm_state=3'b001; w_input_count=3'd4; w_digit_data=16'h5678; w_fail_count=4'd1; end
            6'd8 : begin w_fsm_state=3'b010; w_fail_count=4'd1; end

            6'd9 : begin w_fsm_state=3'b001; w_input_count=3'd0; w_fail_count=4'd2; end
            6'd10: begin w_fsm_state=3'b001; w_input_count=3'd4; w_digit_data=16'h9012; w_fail_count=4'd2; end
            6'd11: begin w_fsm_state=3'b010; w_fail_count=4'd2; end

            6'd12: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd13: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd14: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd15: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd16: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd17: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd18: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd19: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd20: begin w_fsm_state=3'b100; w_fail_count=4'd3; end
            6'd21: begin w_fsm_state=3'b100; w_fail_count=4'd3; end

            6'd22: begin w_fsm_state=3'b011; w_fail_count=4'd0; end
            6'd23: begin w_fsm_state=3'b000; w_fail_count=4'd0; end
            6'd24: begin w_fsm_state=3'b000; w_fail_count=4'd0; end

            default: begin w_fsm_state=3'b000; end
        endcase
    end

    fnd_driver #(
        .SCAN_DIV    (1),
        .BLINK_DIV   (100),
        .LOCK_CYCLES (5000)
    ) U_FND (
        .clk         (clk),
        .reset_n     (reset_n),
        .fsm_state   (w_fsm_state),
        .mask_enable (w_mask_enable),
        .input_count (w_input_count),
        .digit_data  (w_digit_data),
        .fail_count  (w_fail_count),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com),
        .fnd1_seg    (fnd1_seg)
    );

endmodule

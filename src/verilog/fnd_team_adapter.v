module fnd_team_adapter (
    input  wire        clk,
    input  wire        rst,
    input  wire [2:0]  state,
    input  wire [3:0]  input_count_led,
    input  wire        alarm_on,
    input  wire [3:0]  digit_in,
    input  wire        key_valid,
    output wire [7:0]  fnd_seg,
    output wire [3:0]  fnd_com,
    output wire [7:0]  fnd1_seg
);

    localparam [2:0] S_IDLE   = 3'd0;
    localparam [2:0] S_INPUT  = 3'd1;
    localparam [2:0] S_CHANGE = 3'd5;

    wire reset_n_int = ~rst;

    reg  [15:0] disp_buf;
    reg  [2:0]  cap_cnt;
    reg         key_prev;
    wire        key_pulse = key_valid & ~key_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            disp_buf <= 16'd0;
            cap_cnt  <= 3'd0;
            key_prev <= 1'b0;
        end else begin
            key_prev <= key_valid;

            if (state == S_IDLE) begin
                if (key_pulse) begin
                    disp_buf <= {digit_in, 12'd0};
                    cap_cnt  <= 3'd1;
                end else begin
                    disp_buf <= 16'd0;
                    cap_cnt  <= 3'd0;
                end
            end else if (state == S_INPUT || state == S_CHANGE) begin
                if (key_pulse && cap_cnt < 3'd4) begin
                    case (cap_cnt)
                        3'd0: disp_buf[15:12] <= digit_in;
                        3'd1: disp_buf[11: 8] <= digit_in;
                        3'd2: disp_buf[ 7: 4] <= digit_in;
                        3'd3: disp_buf[ 3: 0] <= digit_in;
                        default: ;
                    endcase
                    cap_cnt <= cap_cnt + 3'd1;
                end
            end else begin
                disp_buf <= 16'd0;
                cap_cnt  <= 3'd0;
            end
        end
    end

    wire [2:0] input_count_int =
          {2'b00, input_count_led[0]}
        + {2'b00, input_count_led[1]}
        + {2'b00, input_count_led[2]}
        + {2'b00, input_count_led[3]};

    fnd_driver #(
        .SCAN_DIV    (1),
        .BLINK_DIV   (100),
        .LOCK_CYCLES (10000)
    ) U_FND (
        .clk         (clk),
        .reset_n     (reset_n_int),
        .fsm_state   (state),
        .mask_enable (1'b0),
        .input_count (input_count_int),
        .digit_data  (disp_buf),
        .lock        (alarm_on),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com),
        .fnd1_seg    (fnd1_seg)
    );

endmodule

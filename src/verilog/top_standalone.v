//------------------------------------------------------------------------------
// 파일명   : top_standalone.v
// 모듈명   : top_standalone
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
//
// 용도
//   ★ 단독 보드 검증 / 발표 시연용 래퍼 ★
//   본 모듈은 fnd_driver 의 모든 입력(fsm_state, mask_enable, input_count,
//   digit_data) 을 내부 카운터로 자동 생성하여, reset 한 번만 누르면
//   6개 FSM 상태를 순환 시연한다.
//
//   덕분에 보드에 할당해야 할 핀은 다음 14개로 줄어든다:
//     - clk          (1)
//     - reset_n      (1)
//     - fnd_seg[7:0] (8)
//     - fnd_com[3:0] (4)
//
//   ※ 팀 통합 시(3주차) 에는 이 파일을 사용하지 않고, 이서영의 top 에서
//      fnd_driver (또는 fnd_team_adapter) 만 인스턴스화하여 사용한다.
//
//   ★ 팀 명세 §1 의 1kHz 단일 도메인에 맞춰 모든 카운터를 1kHz 기준으로 튜닝.
//
// 시연 시나리오 (1kHz 기준 약 ~17초 한 사이클)
//   phase 0 : IDLE        (1초)  ----
//   phase 1 : INPUT cnt=0 (0.5초) ____
//   phase 2 : INPUT cnt=1 (0.5초) *___
//   phase 3 : INPUT cnt=2 (0.5초) **__
//   phase 4 : INPUT cnt=3 (0.5초) ***_
//   phase 5 : INPUT cnt=4 (1초)   ****
//   phase 6 : CHECK       (2초)   **** ↔ blank blink
//   phase 7 : UNLOCK      (1초)   blank
//   phase 8 : ALARM       (2초)   FAIL
//   phase 9 : CHANGE cnt=2(1초)   **__
//   phase 10: IDLE        (1초)   ----  → 다시 phase 0 으로
//------------------------------------------------------------------------------
module top_standalone (
    input  wire       clk,        // 1MHz 보드 클럭
    input  wire       reset_n,    // 푸시버튼 (active-low)
    output wire [7:0] fnd_seg,    // a..g, dp
    output wire [3:0] fnd_com     // COM1..4 (active-low)
);

    //--------------------------------------------------------------
    // 0.5초 펄스 생성
    //   1kHz 클럭에서 0.5s = 500 cycles → 카운터 0~499 → 비교값 499
    //--------------------------------------------------------------
    reg [9:0] hz_cnt;
    reg       half_sec_tick;     // 0.5초마다 1-cycle 펄스

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

    //--------------------------------------------------------------
    // 시연 시퀀서 : 0.5초마다 phase 증가, 33 step (16.5초) 후 wrap
    //--------------------------------------------------------------
    reg [5:0] phase;  // 0~32

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            phase <= 6'd0;
        else if (half_sec_tick) begin
            if (phase == 6'd32)
                phase <= 6'd0;
            else
                phase <= phase + 6'd1;
        end
    end

    //--------------------------------------------------------------
    // phase → (fsm_state, input_count, mask_enable, digit_data) 매핑
    //--------------------------------------------------------------
    reg [2:0]  w_fsm_state;
    reg        w_mask_enable;
    reg [2:0]  w_input_count;
    reg [15:0] w_digit_data;

    always @* begin
        // 기본값
        w_fsm_state   = 3'b000;
        w_mask_enable = 1'b1;
        w_input_count = 3'b000;
        w_digit_data  = 16'h0000;

        case (phase)
            // ── IDLE (1초) ───────────────────────────────────────
            6'd0, 6'd1: begin
                w_fsm_state = 3'b000;
            end

            // ── INPUT cnt 0→4 (각 0.5초, 마지막은 1초 유지) ─────
            6'd2 : begin w_fsm_state=3'b001; w_input_count=3'd0; end
            6'd3 : begin w_fsm_state=3'b001; w_input_count=3'd1; end
            6'd4 : begin w_fsm_state=3'b001; w_input_count=3'd2; end
            6'd5 : begin w_fsm_state=3'b001; w_input_count=3'd3; end
            6'd6, 6'd7 : begin w_fsm_state=3'b001; w_input_count=3'd4; end

            // ── CHECK (2초) blink 관찰 ───────────────────────────
            6'd8, 6'd9, 6'd10, 6'd11: begin
                w_fsm_state = 3'b010;
            end

            // ── UNLOCK (1초) blank ──────────────────────────────
            6'd12, 6'd13: begin
                w_fsm_state = 3'b011;
            end

            // ── ALARM (2초) FAIL ────────────────────────────────
            6'd14, 6'd15, 6'd16, 6'd17: begin
                w_fsm_state = 3'b100;
            end

            // ── CHANGE cnt 0→3 (각 0.5초) 마스킹 점진 ───────────
            6'd18: begin w_fsm_state=3'b101; w_input_count=3'd0; end
            6'd19: begin w_fsm_state=3'b101; w_input_count=3'd1; end
            6'd20: begin w_fsm_state=3'b101; w_input_count=3'd2; end
            6'd21: begin w_fsm_state=3'b101; w_input_count=3'd3; end
            6'd22, 6'd23: begin w_fsm_state=3'b101; w_input_count=3'd4; end

            // ── 보너스: mask_enable=0 으로 raw digit_data 표시 ──
            //    1234 가 그대로 보임
            6'd24, 6'd25, 6'd26, 6'd27: begin
                w_fsm_state   = 3'b001;
                w_mask_enable = 1'b0;
                w_input_count = 3'd4;
                w_digit_data  = 16'h1234;
            end

            // ── IDLE 복귀 (마지막 idle) ─────────────────────────
            6'd28, 6'd29, 6'd30, 6'd31, 6'd32: begin
                w_fsm_state = 3'b000;
            end

            default: begin
                w_fsm_state = 3'b000;
            end
        endcase
    end

    //--------------------------------------------------------------
    // fnd_driver 인스턴스
    //   1kHz 단일 도메인 default (SCAN_DIV=1, BLINK_DIV=100) 그대로 사용.
    //   명시성을 위해 #() 로 한 번 더 표기.
    //--------------------------------------------------------------
    fnd_driver #(
        .SCAN_DIV  (1),
        .BLINK_DIV (100)
    ) U_FND (
        .clk         (clk),
        .reset_n     (reset_n),
        .fsm_state   (w_fsm_state),
        .mask_enable (w_mask_enable),
        .input_count (w_input_count),
        .digit_data  (w_digit_data),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com)
    );

endmodule

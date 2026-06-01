//------------------------------------------------------------------------------
// 파일명   : fnd_team_adapter.v
// 모듈명   : fnd_team_adapter
// 작성자   : 장현석 (E)
// 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
//
// ★ 용도 — 팀 통합 시 fnd_driver 와 팀 FSM 사이의 신호 변환을 책임지는 래퍼.
//          (장현석 모듈 내부 코드는 손대지 않고, 인터페이스 차이만 흡수)
//
// 팀 명세서 vs 본 모듈 인터페이스 차이 (요약)
//   ┌──────────────┬────────────────────┬────────────────────────┬──────────────┐
//   │ 항목          │ 팀 FSM 명세         │ 본 fnd_driver 입력     │ 어댑터 처리   │
//   ├──────────────┼────────────────────┼────────────────────────┼──────────────┤
//   │ 리셋 극성     │ rst (active-high)  │ reset_n (active-low)   │ ~rst         │
//   │ 자릿수 신호   │ input_count_led[3:0]│ input_count[2:0]      │ popcount     │
//   │              │ (thermometer)       │ (정수 0~4)             │ (1의 개수)   │
//   │ 마스킹 신호   │ (미제공)           │ mask_enable            │ 1'b1 상수     │
//   │ 숫자 데이터   │ input_buffer 미노출 │ digit_data[15:0]      │ 16'h0000 상수│
//   │ 상태         │ state[2:0]          │ fsm_state[2:0]        │ 직결 (동일)  │
//   └──────────────┴────────────────────┴────────────────────────┴──────────────┘
//
// 이 모듈만 인스턴스화하면 팀 Top 에서는 위 변환을 신경 쓸 필요가 없다.
//
// 사용 예 (이서영의 top.v 에서)
//   fnd_team_adapter U_FND (
//       .clk             (clk_1khz),
//       .rst             (rst),
//       .state           (state),
//       .input_count_led (input_count_led),
//       .fnd_seg         (fnd_seg),
//       .fnd_com         (fnd_com)
//   );
//------------------------------------------------------------------------------
module fnd_team_adapter (
    // ── 팀 명세 그대로의 신호들 ────────────────────────────────────
    input  wire        clk,              // 1kHz 단일 도메인
    input  wire        rst,              // active-high 비동기 리셋
    input  wire [2:0]  state,            // FSM 상태 (인코딩은 fnd_driver 와 동일)
    input  wire [3:0]  input_count_led,  // thermometer (0000→0001→0011→0111→1111)
    // ── 보드 FND 핀 ───────────────────────────────────────────────
    output wire [7:0]  fnd_seg,
    output wire [3:0]  fnd_com
);

    //--------------------------------------------------------------
    // (1) 리셋 극성 변환 : active-high rst → active-low reset_n
    //--------------------------------------------------------------
    wire reset_n_int = ~rst;

    //--------------------------------------------------------------
    // (2) input_count_led(4-bit thermometer) → input_count(3-bit 0~4)
    //     popcount = 비트 1의 개수.
    //     thermometer 인코딩이므로 부분합 = popcount.
    //     순수 조합 회로 → LUT 한 덩어리.
    //--------------------------------------------------------------
    wire [2:0] input_count_int =
          {2'b00, input_count_led[0]}
        + {2'b00, input_count_led[1]}
        + {2'b00, input_count_led[2]}
        + {2'b00, input_count_led[3]};

    //--------------------------------------------------------------
    // (3) mask_enable = 1'b1 상수 (팀 FSM 미제공이므로 항상 마스킹)
    // (4) digit_data  = 16'h0000 상수 (팀 FSM 의 input_buffer 미노출)
    //     ※ 발표에서 실제 입력 숫자를 보여주려면 팀장과 협의해
    //        input_buffer 를 노출시킨 뒤 여기에 연결.
    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // fnd_driver 인스턴스 (1kHz 단일 도메인 default 유지)
    //--------------------------------------------------------------
    fnd_driver #(
        .SCAN_DIV  (1),     // 1kHz × 1 = 1ms/자리 → 250Hz refresh
        .BLINK_DIV (100)    // 1kHz × 100 = 100ms 토글 → 5Hz blink
    ) U_FND (
        .clk         (clk),
        .reset_n     (reset_n_int),
        .fsm_state   (state),
        .mask_enable (1'b1),
        .input_count (input_count_int),
        .digit_data  (16'h0000),
        .fnd_seg     (fnd_seg),
        .fnd_com     (fnd_com)
    );

endmodule

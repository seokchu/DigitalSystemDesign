//------------------------------------------------------------------------------
// 파일명 : tb_seg7_decoder.v
// 대상   : seg7_decoder
//
// 16개 코드(0x0~0xF) 각각에 대해 기대 패턴 일치 여부 자동 확인.
//------------------------------------------------------------------------------
`timescale 1ns/1ns

module tb_seg7_decoder;

    reg  [3:0] digit_in;
    wire [7:0] seg_out;

    integer i;
    integer fail_cnt = 0;

    // 기대 패턴 LUT (../vhdl/tb_seg7_decoder.vhd 와 동일)
    reg [7:0] expected [0:15];
    initial begin
        expected[0]  = 8'b11111100;
        expected[1]  = 8'b01100000;
        expected[2]  = 8'b11011010;
        expected[3]  = 8'b11110010;
        expected[4]  = 8'b01100110;
        expected[5]  = 8'b10110110;
        expected[6]  = 8'b10111110;
        expected[7]  = 8'b11100000;
        expected[8]  = 8'b11111110;
        expected[9]  = 8'b11110110;
        expected[10] = 8'b11111110;
        expected[11] = 8'b00000010;
        expected[12] = 8'b00000000;
        expected[13] = 8'b10001110;
        expected[14] = 8'b11101110;
        expected[15] = 8'b00011100;
    end

    seg7_decoder DUT (
        .digit_in (digit_in),
        .seg_out  (seg_out)
    );

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            digit_in = i[3:0];
            #10;
            if (seg_out !== expected[i]) begin
                $display("MISMATCH at code %0d : got %b, expected %b",
                         i, seg_out, expected[i]);
                fail_cnt = fail_cnt + 1;
            end
        end

        if (fail_cnt == 0)
            $display("==== seg7_decoder PASS : 16/16 codes verified ====");
        else
            $display("==== seg7_decoder FAIL : %0d / 16 mismatches ====", fail_cnt);

        $finish;
    end

endmodule

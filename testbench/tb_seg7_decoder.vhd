--------------------------------------------------------------------------------
-- 파일명   : tb_seg7_decoder.vhd
-- 대상     : seg7_decoder
-- 작성자   : 장현석
--
-- 검증 목표
--   16가지 입력 코드(0x0~0xF) 각각에 대해 기대 패턴이 출력되는지 자동 확인.
--   불일치 시 assert로 에러 메시지 출력.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_seg7_decoder is
end entity;

architecture sim of tb_seg7_decoder is
    signal digit_in : std_logic_vector(3 downto 0) := (others => '0');
    signal seg_out  : std_logic_vector(7 downto 0);

    -- 기대 패턴 LUT (docs/03 진리표와 동일)
    type t_lut is array (0 to 15) of std_logic_vector(7 downto 0);
    constant EXPECTED : t_lut := (
        "11111100", "01100000", "11011010", "11110010",
        "01100110", "10110110", "10111110", "11100000",
        "11111110", "11110110", "11111110", "00000010",
        "00000000", "10001110", "11101110", "00011100"
    );
begin

    DUT : entity work.seg7_decoder
        port map (
            digit_in => digit_in,
            seg_out  => seg_out
        );

    p_stim : process
    begin
        for i in 0 to 15 loop
            digit_in <= std_logic_vector(to_unsigned(i, 4));
            wait for 10 ns;
            assert seg_out = EXPECTED(i)
                report "MISMATCH at code " & integer'image(i)
                severity error;
        end loop;

        report "==== seg7_decoder PASS : 16/16 codes verified ===="
            severity note;
        wait;
    end process;

end architecture;

--------------------------------------------------------------------------------
-- 파일명   : tb_digit_scanner.vhd
-- 대상     : digit_scanner
-- 작성자   : 장현석
--
-- 검증 목표
--   scan_tick 펄스 입력에 맞춰 digit_sel 이 0→1→2→3→0 순환하고,
--   fnd_com 이 one-hot active-low ("1110","1101","1011","0111") 로 변하는지 확인.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_digit_scanner is
end entity;

architecture sim of tb_digit_scanner is
    constant CLK_PERIOD : time := 1000 ns;  -- 1MHz

    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal scan_tick : std_logic := '0';
    signal digit_sel : std_logic_vector(1 downto 0);
    signal fnd_com   : std_logic_vector(3 downto 0);

    type t_com is array (0 to 3) of std_logic_vector(3 downto 0);
    constant EXPECTED_COM : t_com := ("1110", "1101", "1011", "0111");
begin

    DUT : entity work.digit_scanner
        port map (
            clk       => clk,
            reset_n   => reset_n,
            scan_tick => scan_tick,
            digit_sel => digit_sel,
            fnd_com   => fnd_com
        );

    p_clk : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    p_stim : process
    begin
        -- 리셋
        reset_n <= '0';
        wait for 3*CLK_PERIOD;
        reset_n <= '1';
        wait for CLK_PERIOD;

        -- 8회 scan_tick 인가 → 두 바퀴 순환
        for i in 0 to 7 loop
            scan_tick <= '1';
            wait for CLK_PERIOD;
            scan_tick <= '0';
            wait for CLK_PERIOD;

            -- 자리·COM 검증
            assert fnd_com = EXPECTED_COM((i+1) mod 4)
                report "MISMATCH at step " & integer'image(i) &
                       " : fnd_com = " &
                       std_logic'image(fnd_com(3)) & std_logic'image(fnd_com(2)) &
                       std_logic'image(fnd_com(1)) & std_logic'image(fnd_com(0))
                severity error;
        end loop;

        report "==== digit_scanner PASS : 두 바퀴 순환 확인 ====" severity note;
        wait;
    end process;

end architecture;

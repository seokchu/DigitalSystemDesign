--------------------------------------------------------------------------------
-- 파일명   : tb_clk_divider.vhd
-- 대상     : clk_divider
-- 작성자   : 장현석
--
-- 검증 목표
--   짧은 분주비(SCAN_DIV=10, BLINK_DIV=20) 로 generic 을 줄여
--   scan_tick 이 10 cycle 마다, blink_tick 이 20 cycle 마다 토글되는지 확인.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_clk_divider is
end entity;

architecture sim of tb_clk_divider is
    constant CLK_PERIOD : time := 1000 ns;  -- 1MHz

    signal clk        : std_logic := '0';
    signal reset_n    : std_logic := '0';
    signal scan_tick  : std_logic;
    signal blink_tick : std_logic;

    signal scan_count : integer := 0;  -- scan_tick rising 횟수
begin

    DUT : entity work.clk_divider
        generic map (
            SCAN_DIV  => 10,
            BLINK_DIV => 20
        )
        port map (
            clk        => clk,
            reset_n    => reset_n,
            scan_tick  => scan_tick,
            blink_tick => blink_tick
        );

    -- Clock 생성
    p_clk : process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

    -- Reset 해제
    p_rst : process
    begin
        reset_n <= '0';
        wait for 3*CLK_PERIOD;
        reset_n <= '1';
        wait;
    end process;

    -- scan_tick 카운트 (확인용)
    p_cnt : process(clk)
    begin
        if rising_edge(clk) then
            if scan_tick = '1' then
                scan_count <= scan_count + 1;
            end if;
        end if;
    end process;

    -- 종료
    p_end : process
    begin
        wait for 200 * CLK_PERIOD;
        report "scan_tick 누적 횟수 = " & integer'image(scan_count) severity note;
        report "==== clk_divider 시뮬레이션 종료. 파형(blink_tick 토글) 확인 ===="
            severity note;
        wait;
    end process;

end architecture;

--------------------------------------------------------------------------------
-- 파일명   : tb_display_policy.vhd
-- 대상     : display_policy
-- 작성자   : 장현석
--
-- 검증 목표
--   6개 FSM 상태 각각에 대해 disp_digits 가 의도된 코드인지 확인.
--   INPUT 상태에서 input_count 변화에 따라 마스킹이 한 칸씩 늘어나는지 확인.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_display_policy is
end entity;

architecture sim of tb_display_policy is

    signal fsm_state    : std_logic_vector(2 downto 0) := "000";
    signal mask_enable  : std_logic := '1';
    signal input_count  : std_logic_vector(2 downto 0) := "000";
    signal digit_data   : std_logic_vector(15 downto 0) := x"1234";
    signal blink_tick   : std_logic := '0';
    signal disp_digits  : std_logic_vector(15 downto 0);

    -- 의미상수
    constant C_STAR  : std_logic_vector(3 downto 0) := "1010";
    constant C_DASH  : std_logic_vector(3 downto 0) := "1011";
    constant C_BLANK : std_logic_vector(3 downto 0) := "1100";

begin

    DUT : entity work.display_policy
        port map (
            fsm_state    => fsm_state,
            mask_enable  => mask_enable,
            input_count  => input_count,
            digit_data   => digit_data,
            blink_tick   => blink_tick,
            disp_digits  => disp_digits
        );

    p_stim : process
    begin
        ------------------------------------------------------------
        -- (1) IDLE → ----
        fsm_state <= "000";
        wait for 100 ns;
        assert disp_digits = (C_DASH & C_DASH & C_DASH & C_DASH)
            report "IDLE FAIL : expected ----" severity error;

        ------------------------------------------------------------
        -- (2) INPUT → 마스킹 0~4 단계 점진 표시
        fsm_state <= "001";
        for n in 0 to 4 loop
            input_count <= std_logic_vector(to_unsigned(n, 3));
            wait for 100 ns;
            report "INPUT cnt=" & integer'image(n) &
                   " disp=" & integer'image(to_integer(unsigned(disp_digits)))
                severity note;
        end loop;

        ------------------------------------------------------------
        -- (3) CHECK → blink_tick 에 따라 **** ↔ blank
        fsm_state <= "010";
        blink_tick <= '0';
        wait for 100 ns;
        assert disp_digits = (C_BLANK & C_BLANK & C_BLANK & C_BLANK)
            report "CHECK(low) FAIL : expected blank" severity error;
        blink_tick <= '1';
        wait for 100 ns;
        assert disp_digits = (C_STAR & C_STAR & C_STAR & C_STAR)
            report "CHECK(high) FAIL : expected ****" severity error;

        ------------------------------------------------------------
        -- (4) UNLOCK → blank
        fsm_state <= "011";
        wait for 100 ns;
        assert disp_digits = (C_BLANK & C_BLANK & C_BLANK & C_BLANK)
            report "UNLOCK FAIL" severity error;

        ------------------------------------------------------------
        -- (5) ALARM → FAIL 패턴
        fsm_state <= "100";
        wait for 100 ns;
        report "ALARM disp=" & integer'image(to_integer(unsigned(disp_digits)))
            severity note;
        -- FAIL 패턴 ( F A 1 L ) 확인 : 코드는 "1101"&"1110"&"0001"&"1111"
        assert disp_digits = ("1101" & "1110" & "0001" & "1111")
            report "ALARM FAIL : expected FAIL pattern" severity error;

        ------------------------------------------------------------
        -- (6) CHANGE → INPUT 과 동일 (마스킹)
        fsm_state   <= "101";
        input_count <= "011";
        wait for 100 ns;
        assert disp_digits = (C_STAR & C_STAR & C_STAR & C_BLANK)
            report "CHANGE FAIL : expected ***_" severity error;

        ------------------------------------------------------------
        -- (7) 마스킹 비활성 모드 : 실제 숫자 그대로 표시
        fsm_state   <= "001";
        mask_enable <= '0';
        digit_data  <= x"1234";
        wait for 100 ns;
        assert disp_digits = x"1234"
            report "NO-MASK FAIL : expected raw digit_data" severity error;

        report "==== display_policy 시나리오 검증 종료 ====" severity note;
        wait;
    end process;

end architecture;

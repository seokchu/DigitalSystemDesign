--------------------------------------------------------------------------------
-- 파일명   : tb_fnd_driver.vhd
-- 대상     : fnd_driver (Top)
-- 작성자   : 장현석
--
-- 검증 목표
--   본 테스트벤치는 fnd_driver 전체를 묶어 시나리오 기반으로 동작 확인.
--   짧은 SCAN_DIV(10), BLINK_DIV(50) 로 줄여 4자리 멀티플렉싱 / 마스킹 /
--   FSM 상태 전환 / blink 동작이 파형에 잘 보이도록 함.
--
-- 시나리오
--   t=  10 us : reset 해제
--   t=  20 us : INPUT, input_count 0 → 4 점진 증가 (마스킹 늘어남)
--   t= 100 us : CHECK (****↔blank blink)
--   t= 150 us : UNLOCK (blank)
--   t= 200 us : ALARM  (FAIL)
--   t= 250 us : CHANGE, input_count 2 (마스킹 **__)
--   t= 300 us : IDLE   (----)
--
--   각 구간에서 fnd_seg / fnd_com 파형을 ModelSim 으로 관찰.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_fnd_driver is
end entity;

architecture sim of tb_fnd_driver is
    constant CLK_PERIOD : time := 1000 ns;  -- 1MHz

    signal clk         : std_logic := '0';
    signal reset_n     : std_logic := '0';
    signal fsm_state   : std_logic_vector(2 downto 0) := "000";
    signal mask_enable : std_logic := '1';
    signal input_count : std_logic_vector(2 downto 0) := "000";
    signal digit_data  : std_logic_vector(15 downto 0) := x"1234";
    signal fnd_seg     : std_logic_vector(7 downto 0);
    signal fnd_com     : std_logic_vector(3 downto 0);

begin

    --------------------------------------------------------------------
    -- DUT (시뮬레이션 가속용 generic 감소)
    --------------------------------------------------------------------
    DUT : entity work.fnd_driver
        generic map (
            SCAN_DIV  => 10,    -- 10us 마다 자리 전환
            BLINK_DIV => 50     -- 50us 마다 blink toggle
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            fsm_state   => fsm_state,
            mask_enable => mask_enable,
            input_count => input_count,
            digit_data  => digit_data,
            fnd_seg     => fnd_seg,
            fnd_com     => fnd_com
        );

    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------
    p_clk : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Scenario
    --------------------------------------------------------------------
    p_stim : process
    begin
        -- Reset
        reset_n <= '0';
        wait for 10 us;
        reset_n <= '1';

        ----------------------------------------------------------------
        -- INPUT : 마스킹 점진 표시
        ----------------------------------------------------------------
        fsm_state   <= "001";
        mask_enable <= '1';
        for n in 0 to 4 loop
            input_count <= std_logic_vector(to_unsigned(n, 3));
            wait for 20 us;
        end loop;

        ----------------------------------------------------------------
        -- CHECK : blink **** ↔ blank
        ----------------------------------------------------------------
        fsm_state <= "010";
        wait for 200 us;  -- 여러 번 toggle 관찰

        ----------------------------------------------------------------
        -- UNLOCK : blank
        ----------------------------------------------------------------
        fsm_state <= "011";
        wait for 50 us;

        ----------------------------------------------------------------
        -- ALARM : FAIL
        ----------------------------------------------------------------
        fsm_state <= "100";
        wait for 50 us;

        ----------------------------------------------------------------
        -- CHANGE : 마스킹 **__
        ----------------------------------------------------------------
        fsm_state   <= "101";
        input_count <= "010";
        wait for 50 us;

        ----------------------------------------------------------------
        -- IDLE : ----
        ----------------------------------------------------------------
        fsm_state <= "000";
        wait for 50 us;

        ----------------------------------------------------------------
        -- 마스킹 OFF 모드 검증 : raw digit_data 표시
        ----------------------------------------------------------------
        fsm_state   <= "001";
        mask_enable <= '0';
        input_count <= "100";
        digit_data  <= x"1234";
        wait for 80 us;  -- 한 바퀴 이상 멀티플렉싱 관찰

        report "==== tb_fnd_driver 시나리오 종료. 파형 확인 ====" severity note;
        wait;
    end process;

end architecture;

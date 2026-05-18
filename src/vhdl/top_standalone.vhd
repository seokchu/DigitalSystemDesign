--------------------------------------------------------------------------------
-- 파일명   : top_standalone.vhd
-- 모듈명   : top_standalone
-- 작성자   : 장현석 (E)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
--
-- 용도 : 단독 보드 검증 / 발표 시연용 래퍼.
--   reset 한 번 누르면 6개 FSM 상태를 자동으로 순환 시연.
--   필요 핀 : clk, reset_n, fnd_seg(8), fnd_com(4) — 총 14개.
--
-- 자세한 phase 시나리오는 ../verilog/top_standalone.v 의 주석 참조.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_standalone is
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        fnd_seg : out std_logic_vector(7 downto 0);
        fnd_com : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of top_standalone is

    component fnd_driver is
        generic (SCAN_DIV : integer := 1000; BLINK_DIV : integer := 100000);
        port (
            clk         : in  std_logic;
            reset_n     : in  std_logic;
            fsm_state   : in  std_logic_vector(2 downto 0);
            mask_enable : in  std_logic;
            input_count : in  std_logic_vector(2 downto 0);
            digit_data  : in  std_logic_vector(15 downto 0);
            fnd_seg     : out std_logic_vector(7 downto 0);
            fnd_com     : out std_logic_vector(3 downto 0)
        );
    end component;

    signal hz_cnt        : unsigned(19 downto 0) := (others => '0');
    signal half_sec_tick : std_logic := '0';
    signal phase         : unsigned(5 downto 0) := (others => '0');

    signal w_fsm_state   : std_logic_vector(2 downto 0);
    signal w_mask_enable : std_logic;
    signal w_input_count : std_logic_vector(2 downto 0);
    signal w_digit_data  : std_logic_vector(15 downto 0);

begin

    -- 0.5초 펄스 (1MHz / 500_000)
    p_tick : process(clk, reset_n)
    begin
        if reset_n = '0' then
            hz_cnt        <= (others => '0');
            half_sec_tick <= '0';
        elsif rising_edge(clk) then
            if hz_cnt = to_unsigned(499_999, hz_cnt'length) then
                hz_cnt        <= (others => '0');
                half_sec_tick <= '1';
            else
                hz_cnt        <= hz_cnt + 1;
                half_sec_tick <= '0';
            end if;
        end if;
    end process;

    -- phase 카운터
    p_phase : process(clk, reset_n)
    begin
        if reset_n = '0' then
            phase <= (others => '0');
        elsif rising_edge(clk) then
            if half_sec_tick = '1' then
                if phase = to_unsigned(32, phase'length) then
                    phase <= (others => '0');
                else
                    phase <= phase + 1;
                end if;
            end if;
        end if;
    end process;

    -- phase → 신호 매핑
    p_map : process(phase)
    begin
        w_fsm_state   <= "000";
        w_mask_enable <= '1';
        w_input_count <= "000";
        w_digit_data  <= x"0000";

        case to_integer(phase) is
            when 0 | 1 => w_fsm_state <= "000";  -- IDLE
            when 2 => w_fsm_state <= "001"; w_input_count <= "000";
            when 3 => w_fsm_state <= "001"; w_input_count <= "001";
            when 4 => w_fsm_state <= "001"; w_input_count <= "010";
            when 5 => w_fsm_state <= "001"; w_input_count <= "011";
            when 6 | 7 => w_fsm_state <= "001"; w_input_count <= "100";
            when 8 | 9 | 10 | 11 => w_fsm_state <= "010";  -- CHECK
            when 12 | 13 => w_fsm_state <= "011";          -- UNLOCK
            when 14 | 15 | 16 | 17 => w_fsm_state <= "100";-- ALARM
            when 18 => w_fsm_state <= "101"; w_input_count <= "000";
            when 19 => w_fsm_state <= "101"; w_input_count <= "001";
            when 20 => w_fsm_state <= "101"; w_input_count <= "010";
            when 21 => w_fsm_state <= "101"; w_input_count <= "011";
            when 22 | 23 => w_fsm_state <= "101"; w_input_count <= "100";
            when 24 | 25 | 26 | 27 =>
                w_fsm_state   <= "001";
                w_mask_enable <= '0';
                w_input_count <= "100";
                w_digit_data  <= x"1234";
            when others => w_fsm_state <= "000";
        end case;
    end process;

    U_FND : fnd_driver
        port map (
            clk         => clk,
            reset_n     => reset_n,
            fsm_state   => w_fsm_state,
            mask_enable => w_mask_enable,
            input_count => w_input_count,
            digit_data  => w_digit_data,
            fnd_seg     => fnd_seg,
            fnd_com     => fnd_com
        );

end architecture;

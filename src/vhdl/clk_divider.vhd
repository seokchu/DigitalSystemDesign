--------------------------------------------------------------------------------
-- 파일명   : clk_divider.vhd
-- 모듈명   : clk_divider
-- 작성자   : 장현석 (E)
-- 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
-- 언어/툴  : VHDL-93 / Intel Quartus Prime
--
-- 기능 개요
--   본 모듈은 입력 클럭(보드 1MHz) 로부터 두 종류의 enable 펄스를 생성한다.
--     scan_tick  : 자리 스캐닝용 1kHz 1-cycle 펄스   (자리당 1ms 점등)
--     blink_tick : CHECK 상태 깜빡임용 ~5Hz 레벨 토글 신호 (200ms 주기)
--
--   ★ 중요 설계 원칙:
--     - 본 모듈은 새로운 clock 을 만들지 않는다 (clock divider 가 아니라
--       '클럭 인에이블 펄스 생성기'). 모든 sequential block 은 단일 1MHz
--       도메인을 공유하므로 클럭 트리·STA 가 단순해지고 메타스테이빌리티
--       위험이 사라진다.
--
-- Generic 사용 이유
--   시뮬레이션 시 분주비를 작게 줄여 시간을 단축할 수 있도록 generic 으로
--   매개변수화. 합성 시에는 default 값(1000, 100000) 사용.
--
-- 전체 프로젝트에서의 위치
--   fnd_driver.vhd 내부에서 1MHz clk 를 받아 scan_tick / blink_tick 을 생성,
--   각각 digit_scanner 와 display_policy 에 enable / level 신호로 전달.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_divider is
    generic (
        -- scan_tick : SCAN_DIV 주기마다 1-cycle 펄스 (default 1MHz/1000=1kHz)
        SCAN_DIV  : integer := 1000;
        -- blink_tick : BLINK_DIV 주기마다 토글 (default 1MHz/100000 → 200ms 주기 5Hz)
        BLINK_DIV : integer := 100000
    );
    port (
        clk        : in  std_logic;  -- 1MHz 보드 클럭
        reset_n    : in  std_logic;  -- 비동기 active-low 리셋
        scan_tick  : out std_logic;  -- 1kHz 1-cycle 펄스
        blink_tick : out std_logic   -- 5Hz 레벨 토글
    );
end entity clk_divider;

architecture rtl of clk_divider is

    -- 카운터 폭은 generic 값에 맞춰 자동 계산되지 않으므로,
    -- 충분히 큰 폭(20-bit, 최대 1,048,575) 을 고정 사용. 합성 시 사용되지 않는
    -- 상위 비트는 Quartus 가 자동 제거함.
    signal scan_cnt   : unsigned(19 downto 0) := (others => '0');
    signal blink_cnt  : unsigned(19 downto 0) := (others => '0');
    signal blink_lvl  : std_logic := '0';   -- 토글 보관용

begin

    --------------------------------------------------------------------
    -- scan_tick 생성 : SCAN_DIV 마다 1-cycle '1' 펄스
    --------------------------------------------------------------------
    p_scan : process(clk, reset_n)
    begin
        if reset_n = '0' then
            scan_cnt  <= (others => '0');
            scan_tick <= '0';
        elsif rising_edge(clk) then
            if scan_cnt = to_unsigned(SCAN_DIV - 1, scan_cnt'length) then
                scan_cnt  <= (others => '0');
                scan_tick <= '1';            -- 펄스 1 cycle
            else
                scan_cnt  <= scan_cnt + 1;
                scan_tick <= '0';
            end if;
        end if;
    end process p_scan;

    --------------------------------------------------------------------
    -- blink_tick 생성 : BLINK_DIV 마다 토글 (level signal)
    --   CHECK 상태의 깜빡임은 펄스가 아니라 레벨이 주기적으로 0/1 로
    --   바뀌어야 하므로 토글로 구현.
    --------------------------------------------------------------------
    p_blink : process(clk, reset_n)
    begin
        if reset_n = '0' then
            blink_cnt <= (others => '0');
            blink_lvl <= '0';
        elsif rising_edge(clk) then
            if blink_cnt = to_unsigned(BLINK_DIV - 1, blink_cnt'length) then
                blink_cnt <= (others => '0');
                blink_lvl <= not blink_lvl;
            else
                blink_cnt <= blink_cnt + 1;
            end if;
        end if;
    end process p_blink;

    blink_tick <= blink_lvl;

end architecture rtl;

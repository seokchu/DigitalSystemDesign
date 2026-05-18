--------------------------------------------------------------------------------
-- 파일명   : digit_scanner.vhd
-- 모듈명   : digit_scanner
-- 작성자   : 장현석 (E)
-- 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
-- 언어/툴  : VHDL-93 / Intel Quartus Prime
--
-- 기능 개요
--   2-bit 자리 선택 카운터. scan_tick 펄스가 들어올 때마다 1씩 증가하여
--   00 → 01 → 10 → 11 → 00 ... 순으로 순환.
--   digit_sel 신호는 (1) 4:1 MUX 가 어느 자리 데이터를 디코더에 보낼지 선택,
--                  (2) COM 디코더가 어떤 COM 핀을 활성화할지 결정 에 사용.
--
-- 시분할 멀티플렉싱의 시간축 기준
--   scan_tick : 1kHz → digit_sel 은 1ms 마다 갱신 → 4ms 한 바퀴 → 250Hz refresh
--   사람 눈의 잔상 효과(POV) 로 4자리가 동시에 켜져 있는 것처럼 인지됨.
--
-- COM 신호 (one-hot, active-low)
--   Common Cathode 보드이므로 활성 자리의 COM 만 0, 나머지는 1.
--   fnd_com(0) = COM1 = Digit1 으로 약속.
--
-- 전체 프로젝트에서의 위치
--   clk_divider 의 scan_tick 을 입력 받아 자리 선택 신호와 COM 신호를 생성.
--   digit_sel 은 fnd_driver 내부의 4:1 MUX 로,
--   fnd_com 은 보드 핀으로 출력.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity digit_scanner is
    port (
        clk       : in  std_logic;                     -- 1MHz 시스템 클럭
        reset_n   : in  std_logic;                     -- 비동기 active-low 리셋
        scan_tick : in  std_logic;                     -- 1kHz 1-cycle 펄스
        digit_sel : out std_logic_vector(1 downto 0); -- 현재 자리 0~3
        fnd_com   : out std_logic_vector(3 downto 0)  -- COM1~4 (active-low)
    );
end entity digit_scanner;

architecture rtl of digit_scanner is
    signal sel_r : unsigned(1 downto 0) := (others => '0');
begin

    --------------------------------------------------------------------
    -- 자리 카운터 : scan_tick 이 1일 때만 +1 (enable 방식)
    --   주의: scan_tick 은 1MHz 도메인에서 만든 1-cycle 펄스이므로
    --         CDC 문제 없음.
    --------------------------------------------------------------------
    p_count : process(clk, reset_n)
    begin
        if reset_n = '0' then
            sel_r <= (others => '0');
        elsif rising_edge(clk) then
            if scan_tick = '1' then
                sel_r <= sel_r + 1;   -- 2-bit 이므로 11 → 00 자동 wrap
            end if;
        end if;
    end process p_count;

    digit_sel <= std_logic_vector(sel_r);

    --------------------------------------------------------------------
    -- COM 디코더 : one-hot active-low
    --   Reset 시점에는 모든 자리 OFF ("1111") 가 안전. 본 구현은
    --   초기값이 sel_r="00" 이므로 reset 직후 COM1 이 켜진 상태로 출력되며,
    --   첫 scan_tick 까지 동일 자리가 유지된다. 빈 화면을 원할 때는
    --   display_policy 에서 모든 자리 데이터를 ' '(0xC) 로 만들어 처리한다.
    --------------------------------------------------------------------
    with sel_r select
        fnd_com <= "1110" when "00",   -- Digit1 활성 (COM1=0)
                   "1101" when "01",   -- Digit2 활성
                   "1011" when "10",   -- Digit3 활성
                   "0111" when "11",   -- Digit4 활성
                   "1111" when others; -- 전 자리 OFF (도달 불가)

end architecture rtl;

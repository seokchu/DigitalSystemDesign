--------------------------------------------------------------------------------
-- 파일명   : fnd_driver.vhd
-- 모듈명   : fnd_driver  (★ Top Entity for this part)
-- 작성자   : 장현석 (E)
-- 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
-- 언어/툴  : VHDL-93 / Intel Quartus Prime
--
-- 기능 개요
--   본 파일은 「FND 출력 모듈」 의 최상위(top) entity 이며, 다음 4개의
--   sub-block 을 인스턴스화하여 단일 외부 인터페이스로 묶는다.
--
--     1. clk_divider     : 1MHz → scan_tick(1kHz) / blink_tick(5Hz) 생성
--     2. digit_scanner   : 2-bit 자리 카운터 + COM one-hot 생성
--     3. display_policy  : FSM 상태별 표시 + 마스킹 결정 (4자리 코드 생성)
--     4. seg7_decoder    : 4-bit 코드 → 8-bit 세그먼트 패턴 변환
--
--   장현석_역할별내용.pptx 의 산출물 명세 (fnd_driver.vhd 단일 파일) 와
--   기능적으로 동일하지만, 가독성·재사용성·시뮬레이션 단위 분리를 위해
--   sub-block 구조를 채택. Quartus 의 합성 결과는 동등하다.
--
-- Entity Port (장현석_역할별내용.pptx 슬라이드 1 표 그대로)
--   clk         in  1   : 1MHz 보드 시스템 클럭
--   reset_n     in  1   : 비동기 active-low 리셋
--   digit_data  in  16  : 4자리 BCD (정용성)
--   input_count in  3   : 현재 입력된 자릿수 0~4 (손동한)
--   mask_enable in  1   : 마스킹 모드 ON/OFF (이서영)
--   fsm_state   in  3   : 메인 FSM 현재 상태 (이서영)
--   fnd_seg     out 8   : a~g + dp (보드 핀)
--   fnd_com     out 4   : COM1~4 active-low (보드 핀)
--
-- 전체 프로젝트에서의 위치
--   이서영(A) 의 top.vhd 에서 본 모듈을 component 로 인스턴스화하여
--   B(이서영 자신의 FSM)·C(손동한)·D(정용성) 의 신호와 연결한다.
--   본 모듈은 보드 IO 핀까지 단독으로 도달하는 자기완결 구조이므로,
--   통합 전 단독 다운로드로 동작 검증이 가능하다.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fnd_driver is
    generic (
        -- 시뮬레이션 단축용. 합성 시 default 그대로.
        SCAN_DIV  : integer := 1000;     -- 1MHz / 1000 = 1kHz
        BLINK_DIV : integer := 100000    -- 1MHz / 100000 = 10Hz 토글 → 5Hz blink
    );
    port (
        -- ── 시스템 ─────────────────────────────────────────────────
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        -- ── FSM / 마스킹 / 데이터 ───────────────────────────────────
        fsm_state   : in  std_logic_vector(2 downto 0);
        mask_enable : in  std_logic;
        input_count : in  std_logic_vector(2 downto 0);
        digit_data  : in  std_logic_vector(15 downto 0);
        -- ── 보드 FND 핀 ────────────────────────────────────────────
        fnd_seg     : out std_logic_vector(7 downto 0);  -- a..g, dp
        fnd_com     : out std_logic_vector(3 downto 0)   -- COM1..4 active-low
    );
end entity fnd_driver;

architecture rtl of fnd_driver is

    -- ────────────────────────────────────────────────────────────────
    -- Component 선언
    -- ────────────────────────────────────────────────────────────────
    component clk_divider is
        generic (
            SCAN_DIV  : integer := 1000;
            BLINK_DIV : integer := 100000
        );
        port (
            clk        : in  std_logic;
            reset_n    : in  std_logic;
            scan_tick  : out std_logic;
            blink_tick : out std_logic
        );
    end component;

    component digit_scanner is
        port (
            clk       : in  std_logic;
            reset_n   : in  std_logic;
            scan_tick : in  std_logic;
            digit_sel : out std_logic_vector(1 downto 0);
            fnd_com   : out std_logic_vector(3 downto 0)
        );
    end component;

    component display_policy is
        port (
            fsm_state    : in  std_logic_vector(2 downto 0);
            mask_enable  : in  std_logic;
            input_count  : in  std_logic_vector(2 downto 0);
            digit_data   : in  std_logic_vector(15 downto 0);
            blink_tick   : in  std_logic;
            disp_digits  : out std_logic_vector(15 downto 0)
        );
    end component;

    component seg7_decoder is
        port (
            digit_in : in  std_logic_vector(3 downto 0);
            seg_out  : out std_logic_vector(7 downto 0)
        );
    end component;

    -- ────────────────────────────────────────────────────────────────
    -- 내부 신호
    -- ────────────────────────────────────────────────────────────────
    signal s_scan_tick   : std_logic;
    signal s_blink_tick  : std_logic;
    signal s_digit_sel   : std_logic_vector(1 downto 0);
    signal s_disp_digits : std_logic_vector(15 downto 0);
    signal s_cur_digit   : std_logic_vector(3 downto 0);

begin

    --------------------------------------------------------------------
    -- 1. 분주기 : 1MHz → scan_tick(1kHz) + blink_tick(5Hz 토글)
    --------------------------------------------------------------------
    U_DIV : clk_divider
        generic map (
            SCAN_DIV  => SCAN_DIV,
            BLINK_DIV => BLINK_DIV
        )
        port map (
            clk        => clk,
            reset_n    => reset_n,
            scan_tick  => s_scan_tick,
            blink_tick => s_blink_tick
        );

    --------------------------------------------------------------------
    -- 2. 자리 카운터 + COM 디코더
    --------------------------------------------------------------------
    U_SCAN : digit_scanner
        port map (
            clk       => clk,
            reset_n   => reset_n,
            scan_tick => s_scan_tick,
            digit_sel => s_digit_sel,
            fnd_com   => fnd_com
        );

    --------------------------------------------------------------------
    -- 3. 표시 정책 : FSM 상태별 4자리 출력 코드 결정
    --------------------------------------------------------------------
    U_POL : display_policy
        port map (
            fsm_state   => fsm_state,
            mask_enable => mask_enable,
            input_count => input_count,
            digit_data  => digit_data,
            blink_tick  => s_blink_tick,
            disp_digits => s_disp_digits
        );

    --------------------------------------------------------------------
    -- 4:1 MUX (자리별 데이터 선택)
    --   s_disp_digits packing : (15:12)=Digit1 ... (3:0)=Digit4
    --   digit_sel = 00 → Digit1, 01 → Digit2 ...
    --------------------------------------------------------------------
    with s_digit_sel select
        s_cur_digit <= s_disp_digits(15 downto 12) when "00",
                       s_disp_digits(11 downto  8) when "01",
                       s_disp_digits( 7 downto  4) when "10",
                       s_disp_digits( 3 downto  0) when "11",
                       "1100"                       when others;  -- ' '

    --------------------------------------------------------------------
    -- 4. 7-Seg 디코더 : 4-bit → 8-bit 패턴
    --------------------------------------------------------------------
    U_DEC : seg7_decoder
        port map (
            digit_in => s_cur_digit,
            seg_out  => fnd_seg
        );

end architecture rtl;

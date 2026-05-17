--------------------------------------------------------------------------------
-- 파일명   : display_policy.vhd
-- 모듈명   : display_policy
-- 작성자   : 장현석 (E)
-- 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
-- 언어/툴  : VHDL-93 / Intel Quartus Prime
--
-- 기능 개요
--   FSM 상태(fsm_state)와 마스킹 신호(mask_enable, input_count) 를 바탕으로
--   4자리 FND 에 표시할 코드 4개 (각 4-bit, 16-bit total) 를 결정한다.
--   본 모듈은 순수 조합/저비용 로직으로, FSM 의 표시 정책을 담당.
--
--   출력 코드는 seg7_decoder 의 입력 코드 정의와 동일하다.
--     0x0~0x9 : 숫자
--     0xA     : '*' (마스킹)
--     0xB     : '-' (대시)
--     0xC     : ' ' (빈칸)
--     0xD/E/F : F / A / L
--
-- FSM 상태별 표시 정책 (장현석_역할별내용.pptx 슬라이드 2)
--   000 IDLE   : ---- (대시 4개)
--   001 INPUT  : **** 마스킹 (input_count 동기)
--   010 CHECK  : 짧은 깜빡임 (**** ↔ blank)
--   011 UNLOCK : 빈 화면 (LCD 메시지에 양보)
--   100 ALARM  : 'FAIL' 정적 표시
--   101 CHANGE : INPUT 과 동일 (마스킹)
--   기타       : 빈 화면 (안전)
--
-- 마스킹 정책
--   input_count = N (0~4) 일 때, 왼쪽부터 N개의 자리만 '*', 나머지는 빈칸.
--   자리 인덱스 약속:
--     digits_out(15:12) = Digit1 (가장 왼쪽, MSB 자리)
--     digits_out(11: 8) = Digit2
--     digits_out( 7: 4) = Digit3
--     digits_out( 3: 0) = Digit4 (가장 오른쪽, LSB 자리)
--
--   ※ mask_enable 신호는 「현재 상태가 마스킹이 필요한 상태인가」 를
--      상위 FSM(이서영) 이 명시적으로 알려주는 의미이며, INPUT/CHANGE 외
--      어떤 상태에서도 보안상 필요 시 마스킹을 강제할 수 있다.
--
-- 전체 프로젝트에서의 위치
--   fnd_driver 내부에서:
--     입력 : fsm_state(3), mask_enable, input_count(3), digit_data(16),
--            blink_tick
--     출력 : disp_digits(16)  → 후속 4:1 MUX 로 전달
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity display_policy is
    port (
        fsm_state    : in  std_logic_vector(2 downto 0);
        mask_enable  : in  std_logic;
        input_count  : in  std_logic_vector(2 downto 0);  -- 0~4
        digit_data   : in  std_logic_vector(15 downto 0); -- 4 BCD 자리
        blink_tick   : in  std_logic;                     -- 5Hz 토글
        disp_digits  : out std_logic_vector(15 downto 0)  -- 4자리 출력 코드
    );
end entity display_policy;

architecture rtl of display_policy is

    -- 의미 있는 상수 명명 (가독성)
    constant C_STAR  : std_logic_vector(3 downto 0) := "1010";  -- '*'
    constant C_DASH  : std_logic_vector(3 downto 0) := "1011";  -- '-'
    constant C_BLANK : std_logic_vector(3 downto 0) := "1100";  -- ' '
    constant C_F     : std_logic_vector(3 downto 0) := "1101";
    constant C_A     : std_logic_vector(3 downto 0) := "1110";
    constant C_L     : std_logic_vector(3 downto 0) := "1111";

    constant ST_IDLE   : std_logic_vector(2 downto 0) := "000";
    constant ST_INPUT  : std_logic_vector(2 downto 0) := "001";
    constant ST_CHECK  : std_logic_vector(2 downto 0) := "010";
    constant ST_UNLOCK : std_logic_vector(2 downto 0) := "011";
    constant ST_ALARM  : std_logic_vector(2 downto 0) := "100";
    constant ST_CHANGE : std_logic_vector(2 downto 0) := "101";

    -- 내부 신호 : 4자리 코드를 따로 두면 case 분기에서 다루기 편함
    signal d1, d2, d3, d4 : std_logic_vector(3 downto 0);

    -- 마스킹 패턴 4자리 (input_count 에 따라)
    -- 왼쪽부터 채워지는 UX : input_count=1 → "*___"
    function mask_pattern(cnt : integer) return std_logic_vector is
        variable v : std_logic_vector(15 downto 0);
    begin
        -- 기본 : 전부 빈칸
        v := C_BLANK & C_BLANK & C_BLANK & C_BLANK;
        if cnt >= 1 then v(15 downto 12) := C_STAR; end if;  -- Digit1
        if cnt >= 2 then v(11 downto  8) := C_STAR; end if;  -- Digit2
        if cnt >= 3 then v( 7 downto  4) := C_STAR; end if;  -- Digit3
        if cnt >= 4 then v( 3 downto  0) := C_STAR; end if;  -- Digit4
        return v;
    end function;

begin

    --------------------------------------------------------------------
    -- 메인 표시 정책 결정 (조합 로직)
    --------------------------------------------------------------------
    process(fsm_state, mask_enable, input_count, digit_data, blink_tick)
        variable cnt_i : integer range 0 to 7;
        variable masked: std_logic_vector(15 downto 0);
    begin
        cnt_i  := to_integer(unsigned(input_count));
        masked := mask_pattern(cnt_i);

        -- 기본값(안전망): 빈 화면
        d1 <= C_BLANK;
        d2 <= C_BLANK;
        d3 <= C_BLANK;
        d4 <= C_BLANK;

        case fsm_state is

            --------------------------------------------------------
            when ST_IDLE =>
                -- ---- 대기 화면 (전원 ON 직후, 자동 잠금 복귀 등)
                d1 <= C_DASH;
                d2 <= C_DASH;
                d3 <= C_DASH;
                d4 <= C_DASH;

            --------------------------------------------------------
            when ST_INPUT | ST_CHANGE =>
                -- INPUT, CHANGE 는 동일하게 마스킹 표시
                -- mask_enable = 0 이면(예: 디버그 모드) 실제 숫자를 보여줌
                if mask_enable = '1' then
                    d1 <= masked(15 downto 12);
                    d2 <= masked(11 downto  8);
                    d3 <= masked( 7 downto  4);
                    d4 <= masked( 3 downto  0);
                else
                    d1 <= digit_data(15 downto 12);
                    d2 <= digit_data(11 downto  8);
                    d3 <= digit_data( 7 downto  4);
                    d4 <= digit_data( 3 downto  0);
                end if;

            --------------------------------------------------------
            when ST_CHECK =>
                -- 검증 중 시각 피드백 : 5Hz 로 **** ↔ blank
                if blink_tick = '1' then
                    d1 <= C_STAR;
                    d2 <= C_STAR;
                    d3 <= C_STAR;
                    d4 <= C_STAR;
                else
                    d1 <= C_BLANK;
                    d2 <= C_BLANK;
                    d3 <= C_BLANK;
                    d4 <= C_BLANK;
                end if;

            --------------------------------------------------------
            when ST_UNLOCK =>
                -- LCD 가 'UNLOCKED' 메시지 담당하므로 FND 는 빈 화면
                d1 <= C_BLANK;
                d2 <= C_BLANK;
                d3 <= C_BLANK;
                d4 <= C_BLANK;

            --------------------------------------------------------
            when ST_ALARM =>
                -- FAIL 정적 표시 (LED·Buzzer 와 동시 동작)
                -- 변형 옵션) 시도 횟수 표시:
                --   d1 <= C_F; d2 <= C_A;
                --   d3 <= "0000";
                --   d4 <= digit_data(3 downto 0);  -- fail_cnt
                d1 <= C_F;
                d2 <= C_A;
                d3 <= "0001";  -- 'I' 모양과 가장 비슷한 숫자 1 사용
                d4 <= C_L;

            --------------------------------------------------------
            when others =>
                -- 미정의 상태 → 빈 화면 (안전)
                d1 <= C_BLANK;
                d2 <= C_BLANK;
                d3 <= C_BLANK;
                d4 <= C_BLANK;
        end case;
    end process;

    -- 4자리를 16-bit 로 packing (Digit1=MSB, Digit4=LSB)
    disp_digits <= d1 & d2 & d3 & d4;

end architecture rtl;

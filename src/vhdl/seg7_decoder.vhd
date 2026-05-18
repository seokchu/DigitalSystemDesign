--------------------------------------------------------------------------------
-- 파일명   : seg7_decoder.vhd
-- 모듈명   : seg7_decoder
-- 작성자   : 장현석 (E)
-- 과목     : 디지털 시스템 설계 / 팀 프로젝트(디지털 도어락)
-- 보드     : HBE-Combo II-SE  (Altera Cyclone II EP2C8Q208C8)
-- 언어/툴  : VHDL-93 / Intel Quartus Prime
--
-- 기능 개요
--   4-bit 코드 입력을 받아 7-Segment (a~g) + dp 의 8-bit 패턴으로 변환.
--   Common Cathode 방식이므로 세그먼트는 active-high (1 = ON).
--
--   입력 코드 약속:
--     0x0~0x9 : 숫자 0~9
--     0xA     : '*' (마스킹, a~g 전체 점등)
--     0xB     : '-' (g 만 점등)
--     0xC     : ' ' (전체 OFF, 빈칸)
--     0xD     : 'F'
--     0xE     : 'A'
--     0xF     : 'L'
--
--   세그먼트 비트 순서:
--     seg_out(7)=a, (6)=b, (5)=c, (4)=d, (3)=e, (2)=f, (1)=g, (0)=dp
--
-- 전체 프로젝트에서의 위치
--   본 모듈은 fnd_driver.vhd 의 마지막 단(보드 핀 직전) 에 위치.
--   digit_scanner -> 4:1 MUX -> [seg7_decoder] -> fnd_seg(8) -> 보드 FND
--   4자리분의 디코더를 따로 두지 않고, 시분할로 디코더 1개를 공유함.
--
-- 합성 결과
--   순수 조합 회로. Quartus 가 LUT 1개 덩어리로 구현.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity seg7_decoder is
    port (
        digit_in : in  std_logic_vector(3 downto 0);  -- 4-bit 코드
        seg_out  : out std_logic_vector(7 downto 0)   -- a b c d e f g dp
    );
end entity seg7_decoder;

architecture rtl of seg7_decoder is
begin

    -- with-select : 조합 회로 LUT 한 덩어리로 합성
    -- 형식 = "abcdefg" + dp (MSB=a, LSB=dp)
    with digit_in select
        seg_out <=
            "11111100" when "0000",  -- 0
            "01100000" when "0001",  -- 1
            "11011010" when "0010",  -- 2
            "11110010" when "0011",  -- 3
            "01100110" when "0100",  -- 4
            "10110110" when "0101",  -- 5
            "10111110" when "0110",  -- 6
            "11100000" when "0111",  -- 7
            "11111110" when "1000",  -- 8
            "11110110" when "1001",  -- 9
            "11111110" when "1010",  -- '*' (마스킹) : 8과 형태는 같으나 의미 분리
            "00000010" when "1011",  -- '-' (g 만)
            "00000000" when "1100",  -- ' ' (빈칸)
            "10001110" when "1101",  -- 'F'
            "11101110" when "1110",  -- 'A'
            "00011100" when "1111",  -- 'L'
            "00000000" when others;  -- 안전망 (도달 불가)

end architecture rtl;

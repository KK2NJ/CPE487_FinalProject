library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity trig_lut is
    port (
        angle   : in  unsigned(7 downto 0);  -- 0..255 => 0..2π
        sin_out : out fixed_point;           -- Q16.16
        cos_out : out fixed_point            -- Q16.16
    );
end entity;

architecture rtl of trig_lut is
    type lut_array is array(0 to 64) of fixed_point;

    -- sin(i*2π/256) for i=0..64 (inclusive, so entry 64 = 1.0)
    constant SIN_QTR : lut_array := (
        0  => x"00000000",  1  => x"00000648",  2  => x"00000C90",  3  => x"000012D5",
        4  => x"00001918",  5  => x"00001F56",  6  => x"00002590",  7  => x"00002BC4",
        8  => x"000031F1",  9  => x"00003817", 10  => x"00003E34", 11  => x"00004447",
        12 => x"00004A50", 13 => x"0000504E", 14 => x"00005640", 15 => x"00005C25",
        16 => x"000061FC", 17 => x"000067C4", 18 => x"00006D7D", 19 => x"00007325",
        20 => x"000078BC", 21 => x"00007E41", 22 => x"000083B4", 23 => x"00008912",
        24 => x"00008E5D", 25 => x"00009392", 26 => x"000098B1", 27 => x"00009DB9",
        28 => x"0000A2AA", 29 => x"0000A783", 30 => x"0000AC43", 31 => x"0000B0E9",
        32 => x"0000B575", 33 => x"0000B9E7", 34 => x"0000BE3D", 35 => x"0000C277",
        36 => x"0000C696", 37 => x"0000CA96", 38 => x"0000CE79", 39 => x"0000D23E",
        40 => x"0000D5E4", 41 => x"0000D96A", 42 => x"0000DCD0", 43 => x"0000E015",
        44 => x"0000E338", 45 => x"0000E639", 46 => x"0000E918", 47 => x"0000EBD3",
        48 => x"0000EE6B", 49 => x"0000F0DE", 50 => x"0000F32D", 51 => x"0000F557",
        52 => x"0000F75B", 53 => x"0000F93A", 54 => x"0000FAF3", 55 => x"0000FC85",
        56 => x"0000FDF0", 57 => x"0000FF35", 58 => x"00010052", 59 => x"00010148",
        60 => x"00010216", 61 => x"000102BD", 62 => x"0001033C", 63 => x"00010393",
        64 => x"00010000"
    );

    function neg_fp(a : fixed_point) return fixed_point is
    begin
        return -a;
    end function;

    signal q   : unsigned(1 downto 0);
    signal idx : unsigned(5 downto 0);

    signal s0, c0 : fixed_point;
begin
    q   <= angle(7 downto 6);
    idx <= angle(5 downto 0);

    process(q, idx)
        variable i    : integer;
        variable im   : integer;
        variable sbase, cbase : fixed_point;
    begin
        i  := to_integer(idx);      -- 0..63
        im := 64 - i;               -- 64..1

        sbase := SIN_QTR(i);
        cbase := SIN_QTR(im);

        -- quadrant mapping
        case q is
            when "00" =>  -- 0..90
                s0 <= sbase;
                c0 <= cbase;
            when "01" =>  -- 90..180
                s0 <= cbase;
                c0 <= neg_fp(sbase);
            when "10" =>  -- 180..270
                s0 <= neg_fp(sbase);
                c0 <= neg_fp(cbase);
            when others => -- 270..360
                s0 <= neg_fp(cbase);
                c0 <= sbase;
        end case;
    end process;

    sin_out <= s0;
    cos_out <= c0;
end architecture;



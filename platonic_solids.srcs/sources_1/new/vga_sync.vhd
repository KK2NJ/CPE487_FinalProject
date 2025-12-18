library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_sync is
    port (
        pixel_clk : in  std_logic;

        red_in    : in  std_logic_vector(3 downto 0);
        green_in  : in  std_logic_vector(3 downto 0);
        blue_in   : in  std_logic_vector(3 downto 0);

        red_out   : out std_logic_vector(3 downto 0);
        green_out : out std_logic_vector(3 downto 0);
        blue_out  : out std_logic_vector(3 downto 0);

        hsync     : out std_logic;
        vsync     : out std_logic;

        pixel_row : out std_logic_vector(10 downto 0);
        pixel_col : out std_logic_vector(10 downto 0)
    );
end vga_sync;

architecture rtl of vga_sync is
    -- 800x600 @ 60Hz nominal timing
    constant H_ACTIVE : integer := 800;
    constant H_FP     : integer := 40;
    constant H_SYNC   : integer := 128;
    constant H_BP     : integer := 88;
    constant H_TOTAL  : integer := H_ACTIVE + H_FP + H_SYNC + H_BP; -- 1056

    constant V_ACTIVE : integer := 600;
    constant V_FP     : integer := 1;
    constant V_SYNC   : integer := 4;
    constant V_BP     : integer := 23;
    constant V_TOTAL  : integer := V_ACTIVE + V_FP + V_SYNC + V_BP; -- 628

    signal h_cnt : unsigned(10 downto 0) := (others => '0');
    signal v_cnt : unsigned(10 downto 0) := (others => '0');

    signal video_on : std_logic := '0';
begin

    process(pixel_clk)
    begin
        if rising_edge(pixel_clk) then
            -- horizontal counter
            if h_cnt = to_unsigned(H_TOTAL - 1, h_cnt'length) then
                h_cnt <= (others => '0');

                -- vertical counter increments at end of each line
                if v_cnt = to_unsigned(V_TOTAL - 1, v_cnt'length) then
                    v_cnt <= (others => '0');
                else
                    v_cnt <= v_cnt + 1;
                end if;

            else
                h_cnt <= h_cnt + 1;
            end if;

            -- HSYNC (active-low during sync pulse)
            if (to_integer(h_cnt) >= H_ACTIVE + H_FP) and (to_integer(h_cnt) < H_ACTIVE + H_FP + H_SYNC) then
                hsync <= '0';
            else
                hsync <= '1';
            end if;

            -- VSYNC (active-low during sync pulse)
            if (to_integer(v_cnt) >= V_ACTIVE + V_FP) and (to_integer(v_cnt) < V_ACTIVE + V_FP + V_SYNC) then
                vsync <= '0';
            else
                vsync <= '1';
            end if;

            -- video on only in active area
            if (to_integer(h_cnt) < H_ACTIVE) and (to_integer(v_cnt) < V_ACTIVE) then
                video_on <= '1';
            else
                video_on <= '0';
            end if;

            -- pixel coordinates (full counters)
            pixel_col <= std_logic_vector(h_cnt);
            pixel_row <= std_logic_vector(v_cnt);

            -- output RGB (blank during non-active)
            if video_on = '1' then
                red_out   <= red_in;
                green_out <= green_in;
                blue_out  <= blue_in;
            else
                red_out   <= (others => '0');
                green_out <= (others => '0');
                blue_out  <= (others => '0');
            end if;
        end if;
    end process;

end rtl;

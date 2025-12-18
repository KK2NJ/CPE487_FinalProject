library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity final_project_top is 
    port ( 
        clk_in    : in  std_logic; 
        btn0      : in  std_logic;
        btnl      : in  std_logic;
        btnr      : in  std_logic;

        VGA_red   : out std_logic_vector(3 downto 0); 
        VGA_green : out std_logic_vector(3 downto 0);
        VGA_blue  : out std_logic_vector(3 downto 0);
        VGA_hsync : out std_logic;
        VGA_vsync : out std_logic
    );
end entity;

architecture rtl of final_project_top is
    signal pxl_clk : std_logic;
    signal r_int, g_int, b_int : std_logic_vector(3 downto 0);
    signal row, col : std_logic_vector(10 downto 0);
    signal vs_int, hs_int : std_logic;
begin

    clk_gen : entity work.clk_wiz_0
        port map (clk_in1 => clk_in, clk_out1 => pxl_clk);

    engine : entity work.engine_3d
        port map (
            clk => pxl_clk,
            btn0 => btn0,
            btnl => btnl,
            btnr => btnr,
            vsync => vs_int,
            pixel_row => row,
            pixel_col => col,
            red_out => r_int,
            green_out => g_int,
            blue_out => b_int
        );

    vga : entity work.vga_sync
        port map (
            pixel_clk => pxl_clk,
            red_in => r_int,
            green_in => g_int,
            blue_in => b_int,
            red_out => VGA_red,
            green_out => VGA_green,
            blue_out => VGA_blue,
            pixel_row => row,
            pixel_col => col,
            hsync => hs_int,
            vsync => vs_int
        );

    VGA_hsync <= hs_int;
    VGA_vsync <= vs_int;

end architecture;

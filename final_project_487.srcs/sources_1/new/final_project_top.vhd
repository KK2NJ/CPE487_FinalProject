library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity final_project_top is 
    port ( 
        clk_in    : in  std_logic; -- 100 MHz clock 
        btn0      : in  std_logic;
        btnl      : in  std_logic;

        VGA_red   : out std_logic_vector(3 downto 0); -- VGA outputs
        VGA_green : out std_logic_vector(3 downto 0);
        VGA_blue  : out std_logic_vector(3 downto 0);
        VGA_hsync : out std_logic;
        VGA_vsync : out std_logic
    );
end entity final_project_top;

architecture rtl of final_project_top is

    --------------------------------------------------------------------
    -- Clocking
    --------------------------------------------------------------------
    signal pxl_clk : std_logic;

    --------------------------------------------------------------------
    -- Internal RGB before vga_sync blanking
    --------------------------------------------------------------------
    signal rgb_r_int : std_logic_vector(3 downto 0) := (others => '0');
    signal rgb_g_int : std_logic_vector(3 downto 0) := (others => '0');
    signal rgb_b_int : std_logic_vector(3 downto 0) := (others => '0');

    signal pixel_row_int : std_logic_vector(10 downto 0);
    signal pixel_col_int : std_logic_vector(10 downto 0);
    signal vsync_int     : std_logic;
    signal hsync_int     : std_logic;

begin

    --------------------------------------------------------------------
    -- 1) Clock wizard: generate pixel clock from 100 MHz
    --------------------------------------------------------------------
    clk_wiz_0_inst : entity work.clk_wiz_0
        port map (
            clk_in1  => clk_in,
            clk_out1 => pxl_clk
        );

    --------------------------------------------------------------------
    -- 2) VGA timing generator
    --------------------------------------------------------------------
    vga_driver : entity work.vga_sync
        port map (
            pixel_clk => pxl_clk, 
            red_in    => rgb_r_int, 
            green_in  => rgb_g_int, 
            blue_in   => rgb_b_int, 
            red_out   => VGA_red, 
            green_out => VGA_green, 
            blue_out  => VGA_blue, 
            pixel_row => pixel_row_int, 
            pixel_col => pixel_col_int, 
            hsync     => hsync_int, 
            vsync     => vsync_int
        );

    VGA_hsync <= hsync_int;
    VGA_vsync <= vsync_int;

    --------------------------------------------------------------------
    -- 3) Cube engine: decides pixel color
    --------------------------------------------------------------------
    cube_engine_inst : entity work.cube_engine_3d
        port map (
            clk        => pxl_clk,
            btn0    => btn0,
            btnl     => btnl,
            vsync      => vsync_int,
            pixel_row  => pixel_row_int,
            pixel_col  => pixel_col_int,
            red_out    => rgb_r_int,
            green_out  => rgb_g_int,
            blue_out   => rgb_b_int
        );

end architecture rtl;

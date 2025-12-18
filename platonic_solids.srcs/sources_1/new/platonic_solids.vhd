library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;


entity platonic_solids is 
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
end entity platonic_solids;

architecture rtl of platonic_solids is 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity mesh_rom is
    port (
        clk         : in  std_logic;
        tri_index   : in  unsigned(3 downto 0);  -- 0-11 for 12 triangles
        triangle_out: out triangle
    );
end entity mesh_rom;

architecture rtl of mesh_rom is
    -- Cube mesh data (12 triangles defining a unit cube)
    constant CUBE_MESH : mesh_array := (
        -- SOUTH face
        0  => ((to_fixed(0.0), to_fixed(0.0), to_fixed(0.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(0.0))),
        1  => ((to_fixed(0.0), to_fixed(0.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(0.0), to_fixed(0.0))),
        
        -- EAST face
        2  => ((to_fixed(1.0), to_fixed(0.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(1.0))),
        3  => ((to_fixed(1.0), to_fixed(0.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(1.0), to_fixed(0.0), to_fixed(1.0))),
        
        -- NORTH face
        4  => ((to_fixed(1.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(1.0))),
        5  => ((to_fixed(1.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(0.0), to_fixed(1.0))),
        
        -- WEST face
        6  => ((to_fixed(0.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(0.0))),
        7  => ((to_fixed(0.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(0.0), to_fixed(0.0), to_fixed(0.0))),
        
        -- TOP face
        8  => ((to_fixed(0.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(0.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(1.0))),
        9  => ((to_fixed(0.0), to_fixed(1.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(1.0)),
               (to_fixed(1.0), to_fixed(1.0), to_fixed(0.0))),
        
        -- BOTTOM face
        10 => ((to_fixed(1.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(0.0), to_fixed(0.0))),
        11 => ((to_fixed(1.0), to_fixed(0.0), to_fixed(1.0)),
               (to_fixed(0.0), to_fixed(0.0), to_fixed(0.0)),
               (to_fixed(1.0), to_fixed(0.0), to_fixed(0.0)))
    );
begin
    process(clk)
    begin
        if rising_edge(clk) then
            triangle_out <= CUBE_MESH(to_integer(tri_index));
        end if;
    end process;
end architecture rtl;
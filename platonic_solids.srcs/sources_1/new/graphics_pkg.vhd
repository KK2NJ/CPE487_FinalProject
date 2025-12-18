library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

package graphics_pkg is 
    subtype fixed_point is signed(31 downto 0);
    
    type vec3d is record -- 3d vector 
        x : fixed_point;
        y : fixed_point;
        z : fixed_point;
    end record;
    
    type triangle is record
        p0 : vec3d;
        p1 : vec3d;
        p2 : vec3d;
    end record;
    
    -- 4x4 Matrix (stored as array for easier indexing)
    type matrix4x4 is array(0 to 3, 0 to 3) of fixed_point;
    
      -- Cube mesh: 12 triangles
    type mesh_array is array(0 to 11) of triangle;
    
    --constants
    constant FIXED_ONE : fixed_point := x"00010000";  -- 1.0 in Q16.16
    constant FIXED_ZERO : fixed_point := x"00000000"; -- 0.0
    constant FIXED_HALF : fixed_point := x"00008000"; -- 0.5
    -- Screen dimensions
    constant SCREEN_WIDTH : integer := 800; 
    constant SCREEN_HEIGHT : integer := 600; 
    
    -- Functions
    function to_fixed(value : real) return fixed_point;
    function fixed_mult(a, b : fixed_point) return fixed_point;
    
end graphics_pkg;

package body graphics_pkg is 
    function to_fixed(value : real) return fixed_point is
    begin
        return to_signed(integer(value * 65536.0), 32);
    end function;
    
    function fixed_mult(a, b : fixed_point) return fixed_point is
        variable temp : signed(63 downto 0);
    begin
        temp := a * b;
        return temp(47 downto 16);  -- Keep Q16.16 format
    end function;
end package body graphics_pkg;
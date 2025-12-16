library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity rotation_matrix_gen is
    port (
        clk       : in  std_logic;
        theta     : in  unsigned(7 downto 0);  -- 0..255 angle
        mat_rot_z : out matrix4x4;
        mat_rot_x : out matrix4x4
    );
end entity rotation_matrix_gen;

architecture rtl of rotation_matrix_gen is

    signal sin_theta, cos_theta : fixed_point;
    signal sin_half,  cos_half  : fixed_point;

    signal theta_half : unsigned(7 downto 0);
begin
    -- θ/2 : shift right by 1
    theta_half <= '0' & theta(7 downto 1);

    -- Full angle trig (for Z rotation)
    trig_full : entity work.trig_lut
        port map (
            angle   => theta,
            sin_out => sin_theta,
            cos_out => cos_theta
        );

    -- Half angle trig (for X rotation)
    trig_half : entity work.trig_lut
        port map (
            angle   => theta_half,
            sin_out => sin_half,
            cos_out => cos_half
        );

    process(clk)
        variable mZ : matrix4x4;
        variable mX : matrix4x4;
    begin
        if rising_edge(clk) then
            -- default all zeros
            for r in 0 to 3 loop
                for c in 0 to 3 loop
                    mZ(r,c) := FIXED_ZERO;
                    mX(r,c) := FIXED_ZERO;
                end loop;
            end loop;

            ----------------------------------------------------------------
            -- Z rotation matrix (like Javidx9)
            -- x' =  x*cosθ - y*sinθ
            -- y' =  x*sinθ + y*cosθ
            -- z' =  z
            ----------------------------------------------------------------
            mZ(0,0) := cos_theta;   -- x' = cos*x + (-sin)*y
            mZ(1,0) := -sin_theta;

            mZ(0,1) := sin_theta;   -- y' = sin*x + cos*y
            mZ(1,1) := cos_theta;

            mZ(2,2) := FIXED_ONE;   -- z' = z
            mZ(3,3) := FIXED_ONE;   -- w = 1

            ----------------------------------------------------------------
            -- X rotation matrix (half angle)
            -- y' =  y*cosφ - z*sinφ
            -- z' =  y*sinφ + z*cosφ
            -- x' =  x
            ----------------------------------------------------------------
            mX(0,0) := FIXED_ONE;   -- x' = x

            mX(1,1) := cos_half;    -- y' = cos*y + (-sin)*z
            mX(2,1) := -sin_half;

            mX(1,2) := sin_half;    -- z' = sin*y + cos*z
            mX(2,2) := cos_half;

            mX(3,3) := FIXED_ONE;

            mat_rot_z <= mZ;
            mat_rot_x <= mX;
        end if;
    end process;

end architecture rtl;

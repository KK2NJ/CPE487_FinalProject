library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity rotation_matrix_gen is
    port (
        clk         : in  std_logic;
        theta       : in  unsigned(7 downto 0);
        mat_rot_z   : out matrix4x4;
        mat_rot_x   : out matrix4x4
    );
end entity rotation_matrix_gen;

architecture rtl of rotation_matrix_gen is
    signal sin_theta, cos_theta : fixed_point;
    signal sin_half, cos_half : fixed_point;
    signal theta_half : unsigned(7 downto 0);
begin
    theta_half <= '0' & theta(7 downto 1);  -- theta * 0.5
    
    trig_full: entity work.trig_lut
        port map(angle => theta,
                 sin_out => sin_theta,
                 cos_out => cos_theta);
    
    trig_half: entity work.trig_lut
        port map(angle => theta,
                 sin_out => sin_theta,
                 cos_out => cos_theta);
    
    process(clk)
    begin
        if rising_edge(clk) then
            -- Z-axis rotation matrix
            mat_rot_z(0,0) <= cos_theta;
            mat_rot_z(0,1) <= sin_theta;
            mat_rot_z(0,2) <= FIXED_ZERO;
            mat_rot_z(0,3) <= FIXED_ZERO;
            
            mat_rot_z(1,0) <= -sin_theta;
            mat_rot_z(1,1) <= cos_theta;
            mat_rot_z(1,2) <= FIXED_ZERO;
            mat_rot_z(1,3) <= FIXED_ZERO;
            
            mat_rot_z(2,2) <= FIXED_ONE;
            mat_rot_z(3,3) <= FIXED_ONE;
            
            -- X-axis rotation matrix
            mat_rot_x(0,0) <= FIXED_ONE;
            
            mat_rot_x(1,1) <= cos_half;
            mat_rot_x(1,2) <= sin_half;
            mat_rot_x(1,3) <= FIXED_ZERO;
            
            mat_rot_x(2,1) <= -sin_half;
            mat_rot_x(2,2) <= cos_half;
            mat_rot_x(2,3) <= FIXED_ZERO;
            
            mat_rot_x(3,3) <= FIXED_ONE;
        end if;
    end process;
end architecture rtl;

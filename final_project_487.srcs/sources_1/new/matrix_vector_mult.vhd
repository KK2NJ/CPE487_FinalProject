library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity matrix_vector_mult is
    port (
        clk     : in  std_logic;
        reset   : in  std_logic;
        enable  : in  std_logic;

        matrix  : in  matrix4x4;
        vec_in  : in  vec3d;

        vec_out : out vec3d;
        w_out   : out fixed_point;
        valid   : out std_logic
    );
end entity matrix_vector_mult;

architecture rtl of matrix_vector_mult is
begin
    process(clk)
        variable dot_x, dot_y, dot_z, dot_w : signed(63 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                vec_out <= (x => FIXED_ZERO, y => FIXED_ZERO, z => FIXED_ZERO);
                w_out   <= FIXED_ZERO;
                valid   <= '0';
            elsif enable = '1' then
                -- X component
                dot_x := (matrix(0,0) * vec_in.x) +
                         (matrix(1,0) * vec_in.y) +
                         (matrix(2,0) * vec_in.z) +
                         (matrix(3,0) * FIXED_ONE);

                -- Y component
                dot_y := (matrix(0,1) * vec_in.x) +
                         (matrix(1,1) * vec_in.y) +
                         (matrix(2,1) * vec_in.z) +
                         (matrix(3,1) * FIXED_ONE);

                -- Z component
                dot_z := (matrix(0,2) * vec_in.x) +
                         (matrix(1,2) * vec_in.y) +
                         (matrix(2,2) * vec_in.z) +
                         (matrix(3,2) * FIXED_ONE);

                -- W component
                dot_w := (matrix(0,3) * vec_in.x) +
                         (matrix(1,3) * vec_in.y) +
                         (matrix(2,3) * vec_in.z) +
                         (matrix(3,3) * FIXED_ONE);

                -- Convert back to Q16.16
                vec_out.x <= dot_x(47 downto 16);
                vec_out.y <= dot_y(47 downto 16);
                vec_out.z <= dot_z(47 downto 16);
                w_out     <= dot_w(47 downto 16);

                valid <= '1';
            else
                valid <= '0';
            end if;
        end if;
    end process;

end architecture rtl;

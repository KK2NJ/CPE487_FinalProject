library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity cube_engine_3d is
    port (
        clk       : in  std_logic;                          -- pixel clock
        vsync     : in  std_logic;                          -- from vga_sync (active-low pulse)
        btn0      : in  std_logic;                          -- reset -> black
        btnl      : in  std_logic;                          -- start/resume
        pixel_row : in  std_logic_vector(10 downto 0);      -- from vga_sync
        pixel_col : in  std_logic_vector(10 downto 0);      -- from vga_sync
        red_out   : out std_logic_vector(3 downto 0);
        green_out : out std_logic_vector(3 downto 0);
        blue_out  : out std_logic_vector(3 downto 0)
    );
end entity cube_engine_3d;

architecture rtl of cube_engine_3d is

    type point2d is record
        x : integer;
        y : integer;
    end record;

    type point_array is array(0 to 7) of point2d;

    type edge is record
        p0 : integer range 0 to 7;
        p1 : integer range 0 to 7;
    end record;

    type edge_array is array(0 to 11) of edge;

    type vertex3d_array is array(0 to 7) of vec3d;

    constant CUBE_VERTICES_3D : vertex3d_array := (
        0 => (x => to_fixed(-0.5), y => to_fixed(-0.5), z => to_fixed(-0.5)),
        1 => (x => to_fixed( 0.5), y => to_fixed(-0.5), z => to_fixed(-0.5)),
        2 => (x => to_fixed( 0.5), y => to_fixed( 0.5), z => to_fixed(-0.5)),
        3 => (x => to_fixed(-0.5), y => to_fixed( 0.5), z => to_fixed(-0.5)),
        4 => (x => to_fixed(-0.5), y => to_fixed(-0.5), z => to_fixed( 0.5)),
        5 => (x => to_fixed( 0.5), y => to_fixed(-0.5), z => to_fixed( 0.5)),
        6 => (x => to_fixed( 0.5), y => to_fixed( 0.5), z => to_fixed( 0.5)),
        7 => (x => to_fixed(-0.5), y => to_fixed( 0.5), z => to_fixed( 0.5))
    );

    constant CUBE_EDGES : edge_array := (
        0  => (p0 => 0, p1 => 1),
        1  => (p0 => 1, p1 => 2),
        2  => (p0 => 2, p1 => 3),
        3  => (p0 => 3, p1 => 0),
        4  => (p0 => 4, p1 => 5),
        5  => (p0 => 5, p1 => 6),
        6  => (p0 => 6, p1 => 7),
        7  => (p0 => 7, p1 => 4),
        8  => (p0 => 0, p1 => 4),
        9  => (p0 => 1, p1 => 5),
        10 => (p0 => 2, p1 => 6),
        11 => (p0 => 3, p1 => 7)
    );

    signal cube_points : point_array := (others => (
        x => SCREEN_WIDTH/2,
        y => SCREEN_HEIGHT/2
    ));

    signal theta      : unsigned(7 downto 0) := (others => '0');
    signal sin_theta  : fixed_point;
    signal cos_theta  : fixed_point;

    constant Z_OFFSET     : integer := 6;
    constant Z_OFFSET_Q16 : integer := Z_OFFSET * 65536;
    constant Z_MIN_Q16    : integer := 2 * 65536;

    constant PERSCALE     : integer := 450;

    signal running    : std_logic := '0';
    signal btnl_prev  : std_logic := '0';
    signal vsync_prev : std_logic := '1';

    function abs_int(val : integer) return integer is
    begin
        if val < 0 then return -val; else return val; end if;
    end function;

    function edge_fn(x0, y0, x1, y1, x, y : integer) return integer is
    begin
        return (x - x0) * (y1 - y0) - (y - y0) * (x1 - x0);
    end function;

begin

    trig_inst : entity work.trig_lut
        port map (
            angle   => theta,
            sin_out => sin_theta,
            cos_out => cos_theta
        );

    transform_proc : process(clk)
        variable x_fp, y_fp, z_fp : fixed_point;
        variable x_rot, y_rot, z_rot : fixed_point;

        variable x_q16, y_q16, z_q16 : integer;
        variable x_num, y_num        : integer;
        variable z_den               : integer;

        variable sx_int, sy_int : integer;
    begin
        if rising_edge(clk) then
            btnl_prev  <= btnl;
            vsync_prev <= vsync;

            if btn0 = '1' then
                running <= '0';
                theta   <= (others => '0');

            else
                if (btnl = '1' and btnl_prev = '0') then
                    running <= '1';
                end if;

                -- update once per frame on vsync 0->1 edge
                if (running = '1') and (vsync = '1' and vsync_prev = '0') then

                    for i in 0 to 7 loop
                        x_fp := CUBE_VERTICES_3D(i).x;
                        y_fp := CUBE_VERTICES_3D(i).y;
                        z_fp := CUBE_VERTICES_3D(i).z;

                        -- rotate around Y
                        x_rot := fixed_mult(x_fp, cos_theta) + fixed_mult(z_fp, sin_theta);
                        z_rot := fixed_mult(z_fp, cos_theta) - fixed_mult(x_fp, sin_theta);
                        y_rot := y_fp;

                        -- keep FULL Q16.16 integer values
                        x_q16 := to_integer(x_rot);
                        y_q16 := to_integer(y_rot);
                        z_q16 := to_integer(z_rot);

                        z_den := z_q16 + Z_OFFSET_Q16;
                        if z_den < Z_MIN_Q16 then
                            z_den := Z_MIN_Q16;
                        end if;

                        x_num := x_q16 * PERSCALE;
                        y_num := y_q16 * PERSCALE;

                        sx_int := (SCREEN_WIDTH  / 2) + (x_num / z_den);
                        sy_int := (SCREEN_HEIGHT / 2) - (y_num / z_den);

                        cube_points(i).x <= sx_int;
                        cube_points(i).y <= sy_int;
                    end loop;

                    theta <= theta + 1;
                end if;
            end if;
        end if;
    end process;

    pixel_proc : process(clk)
        variable x, y    : integer;
        variable on_edge : boolean;

        constant EDGE_PIX_TOL : integer := 2;

        variable x0, y0, x1, y1 : integer;
        variable xmin, xmax, ymin, ymax : integer;

        variable w, dx, dy, len : integer;
    begin
        if rising_edge(clk) then
            x := to_integer(unsigned(pixel_col));
            y := to_integer(unsigned(pixel_row));

            if running = '0' then
                red_out   <= (others => '0');
                green_out <= (others => '0');
                blue_out  <= (others => '0');
            else
                on_edge := false;

                for i in 0 to 11 loop
                    x0 := cube_points(CUBE_EDGES(i).p0).x;
                    y0 := cube_points(CUBE_EDGES(i).p0).y;
                    x1 := cube_points(CUBE_EDGES(i).p1).x;
                    y1 := cube_points(CUBE_EDGES(i).p1).y;

                    if x0 < x1 then xmin := x0; xmax := x1; else xmin := x1; xmax := x0; end if;
                    if y0 < y1 then ymin := y0; ymax := y1; else ymin := y1; ymax := y0; end if;

                    if (x >= xmin - 2 and x <= xmax + 2) and
                       (y >= ymin - 2 and y <= ymax + 2) then

                        dx  := x1 - x0;
                        dy  := y1 - y0;
                        len := abs_int(dx) + abs_int(dy);

                        if len > 0 then
                            w := edge_fn(x0, y0, x1, y1, x, y);
                            if abs_int(w) <= EDGE_PIX_TOL * len then
                                on_edge := true;
                            end if;
                        end if;
                    end if;
                end loop;

                if on_edge then
                    red_out   <= "1111";
                    green_out <= "1111";
                    blue_out  <= "1111";
                else
                    red_out   <= (others => '0');
                    green_out <= (others => '0');
                    blue_out  <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture rtl;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity cube_engine_3d is
    port (
        clk        : in  std_logic;
        btn0       : in  std_logic;  -- reset button: stop & clear
        btnl       : in  std_logic;  -- enable: start cube

        vsync      : in  std_logic;  -- from vga_sync
        pixel_row  : in  std_logic_vector(10 downto 0);
        pixel_col  : in  std_logic_vector(10 downto 0);

        red_out    : out std_logic_vector(3 downto 0);
        green_out  : out std_logic_vector(3 downto 0);
        blue_out   : out std_logic_vector(3 downto 0)
    );
end entity cube_engine_3d;

architecture rtl of cube_engine_3d is

    --------------------------------------------------------------------
    -- 2D types: projected points + edges
    --------------------------------------------------------------------
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

    --------------------------------------------------------------------
    -- 3D cube vertices in model space (Q16.16)
    -- Cube from (-1,-1,-1) to (1,1,1)
    --------------------------------------------------------------------
    type vertex3d_array is array(0 to 7) of vec3d;

    constant CUBE_VERTICES_3D : vertex3d_array := (
        0 => (x => to_fixed(-1.0), y => to_fixed(-1.0), z => to_fixed(-1.0)),
        1 => (x => to_fixed( 1.0), y => to_fixed(-1.0), z => to_fixed(-1.0)),
        2 => (x => to_fixed( 1.0), y => to_fixed( 1.0), z => to_fixed(-1.0)),
        3 => (x => to_fixed(-1.0), y => to_fixed( 1.0), z => to_fixed(-1.0)),
        4 => (x => to_fixed(-1.0), y => to_fixed(-1.0), z => to_fixed( 1.0)),
        5 => (x => to_fixed( 1.0), y => to_fixed(-1.0), z => to_fixed( 1.0)),
        6 => (x => to_fixed( 1.0), y => to_fixed( 1.0), z => to_fixed( 1.0)),
        7 => (x => to_fixed(-1.0), y => to_fixed( 1.0), z => to_fixed( 1.0))
    );

    --------------------------------------------------------------------
    -- Cube edges (12 segments) using vertex indices
    --------------------------------------------------------------------
    constant cube_edges : edge_array := (
        -- Back face
        0  => (p0 => 0, p1 => 1),
        1  => (p0 => 1, p1 => 2),
        2  => (p0 => 2, p1 => 3),
        3  => (p0 => 3, p1 => 0),

        -- Front face
        4  => (p0 => 4, p1 => 5),
        5  => (p0 => 5, p1 => 6),
        6  => (p0 => 6, p1 => 7),
        7  => (p0 => 7, p1 => 4),

        -- Connecting edges
        8  => (p0 => 0, p1 => 4),
        9  => (p0 => 1, p1 => 5),
        10 => (p0 => 2, p1 => 6),
        11 => (p0 => 3, p1 => 7)
    );

    --------------------------------------------------------------------
    -- Projected 2D vertex positions (updated once per frame)
    --------------------------------------------------------------------
    signal cube_points : point_array := (others => (x => 0, y => 0));

    --------------------------------------------------------------------
    -- Projection & depth constants
    --------------------------------------------------------------------
    constant Z_OFFSET  : integer := 5;    -- move cube in front of camera
    constant PERSCALE  : integer := 300;  -- perspective scale factor

    --------------------------------------------------------------------
    -- Utility functions
    --------------------------------------------------------------------
    function edge_fn(x0, y0, x1, y1, x, y : integer) return integer is
    begin
        return (x - x0) * (y1 - y0) - (y - y0) * (x1 - x0);
    end function;

    function abs_int(val : integer) return integer is
    begin
        if val < 0 then
            return -val;
        else
            return val;
        end if;
    end function;

    --------------------------------------------------------------------
    -- Rotation angle & trig LUT
    --------------------------------------------------------------------
    signal theta     : unsigned(7 downto 0) := (others => '0'); -- 0..255
    signal sin_theta : fixed_point;
    signal cos_theta : fixed_point;

    --------------------------------------------------------------------
    -- Buttons / control
    --------------------------------------------------------------------
    signal running    : std_logic := '0';
    signal btnl_prev  : std_logic := '0';
    signal vsync_prev : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Trig lookup (angle in 0..255 -> sin/cos in Q16.16)
    --------------------------------------------------------------------
    trig_inst : entity work.trig_lut
        port map (
            angle   => theta,
            sin_out => sin_theta,
            cos_out => cos_theta
        );

    --------------------------------------------------------------------
    -- Control + per-frame 3D rotation + perspective projection
    --------------------------------------------------------------------
    ctrl_proc : process(clk)
        variable x_fp, y_fp, z_fp     : fixed_point;
        variable x_rot, y_rot, z_rot  : fixed_point;
        variable xr_i, yr_i, zr_i     : integer;
        variable z_cam_i              : integer;
        variable sx_int, sy_int       : integer;
        variable tmpx, tmpy           : integer;
    begin
        if rising_edge(clk) then
            -- Track for edge detection and frame sync
            btnl_prev  <= btnl;
            vsync_prev <= vsync;

            -- Button control
            if btn0 = '1' then
                running <= '0';
            else
                if (btnl = '1' and btnl_prev = '0') then
                    running <= '1';
                end if;
            end if;

            -- On each new frame (vsync rising edge) update cube vertices
            if running = '1' and vsync_prev = '0' and vsync = '1' then

                for i in 0 to 7 loop
                    x_fp := CUBE_VERTICES_3D(i).x;
                    y_fp := CUBE_VERTICES_3D(i).y;
                    z_fp := CUBE_VERTICES_3D(i).z;

                    -- Rotate around Y:
                    -- x' =  x*cosθ + z*sinθ
                    -- z' =  z*cosθ - x*sinθ
                    -- y' =  y
                    x_rot := fixed_mult(x_fp, cos_theta) + fixed_mult(z_fp, sin_theta);
                    z_rot := fixed_mult(z_fp, cos_theta) - fixed_mult(x_fp, sin_theta);
                    y_rot := y_fp;

                    -- Convert Q16.16 -> integer (just take high 16 bits)
                    xr_i := to_integer(signed(x_rot(31 downto 16)));
                    yr_i := to_integer(signed(y_rot(31 downto 16)));
                    zr_i := to_integer(signed(z_rot(31 downto 16)));

                    -- Move cube away from camera to avoid z <= 0
                    z_cam_i := zr_i + Z_OFFSET;
                    if z_cam_i < 1 then
                        z_cam_i := 1;  -- avoid division by zero
                    end if;

                    -- Perspective projection:
                    -- sx = cx + (xr_i * PERSCALE) / z_cam_i
                    -- sy = cy - (yr_i * PERSCALE) / z_cam_i
                    tmpx  := xr_i * PERSCALE;
                    tmpy  := yr_i * PERSCALE;
                    sx_int := (SCREEN_WIDTH  / 2) + (tmpx / z_cam_i);
                    sy_int := (SCREEN_HEIGHT / 2) - (tmpy / z_cam_i);

                    cube_points(i).x <= sx_int;
                    cube_points(i).y <= sy_int;
                end loop;

                -- advance angle for next frame
                theta <= theta + 1;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Pixel generator: draw only cube edges (wireframe)
    --------------------------------------------------------------------
    pixel_proc : process(clk)
        variable x       : integer;
        variable y       : integer;
        variable w       : integer;
        variable on_edge : boolean;
        constant EDGE_TOL : integer := 400;  -- line thickness band
        variable x0, y0, x1, y1 : integer;
        variable xmin, xmax, ymin, ymax : integer;
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

                -- Check for proximity to any of the 12 edges
                for i in 0 to 11 loop
                    x0 := cube_points(cube_edges(i).p0).x;
                    y0 := cube_points(cube_edges(i).p0).y;
                    x1 := cube_points(cube_edges(i).p1).x;
                    y1 := cube_points(cube_edges(i).p1).y;

                    -- bounding box reject first
                    if x0 < x1 then
                        xmin := x0;
                        xmax := x1;
                    else
                        xmin := x1;
                        xmax := x0;
                    end if;

                    if y0 < y1 then
                        ymin := y0;
                        ymax := y1;
                    else
                        ymin := y1;
                        ymax := y0;
                    end if;

                    if (x >= xmin - 1 and x <= xmax + 1) and
                       (y >= ymin - 1 and y <= ymax + 1) then

                        -- distance-like measure via edge function
                        w := edge_fn(x0, y0, x1, y1, x, y);

                        if abs_int(w) <= EDGE_TOL then
                            on_edge := true;
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

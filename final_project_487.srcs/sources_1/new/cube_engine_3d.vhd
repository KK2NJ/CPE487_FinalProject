library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;  -- make sure package is named graphic_pkg

entity cube_engine_3d is
    port (
        clk        : in  std_logic;
        btn0       : in  std_logic;  -- reset button: clears & stops drawing
        btnl       : in  std_logic;  -- enable/start button

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
    -- 2D structures for projected vertices + edges
    --------------------------------------------------------------------
    type point2d is record
        x : integer;
        y : integer;
    end record;

    type point_array is array(0 to 7) of point2d;

    type edge is record
        p0 : integer range 0 to 7;  -- index into point array
        p1 : integer range 0 to 7;
    end record;

    type edge_array is array(0 to 11) of edge;

    --------------------------------------------------------------------
    -- 3D cube in model space, Q16.16 (vec3d is from graphic_pkg)
    -- Unit cube from (-1,-1,-1) to (1,1,1)
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
    -- Edges of the cube (12 edges)
    --------------------------------------------------------------------
    constant cube_edges : edge_array := (
        -- Back square
        0  => (p0 => 0, p1 => 1),
        1  => (p0 => 1, p1 => 2),
        2  => (p0 => 2, p1 => 3),
        3  => (p0 => 3, p1 => 0),

        -- Front square
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
    -- Dynamic 2D projected points (updated once per frame)
    --------------------------------------------------------------------
    signal cube_points : point_array := (
        others => (x => 0, y => 0)
    );

    --------------------------------------------------------------------
    -- Scale factor from world units to pixels (orthographic projection)
    --------------------------------------------------------------------
    constant SCALE : fixed_point := to_fixed(150.0);  -- ~150 px per unit

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
    -- Rotation angle + trig LUT
    --------------------------------------------------------------------
    signal theta     : unsigned(7 downto 0) := (others => '0'); -- 0..255
    signal sin_theta : fixed_point;
    signal cos_theta : fixed_point;

    --------------------------------------------------------------------
    -- Button / control signals
    --------------------------------------------------------------------
    signal running    : std_logic := '0';
    signal btnl_prev  : std_logic := '0';
    signal vsync_prev : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Trig LUT: maps angle index (0..255) to sin/cos in Q16.16
    --------------------------------------------------------------------
    trig_inst : entity work.trig_lut
        port map (
            angle   => theta,
            sin_out => sin_theta,
            cos_out => cos_theta
        );

    --------------------------------------------------------------------
    -- Control + per-frame vertex update
    --  - btn0 = reset: stop drawing
    --  - btnl rising edge: start drawing
    --  - On rising edge of vsync while running: rotate & project cube
    --------------------------------------------------------------------
    ctrl_proc : process(clk)
        variable x, y, z      : fixed_point;
        variable x_rot, y_rot : fixed_point;
        variable z_rot        : fixed_point;
        variable sx_fp, sy_fp : fixed_point;
        variable sx_int       : integer;
        variable sy_int       : integer;
    begin
        if rising_edge(clk) then
            -- Track previous button and vsync states
            btnl_prev  <= btnl;
            vsync_prev <= vsync;

            -- Button control
            if btn0 = '1' then
                running <= '0';
            else
                -- start on rising edge of btnl
                if (btnl = '1' and btnl_prev = '0') then
                    running <= '1';
                end if;
            end if;

            -- Per-frame update on rising edge of vsync
            if running = '1' and vsync_prev = '0' and vsync = '1' then
                -- For each vertex: rotate around Y, then project orthographically
                for i in 0 to 7 loop
                    x := CUBE_VERTICES_3D(i).x;
                    y := CUBE_VERTICES_3D(i).y;
                    z := CUBE_VERTICES_3D(i).z;

                    -- Y-axis rotation:
                    -- x' =  x*cosθ + z*sinθ
                    -- z' = -x*sinθ + z*cosθ
                    -- y' =  y
                    x_rot := fixed_mult(x, cos_theta) + fixed_mult(z, sin_theta);
                    z_rot := fixed_mult(z, cos_theta) - fixed_mult(x, sin_theta);
                    y_rot := y;

                    -- Orthographic projection with scaling
                    sx_fp := fixed_mult(x_rot, SCALE);
                    sy_fp := fixed_mult(y_rot, SCALE);

                    -- Convert from Q16.16 to integer, center on screen
                    sx_int := SCREEN_WIDTH / 2  + to_integer(signed(sx_fp(31 downto 16)));
                    sy_int := SCREEN_HEIGHT / 2 - to_integer(signed(sy_fp(31 downto 16)));

                    cube_points(i).x <= sx_int;
                    cube_points(i).y <= sy_int;
                end loop;

                -- Advance angle for next frame
                theta <= theta + 1;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Pixel generator: wireframe cube
    -- For each pixel:
    --   - if running = 0 -> black
    --   - else, if near any edge -> white; otherwise black
    --------------------------------------------------------------------
    pixel_proc : process(clk)
        variable x       : integer;
        variable y       : integer;
        variable w       : integer;
        variable on_edge : boolean;
        constant EDGE_TOL : integer := 400;  -- band thickness around line
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

                -- Test against all 12 cube edges
                for i in 0 to 11 loop
                    x0 := cube_points(cube_edges(i).p0).x;
                    y0 := cube_points(cube_edges(i).p0).y;
                    x1 := cube_points(cube_edges(i).p1).x;
                    y1 := cube_points(cube_edges(i).p1).y;

                    -- Quick bounding box rejection
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

                        -- Distance-ish measure via edge function
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

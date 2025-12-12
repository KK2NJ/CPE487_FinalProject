library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphic_pkg.all;

entity cube_engine_3d is
    port (
        clk        : in  std_logic;
        btn0       : in  std_logic;  -- reset button: clears & stops drawing
        btnl       : in  std_logic;  -- enable/start drawing

        vsync      : in  std_logic;  -- reserved for future frame-sync
        pixel_row  : in  std_logic_vector(10 downto 0);
        pixel_col  : in  std_logic_vector(10 downto 0);

        red_out    : out std_logic_vector(3 downto 0);
        green_out  : out std_logic_vector(3 downto 0);
        blue_out   : out std_logic_vector(3 downto 0)
    );
end entity cube_engine_3d;

architecture rtl of cube_engine_3d is

    --------------------------------------------------------------------
    -- 2D point and edge types
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
    -- Cube corners (2D projection for now, static)
    -- Back square:
    --   A  = (300,150)  (0)
    --   B  = (500,150)  (1)
    --   C  = (500,350)  (2)
    --   D  = (300,350)  (3)
    --
    -- Front square:
    --   A' = (350,200)  (4)
    --   B' = (550,200)  (5)
    --   C' = (550,400)  (6)
    --   D' = (350,400)  (7)
    --------------------------------------------------------------------
    constant cube_points : point_array := (
        0 => (x => 300, y => 150),  -- A
        1 => (x => 500, y => 150),  -- B
        2 => (x => 500, y => 350),  -- C
        3 => (x => 300, y => 350),  -- D
        4 => (x => 350, y => 200),  -- A'
        5 => (x => 550, y => 200),  -- B'
        6 => (x => 550, y => 400),  -- C'
        7 => (x => 350, y => 400)   -- D'
    );

    --------------------------------------------------------------------
    -- Cube edges: 12 line segments
    --------------------------------------------------------------------
    constant cube_edges : edge_array := (
        -- Back square edges
        0  => (p0 => 0, p1 => 1),   -- A-B
        1  => (p0 => 1, p1 => 2),   -- B-C
        2  => (p0 => 2, p1 => 3),   -- C-D
        3  => (p0 => 3, p1 => 0),   -- D-A

        -- Front square edges
        4  => (p0 => 4, p1 => 5),   -- A'-B'
        5  => (p0 => 5, p1 => 6),   -- B'-C'
        6  => (p0 => 6, p1 => 7),   -- C'-D'
        7  => (p0 => 7, p1 => 4),   -- D'-A'

        -- Connecting edges between back and front
        8  => (p0 => 0, p1 => 4),   -- A-A'
        9  => (p0 => 1, p1 => 5),   -- B-B'
        10 => (p0 => 2, p1 => 6),   -- C-C'
        11 => (p0 => 3, p1 => 7)    -- D-D'
    );

    --------------------------------------------------------------------
    -- Edge function (same as before, but now used to decide if pixel is
    -- near a line, not inside a triangle)
    --------------------------------------------------------------------
    function edge_fn(x0, y0, x1, y1, x, y : integer) return integer is
    begin
        return (x - x0) * (y1 - y0) - (y - y0) * (x1 - x0);
    end function;

    --------------------------------------------------------------------
    -- Simple absolute value for integers
    --------------------------------------------------------------------
    function abs_int(val : integer) return integer is
    begin
        if val < 0 then
            return -val;
        else
            return val;
        end if;
    end function;

    --------------------------------------------------------------------
    -- Control: running flag and btnl edge detection
    --------------------------------------------------------------------
    signal running   : std_logic := '0';
    signal btnl_prev : std_logic := '0';

begin

    --------------------------------------------------------------------
    -- Button control
    --  btn0 = 1 -> reset: stop drawing (screen black)
    --  btnl rising edge -> start drawing cube
    --------------------------------------------------------------------
    ctrl_proc : process(clk)
    begin
        if rising_edge(clk) then
            btnl_prev <= btnl;

            if btn0 = '1' then
                running <= '0';
            else
                if (btnl = '1' and btnl_prev = '0') then
                    running <= '1';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Pixel generator: wireframe cube
    -- For each pixel:
    --   - if running = 0 -> black
    --   - else, if pixel is near ANY edge -> white
    --          otherwise -> black
    --------------------------------------------------------------------
    pixel_proc : process(clk)
        variable x       : integer;
        variable y       : integer;
        variable w       : integer;
        variable on_edge : boolean;
        constant EDGE_TOL : integer := 400;  -- thickness of line band
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

                -- Test against all 12 edges
                for i in 0 to 11 loop
                    x0 := cube_points(cube_edges(i).p0).x;
                    y0 := cube_points(cube_edges(i).p0).y;
                    x1 := cube_points(cube_edges(i).p1).x;
                    y1 := cube_points(cube_edges(i).p1).y;

                    -- Quick bounding box check so we don't light pixels
                    -- far away from this segment even if w is small
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

                        -- Signed area-style distance to line
                        w := edge_fn(x0, y0, x1, y1, x, y);

                        -- If it's close to the line (within tolerance),
                        -- mark this pixel as "on edge"
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



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity engine_3d is
    port (
        clk         : in  std_logic;
        btn0        : in  std_logic; -- Start/Pause (pause also clears to black)
        btnl        : in  std_logic; -- Next solid (press)
        btnr        : in  std_logic; -- Reset solid to tetra (press)
        vsync       : in  std_logic;
        pixel_row   : in  std_logic_vector(10 downto 0);
        pixel_col   : in  std_logic_vector(10 downto 0);
        red_out     : out std_logic_vector(3 downto 0);
        green_out   : out std_logic_vector(3 downto 0);
        blue_out    : out std_logic_vector(3 downto 0)
    );
end entity;

architecture rtl of engine_3d is

    --------------------------------------------------------------------
    -- Framebuffer: 160x120 (maps cleanly to 800x600 by /5)
    --------------------------------------------------------------------
    constant FB_W : integer := 160;
    constant FB_H : integer := 120;
    constant FB_SIZE : integer := FB_W * FB_H;

    type ram_type is array (0 to FB_SIZE-1) of std_logic;
    signal video_ram : ram_type := (others => '0');

    --------------------------------------------------------------------
    -- Solids + ROM
    --------------------------------------------------------------------
    signal solid_id : unsigned(2 downto 0) := (others => '0'); -- 0 tetra .. 4 icosa
    signal edge_idx : unsigned(5 downto 0) := (others => '0');
    signal num_edges : unsigned(5 downto 0);

    signal v0_3d, v1_3d : vec3d;

--    rom_inst : entity work.platonic_rom
--        port map (
--            solid_id   => solid_id,
--            edge_index => edge_idx,
--            v0         => v0_3d,
--            v1         => v1_3d,
--            num_edges  => num_edges
--        );

    --------------------------------------------------------------------
    -- Rotation (two LUTs: Z uses angle, X uses angle/2)
    --------------------------------------------------------------------
    signal angle      : unsigned(7 downto 0) := (others => '0');
    signal angle_half : unsigned(7 downto 0);

    signal sin_z, cos_z : fixed_point;
    signal sin_x, cos_x : fixed_point;

--    angle_half <= '0' & angle(7 downto 1);

--    lut_z : entity work.trig_lut
--        port map (angle => angle, sin_out => sin_z, cos_out => cos_z);

--    lut_x : entity work.trig_lut
--        port map (angle => angle_half, sin_out => sin_x, cos_out => cos_x);

    --------------------------------------------------------------------
    -- VSYNC start-of-frame detect
    --------------------------------------------------------------------
    signal prev_vsync  : std_logic := '0';
    signal start_frame : std_logic := '0';

    --------------------------------------------------------------------
    -- Buttons edge-detect
    --------------------------------------------------------------------
    signal prev_btn0, prev_btnl, prev_btnr : std_logic := '0';
    signal btn0_rise, btnl_rise, btnr_rise : std_logic := '0';

    signal run_en : std_logic := '1';  -- start running by default

    --------------------------------------------------------------------
    -- Bresenham engine (robust all-octants)
    --------------------------------------------------------------------
    type state_type is (IDLE, CLEAR_RAM, LOAD_EDGE, CALC_EDGE, INIT_LINE, STEP_LINE, NEXT_EDGE, WAIT_FRAME);
    signal state : state_type := IDLE;

    signal clear_addr : integer range 0 to FB_SIZE-1 := 0;

    signal bx0, by0, bx1, by1 : integer := 0;
    signal cur_x, cur_y       : integer := 0;

    signal line_dx  : integer := 0;
    signal line_dy  : integer := 0;  -- negative
    signal line_sx  : integer := 0;
    signal line_sy  : integer := 0;
    signal line_err : integer := 0;

    --------------------------------------------------------------------
    -- Render scale tuning
    --------------------------------------------------------------------
    constant CX : integer := FB_W/2;
    constant CY : integer := FB_H/2;
    constant SCALE : integer := 28;   -- smaller => less zoom

begin
    angle_half <= '0' & angle(7 downto 1);

    rom_inst : entity work.platonic_rom
        port map (
            solid_id   => solid_id,
            edge_index => edge_idx,
            v0         => v0_3d,
            v1         => v1_3d,
            num_edges  => num_edges
        );

    lut_z : entity work.trig_lut
        port map (angle => angle, sin_out => sin_z, cos_out => cos_z);

    lut_x : entity work.trig_lut
        port map (angle => angle_half, sin_out => sin_x, cos_out => cos_x);
    --------------------------------------------------------------------
    -- Main FSM
    --------------------------------------------------------------------
    process(clk)
        variable e2      : integer;
        variable errv    : integer;
        variable x0i,y0i,x1i,y1i : integer;

        -- rotation intermediates
        variable xz0, yz0, zz0 : fixed_point;
        variable xz1, yz1, zz1 : fixed_point;
        variable yx0, zx0      : fixed_point;
        variable yx1, zx1      : fixed_point;

        variable ox, oy : integer;

        variable ne     : integer;
        variable addr   : integer;
    begin
        if rising_edge(clk) then

            -- vsync falling edge = start of vblank pulse 
            start_frame <= '0';
            if (prev_vsync = '1') and (vsync = '0') then
                start_frame <= '1';
            end if;
            prev_vsync <= vsync;

            -- button edge detect
            btn0_rise <= '0'; btnl_rise <= '0'; btnr_rise <= '0';
            if (prev_btn0 = '0') and (btn0 = '1') then btn0_rise <= '1'; end if;
            if (prev_btnl = '0') and (btnl = '1') then btnl_rise <= '1'; end if;
            if (prev_btnr = '0') and (btnr = '1') then btnr_rise <= '1'; end if;
            prev_btn0 <= btn0;
            prev_btnl <= btnl;
            prev_btnr <= btnr;

            -- handle solid selection buttons anytime
            if btnr_rise = '1' then
                solid_id <= (others => '0'); -- back to tetra
            elsif btnl_rise = '1' then
                if solid_id = to_unsigned(4,3) then
                    solid_id <= (others => '0');
                else
                    solid_id <= solid_id + 1;
                end if;
            end if;

            -- btn0: start/pause toggle, and clear to black when pausing
            if btn0_rise = '1' then
                if run_en = '1' then
                    run_en <= '0';
                    clear_addr <= 0;
                    state <= CLEAR_RAM;
                else
                    run_en <= '1';
                end if;
            end if;

            case state is
                when IDLE =>
                    if start_frame = '1' then
                        if run_en = '1' then
                            angle <= angle + 1; -- 1 step per frame
                        end if;
                        clear_addr <= 0;
                        state <= CLEAR_RAM;
                    end if;

                when CLEAR_RAM =>
                    video_ram(clear_addr) <= '0';
                    if clear_addr = FB_SIZE-1 then
                        if run_en = '1' then
                            edge_idx <= (others => '0');
                            state <= LOAD_EDGE;
                        else
                            state <= WAIT_FRAME; -- paused (black)
                        end if;
                    else
                        clear_addr <= clear_addr + 1;
                    end if;

                when LOAD_EDGE =>
                    -- endpoints are coming from ROM combinationally, just move on
                    state <= CALC_EDGE;

                when CALC_EDGE =>
                    -- Rotate v0 around Z then X
                    xz0 := fixed_mult(v0_3d.x, cos_z) - fixed_mult(v0_3d.y, sin_z);
                    yz0 := fixed_mult(v0_3d.x, sin_z) + fixed_mult(v0_3d.y, cos_z);
                    zz0 := v0_3d.z;

                    yx0 := fixed_mult(yz0, cos_x) - fixed_mult(zz0, sin_x);
                    zx0 := fixed_mult(yz0, sin_x) + fixed_mult(zz0, cos_x);

                    -- Rotate v1 around Z then X
                    xz1 := fixed_mult(v1_3d.x, cos_z) - fixed_mult(v1_3d.y, sin_z);
                    yz1 := fixed_mult(v1_3d.x, sin_z) + fixed_mult(v1_3d.y, cos_z);
                    zz1 := v1_3d.z;

                    yx1 := fixed_mult(yz1, cos_x) - fixed_mult(zz1, sin_x);
                    zx1 := fixed_mult(yz1, sin_x) + fixed_mult(zz1, cos_x);

                    -- Orthographic projection into framebuffer
                    ox := (to_integer(xz0) * SCALE) / 65536;
                    oy := (to_integer(yx0) * SCALE) / 65536;
                    bx0 <= CX + ox;
                    by0 <= CY + oy;

                    ox := (to_integer(xz1) * SCALE) / 65536;
                    oy := (to_integer(yx1) * SCALE) / 65536;
                    bx1 <= CX + ox;
                    by1 <= CY + oy;

                    state <= INIT_LINE;

                when INIT_LINE =>
                    cur_x <= bx0;
                    cur_y <= by0;

                    x0i := bx0; y0i := by0; x1i := bx1; y1i := by1;

                    line_dx <= abs(x1i - x0i);
                    if x0i < x1i then line_sx <= 1; else line_sx <= -1; end if;

                    line_dy <= -abs(y1i - y0i);
                    if y0i < y1i then line_sy <= 1; else line_sy <= -1; end if;

                    line_err <= abs(x1i - x0i) + (-abs(y1i - y0i));
                    state <= STEP_LINE;

                when STEP_LINE =>
                    -- plot pixel
                    if (cur_x >= 0 and cur_x < FB_W and cur_y >= 0 and cur_y < FB_H) then
                        addr := cur_y * FB_W + cur_x;
                        if addr >= 0 and addr < FB_SIZE then
                            video_ram(addr) <= '1';
                        end if;
                    end if;

                    if (cur_x = bx1) and (cur_y = by1) then
                        state <= NEXT_EDGE;
                    else
                        -- IMPORTANT: update err with a variable so both X/Y steps can apply correctly
                        errv := line_err;
                        e2 := 2 * errv;

                        if e2 >= line_dy then
                            errv := errv + line_dy;
                            cur_x <= cur_x + line_sx;
                        end if;

                        if e2 <= line_dx then
                            errv := errv + line_dx;
                            cur_y <= cur_y + line_sy;
                        end if;

                        line_err <= errv;
                    end if;

                when NEXT_EDGE =>
                    ne := to_integer(num_edges);
                    if ne <= 0 then
                        state <= WAIT_FRAME;
                    else
                        if to_integer(edge_idx) = (ne - 1) then
                            state <= WAIT_FRAME;
                        else
                            edge_idx <= edge_idx + 1;
                            state <= LOAD_EDGE;
                        end if;
                    end if;

                when WAIT_FRAME =>
                    if start_frame = '1' then
                        if run_en = '1' then
                            angle <= angle + 1;
                        end if;
                        clear_addr <= 0;
                        state <= CLEAR_RAM;
                    end if;

            end case;
        end if;
    end process;

    --------------------------------------------------------------------
    -- VGA sampling (800x600 -> 160x120 via /5)
    --------------------------------------------------------------------
    process(pixel_row, pixel_col, video_ram)
        variable px, py : integer;
        variable c, r   : integer;
        variable addr   : integer;
    begin
        px := to_integer(unsigned(pixel_col));
        py := to_integer(unsigned(pixel_row));

        c := px / 5;
        r := py / 5;

        if (c >= 0 and c < FB_W and r >= 0 and r < FB_H) then
            addr := r * FB_W + c;
            if (addr >= 0 and addr < FB_SIZE) and (video_ram(addr) = '1') then
                red_out   <= "1111";
                green_out <= "1111";
                blue_out  <= "1111";
            else
                red_out   <= "0000";
                green_out <= "0000";
                blue_out  <= "0000";
            end if;
        else
            red_out   <= "0000";
            green_out <= "0000";
            blue_out  <= "0000";
        end if;
    end process;

end architecture;

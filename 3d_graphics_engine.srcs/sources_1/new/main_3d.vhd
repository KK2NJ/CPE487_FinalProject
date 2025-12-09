library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.graphics_pkg.all;

entity graphics_engine_3d is
    port (
        clk_in          : in std_logic; -- 100 MHz clock 
       -- clk             : out  std_logic; -- don't know if this is needed, changed from in to out 
        reset           : in  std_logic;
        enable          : in  std_logic;
        VGA_red : OUT STD_LOGIC_VECTOR (3 DOWNTO 0); -- VGA outputs
        VGA_green : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_blue : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_hsync : OUT STD_LOGIC;
        VGA_vsync : OUT STD_LOGIC   
        
        -- Output: Screen coordinates for line drawing
--        vertex_valid    : out std_logic;
--        vertex_x        : out unsigned(7 downto 0);  -- 0-255
--        vertex_y        : out unsigned(7 downto 0);  -- 0-239
--        triangle_done   : out std_logic;
--        frame_done      : out std_logic
    );
end entity graphics_engine_3d;

architecture rtl of graphics_engine_3d is


    -- Screen Coordinates signals
    signal vertex_valid : std_logic;
    signal vertex_x : unsigned(7 downto 0);  -- 0-255
    signal vertex_y : unsigned(7 downto 0);  -- 0-239
    signal triangle_done : std_logic;
    signal frame_done : std_logic;
    -- FSM States
    type state_type is (IDLE, FETCH_TRIANGLE, ROTATE_Z, ROTATE_X, TRANSLATE, 
                        PROJECT, VIEWPORT, OUTPUT_V0, OUTPUT_V1, OUTPUT_V2, NEXT_TRI);
    signal state : state_type := IDLE;
    
    -- Counters
    signal tri_counter : unsigned(3 downto 0) := (others => '0');
    signal theta_counter : unsigned(7 downto 0) := (others => '0');
    
    -- Pipeline signals
    signal current_tri : triangle;
    signal tri_rot_z, tri_rot_x, tri_translated, tri_projected : triangle;
    signal mat_rot_z, mat_rot_x, mat_proj : matrix4x4;
    
    -- Matrix multiplier interface
    signal mat_mult_enable : std_logic := '0';
    signal mat_mult_valid : std_logic;
    signal mat_mult_matrix : matrix4x4;
    signal mat_mult_vec_in : vec3d;
    signal mat_mult_vec_out : vec3d;
    signal mat_mult_w : fixed_point;
    
    -- Vertex processing counter
    signal vertex_idx : integer range 0 to 2 := 0;
    
    -- clk_in
    
    signal pxl_clk : std_logic;
    
    -- signals for vga_sync
    
    SIGNAL S_red, S_green, S_blue : STD_LOGIC; --_VECTOR (3 DOWNTO 0);
    SIGNAL S_vsync : STD_LOGIC;
    SIGNAL S_pixel_row, S_pixel_col : STD_LOGIC_VECTOR (10 DOWNTO 0);
    
    
    
begin
--    COMPONENT clk_wiz_0 is
--        PORT (
--            clk_in1  : in std_logic;
--            clk_out1 : out std_logic
--        );
--    END COMPONENT;

    
    vga_driver : entity work.vga_sync
    PORT MAP(--instantiate vga_sync component
        pixel_clk => pxl_clk, 
        red_in => S_red & "000", 
        green_in => S_green & "000", 
        blue_in => S_blue & "000", 
        red_out => VGA_red, 
        green_out => VGA_green, 
        blue_out => VGA_blue, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        hsync => VGA_hsync, 
        vsync => S_vsync
    );
    VGA_vsync <= S_vsync; --connect output vsync
    
    clk_wiz_0_inst : entity work.clk_wiz_0
    port map (
      clk_in1 => clk_in,
      clk_out1 => pxl_clk
    );
    
      
    
    -- clk <= pxl_clk;
    -- Instantiate mesh ROM
    mesh: entity work.mesh_rom
        port map(clk => pxl_clk,
         tri_index => tri_counter, 
         triangle_out => current_tri);
    
    -- Instantiate rotation matrix generator
    rot_gen: entity work.rotation_matrix_gen
        port map(clk => pxl_clk,
                 theta => theta_counter,
                 mat_rot_z => mat_rot_z,
                 mat_rot_x => mat_rot_x);
    
    -- Instantiate matrix-vector multiplier
    mat_mult: entity work.matrix_vector_mult
        port map(clk  => pxl_clk, 
                reset => reset,
                enable => mat_mult_enable,
                matrix => mat_mult_matrix, 
                vec_in => mat_mult_vec_in,
                vec_out => mat_mult_vec_out,
                w_out => mat_mult_w, 
                valid => mat_mult_valid
                );
    
    --Build projection matrix (constant for now)
    process(pxl_clk)
        constant F_NEAR : real := 0.1;
        constant F_FAR : real := 1000.0;
        constant F_FOV : real := 90.0;
        constant ASPECT : real := real(SCREEN_HEIGHT) / real(SCREEN_WIDTH);
    begin
        if rising_edge(pxl_clk) then
            if reset = '1' then
                -- Initialize projection matrix
                mat_proj(0,0) <= to_fixed(ASPECT * 1.0);  -- Simplified
                mat_proj(1,1) <= FIXED_ONE;
                mat_proj(2,2) <= to_fixed(F_FAR / (F_FAR - F_NEAR));
                mat_proj(3,2) <= to_fixed(-F_FAR * F_NEAR / (F_FAR - F_NEAR));
                mat_proj(2,3) <= FIXED_ONE;
                mat_proj(3,3) <= FIXED_ZERO;
            end if;
        end if;
    end process;

    --
    
    -- Main control FSM
    process(pxl_clk)
        variable temp_vec : vec3d;
        variable screen_x, screen_y : signed(31 downto 0);
    begin
        if rising_edge(pxl_clk) then -- maybe change to rising_edge(pxl_clk)?
            if reset = '1' then
                state <= IDLE;
                tri_counter <= (others => '0');
                theta_counter <= (others => '0');
                frame_done <= '0';
                triangle_done <= '0';
                vertex_valid <= '0';
                
            elsif enable = '1' then
                case state is
                    when IDLE =>
                        theta_counter <= theta_counter + 1;  -- Auto-rotate
                        tri_counter <= (others => '0');
                        frame_done <= '0';
                        state <= FETCH_TRIANGLE;
                    
                    when FETCH_TRIANGLE =>
                        -- Mesh ROM outputs triangle after 1 cycle
                        vertex_idx <= 0;
                        state <= ROTATE_Z;
                    
                    when ROTATE_Z =>
                        -- Rotate all 3 vertices around Z axis
                        case vertex_idx is
                            when 0 => mat_mult_vec_in <= current_tri.p0;
                            when 1 => mat_mult_vec_in <= current_tri.p1;
                            when 2 => mat_mult_vec_in <= current_tri.p2;
                        end case;
                        mat_mult_matrix <= mat_rot_z;
                        mat_mult_enable <= '1';
                        
                        if mat_mult_valid = '1' then
                            case vertex_idx is
                                when 0 => tri_rot_z.p0 <= mat_mult_vec_out;
                                when 1 => tri_rot_z.p1 <= mat_mult_vec_out;
                                when 2 => tri_rot_z.p2 <= mat_mult_vec_out;
                            end case;
                            
                            if vertex_idx = 2 then
                                vertex_idx <= 0;
                                state <= ROTATE_X;
                            else
                                vertex_idx <= vertex_idx + 1;
                            end if;
                        end if;
                    
                    when ROTATE_X =>
                        -- Rotate around X axis
                        case vertex_idx is
                            when 0 => mat_mult_vec_in <= tri_rot_z.p0;
                            when 1 => mat_mult_vec_in <= tri_rot_z.p1;
                            when 2 => mat_mult_vec_in <= tri_rot_z.p2;
                        end case;
                        mat_mult_matrix <= mat_rot_x;
                        mat_mult_enable <= '1';
                        
                        if mat_mult_valid = '1' then
                            case vertex_idx is
                                when 0 => tri_rot_x.p0 <= mat_mult_vec_out;
                                when 1 => tri_rot_x.p1 <= mat_mult_vec_out;
                                when 2 => tri_rot_x.p2 <= mat_mult_vec_out;
                            end case;
                            
                            if vertex_idx = 2 then
                                state <= TRANSLATE;
                            else
                                vertex_idx <= vertex_idx + 1;
                            end if;
                        end if;
                    
                    when TRANSLATE =>
                        -- Move into screen (Z += 3.0)
                        tri_translated.p0 <= tri_rot_x.p0;
                        tri_translated.p1 <= tri_rot_x.p1;
                        tri_translated.p2 <= tri_rot_x.p2;
                        tri_translated.p0.z <= tri_rot_x.p0.z + to_fixed(3.0);
                        tri_translated.p1.z <= tri_rot_x.p1.z + to_fixed(3.0);
                        tri_translated.p2.z <= tri_rot_x.p2.z + to_fixed(3.0);
                        vertex_idx <= 0;
                        state <= PROJECT;
                    
                    when PROJECT =>
                        -- Apply projection matrix
                        case vertex_idx is
                            when 0 => mat_mult_vec_in <= tri_translated.p0;
                            when 1 => mat_mult_vec_in <= tri_translated.p1;
                            when 2 => mat_mult_vec_in <= tri_translated.p2;
                        end case;
                        mat_mult_matrix <= mat_proj;
                        mat_mult_enable <= '1';
                        
                        if mat_mult_valid = '1' then
                            -- Perspective divide (divide by W)
                            temp_vec := mat_mult_vec_out;
                            if mat_mult_w /= FIXED_ZERO then
                                temp_vec.x := fixed_mult(temp_vec.x, 
                                              FIXED_ONE);  -- Simplified
                                temp_vec.y := fixed_mult(temp_vec.y, FIXED_ONE);
                                temp_vec.z := fixed_mult(temp_vec.z, FIXED_ONE);
                            end if;
                            
                            case vertex_idx is
                                when 0 => tri_projected.p0 <= temp_vec;
                                when 1 => tri_projected.p1 <= temp_vec;
                                when 2 => tri_projected.p2 <= temp_vec;
                            end case;
                            
                            if vertex_idx = 2 then
                                state <= VIEWPORT;
                            else
                                vertex_idx <= vertex_idx + 1;
                            end if;
                        end if;
                    
                    when VIEWPORT =>
                        -- Scale to screen coordinates
                        -- x = (x + 1) * 0.5 * SCREEN_WIDTH
                        screen_x := tri_projected.p0.x + FIXED_ONE;
                        screen_x := fixed_mult(screen_x, FIXED_HALF);
                        screen_x := fixed_mult(screen_x, to_fixed(real(SCREEN_WIDTH)));
                        
                        screen_y := tri_projected.p0.y + FIXED_ONE;
                        screen_y := fixed_mult(screen_y, FIXED_HALF);
                        screen_y := fixed_mult(screen_y, to_fixed(real(SCREEN_HEIGHT)));
                        
                        state <= OUTPUT_V0;
                    
                    when OUTPUT_V0 =>
                        vertex_x <= unsigned(tri_projected.p0.x(23 downto 16));
                        vertex_y <= unsigned(tri_projected.p0.y(23 downto 16));
                        vertex_valid <= '1';
                        state <= OUTPUT_V1;
                    
                    when OUTPUT_V1 =>
                        vertex_x <= unsigned(tri_projected.p1.x(23 downto 16));
                        vertex_y <= unsigned(tri_projected.p1.y(23 downto 16));
                        vertex_valid <= '1';
                        state <= OUTPUT_V2;
                    
                    when OUTPUT_V2 =>
                        vertex_x <= unsigned(tri_projected.p2.x(23 downto 16));
                        vertex_y <= unsigned(tri_projected.p2.y(23 downto 16));
                        vertex_valid <= '1';
                        triangle_done <= '1';
                        state <= NEXT_TRI;
                    
                    when NEXT_TRI =>
                        vertex_valid <= '0';
                        triangle_done <= '0';
                        
                        if tri_counter = 11 then
                            frame_done <= '1';
                            state <= IDLE;
                        else
                            tri_counter <= tri_counter + 1;
                            state <= FETCH_TRIANGLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
end architecture rtl;
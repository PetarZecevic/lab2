-------------------------------------------------------------------------------
--  Department of Computer Engineering and Communications
--  Author: LPRS2  <lprs2@rt-rk.com>
--
--  Module Name: top
--
--  Description:
--
--    Simple test for VGA control
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity top is
  generic (
    RES_TYPE             : natural := 1;
    TEXT_MEM_DATA_WIDTH  : natural := 6;
    GRAPH_MEM_DATA_WIDTH : natural := 32
    );
  port (
    clk_i          : in  std_logic;
    reset_n_i      : in  std_logic;
	 direct_mode_i : in std_logic;
	 display_mode_i : in std_logic_vector(1 downto 0);
    -- vga
    vga_hsync_o    : out std_logic;
    vga_vsync_o    : out std_logic;
    blank_o        : out std_logic;
    pix_clock_o    : out std_logic;
    psave_o        : out std_logic;
    sync_o         : out std_logic;
    red_o          : out std_logic_vector(7 downto 0);
    green_o        : out std_logic_vector(7 downto 0);
    blue_o         : out std_logic_vector(7 downto 0)
   );
end top;

architecture rtl of top is

  constant RES_NUM : natural := 6;

  type t_param_array is array (0 to RES_NUM-1) of natural;
  
  constant H_RES_ARRAY           : t_param_array := ( 0 => 64, 1 => 640,  2 => 800,  3 => 1024,  4 => 1152,  5 => 1280,  others => 0 );
  constant V_RES_ARRAY           : t_param_array := ( 0 => 48, 1 => 480,  2 => 600,  3 => 768,   4 => 864,   5 => 1024,  others => 0 );
  constant MEM_ADDR_WIDTH_ARRAY  : t_param_array := ( 0 => 12, 1 => 14,   2 => 13,   3 => 14,    4 => 14,    5 => 15,    others => 0 );
  constant MEM_SIZE_ARRAY        : t_param_array := ( 0 => 48, 1 => 4800, 2 => 7500, 3 => 12576, 4 => 15552, 5 => 20480, others => 0 ); 
  
  constant H_RES          : natural := H_RES_ARRAY(RES_TYPE);
  constant V_RES          : natural := V_RES_ARRAY(RES_TYPE);
  constant MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH_ARRAY(RES_TYPE);
  constant MEM_SIZE       : natural := MEM_SIZE_ARRAY(RES_TYPE);

  component vga_top is 
    generic (
      H_RES                : natural := 640;
      V_RES                : natural := 480;
      MEM_ADDR_WIDTH       : natural := 32;
      GRAPH_MEM_ADDR_WIDTH : natural := 32;
      TEXT_MEM_DATA_WIDTH  : natural := 32;
      GRAPH_MEM_DATA_WIDTH : natural := 32;
      RES_TYPE             : integer := 1;
      MEM_SIZE             : natural := 4800
      );
    port (
      clk_i               : in  std_logic;
      reset_n_i           : in  std_logic;
      --
      direct_mode_i       : in  std_logic; -- 0 - text and graphics interface mode, 1 - direct mode (direct force RGB component)
      dir_red_i           : in  std_logic_vector(7 downto 0);
      dir_green_i         : in  std_logic_vector(7 downto 0);
      dir_blue_i          : in  std_logic_vector(7 downto 0);
      dir_pixel_column_o  : out std_logic_vector(10 downto 0);
      dir_pixel_row_o     : out std_logic_vector(10 downto 0);
      -- mode interface
      display_mode_i      : in  std_logic_vector(1 downto 0);  -- 00 - text mode, 01 - graphics mode, 01 - text & graphics
      -- text mode interface
      text_addr_i         : in  std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
      text_data_i         : in  std_logic_vector(TEXT_MEM_DATA_WIDTH-1 downto 0);
      text_we_i           : in  std_logic;
      -- graphics mode interface
      graph_addr_i        : in  std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
      graph_data_i        : in  std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
      graph_we_i          : in  std_logic;
      --
      font_size_i         : in  std_logic_vector(3 downto 0);
      show_frame_i        : in  std_logic;
      foreground_color_i  : in  std_logic_vector(23 downto 0);
      background_color_i  : in  std_logic_vector(23 downto 0);
      frame_color_i       : in  std_logic_vector(23 downto 0);
      -- vga
      vga_hsync_o         : out std_logic;
      vga_vsync_o         : out std_logic;
      blank_o             : out std_logic;
      pix_clock_o         : out std_logic;
      vga_rst_n_o         : out std_logic;
      psave_o             : out std_logic;
      sync_o              : out std_logic;
      red_o               : out std_logic_vector(7 downto 0);
      green_o             : out std_logic_vector(7 downto 0);
      blue_o              : out std_logic_vector(7 downto 0)
    );
  end component;
  
  component ODDR2
  generic(
   DDR_ALIGNMENT : string := "NONE";
   INIT          : bit    := '0';
   SRTYPE        : string := "SYNC"
   );
  port(
    Q           : out std_ulogic;
    C0          : in  std_ulogic;
    C1          : in  std_ulogic;
    CE          : in  std_ulogic := 'H';
    D0          : in  std_ulogic;
    D1          : in  std_ulogic;
    R           : in  std_ulogic := 'L';
    S           : in  std_ulogic := 'L'
  );
  end component;
  
  component reg
	generic(
		WIDTH    : positive := 1;
		RST_INIT : integer := 0
	);
	port(
		i_clk  : in  std_logic;
		in_rst : in  std_logic;
		i_d    : in  std_logic_vector(WIDTH-1 downto 0);
		o_q    : out std_logic_vector(WIDTH-1 downto 0)
	);
  end component;
  
  constant update_period     : std_logic_vector(31 downto 0) := conv_std_logic_vector(1, 32);
  
  constant GRAPH_MEM_ADDR_WIDTH : natural := MEM_ADDR_WIDTH + 6;-- graphics addres is scales with minumum char size 8*8 log2(64) = 6
  
  -- text
  signal message_lenght      : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal graphics_lenght     : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  
  --signal direct_mode         : std_logic;
  --
  signal font_size           : std_logic_vector(3 downto 0);
  signal show_frame          : std_logic;
  --signal display_mode        : std_logic_vector(1 downto 0);  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  signal foreground_color    : std_logic_vector(23 downto 0);
  signal background_color    : std_logic_vector(23 downto 0);
  signal frame_color         : std_logic_vector(23 downto 0);

  signal char_we             : std_logic;
  signal char_address        : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal char_address_next	  : std_logic_vector(MEM_ADDR_WIDTH-1 downto 0);
  signal char_value          : std_logic_vector(5 downto 0);

  signal pixel_address       : std_logic_vector(GRAPH_MEM_ADDR_WIDTH-1 downto 0);
  signal pixel_value         : std_logic_vector(GRAPH_MEM_DATA_WIDTH-1 downto 0);
  signal pixel_we            : std_logic;

  signal pix_clock_s         : std_logic;
  signal vga_rst_n_s         : std_logic;
  signal pix_clock_n         : std_logic;
   
  signal dir_red             : std_logic_vector(7 downto 0);
  signal dir_green           : std_logic_vector(7 downto 0);
  signal dir_blue            : std_logic_vector(7 downto 0);
  signal dir_pixel_column    : std_logic_vector(10 downto 0);
  signal dir_pixel_row       : std_logic_vector(10 downto 0);
  signal rgb	: std_logic_vector(23 downto 0);
  -- time counter --
  constant maxcnt_s			  : std_logic_vector(19 downto 0) := "11111111111111111111";
  signal time_s		: std_logic_vector(19 downto 0);
  signal time_next_s : std_logic_vector(19 downto 0);
  signal val_o : std_logic;
  
  -- offset counter --
  constant maxoffset_s : std_logic_vector(13 downto 0) := "00001110001000";
  signal offset_s : std_logic_vector(13 downto 0);
  signal offset_next_s : std_logic_vector(13 downto 0);
  
  
  --pixel counter--
  constant maxpixel_s : std_logic_vector(19 downto 0) := conv_std_logic_vector(9580, 20);
  --signal pixel_s : std_logic_vector(13 downto 0);
  signal pixel_next_s : std_logic_vector(19 downto 0);
  
begin

  -- calculate message lenght from font size
  message_lenght <= conv_std_logic_vector(MEM_SIZE/64, MEM_ADDR_WIDTH)when (font_size = 3) else -- note: some resolution with font size (32, 64)  give non integer message lenght (like 480x640 on 64 pixel font size) 480/64= 7.5
                    conv_std_logic_vector(MEM_SIZE/16, MEM_ADDR_WIDTH)when (font_size = 2) else
                    conv_std_logic_vector(MEM_SIZE/4 , MEM_ADDR_WIDTH)when (font_size = 1) else
                    conv_std_logic_vector(MEM_SIZE   , MEM_ADDR_WIDTH);
  
  graphics_lenght <= conv_std_logic_vector(MEM_SIZE*8*8, GRAPH_MEM_ADDR_WIDTH);
  
  -- removed to inputs pin
  --direct_mode <= '0';
  --display_mode     <= "01";  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
  
  font_size        <= x"1";
  show_frame       <= '1';
  foreground_color <= x"FFFFFF";
  background_color <= x"000000";
  frame_color      <= x"FF0000";

  clk5m_inst : ODDR2
  generic map(
    DDR_ALIGNMENT => "NONE",  -- Sets output alignment to "NONE","C0", "C1" 
    INIT => '0',              -- Sets initial state of the Q output to '0' or '1'
    SRTYPE => "SYNC"          -- Specifies "SYNC" or "ASYNC" set/reset
  )
  port map (
    Q  => pix_clock_o,       -- 1-bit output data
    C0 => pix_clock_s,       -- 1-bit clock input
    C1 => pix_clock_n,       -- 1-bit clock input
    CE => '1',               -- 1-bit clock enable input
    D0 => '1',               -- 1-bit data input (associated with C0)
    D1 => '0',               -- 1-bit data input (associated with C1)
    R  => '0',               -- 1-bit reset input
    S  => '0'                -- 1-bit set input
  );
  pix_clock_n <= not(pix_clock_s);

  -- component instantiation
  vga_top_i: vga_top
  generic map(
    RES_TYPE             => RES_TYPE,
    H_RES                => H_RES,
    V_RES                => V_RES,
    MEM_ADDR_WIDTH       => MEM_ADDR_WIDTH,
    GRAPH_MEM_ADDR_WIDTH => GRAPH_MEM_ADDR_WIDTH,
    TEXT_MEM_DATA_WIDTH  => TEXT_MEM_DATA_WIDTH,
    GRAPH_MEM_DATA_WIDTH => GRAPH_MEM_DATA_WIDTH,
    MEM_SIZE             => MEM_SIZE
  )
  port map(
    clk_i              => clk_i,
    reset_n_i          => reset_n_i,
    --
    direct_mode_i      => direct_mode_i,
    dir_red_i          => dir_red,
    dir_green_i        => dir_green,
    dir_blue_i         => dir_blue,
    dir_pixel_column_o => dir_pixel_column,
    dir_pixel_row_o    => dir_pixel_row,
    -- cfg
    display_mode_i     => display_mode_i,  -- 01 - text mode, 10 - graphics mode, 11 - text & graphics
    -- text mode interface
    text_addr_i        => char_address,
    text_data_i        => char_value,
    text_we_i          => char_we,
    -- graphics mode interface
    graph_addr_i       => pixel_address,
    graph_data_i       => pixel_value,
    graph_we_i         => pixel_we,
    -- cfg
    font_size_i        => font_size,
    show_frame_i       => show_frame,
    foreground_color_i => foreground_color,
    background_color_i => background_color,
    frame_color_i      => frame_color,
    -- vga
    vga_hsync_o        => vga_hsync_o,
    vga_vsync_o        => vga_vsync_o,
    blank_o            => blank_o,
    pix_clock_o        => pix_clock_s,
    vga_rst_n_o        => vga_rst_n_s,
    psave_o            => psave_o,
    sync_o             => sync_o,
    red_o              => red_o,
    green_o            => green_o,
    blue_o             => blue_o     
  );
  
  address_counter : reg
	generic map(
		WIDTH => 14,
		RST_INIT => 0
	)
	port map(
		i_clk => pix_clock_s,
		in_rst => vga_rst_n_s,
		i_d => char_address_next,
		o_q => char_address
	);
	
	time_counter : reg
	generic map(
		WIDTH => 20,
		RST_INIT => 0
	)
	port map(
		i_clk => pix_clock_s,
		in_rst => vga_rst_n_s,
		i_d => time_next_s,
		o_q => time_s
	);
	
	offset_counter : reg
	generic map(
		WIDTH => 14,
		RST_INIT => 0
	)
	port map(
		i_clk => pix_clock_s,
		in_rst => vga_rst_n_s,
		i_d => offset_next_s,
		o_q => offset_s
	);
	
	pixel_counter : reg
	generic map(
		WIDTH => 20,
		RST_INIT => 0
	)
	port map(
		i_clk => pix_clock_s,
		in_rst => vga_rst_n_s,
		i_d => pixel_next_s,
		o_q => pixel_address
	);
	
	
	time_next_s <= time_s + 1 when time_s /= maxcnt_s else
						conv_std_logic_vector(0, 20);
	
	val_o <= '1' when time_s = maxcnt_s else
				'0';
	
	offset_next_s <= offset_s + 1 when val_o = '1' else
						  conv_std_logic_vector(0, 14) when offset_s = maxoffset_s else
						  offset_s;
	
  -- na osnovu signala iz vga_top modula dir_pixel_column i dir_pixel_row realizovati logiku koja genereise
  --dir_red
  --dir_green
  --dir_blue
	rgb <= x"FFFFFF" when dir_pixel_column < H_RES / 8 else
			 x"FFFF00" when dir_pixel_column < 2*H_RES / 8 else
			 x"0099ff" when dir_pixel_column < 3*H_RES / 8 else
			 x"00FF00" when dir_pixel_column < 4*H_RES / 8 else
			 x"FF00FF" when dir_pixel_column < 5*H_RES / 8 else
			 x"FF0000" when dir_pixel_column < 6*H_RES / 8 else
			 x"0000FF" when dir_pixel_column < 7*H_RES / 8 else
			 x"000000";
	
	dir_red <= rgb(23 downto 16);
	dir_green <= rgb(15 downto 8);
	dir_blue <= rgb(7 downto 0);
	
  -- koristeci signale realizovati logiku koja pise po TXT_MEM
  --char_address
  --char_value
  --char_we
  
  -- offset and timer logic --
  
  char_address_next <= char_address + 1 when char_address /= "01001011000000" else -- index za ekran
						  conv_std_logic_vector(0, 14);
  char_we <= '1';
  
  char_value <= conv_std_logic_vector(16,6) when char_address = 0+offset_s else
					conv_std_logic_vector(5,6) when char_address = 1+offset_s else
					conv_std_logic_vector(20,6) when char_address = 2+offset_s else
					conv_std_logic_vector(1,6) when char_address = 3+offset_s else
					conv_std_logic_vector(18,6) when char_address = 4+offset_s else
					conv_std_logic_vector(18,6) when char_address = 6+offset_s else
					conv_std_logic_vector(1,6) when char_address = 7+offset_s else
					conv_std_logic_vector(4,6) when char_address = 8+offset_s else
					conv_std_logic_vector(15,6) when char_address = 9+offset_s else
					conv_std_logic_vector(22,6) when char_address = 10+offset_s else
					conv_std_logic_vector(1,6) when char_address = 11+offset_s else
					conv_std_logic_vector(14,6) when char_address = 12+offset_s else
					conv_std_logic_vector(32,6);
					
  -- koristeci signale realizovati logiku koja pise po GRAPH_MEM
  --pixel_address
  --pixel_value
  --pixel_we
  pixel_next_s <= pixel_address + 1 when pixel_address /= maxpixel_s else -- index za ekran
						  conv_std_logic_vector(0, 20);
				
  pixel_we <='1';
  
  pixel_value <= x"ffffffff" when pixel_address > 100*20 + 4 +offset_s and pixel_address < 101*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 101*20 + 4 +offset_s and pixel_address < 102*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 102*20 + 4 +offset_s and pixel_address < 103*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 103*20 + 4 +offset_s and pixel_address < 104*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 104*20 + 4 +offset_s and pixel_address < 105*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 105*20 + 4 +offset_s and pixel_address < 106*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 106*20 + 4 +offset_s and pixel_address < 107*20-13 +offset_s else
					  x"ffffffff" when pixel_address > 107*20 + 4 +offset_s and pixel_address < 108*20-13 +offset_s else
					  x"00000000";
  
end rtl;
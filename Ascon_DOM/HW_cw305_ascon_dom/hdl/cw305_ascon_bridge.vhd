------------------------------------------------------------------
-- Copyright (c) 2025, Security Pattern                         --
------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cw305_ascon_bridge is
  port( clk         :in  std_logic;
        rst         :in  std_logic;
        sdin        :in  std_logic_vector(64-1 downto 0);
        pdin        :in  std_logic_vector(64-1 downto 0);
        rdin        :in  std_logic_vector(320-1 downto 0);
        init        :in  std_logic;
        start       :in  std_logic;
        waddr       :out std_logic_vector(7 downto 0);
        wraddr      :out std_logic_vector(7 downto 0);
        val_dout    :out std_logic;
        dout        :out std_logic_vector(64-1 downto 0);
        busy        :out std_logic
    );

end cw305_ascon_bridge;

architecture rtl of cw305_ascon_bridge is

--components

component LWC_SCA is
--! Global ports
   port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        --! Public data input
        pdi_data  : in  std_logic_vector(64 - 1 downto 0);
        pdi_valid : in  std_logic;
        pdi_ready : out std_logic;
        --! Secret data input
        sdi_data  : in  std_logic_vector(64 - 1 downto 0);
        sdi_valid : in  std_logic;
        sdi_ready : out std_logic;
        --! Data out ports
        do_data   : out std_logic_vector(64 - 1 downto 0);
        do_last   : out std_logic;
        do_valid  : out std_logic;
        do_ready  : in  std_logic;
        --! Random Input
        rdi_data  : in  std_logic_vector(320 - 1 downto 0);
        rdi_valid : in  std_logic;
        rdi_ready : out std_logic
        );
    end component;


----------------------------------------------------------------------------
-- Internal signal declarations
----------------------------------------------------------------------------
constant DATA_WIDTH : integer := 64;

signal c_rst        : std_logic;
signal dout_val     : std_logic;
signal s_sdin       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_pdin       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_dout       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_rdin       : std_logic_vector(320 - 1 downto 0);

signal c_pdi_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal c_pdi_valid  : std_logic;
signal c_pdi_ready  : std_logic;
--! Secret data input
signal c_sdi_data   : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal c_sdi_valid  : std_logic;
signal c_sdi_ready  : std_logic;
--! Data out ports
signal c_do_data    : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal c_do_last    : std_logic;
signal c_do_valid   : std_logic;
signal c_do_ready   : std_logic; 

signal c_rdi_data   : std_logic_vector(320 - 1 downto 0);

signal s_pdi_valid  : std_logic;
signal s_sdi_valid  : std_logic;
signal s_cmd        : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_wr_cmd     : std_logic;
signal r_cmd        : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal r_wr_cmd     : std_logic;

signal s_waddr      : unsigned(7 downto 0);
signal s_wraddr     : unsigned(7 downto 0);
signal reg_cnt      : unsigned(7 downto 0);

begin  -- Rtl

-- port map

core_map : LWC_SCA 
    port map(   clk         => clk,
                rst         => c_rst,
                pdi_data    => c_pdi_data,
                pdi_valid   => c_pdi_valid,
                pdi_ready   => c_pdi_ready,
                sdi_data    => c_sdi_data,
                sdi_valid   => c_sdi_valid,
                sdi_ready   => c_sdi_ready,
                do_data     => c_do_data,
                do_last     => c_do_last,
                do_valid    => c_do_valid,
                do_ready    => c_do_ready,
                rdi_data    => c_rdi_data,
                rdi_valid   => '1',
                rdi_ready   => open
            );


-- Main counter
p_main : process (clk, rst)
begin  -- process p_main
    if rst = '0' then
        reg_cnt <= x"00";
        c_pdi_valid <= '0';
        c_sdi_valid <= '0';        
    elsif clk'event and clk = '1' then  -- rising clk edge
        if init = '1' then
            reg_cnt <= x"00";
        else
            -- Start
            if start = '1' then
                reg_cnt <= x"01";
            elsif reg_cnt > x"90" then
                reg_cnt <= x"00";
            elsif reg_cnt > x"00" then
                reg_cnt <= reg_cnt + 1;
            end if;
            c_pdi_valid <= s_pdi_valid;
            c_sdi_valid <= s_sdi_valid;
            r_cmd <= s_cmd;
            r_wr_cmd <= s_wr_cmd;
        end if;
    end if;
end process p_main;

p_data : process (reg_cnt)
begin
    s_waddr <= x"00";
    s_wraddr <= x"00";
    s_pdi_valid <= '0';
    s_sdi_valid <= '0';
    s_cmd <= (others=>'0');
    s_wr_cmd <= '0';
    case reg_cnt is
        when x"01" =>
            s_pdi_valid <= '1';
            s_wr_cmd <= '1';
            s_cmd <= x"7000000000000000";
        when x"02" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_wr_cmd <= '1';
            s_cmd <= x"4000000000000000";
        when x"03" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_wr_cmd <= '1';
            s_cmd <= x"c700001000000000";
        when x"04" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
        when x"05" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_waddr <= x"00";
        when x"06" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_waddr <= x"01";
        when x"07" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_waddr <= x"02";
        when x"08" =>
            s_pdi_valid <= '1';
            s_sdi_valid <= '1';
            s_waddr <= x"03";
        when x"09" =>
            s_pdi_valid <='1';
            s_wr_cmd <= '1';
            s_cmd <= x"2000000000000000";
        when x"0a" =>
            s_pdi_valid <='1';
            s_wr_cmd <= '1';
            s_cmd <= x"d200001000000000";
        when x"0b" =>
            s_pdi_valid <='1';
            s_waddr <= x"04";
        when x"0c" =>
            s_pdi_valid <='1';
            s_waddr <= x"05";
        when x"0d" =>
            s_pdi_valid <='1';
            s_waddr <= x"06";
        when x"0e" =>
            s_pdi_valid <='1';
            s_waddr <= x"07";
        when x"0f" =>
            s_pdi_valid <='1';
            s_wr_cmd <= '1';
            s_cmd <= x"1200001000000000";
        when x"10" =>
            s_pdi_valid <='1';
            s_wraddr <= x"00";
        when x"11" =>
            s_pdi_valid <='1';
            s_wraddr <= x"00";
        when x"12" =>
            s_pdi_valid <='1';
            s_wraddr <= x"01";
        when x"13" =>
            s_pdi_valid <='1';
            s_wraddr <= x"01";
        when x"14" =>
            s_pdi_valid <='1';
            s_wraddr <= x"02";
        when x"15" =>
            s_pdi_valid <='1';
            s_wraddr <= x"02";
        when x"16" =>
            s_pdi_valid <='1';
            s_wraddr <= x"03";
        when x"17" =>
            s_pdi_valid <='1';
            s_wraddr <= x"03";
        when x"18" =>
            s_pdi_valid <='1';
            s_wraddr <= x"04";
        when x"19" =>
            s_pdi_valid <='1';
            s_wraddr <= x"04";
        when x"1a" =>
            s_pdi_valid <='1';
            s_wraddr <= x"05";
        when x"1b" =>
            s_pdi_valid <='1';
            s_wraddr <= x"05";
        when x"1c" =>
            s_pdi_valid <='1';
            s_wraddr <= x"06";
        when x"1d" =>
            s_pdi_valid <='1';
            s_wraddr <= x"06";
        when x"1e" =>
            s_pdi_valid <='1';
            s_wraddr <= x"07";
        when x"1f" =>
            s_pdi_valid <='1';
            s_wraddr <= x"07";
        when x"20" =>
            s_pdi_valid <='1';
            s_wraddr <= x"08";
        when x"21" =>
            s_pdi_valid <='1';
            s_wraddr <= x"08";
        when x"22" =>
            s_pdi_valid <='1';
            s_wraddr <= x"09";
        when x"23" =>
            s_pdi_valid <='1';
            s_wraddr <= x"09";
        when x"24" =>
            s_pdi_valid <='1';
            s_wraddr <= x"0a";
        when x"25" =>
            s_pdi_valid <='1';
            s_wraddr <= x"0a";
        when x"26" =>
            s_pdi_valid <='1';
            s_wraddr <= x"0b";
        when x"27" =>
            s_pdi_valid <='1';
            s_wraddr <= x"0b";
        when x"28" =>
            s_pdi_valid <='1';
        when x"29" =>
            s_pdi_valid <='1';
            s_waddr <= x"08";
        when x"2a" =>
            s_pdi_valid <='1';
            s_waddr <= x"09";
        when x"2b" =>
            s_pdi_valid <='1';
        when x"2c" =>
            s_pdi_valid <='1';
        when x"2d" =>
            s_pdi_valid <='1';
        when x"2e" =>
            s_pdi_valid <='1';
        when x"2f" =>
            s_pdi_valid <='1';
        when x"30" =>
            s_pdi_valid <='1';
        when x"31" =>
            s_pdi_valid <='1';
        when x"32" =>
            s_pdi_valid <='1';
        when x"33" =>
            s_pdi_valid <='1';
        when x"34" =>
            s_pdi_valid <='1';
        when x"35" =>
            s_pdi_valid <='1';
        when x"36" =>
            s_pdi_valid <='1';
        when x"37" =>
            s_pdi_valid <='1';
            s_waddr <= x"0a";
        when x"38" =>
            s_pdi_valid <='1';
            s_waddr <= x"0b";
        when x"39" =>
            s_pdi_valid <='1';
            s_wr_cmd <= '1';
            s_cmd <= x"4700001000000000";
        when x"3a" =>
            s_pdi_valid <='1';
        when x"3b" =>
            s_pdi_valid <='1';
        when x"3c" =>
            s_pdi_valid <='1';
        when x"3d" =>
            s_pdi_valid <='1';
        when x"3e" =>
            s_pdi_valid <='1';
        when x"3f" =>
            s_pdi_valid <='1';
        when x"40" =>
            s_pdi_valid <='1';
        when x"41" =>
            s_pdi_valid <='1';
        when x"42" =>
            s_pdi_valid <='1';
        when x"43" =>
            s_pdi_valid <='1';
        when x"44" =>
            s_pdi_valid <='1';
        when x"45" =>
            s_pdi_valid <='1';
        when x"46" =>
            s_pdi_valid <='1';
        when x"47" =>
            s_pdi_valid <='1';
        when x"48" =>
            s_pdi_valid <='1';
        when x"49" =>
            s_pdi_valid <='1';
        when x"4a" =>
            s_pdi_valid <='1';
        when x"4b" =>
            s_pdi_valid <='1';
        when x"4c" =>
            s_pdi_valid <='1';
        when x"4d" =>
            s_pdi_valid <='1';
        when x"4e" =>
            s_pdi_valid <='1';
        when x"4f" =>
            s_pdi_valid <='1';
        when x"50" =>
            s_pdi_valid <='1';
        when x"51" =>
            s_pdi_valid <='1';
        when x"52" =>
            s_pdi_valid <='1';
        when x"53" =>
            s_pdi_valid <='1';
            s_waddr <= x"0c";
        when x"54" =>
            s_pdi_valid <='1';
            s_waddr <= x"0d";
        when x"55" =>
            s_pdi_valid <='1';
            s_waddr <= x"0c";
        when x"56" =>
            s_pdi_valid <='1';
            s_waddr <= x"0d";
        when x"57" =>
            s_pdi_valid <='1';
        when x"58" =>
            s_pdi_valid <='1';
        when x"59" =>
            s_pdi_valid <='1';
        when x"5a" =>
            s_pdi_valid <='1';
        when x"5b" =>
            s_pdi_valid <='1';
        when x"5c" =>
            s_pdi_valid <='1';
        when x"5d" =>
            s_pdi_valid <='1';
        when x"5e" =>
            s_pdi_valid <='1';
        when x"5f" =>
            s_pdi_valid <='1';
        when x"60" =>
            s_pdi_valid <='1';
        when x"61" =>
            s_pdi_valid <='1';
            s_waddr <= x"0e";
        when x"62" =>
            s_pdi_valid <='1';
            s_waddr <= x"0f";
        when x"63" =>
            s_pdi_valid <='1';
            s_waddr <= x"0e";
        when x"64" =>
            s_pdi_valid <='1';
            s_waddr <= x"0f";
        when x"8c" =>
            s_waddr <= x"10";
        when x"8d" =>
            s_waddr <= x"11";
        when x"8e" =>
            s_waddr <= x"12";
        when x"8f" =>
            s_waddr <= x"13";
        when others =>
            s_waddr <= x"00";
            s_wraddr <= x"00";
            s_pdi_valid <= '0';
            s_sdi_valid <= '0';
            s_cmd <= (others=>'0');
            s_wr_cmd <= '0';
    end case;
end process p_data;

-- TODO this is not parametric
s_sdin <= sdin(39 downto 32) & sdin(47 downto 40) & sdin(55 downto 48) & sdin(63 downto 56) & sdin(7 downto 0) & sdin(15 downto 8) & sdin(23 downto 16) & sdin(31 downto 24);
s_pdin <= pdin(39 downto 32) & pdin(47 downto 40) & pdin(55 downto 48) & pdin(63 downto 56) & pdin(7 downto 0) & pdin(15 downto 8) & pdin(23 downto 16) & pdin(31 downto 24);
s_dout <= c_do_data(39 downto 32) & c_do_data(47 downto 40) & c_do_data(55 downto 48) & c_do_data(63 downto 56) & c_do_data(7 downto 0) & c_do_data(15 downto 8) & c_do_data(23 downto 16) & c_do_data(31 downto 24);
s_rdin <=   rdin(319-24 downto 320-32)  & rdin(319-16 downto 320-24) & rdin(319-8 downto 320-16) & rdin(319 downto 320-8) &
            rdin(287-24 downto 288-32)  & rdin(287-16 downto 288-24) & rdin(287-8 downto 288-16) & rdin(287 downto 288-8) &
            rdin(255-24 downto 256-32)  & rdin(255-16 downto 256-24) & rdin(255-8 downto 256-16) & rdin(255 downto 256-8) &
            rdin(223-24 downto 224-32)  & rdin(223-16 downto 224-24) & rdin(223-8 downto 224-16) & rdin(223 downto 224-8) &
            rdin(191-24 downto 192-32)  & rdin(191-16 downto 192-24) & rdin(191-8 downto 192-16) & rdin(191 downto 192-8) &
            rdin(159-24 downto 160-32)  & rdin(159-16 downto 160-24) & rdin(159-8 downto 160-16) & rdin(159 downto 160-8) &
            rdin(127-24 downto 128-32)  & rdin(127-16 downto 128-24) & rdin(127-8 downto 128-16) & rdin(127 downto 128-8) &
            rdin( 95-24 downto  96-32)  & rdin( 95-16 downto  96-24) & rdin( 95-8 downto  96-16) & rdin( 95 downto  96-8) &
            rdin( 63-24 downto  64-32)  & rdin( 63-16 downto  64-24) & rdin( 63-8 downto  64-16) & rdin( 63 downto  64-8) &
            rdin( 31-24 downto  32-32)  & rdin( 31-16 downto  32-24) & rdin( 31-8 downto  32-16) & rdin( 31 downto  32-8);

-- From EXT to CORE
c_rst <= not rst or init;
c_do_ready <= '1';
c_sdi_data <=   (others=>'0') when c_sdi_valid = '0' else
                r_cmd when r_wr_cmd = '1' else 
                s_sdin;
c_pdi_data <=   (others=>'0') when c_pdi_valid = '0' else
                r_cmd when r_wr_cmd = '1' else 
                s_pdin;

c_rdi_data <=   s_rdin;

-- From CORE to EXT
waddr <= std_logic_vector(s_waddr);
wraddr <= std_logic_vector(s_wraddr);
dout_val <= '1' when reg_cnt = x"55" or reg_cnt = x"56" or reg_cnt = x"63" or reg_cnt = x"64" or
                reg_cnt = x"8c" or reg_cnt = x"8d" or reg_cnt = x"8e" or reg_cnt = x"8f" else '0';
val_dout <= dout_val;
dout <= s_dout when dout_val = '1' else (others=>'0');
busy <= '1' when reg_cnt /= x"00" else '0';

end rtl;

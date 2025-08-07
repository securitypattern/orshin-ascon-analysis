------------------------------------------------------------------
-- Copyright (c) 2025, Security Pattern                         --
------------------------------------------------------------------

library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity cw305_ascon_bridge is
  port( clk         :in  std_logic;
        rst         :in  std_logic;
        kdin        :in  std_logic_vector(4 downto 0);
        ndin        :in  std_logic_vector(4 downto 0);
        addin       :in  std_logic_vector(4 downto 0);
        ptdin       :in  std_logic_vector(4 downto 0);
        start       :in  std_logic;
        waddr       :out std_logic_vector(11 downto 0);
        val_dout    :out std_logic;
        dout        :out std_logic;
        tagout      :out std_logic;
        busy        :out std_logic
    );

end cw305_ascon_bridge;

architecture rtl of cw305_ascon_bridge is

--components

component ASCON
  generic (
    k  : integer := 128;
    r  : integer := 64;
    a  : integer := 12;
    b  : integer := 6;
    l  : integer := 32;
    y  : integer := 32;
    TI : integer := 0;
    FP : integer := 0
  );
  port (
    clk                    : in  std_logic;
    rst                    : in  std_logic;
    keyxSI                 : in  std_logic_vector(4 downto 0);
    noncexSI               : in  std_logic_vector(4 downto 0);
    associated_dataxSI     : in  std_logic_vector(4 downto 0);
    plain_textxSI          : in  std_logic_vector(4 downto 0);
    encryption_startxSI    : in  std_logic;
    decryption_startxSI    : in  std_logic;
    r_64xSI                : in  std_logic_vector(13 downto 0);
    r_128xSI               : in  std_logic_vector(2 downto 0);
    r_ptxSI                : in  std_logic_vector(2 downto 0);

    cipher_textxSO         : out std_logic;
    plain_textxS0          : out std_logic;
    tagxSO                 : out std_logic;
    dec_tagxSO             : out std_logic;
    encryption_readyxSO    : out std_logic;
    decryption_readyxSO    : out std_logic;
    message_authentication : out std_logic
  );
end component;
    
----------------------------------------------------------------------------
-- Internal signal declarations
----------------------------------------------------------------------------
constant DATA_WIDTH : integer := 5;

signal c_rst        : std_logic;
signal c_start      : std_logic;
signal dout_val     : std_logic;
signal s_kdin       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_ndin       : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_addin      : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_ptdin      : std_logic_vector(DATA_WIDTH - 1 downto 0);
signal s_dout       : std_logic;
signal s_tagout     : std_logic;

signal s_waddr      : unsigned(11 downto 0);
signal reg_cnt      : unsigned(11 downto 0);

begin  -- Rtl

-- port map

core_map : ASCON
    generic map (
        k  => 128,
        r  => 64,
        a  => 12,
        b  => 6,
        l  => 128,
        y  => 128,
        TI => 1,
        FP => 0
    )
    port map (
        clk                    => clk,
        rst                    => c_rst,
        keyxSI                 => s_kdin,
        noncexSI               => s_ndin,
        associated_dataxSI     => s_addin,
        plain_textxSI          => s_ptdin,
        encryption_startxSI    => c_start,
        decryption_startxSI    => '0',
        r_64xSI                => (others=>'0'),
        r_128xSI               => (others=>'0'),
        r_ptxSI                => (others=>'0'),

        cipher_textxSO         => s_dout,
        plain_textxS0          => open,
        tagxSO                 => s_tagout,
        dec_tagxSO             => open,
        encryption_readyxSO    => open,
        decryption_readyxSO    => open,
        message_authentication => open
    );

-- Main counter
p_main : process (clk, rst)
begin  -- process p_main
    if rst = '0' then
        reg_cnt <= x"000";
    elsif clk'event and clk = '1' then  -- rising clk edge
        -- Start
        if start = '1' then
            reg_cnt <= x"001";
        elsif reg_cnt > x"14A" then
            reg_cnt <= x"000";
        elsif reg_cnt > x"000" then
            reg_cnt <= reg_cnt + 1;
        end if;
    end if;
end process p_main;

p_data : process (reg_cnt)
begin
    if reg_cnt >= x"001" and reg_cnt <= x"081" then
        s_waddr <= reg_cnt;
    elsif reg_cnt >= x"0C9" and reg_cnt <= x"148" then
        s_waddr <= 127 - (reg_cnt - x"0C9");
    else
        s_waddr <= x"000";
    end if;
    --
    if reg_cnt = 130 then
        c_start <= '1';
    else
        c_start <= '0';
    end if;
end process p_data;

-- From EXT to CORE
c_rst <= '0' when reg_cnt /= x"000" else '1';
s_kdin <= kdin;
s_ndin <= ndin;
s_addin <= addin;
s_ptdin <= ptdin;

-- From CORE to EXT
waddr <= std_logic_vector(s_waddr);
dout_val <= '1' when reg_cnt >= x"0C9" and reg_cnt <= x"148" else '0';
val_dout <= dout_val;
dout <= s_dout when dout_val = '1' else '0';
tagout <= s_tagout when dout_val = '1' else '0';
busy <= '1' when reg_cnt /= x"000" else '0';

end rtl;

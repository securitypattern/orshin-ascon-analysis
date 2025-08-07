------------------------------------------------------------------
-- Copyright (c) 2025, Security Pattern                         --
------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.finish;

entity tb_cw305_ascon_bridge_top is
end tb_cw305_ascon_bridge_top;

architecture behavior of tb_cw305_ascon_bridge_top is

    -- component Declaration for the Unit Under Test (UUT)

    component cw305_ascon_bridge
      port( clk         :in  std_logic;
            rst         :in  std_logic;
            sdin        :in  std_logic_vector(32-1 downto 0);
            pdin        :in  std_logic_vector(32-1 downto 0);
            init        :in  std_logic;
            start       :in  std_logic;
            waddr       :out std_logic_vector(7 downto 0);
            val_dout    :out std_logic;
            dout        :out std_logic_vector(32-1 downto 0);
            busy        :out std_logic
        );
    end component;

    -- to be connected to DUT inputs
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal sdin : std_logic_vector(32-1 downto 0) := (others => '0');
    signal sdin_c : std_logic_vector(32-1 downto 0) := (others => '0');
    signal pdin : std_logic_vector(32-1 downto 0) := (others => '0');
    signal pdin_c : std_logic_vector(32-1 downto 0) := (others => '0');
    signal init : std_logic := '0';
    signal start : std_logic := '0';

    -- to be connected to DUT outputs
    signal waddr    : std_logic_vector(7 downto 0);
    signal dout     : std_logic_vector(32-1 downto 0);
    signal dout_c   : std_logic_vector(32-1 downto 0);
    signal val_dout : std_logic;
    signal busy     : std_logic;

    -- Clock period definitions
    constant clk_period : time := 10 ns;

     signal input_key    : std_logic_vector(127 downto 0) := X"732C0DB0CEB900BF3907D4043479F720";
     signal input_nonce  : std_logic_vector(127 downto 0) := X"816FA5D69F1FDF69B3280851322CDE2F";
     signal input_ad     : std_logic_vector(127 downto 0) := X"D4E4551F17B37F00B6AF7A3FA5184C3E";
     signal input_pt     : std_logic_vector(127 downto 0) := X"FB685326E48AB6D801995F9023920510";
    -- Expected CT  9329a00029d07c05a1cfb5d1518ad6a9
    -- Expected MAC 43a0869091f31af7c20b29d6273fc157
--    signal input_key    : std_logic_vector(127 downto 0) := X"00000000000000000000000000000000";
--    signal input_nonce  : std_logic_vector(127 downto 0) := X"00000000000000000000000000000000";
--    signal input_ad     : std_logic_vector(127 downto 0) := X"00000000000000000000000000000000";
--    signal input_pt     : std_logic_vector(127 downto 0) := X"00000000000000000000000000000000";
    -- Expected CT  50e92d5dc831900ae5be0acb152664a9
    -- Expected MAC 118869e23ce0cc8a57263c84ba3aba36

begin
    -- Instantiate the Unit Under Test (UUT)
    uut : cw305_ascon_bridge port map(
        clk => clk,
        rst => rst,
        sdin => sdin_c,
        pdin => pdin_c,
        init => init,
        start => start,
        waddr => waddr,
        val_dout => val_dout,
        dout => dout_c,
        busy => busy
    );

    sdin_c <= sdin(7 downto 0) & sdin(15 downto 8) & sdin(23 downto 16) & sdin(31 downto 24);
    pdin_c <= pdin(7 downto 0) & pdin(15 downto 8) & pdin(23 downto 16) & pdin(31 downto 24);
    dout <= dout_c(7 downto 0) & dout_c(15 downto 8) & dout_c(23 downto 16) & dout_c(31 downto 24);

    -- Clock process definitions
    clk_process : process
    begin
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process;

    -- memory register
    p_mem : process (clk, rst)
    begin  -- process p_main
        if rst = '0' then                 -- asynchronous rst (active low)
            sdin <= x"00000000";
            pdin <= x"00000000";
        elsif clk'event and clk = '1' then  -- rising clk edge
            sdin <= x"00000000";
            pdin <= x"00000000";
            case waddr is
                when x"00" =>
                    sdin <= input_key(127 downto 96);
                when x"01" =>
                    sdin <= input_key( 95 downto 64);
                when x"02" =>
                    sdin <= input_key( 63 downto 32);
                when x"03" =>
                    sdin <= input_key( 31 downto  0);
                when x"04" =>
                    pdin <= input_nonce(127 downto 96);
                when x"05" =>
                    pdin <= input_nonce( 95 downto 64);
                when x"06" =>
                    pdin <= input_nonce( 63 downto 32);
                when x"07" =>
                    pdin <= input_nonce( 31 downto  0);
                when x"08" =>
                    pdin <= input_ad(127 downto 96);
                when x"09" =>
                    pdin <= input_ad( 95 downto 64);
                when x"0a" =>
                    pdin <= input_ad( 63 downto 32);
                when x"0b" =>
                    pdin <= input_ad( 31 downto  0);
                when x"0c" =>
                    pdin <= input_pt(127 downto 96);
                when x"0d" =>
                    pdin <= input_pt( 95 downto 64);
                when x"0e" =>
                    pdin <= input_pt( 63 downto 32);
                when x"0f" =>
                    pdin <= input_pt( 31 downto  0);
                when others =>
                    sdin <= x"00000000";
                    pdin <= x"00000000";
            end case;
        end if;
    end process p_mem;

    -- Stimulus process
    stim_proc : process
    begin
        -- Read the number of testvectors to execute
        report "START";
        wait for 1 ns;
        wait for clk_period * 10;
        rst <= '0';
        wait for clk_period * 10;
        rst <= '1';
        wait for clk_period * 10;
        wait for 100 ps;
        -- 
        init <= '1';
        wait for clk_period;
        init <= '0';
        wait for clk_period * 5;
        -- 
        start <= '1';
        wait for clk_period;
        start <= '0';
        wait for clk_period;
        wait until busy = '0';
        wait for clk_period;
        wait for 100 ps;
        finish;
    end process;

end;
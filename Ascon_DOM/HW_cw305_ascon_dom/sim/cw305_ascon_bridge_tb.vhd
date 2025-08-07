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
    end component;

    constant DATA_WIDTH : integer := 64;

    -- to be connected to DUT inputs
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal sdin : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal sdin_c : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal pdin : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal pdin_c : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal rdin : std_logic_vector(320-1 downto 0) := (others => '0');
    signal rdin_c : std_logic_vector(320-1 downto 0) := (others => '0');
    signal init : std_logic := '0';
    signal start : std_logic := '0';

    -- to be connected to DUT outputs
    signal waddr    : std_logic_vector(7 downto 0);
    signal wraddr   : std_logic_vector(7 downto 0);
    signal dout     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal dout_c   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal val_dout : std_logic;
    signal busy     : std_logic;

    -- Clock period definitions
    constant clk_period : time := 10 ns;

    signal input_key    : std_logic_vector(256-1 downto 0) :=   X"00000000" & X"732C0DB0" & 
                                                                X"00000000" & X"CEB900BF" & 
                                                                X"00000000" & X"3907D404" & 
                                                                X"00000000" & X"3479F720";
    signal input_nonce  : std_logic_vector(256-1 downto 0) :=   X"00000000" & X"816FA5D6" & 
                                                                X"00000000" & X"9F1FDF69" & 
                                                                X"00000000" & X"B3280851" & 
                                                                X"00000000" & X"322CDE2F";
    signal input_ad     : std_logic_vector(256-1 downto 0) :=   X"00000000" & X"D4E4551F" & 
                                                                X"00000000" & X"17B37F00" & 
                                                                X"00000000" & X"B6AF7A3F" & 
                                                                X"00000000" & X"A5184C3E";
    signal input_pt     : std_logic_vector(256-1 downto 0) :=   X"00000000" & X"FB685326" & 
                                                                X"00000000" & X"E48AB6D8" & 
                                                                X"00000000" & X"01995F90" & 
                                                                X"00000000" & X"23920510";
    -- Expected CT  9329a00029d07c05a1cfb5d1518ad6a9
    -- 24c4f7d2 XOR b7ed57d2 -> 9329A000
    -- Expected MAC 43a0869091f31af7c20b29d6273fc157
    -- d37903bf XOR 90d9852f -> 43A08690

    -- #### Authenticated Encryption
    -- #### Msg 624
    -- key     = 3325CEC43D92842D9F48BFD4FB72AD42
    -- npub    = 4E2CE7CC4EBAA431ADF82CD3BBA1B84E
    -- ad      = E628EDAC5A76D4725D795FD0C2750A72
    -- pt      = 9567D7D1654F9F1CD184A025324D2EBE
    -- ct      = 725F58E30B9979ED4A80644FF86ECD71
    -- tag     = 91C514848EEBD80605E71D9B27A16637
    -- # Instruction: Opcode=Load Key
    -- INS = 4000000000000000
    -- # Info :                      Key, EOI=1 EOT=1, Last=1, Length=16 bytes
    -- HDR = C700001000000000
    -- DAT = 9714E8F2A4312636117ED5862CEC51AB731D7FB4EC55C0602A918B41D1E32603
    -- # Instruction: Opcode=Activate Key
    -- INS = 7000000000000000
    -- # Instruction: Opcode=Authenticated Encryption
    -- INS = 2000000000000000
    -- # Info :                     Npub, EOI=0 EOT=1, Last=0, Length=16 bytes
    -- HDR = D200001000000000
    -- DAT = 6AFDDC9624D13B5ADDB974F49303D0C5921CC5123FE4E9C166634305DDC2FB4B
    -- # Info :          Associated Data, EOI=0 EOT=1, Last=0, Length=16 bytes
    -- HDR = 1200001000000000
    -- DAT = A66BCE974043233BF1153AB1AB63EEC3DE363185834F6E55D0A220DA12D72AA8
    -- # Info :                Plaintext, EOI=1 EOT=1, Last=1, Length=16 bytes
    -- HDR = 4700001000000000
    -- DAT = A4FF220B3198F5DA5F61965C3A2E094033D7CB5BE2536B7EA27BDCCA9036F274
    -- signal input_key    : std_logic_vector(256-1 downto 0) :=  X"9714E8F2A4312636117ED5862CEC51AB731D7FB4EC55C0602A918B41D1E32603";
    -- signal input_nonce  : std_logic_vector(256-1 downto 0) :=  X"6AFDDC9624D13B5ADDB974F49303D0C5921CC5123FE4E9C166634305DDC2FB4B";
    -- signal input_ad     : std_logic_vector(256-1 downto 0) :=  X"A66BCE974043233BF1153AB1AB63EEC3DE363185834F6E55D0A220DA12D72AA8";
    -- signal input_pt     : std_logic_vector(256-1 downto 0) :=  X"A4FF220B3198F5DA5F61965C3A2E094033D7CB5BE2536B7EA27BDCCA9036F274";


    -- signal input_key    : std_logic_vector(256-1 downto 0) := (others=>'0');
    -- signal input_nonce  : std_logic_vector(256-1 downto 0) := (others=>'0');
    -- signal input_ad     : std_logic_vector(256-1 downto 0) := (others=>'0');
    -- signal input_pt     : std_logic_vector(256-1 downto 0) := (others=>'0');
    -- Expected CT  50e92d5dc831900ae5be0acb152664a9
    -- e4350128 XOR b4dc2c75 -> 50E92D5D
    -- Expected MAC 118869e23ce0cc8a57263c84ba3aba36
    -- fa0b310a XOR eb8358e8 -> 118869E2

    signal input_rnd    : std_logic_vector(320-1 downto 0) :=   X"00010203" & X"04050607" & 
                                                                X"08090a0b" & X"0c0d0e0f" & 
                                                                X"10111213" & X"14151617" & 
                                                                X"18191a1b" & X"1c1d1e1f" &
                                                                X"20212223" & X"24252627"; 

begin
    -- Instantiate the Unit Under Test (UUT)
    uut : cw305_ascon_bridge port map(
        clk => clk,
        rst => rst,
        sdin => sdin_c,
        pdin => pdin_c,
        rdin => rdin_c,
        init => init,
        start => start,
        waddr => waddr,
        wraddr => wraddr,
        val_dout => val_dout,
        dout => dout_c,
        busy => busy
    );

    -- TODO this is not parametric
    sdin_c <= sdin(39 downto 32) & sdin(47 downto 40) & sdin(55 downto 48) & sdin(63 downto 56) & sdin(7 downto 0) & sdin(15 downto 8) & sdin(23 downto 16) & sdin(31 downto 24);
    pdin_c <= pdin(39 downto 32) & pdin(47 downto 40) & pdin(55 downto 48) & pdin(63 downto 56) & pdin(7 downto 0) & pdin(15 downto 8) & pdin(23 downto 16) & pdin(31 downto 24);
    dout <= dout_c(39 downto 32) & dout_c(47 downto 40) & dout_c(55 downto 48) & dout_c(63 downto 56) & dout_c(7 downto 0) & dout_c(15 downto 8) & dout_c(23 downto 16) & dout_c(31 downto 24);
    rdin_c <=   rdin(319-24 downto 320-32)  & rdin(319-16 downto 320-24) & rdin(319-8 downto 320-16) & rdin(319 downto 320-8) &
                rdin(287-24 downto 288-32)  & rdin(287-16 downto 288-24) & rdin(287-8 downto 288-16) & rdin(287 downto 288-8) &
                rdin(255-24 downto 256-32)  & rdin(255-16 downto 256-24) & rdin(255-8 downto 256-16) & rdin(255 downto 256-8) &
                rdin(223-24 downto 224-32)  & rdin(223-16 downto 224-24) & rdin(223-8 downto 224-16) & rdin(223 downto 224-8) &
                rdin(191-24 downto 192-32)  & rdin(191-16 downto 192-24) & rdin(191-8 downto 192-16) & rdin(191 downto 192-8) &
                rdin(159-24 downto 160-32)  & rdin(159-16 downto 160-24) & rdin(159-8 downto 160-16) & rdin(159 downto 160-8) &
                rdin(127-24 downto 128-32)  & rdin(127-16 downto 128-24) & rdin(127-8 downto 128-16) & rdin(127 downto 128-8) &
                rdin( 95-24 downto  96-32)  & rdin( 95-16 downto  96-24) & rdin( 95-8 downto  96-16) & rdin( 95 downto  96-8) &
                rdin( 63-24 downto  64-32)  & rdin( 63-16 downto  64-24) & rdin( 63-8 downto  64-16) & rdin( 63 downto  64-8) &
                rdin( 31-24 downto  32-32)  & rdin( 31-16 downto  32-24) & rdin( 31-8 downto  32-16) & rdin( 31 downto  32-8);
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
            sdin <= (others=>'0');
            pdin <= (others=>'0');
        elsif clk'event and clk = '1' then  -- rising clk edge
            sdin <= (others=>'0');
            pdin <= (others=>'0');
            case waddr is
                when x"00" =>
                    sdin <= input_key(255 downto 192);
                when x"01" =>
                    sdin <= input_key(191 downto 128);
                when x"02" =>
                    sdin <= input_key(127 downto  64);
                when x"03" =>
                    sdin <= input_key( 63 downto   0);
                when x"04" =>
                    pdin <= input_nonce(255 downto 192);
                when x"05" =>
                    pdin <= input_nonce(191 downto 128);
                when x"06" =>
                    pdin <= input_nonce(127 downto  64);
                when x"07" =>
                    pdin <= input_nonce( 63 downto   0);
                when x"08" =>
                    pdin <= input_ad(255 downto 192);
                when x"09" =>
                    pdin <= input_ad(191 downto 128);
                when x"0a" =>
                    pdin <= input_ad(127 downto  64);
                when x"0b" =>
                    pdin <= input_ad( 63 downto   0);
                when x"0c" =>
                    pdin <= input_pt(255 downto 192);
                when x"0d" =>
                    pdin <= input_pt(191 downto 128);
                when x"0e" =>
                    pdin <= input_pt(127 downto  64);
                when x"0f" =>
                    pdin <= input_pt( 63 downto   0);
                when others =>
                    sdin <= (others=>'0');
                    pdin <= (others=>'0');
            end case;
        end if;
    end process p_mem;

    -- Random memory register
    r_mem : process (clk, rst)
    begin  -- process p_main
        if rst = '0' then                 -- asynchronous rst (active low)
            rdin <= (others=>'0');
        elsif clk'event and clk = '1' then  -- rising clk edge
            rdin <= (others=>'0');
            case wraddr is
                when x"00" =>
                    rdin <= input_rnd(320-1 downto 0);
                when x"01" =>
                    rdin <= input_rnd( 8-1 downto 0) & input_rnd(320-1 downto  8);
                when x"02" =>
                    rdin <= input_rnd(16-1 downto 0) & input_rnd(320-1 downto 16);
                when x"03" =>
                    rdin <= input_rnd(24-1 downto 0) & input_rnd(320-1 downto 24);
                when x"04" =>
                    rdin <= input_rnd(32-1 downto 0) & input_rnd(320-1 downto 32);
                when x"05" =>
                    rdin <= input_rnd(40-1 downto 0) & input_rnd(320-1 downto 40);
                when x"06" =>
                    rdin <= input_rnd(48-1 downto 0) & input_rnd(320-1 downto 48);
                when x"07" =>
                    rdin <= input_rnd(56-1 downto 0) & input_rnd(320-1 downto 56);
                when x"08" =>
                    rdin <= input_rnd(64-1 downto 0) & input_rnd(320-1 downto 64);
                when x"09" =>
                    rdin <= input_rnd(72-1 downto 0) & input_rnd(320-1 downto 72);
                when x"0a" =>
                    rdin <= input_rnd(80-1 downto 0) & input_rnd(320-1 downto 80);
                when x"0b" =>
                    rdin <= input_rnd(88-1 downto 0) & input_rnd(320-1 downto 88);
                when others =>
                    rdin <= (others=>'0');
            end case;
        end if;
    end process r_mem;

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
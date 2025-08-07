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
    end component;

    -- to be connected to DUT inputs
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';
    signal kdin : std_logic_vector(4 downto 0) := (others => '0');
    signal ndin : std_logic_vector(4 downto 0) := (others => '0');
    signal addin : std_logic_vector(4 downto 0) := (others => '0');
    signal ptdin : std_logic_vector(4 downto 0) := (others => '0');
    signal start : std_logic := '0';

    -- to be connected to DUT outputs
    signal waddr    : std_logic_vector(11 downto 0);
    signal dout     : std_logic;
    signal tagout   : std_logic;
    signal val_dout : std_logic;
    signal busy     : std_logic;

    signal intaddr  : integer range 0 to 255;

    -- Clock period definitions
    constant clk_period : time := 10 ns;
    
    signal output_ct    : std_logic_vector(128-1 downto 0);
    signal output_tag   : std_logic_vector(128-1 downto 0);

    signal input_key    : std_logic_vector(128-1 downto 0) :=   X"732C0DB0" & 
                                                                X"CEB900BF" & 
                                                                X"3907D404" & 
                                                                X"3479F720";
    signal input_nonce  : std_logic_vector(128-1 downto 0) :=   X"816FA5D6" & 
                                                                X"9F1FDF69" & 
                                                                X"B3280851" & 
                                                                X"322CDE2F";
    signal input_ad     : std_logic_vector(128-1 downto 0) :=   X"D4E4551F" & 
                                                                X"17B37F00" & 
                                                                X"B6AF7A3F" & 
                                                                X"A5184C3E";
    signal input_pt     : std_logic_vector(128-1 downto 0) :=   X"FB685326" & 
                                                                X"E48AB6D8" & 
                                                                X"01995F90" & 
                                                                X"23920510";
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

    -- signal input_rnd    : std_logic_vector(320-1 downto 0) :=   X"00010203" & X"04050607" & 
    --                                                             X"08090a0b" & X"0c0d0e0f" & 
    --                                                             X"10111213" & X"14151617" & 
    --                                                             X"18191a1b" & X"1c1d1e1f" &
    --                                                             X"20212223" & X"24252627"; 

begin
    -- Instantiate the Unit Under Test (UUT)
    uut : cw305_ascon_bridge port map(
        clk => clk,
        rst => rst,
        kdin => kdin,
        ndin => ndin,
        addin => addin,
        ptdin => ptdin,
        start => start,
        waddr => waddr,
        val_dout => val_dout,
        dout => dout,
        tagout => tagout,
        busy => busy
    );

    -- Clock process definitions
    clk_process : process
    begin
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process;

    intaddr <= to_integer(unsigned(waddr));

    -- memory register
    p_mem : process (clk, rst)
    begin  -- process p_main
        if rst = '0' then                 -- asynchronous rst (active low)
            kdin <= (others=>'0');
            ndin <= (others=>'0');
            addin <= (others=>'0');
            ptdin <= (others=>'0');
            output_ct <= (others=>'0');
            output_tag <= (others=>'0');
        elsif clk'event and clk = '1' then  -- rising clk edge
            if intaddr >= 0 and intaddr <= 127 then
                kdin <= "0000" & input_key(127-intaddr);
                ndin <= "0000" & input_nonce(127-intaddr);
                addin <= "0000" & input_ad(127-intaddr);
                ptdin <= "0000" & input_pt(127-intaddr);
            else
                kdin <= (others=>'0');
                ndin <= (others=>'0');
                addin <= (others=>'0');
                ptdin <= (others=>'0');
            end if;
            if val_dout = '1' then
                output_ct(127-intaddr) <= dout;
                output_tag(127-intaddr) <= tagout;
            end if;
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
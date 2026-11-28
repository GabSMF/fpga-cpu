library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity RAM_8x256 is
    port(
        CLK     : in std_logic;
        DIN     : in std_logic_vector(7 downto 0);
        ADDR    : in std_logic_vector(7 downto 0);
        WE      : in std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
    );
end RAM_8x256;

architecture rtl of RAM_8x256 is
    
    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

    -- prog.asm
    signal ram : RAM_t := (
        0   => "10000011", --   3:   ldi ra, 0xff
        1   => "11111111", --   3:   255
        2   => "10000111", --   4:   ldi rb, 0x01
        3   => "00000001", --   4:   1
        4   => "00000001", --   5:   add ra, rb
        5   => "10000011", --   6:   ldi ra, 0x03
        6   => "00000011", --   6:   3
        7   => "10000111", --   7:   ldi rb, 0x05
        8   => "00000101", --   7:   5
        9   => "00010001", --   8:   sub ra, rb
        10  => "10000011", --   9:   ldi ra, 0x0a
        11  => "00001010", --   9:   10
        12  => "10110100", --  10:   mov rb, ra
        13  => "00010001", --  11:   sub ra, rb
        14  => "10000011", --  12:   ldi ra, 0x0a
        15  => "00001010", --  12:   10
        16  => "10000010", --  13:   st  ra, 0xff
        17  => "11111111", --  13:   255
        18  => "11111111", --  14:   halt
        others => (others => '0')
    );

begin

    process(CLK) is
    begin
        if falling_edge(CLK) then
            if WE = '1' then
                ram(to_integer(unsigned(ADDR))) <= DIN;
            end if;
            read_address <= ADDR;
        end if;
    end process;

    DOUT    <= ram(to_integer(unsigned(read_address)));
    POS_255 <= ram(255);

end architecture;

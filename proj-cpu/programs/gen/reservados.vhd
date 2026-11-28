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
        0   => "10000011", --   6:      ldi ra, 0x11
        1   => "00010001", --   6:      17
        2   => "10000111", --   7:      ldi rb, 0x22
        3   => "00100010", --   7:      34
        4   => "10001011", --   8:      ldi rc, 0x33
        5   => "00110011", --   8:      51
        6   => "10111100", --   9:      mov rd, ra
        7   => "00011101", --  10:      sub rd, rb
        8   => "10001111", --  11:      ldi rd, 0x44
        9   => "01000100", --  11:      68
        10  => "00100010", --  12:      .byte 0x22
        11  => "00100011", --  13:      .byte 0x23
        12  => "00100110", --  14:      .byte 0x26
        13  => "00100111", --  15:      .byte 0x27
        14  => "00101010", --  16:      .byte 0x2a
        15  => "00101011", --  17:      .byte 0x2b
        16  => "00101110", --  18:      .byte 0x2e
        17  => "00101111", --  19:      .byte 0x2f
        18  => "01010001", --  20:      .byte 0x51
        19  => "01010010", --  21:      .byte 0x52
        20  => "01010011", --  22:      .byte 0x53
        21  => "01010101", --  23:      .byte 0x55
        22  => "01010110", --  24:      .byte 0x56
        23  => "01010111", --  25:      .byte 0x57
        24  => "01011001", --  26:      .byte 0x59
        25  => "01011010", --  27:      .byte 0x5a
        26  => "01011011", --  28:      .byte 0x5b
        27  => "01011101", --  29:      .byte 0x5d
        28  => "01011110", --  30:      .byte 0x5e
        29  => "01011111", --  31:      .byte 0x5f
        30  => "11000100", --  32:      .byte 0xc4
        31  => "11001000", --  33:      .byte 0xc8
        32  => "11001100", --  34:      .byte 0xcc
        33  => "11100011", --  35:      .byte 0xe3
        34  => "11100111", --  36:      .byte 0xe7
        35  => "11101011", --  37:      .byte 0xeb
        36  => "11101111", --  38:      .byte 0xef
        37  => "11110001", --  39:      .byte 0xf1
        38  => "11110010", --  40:      .byte 0xf2
        39  => "11110011", --  41:      .byte 0xf3
        40  => "11110100", --  42:      .byte 0xf4
        41  => "11110101", --  43:      .byte 0xf5
        42  => "11110110", --  44:      .byte 0xf6
        43  => "11110111", --  45:      .byte 0xf7
        44  => "11111000", --  46:      .byte 0xf8
        45  => "11111001", --  47:      .byte 0xf9
        46  => "11111010", --  48:      .byte 0xfa
        47  => "11111011", --  49:      .byte 0xfb
        48  => "11111100", --  50:      .byte 0xfc
        49  => "11111101", --  51:      .byte 0xfd
        50  => "11111110", --  52:      .byte 0xfe
        51  => "10001111", --  53:      ldi rd, 0xf3
        52  => "11110011", --  53:      243
        53  => "10101111", --  54:      str rd, [rd]
        54  => "10001111", --  55:      ldi rd, 0xf0
        55  => "11110000", --  55:      240
        56  => "10100011", --  56:      str ra, [rd]
        57  => "00101100", --  57:      inc rd
        58  => "10100111", --  58:      str rb, [rd]
        59  => "00101100", --  59:      inc rd
        60  => "10101011", --  60:      str rc, [rd]
        61  => "10000011", --  61:      ldi ra, @fim
        62  => "01000110", --  61:      70
        63  => "10000111", --  62:      ldi rb, 0x22
        64  => "00100010", --  62:      34
        65  => "10001011", --  63:      ldi rc, 0x11
        66  => "00010001", --  63:      17
        67  => "00011001", --  64:      sub rc, rb
        68  => "11010000", --  65:      bcs ra
        69  => "11111111", --  66:      halt
        70  => "10000011", --  67: fim: ldi ra, 0x5a
        71  => "01011010", --  67: fim: 90
        72  => "10000010", --  68:      st  ra, 255
        73  => "11111111", --  68:      255
        74  => "11111111", --  69:      halt
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

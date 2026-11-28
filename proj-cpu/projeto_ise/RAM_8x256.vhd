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
        0   => "10000011", --  28: inicio:  ldi ra, 0
        1   => "00000000", --  28: inicio:  0
        2   => "10000111", --  29:          ldi rb, 1
        3   => "00000001", --  29:          1
        4   => "10001011", --  30:          ldi rc, @vet
        5   => "11000000", --  30:          192
        6   => "10000010", --  31:          st  ra, @io
        7   => "11111111", --  31:          255
        8   => "10100010", --  32:          str ra, [rc]
        9   => "00101000", --  33:          inc rc
        10  => "10000110", --  34: laco:    st  rb, @io
        11  => "11111111", --  34: laco:    255
        12  => "10100110", --  35:          str rb, [rc]
        13  => "00101000", --  36:          inc rc
        14  => "10111100", --  37:          mov rd, ra
        15  => "00001101", --  38:          add rd, rb
        16  => "10000011", --  39:          ldi ra, @fase2
        17  => "00010111", --  39:          23
        18  => "11010000", --  40:          bcs ra
        19  => "10110001", --  41:          mov ra, rb
        20  => "10110111", --  42:          mov rb, rd
        21  => "11000000", --  43:          jmp @laco
        22  => "00001010", --  43:          10
        23  => "10001111", --  47: fase2:   ldi rd, @vet
        24  => "11000000", --  47: fase2:   192
        25  => "10000111", --  48:          ldi rb, 0
        26  => "00000000", --  48:          0
        27  => "10010011", --  49: impar:   ldr ra, [rd]
        28  => "10001100", --  50:          push rd
        29  => "10001111", --  51:          ldi rd, 1
        30  => "00000001", --  51:          1
        31  => "00110011", --  52:          and ra, rd
        32  => "10001101", --  53:          pop rd
        33  => "10000011", --  54:          ldi ra, @par
        34  => "00100101", --  54:          37
        35  => "11000010", --  55:          bz  ra
        36  => "00100100", --  56:          inc rb
        37  => "00101100", --  57: par:     inc rd
        38  => "10110011", --  58:          mov ra, rd
        39  => "00010010", --  59:          sub ra, rc
        40  => "10000011", --  60:          ldi ra, @impar
        41  => "00011011", --  60:          27
        42  => "11010011", --  61:          bneq ra
        43  => "10000110", --  62:          st  rb, @io
        44  => "11111111", --  62:          255
        45  => "10001111", --  66:          ldi rd, @vet
        46  => "11000000", --  66:          192
        47  => "10000111", --  67:          ldi rb, 0
        48  => "00000000", --  67:          0
        49  => "10010011", --  68: grande:  ldr ra, [rd]
        50  => "01110010", --  69:          lsl ra
        51  => "10000011", --  70:          ldi ra, @pequeno
        52  => "00110111", --  70:          55
        53  => "11010001", --  71:          bcc ra
        54  => "00100100", --  72:          inc rb
        55  => "00101100", --  73: pequeno: inc rd
        56  => "10110011", --  74:          mov ra, rd
        57  => "00010010", --  75:          sub ra, rc
        58  => "10000011", --  76:          ldi ra, @fase4
        59  => "00111111", --  76:          63
        60  => "11010010", --  77:          beq ra
        61  => "11000000", --  78:          jmp @grande
        62  => "00110001", --  78:          49
        63  => "10000110", --  79: fase4:   st  rb, @io
        64  => "11111111", --  79: fase4:   255
        65  => "00101001", --  83:          dec rc
        66  => "10010010", --  84:          ldr ra, [rc]
        67  => "10110100", --  85:          mov rb, ra
        68  => "01110100", --  86:          rol rb
        69  => "01110101", --  87:          ror rb
        70  => "01010100", --  88:          not rb
        71  => "01010100", --  89:          not rb
        72  => "00010100", --  90:          sub rb, ra
        73  => "10001111", --  91:          ldi rd, @falhou
        74  => "01010001", --  91:          81
        75  => "11001111", --  92:          bnz rd
        76  => "10000011", --  93:          ldi ra, @ok
        77  => "10101010", --  93:          170
        78  => "10000010", --  94:          st  ra, @io
        79  => "11111111", --  94:          255
        80  => "11111111", --  95:          halt
        81  => "10000011", --  96: falhou:  ldi ra, @erro
        82  => "11101110", --  96: falhou:  238
        83  => "10000010", --  97:          st  ra, @io
        84  => "11111111", --  97:          255
        85  => "11111111", --  98:          halt
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

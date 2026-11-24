library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RAM de 256 x 8 bits com a mesma interface fornecida pelo professor
-- (CLK, DIN, ADDR, WE, DOUT, POS_255) para troca direta de programas.
entity RAM_8x256 is
    port(
        CLK     : in  std_logic;
        DIN     : in  std_logic_vector(7 downto 0);
        ADDR    : in  std_logic_vector(7 downto 0);
        WE      : in  std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
    );
end entity RAM_8x256;

architecture rtl of RAM_8x256 is

    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

    -- Programa de demonstracao inicial para teste na placa (exercita todas as 6 flags + MEM[255] + HALT):
    --   0x00: ldi Ra, 0xFF   ; Ra <- 255
    --   0x02: ldi Rb, 0x01   ; Rb <- 1
    --   0x04: add Ra, Rb     ; Ra <- 0  -> Z=1, N=0, OVF=1, EQ=0, GT=1, SM=0
    --   0x05: ldi Ra, 0x03   ; Ra <- 3  (flags preservadas)
    --   0x07: ldi Rb, 0x05   ; Rb <- 5  (flags preservadas)
    --   0x09: sub Ra, Rb     ; Ra <- 0xFE -> Z=0, N=1, OVF=1, EQ=0, GT=0, SM=1
    --   0x0A: ldi Ra, 0x0A   ; Ra <- 10 (flags preservadas)
    --   0x0C: mov Rb, Ra     ; Rb <- 10 (flags preservadas)
    --   0x0D: sub Ra, Rb     ; Ra <- 0  -> Z=1, N=0, OVF=0, EQ=1, GT=0, SM=0
    --   0x0E: ldi Ra, 0x0A   ; Ra <- 10 (flags preservadas)
    --   0x10: st  Ra, 0xFF   ; MEM[255] <- 10
    --   0x12: halt           ; Fim do programa
    signal ram : RAM_t := (
        0  => "10000011", -- ldi Ra, 0xFF
        1  => "11111111", -- 255
        2  => "10000111", -- ldi Rb, 0x01
        3  => "00000001", -- 1
        4  => "00000001", -- add Ra, Rb  (Z=1, OVF=1, GT=1)
        5  => "10000011", -- ldi Ra, 0x03
        6  => "00000011", -- 3
        7  => "10000111", -- ldi Rb, 0x05
        8  => "00000101", -- 5
        9  => "00010001", -- sub Ra, Rb  (N=1, OVF=1, SM=1)
        10 => "10000011", -- ldi Ra, 0x0A
        11 => "00001010", -- 10
        12 => "10110100", -- mov Rb, Ra
        13 => "00010001", -- sub Ra, Rb  (Z=1, EQ=1)
        14 => "10000011", -- ldi Ra, 0x0A
        15 => "00001010", -- 10
        16 => "10000010", -- st Ra, 0xFF
        17 => "11111111", -- 255
        18 => "11111111", -- halt
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

end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pacote do LCD: tipos e funcoes de texto.
--
-- rom_str, to_std_logic_vector e to_bcd vem do arquivo do professor
-- (proj-cpu/character_to_slv_v2.txt). Mudancas: decimal_size foi escrita aqui
-- (o trecho original a usava sem defini-la) e foi incluida a tabela TEXTO_IR,
-- versao completa da TEXT_MAP_ROM do professor para a ISA atual.
package lcd_pkg is

    -- linha de 16 caracteres = 32 nibbles (nibble alto e baixo de cada caractere,
    -- na ordem em que sao enviados ao LCD no modo de 4 bits)
    type rom_str is array (0 to 31) of std_logic_vector(3 downto 0);

    function to_std_logic_vector(a : string) return rom_str;
    function decimal_size(n : natural) return natural;
    function to_bcd(Binary : unsigned) return unsigned;
    function hex_ascii(n : std_logic_vector(3 downto 0)) return std_logic_vector;

    -- Modelos da linha 1 indexados pelo IR (gerados por tools/cpu8.py lcdrom).
    -- '#' e '$' marcam o nibble alto e baixo do byte adicional (ldi, st, jmp).
    type texto_ir_t is array (0 to 255) of rom_str;

end package lcd_pkg;

package body lcd_pkg is

    -- do professor: string de ate 16 caracteres (indice a partir de 1) -> 32 nibbles
    FUNCTION to_std_logic_vector(a : STRING) RETURN rom_str IS
        VARIABLE chr2slv               : std_logic_vector(7 DOWNTO 0);
        VARIABLE ret                   : rom_str;
    BEGIN
        FOR i IN a'RANGE LOOP
            chr2slv              := std_logic_vector(to_unsigned(CHARACTER'pos(a(i)), 8));
            ret(2 * (i - 1) + 0) := chr2slv(7 DOWNTO 4);
            ret(2 * (i - 1) + 1) := chr2slv(3 DOWNTO 0);
        END LOOP;
        RETURN ret;
    END FUNCTION to_std_logic_vector;

    -- quantidade de digitos decimais de n (255 -> 3)
    function decimal_size(n : natural) return natural is
        variable v : natural := n;
        variable d : natural := 1;
    begin
        while v >= 10 loop
            v := v / 10;
            d := d + 1;
        end loop;
        return d;
    end function decimal_size;

    -- do professor: binario -> BCD (double dabble). 8 bits -> 3 digitos (12 bits)
    FUNCTION to_bcd(Binary : unsigned) RETURN unsigned IS
        VARIABLE b             : unsigned(Binary'LENGTH - 1 DOWNTO 0) := Binary;
        CONSTANT DIGITS        : NATURAL := decimal_size(2 ** Binary'LENGTH - 1);
        VARIABLE bcd           : unsigned(DIGITS * 4 - 1 DOWNTO 0) := (OTHERS => '0');
    BEGIN
        FOR i IN b'RANGE LOOP
            -- iterate over each group of 4 bits that comprise a digit
            FOR d IN 0 TO DIGITS - 1 LOOP
                IF bcd(d * 4 + 3 DOWNTO d * 4) >= 5 THEN -- will be 10 to 18 on next shift
                    -- add 3 to make it carry over to next digit on next shift
                    -- (5+3)*2 = 16 = 2#1_0000#
                    bcd(d * 4 + 3 DOWNTO d * 4) := bcd(d * 4 + 3 DOWNTO d * 4) + 3;
                END IF;
            END LOOP;
            -- shift left -> multiply by 2
            bcd := bcd(bcd'LEFT - 1 DOWNTO 0) & b(b'left);
            b   := b(b'LEFT - 1 DOWNTO 0) & '0';
        END LOOP; RETURN bcd;
    END FUNCTION;

    -- nibble -> codigo ASCII do digito hexadecimal ('0'..'9', 'A'..'F')
    function hex_ascii(n : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        if unsigned(n) < 10 then
            return "0011" & n;                                  -- 0x30 + n
        else
            return std_logic_vector(to_unsigned(55, 8) + unsigned(n)); -- 0x41 + n - 10
        end if;
    end function hex_ascii;

end package body lcd_pkg;

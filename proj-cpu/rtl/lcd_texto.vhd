library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lcd_pkg.all;

-- Formatacao das duas linhas do LCD (secao 3.1 do enunciado). Combinacional.
--   Linha 1: instrucao do IR em assembly, ex.: "LDI Ra, 0x64", "ADD Ra Rb", "HALT".
--            O byte adicional (ldi, st, jmp) aparece como "--" ate a CPU le-lo (ARG_OK).
--            Antes do primeiro fetch depois do reset (IR_OK = '0'): "RESET".
--            Codigos fora da tabela executam como nop e aparecem como "NOP (0xNN)".
--   Linha 2: "MEM[255] = ddd", com ddd em decimal e zeros a esquerda.
entity lcd_texto is
    port (
        IR      : in  std_logic_vector(7 downto 0);
        ARG     : in  std_logic_vector(7 downto 0);
        IR_OK   : in  std_logic;
        ARG_OK  : in  std_logic;
        POS_255 : in  std_logic_vector(7 downto 0);
        LINHA1  : out rom_str;
        LINHA2  : out rom_str
    );
end entity lcd_texto;

architecture Behavioral of lcd_texto is

    -- Tabela completa (ideia da TEXT_MAP_ROM do professor). Gerada por
    -- "tools/cpu8.py lcdrom" a partir da mesma tabela usada pelo modelo de referencia.
    constant TEXTO_IR : texto_ir_t := (
          0 => to_std_logic_vector("ADD Ra Ra       "), -- 0x00
          1 => to_std_logic_vector("ADD Ra Rb       "), -- 0x01
          2 => to_std_logic_vector("ADD Ra Rc       "), -- 0x02
          3 => to_std_logic_vector("ADD Ra Rd       "), -- 0x03
          4 => to_std_logic_vector("ADD Rb Ra       "), -- 0x04
          5 => to_std_logic_vector("ADD Rb Rb       "), -- 0x05
          6 => to_std_logic_vector("ADD Rb Rc       "), -- 0x06
          7 => to_std_logic_vector("ADD Rb Rd       "), -- 0x07
          8 => to_std_logic_vector("ADD Rc Ra       "), -- 0x08
          9 => to_std_logic_vector("ADD Rc Rb       "), -- 0x09
         10 => to_std_logic_vector("ADD Rc Rc       "), -- 0x0A
         11 => to_std_logic_vector("ADD Rc Rd       "), -- 0x0B
         12 => to_std_logic_vector("ADD Rd Ra       "), -- 0x0C
         13 => to_std_logic_vector("ADD Rd Rb       "), -- 0x0D
         14 => to_std_logic_vector("ADD Rd Rc       "), -- 0x0E
         15 => to_std_logic_vector("ADD Rd Rd       "), -- 0x0F
         16 => to_std_logic_vector("SUB Ra Ra       "), -- 0x10
         17 => to_std_logic_vector("SUB Ra Rb       "), -- 0x11
         18 => to_std_logic_vector("SUB Ra Rc       "), -- 0x12
         19 => to_std_logic_vector("SUB Ra Rd       "), -- 0x13
         20 => to_std_logic_vector("SUB Rb Ra       "), -- 0x14
         21 => to_std_logic_vector("SUB Rb Rb       "), -- 0x15
         22 => to_std_logic_vector("SUB Rb Rc       "), -- 0x16
         23 => to_std_logic_vector("SUB Rb Rd       "), -- 0x17
         24 => to_std_logic_vector("SUB Rc Ra       "), -- 0x18
         25 => to_std_logic_vector("SUB Rc Rb       "), -- 0x19
         26 => to_std_logic_vector("SUB Rc Rc       "), -- 0x1A
         27 => to_std_logic_vector("SUB Rc Rd       "), -- 0x1B
         28 => to_std_logic_vector("SUB Rd Ra       "), -- 0x1C
         29 => to_std_logic_vector("SUB Rd Rb       "), -- 0x1D
         30 => to_std_logic_vector("SUB Rd Rc       "), -- 0x1E
         31 => to_std_logic_vector("SUB Rd Rd       "), -- 0x1F
         32 => to_std_logic_vector("INC Ra          "), -- 0x20
         33 => to_std_logic_vector("DEC Ra          "), -- 0x21
         34 => to_std_logic_vector("NOP (0x22)      "), -- 0x22
         35 => to_std_logic_vector("NOP (0x23)      "), -- 0x23
         36 => to_std_logic_vector("INC Rb          "), -- 0x24
         37 => to_std_logic_vector("DEC Rb          "), -- 0x25
         38 => to_std_logic_vector("NOP (0x26)      "), -- 0x26
         39 => to_std_logic_vector("NOP (0x27)      "), -- 0x27
         40 => to_std_logic_vector("INC Rc          "), -- 0x28
         41 => to_std_logic_vector("DEC Rc          "), -- 0x29
         42 => to_std_logic_vector("NOP (0x2A)      "), -- 0x2A
         43 => to_std_logic_vector("NOP (0x2B)      "), -- 0x2B
         44 => to_std_logic_vector("INC Rd          "), -- 0x2C
         45 => to_std_logic_vector("DEC Rd          "), -- 0x2D
         46 => to_std_logic_vector("NOP (0x2E)      "), -- 0x2E
         47 => to_std_logic_vector("NOP (0x2F)      "), -- 0x2F
         48 => to_std_logic_vector("AND Ra Ra       "), -- 0x30
         49 => to_std_logic_vector("AND Ra Rb       "), -- 0x31
         50 => to_std_logic_vector("AND Ra Rc       "), -- 0x32
         51 => to_std_logic_vector("AND Ra Rd       "), -- 0x33
         52 => to_std_logic_vector("AND Rb Ra       "), -- 0x34
         53 => to_std_logic_vector("AND Rb Rb       "), -- 0x35
         54 => to_std_logic_vector("AND Rb Rc       "), -- 0x36
         55 => to_std_logic_vector("AND Rb Rd       "), -- 0x37
         56 => to_std_logic_vector("AND Rc Ra       "), -- 0x38
         57 => to_std_logic_vector("AND Rc Rb       "), -- 0x39
         58 => to_std_logic_vector("AND Rc Rc       "), -- 0x3A
         59 => to_std_logic_vector("AND Rc Rd       "), -- 0x3B
         60 => to_std_logic_vector("AND Rd Ra       "), -- 0x3C
         61 => to_std_logic_vector("AND Rd Rb       "), -- 0x3D
         62 => to_std_logic_vector("AND Rd Rc       "), -- 0x3E
         63 => to_std_logic_vector("AND Rd Rd       "), -- 0x3F
         64 => to_std_logic_vector("OR Ra Ra        "), -- 0x40
         65 => to_std_logic_vector("OR Ra Rb        "), -- 0x41
         66 => to_std_logic_vector("OR Ra Rc        "), -- 0x42
         67 => to_std_logic_vector("OR Ra Rd        "), -- 0x43
         68 => to_std_logic_vector("OR Rb Ra        "), -- 0x44
         69 => to_std_logic_vector("OR Rb Rb        "), -- 0x45
         70 => to_std_logic_vector("OR Rb Rc        "), -- 0x46
         71 => to_std_logic_vector("OR Rb Rd        "), -- 0x47
         72 => to_std_logic_vector("OR Rc Ra        "), -- 0x48
         73 => to_std_logic_vector("OR Rc Rb        "), -- 0x49
         74 => to_std_logic_vector("OR Rc Rc        "), -- 0x4A
         75 => to_std_logic_vector("OR Rc Rd        "), -- 0x4B
         76 => to_std_logic_vector("OR Rd Ra        "), -- 0x4C
         77 => to_std_logic_vector("OR Rd Rb        "), -- 0x4D
         78 => to_std_logic_vector("OR Rd Rc        "), -- 0x4E
         79 => to_std_logic_vector("OR Rd Rd        "), -- 0x4F
         80 => to_std_logic_vector("NOT Ra          "), -- 0x50
         81 => to_std_logic_vector("NOP (0x51)      "), -- 0x51
         82 => to_std_logic_vector("NOP (0x52)      "), -- 0x52
         83 => to_std_logic_vector("NOP (0x53)      "), -- 0x53
         84 => to_std_logic_vector("NOT Rb          "), -- 0x54
         85 => to_std_logic_vector("NOP (0x55)      "), -- 0x55
         86 => to_std_logic_vector("NOP (0x56)      "), -- 0x56
         87 => to_std_logic_vector("NOP (0x57)      "), -- 0x57
         88 => to_std_logic_vector("NOT Rc          "), -- 0x58
         89 => to_std_logic_vector("NOP (0x59)      "), -- 0x59
         90 => to_std_logic_vector("NOP (0x5A)      "), -- 0x5A
         91 => to_std_logic_vector("NOP (0x5B)      "), -- 0x5B
         92 => to_std_logic_vector("NOT Rd          "), -- 0x5C
         93 => to_std_logic_vector("NOP (0x5D)      "), -- 0x5D
         94 => to_std_logic_vector("NOP (0x5E)      "), -- 0x5E
         95 => to_std_logic_vector("NOP (0x5F)      "), -- 0x5F
         96 => to_std_logic_vector("XOR Ra Ra       "), -- 0x60
         97 => to_std_logic_vector("XOR Ra Rb       "), -- 0x61
         98 => to_std_logic_vector("XOR Ra Rc       "), -- 0x62
         99 => to_std_logic_vector("XOR Ra Rd       "), -- 0x63
        100 => to_std_logic_vector("XOR Rb Ra       "), -- 0x64
        101 => to_std_logic_vector("XOR Rb Rb       "), -- 0x65
        102 => to_std_logic_vector("XOR Rb Rc       "), -- 0x66
        103 => to_std_logic_vector("XOR Rb Rd       "), -- 0x67
        104 => to_std_logic_vector("XOR Rc Ra       "), -- 0x68
        105 => to_std_logic_vector("XOR Rc Rb       "), -- 0x69
        106 => to_std_logic_vector("XOR Rc Rc       "), -- 0x6A
        107 => to_std_logic_vector("XOR Rc Rd       "), -- 0x6B
        108 => to_std_logic_vector("XOR Rd Ra       "), -- 0x6C
        109 => to_std_logic_vector("XOR Rd Rb       "), -- 0x6D
        110 => to_std_logic_vector("XOR Rd Rc       "), -- 0x6E
        111 => to_std_logic_vector("XOR Rd Rd       "), -- 0x6F
        112 => to_std_logic_vector("ROL Ra          "), -- 0x70
        113 => to_std_logic_vector("ROR Ra          "), -- 0x71
        114 => to_std_logic_vector("LSL Ra          "), -- 0x72
        115 => to_std_logic_vector("LSR Ra          "), -- 0x73
        116 => to_std_logic_vector("ROL Rb          "), -- 0x74
        117 => to_std_logic_vector("ROR Rb          "), -- 0x75
        118 => to_std_logic_vector("LSL Rb          "), -- 0x76
        119 => to_std_logic_vector("LSR Rb          "), -- 0x77
        120 => to_std_logic_vector("ROL Rc          "), -- 0x78
        121 => to_std_logic_vector("ROR Rc          "), -- 0x79
        122 => to_std_logic_vector("LSL Rc          "), -- 0x7A
        123 => to_std_logic_vector("LSR Rc          "), -- 0x7B
        124 => to_std_logic_vector("ROL Rd          "), -- 0x7C
        125 => to_std_logic_vector("ROR Rd          "), -- 0x7D
        126 => to_std_logic_vector("LSL Rd          "), -- 0x7E
        127 => to_std_logic_vector("LSR Rd          "), -- 0x7F
        128 => to_std_logic_vector("PUSH Ra         "), -- 0x80
        129 => to_std_logic_vector("POP Ra          "), -- 0x81
        130 => to_std_logic_vector("ST Ra, 0x#$     "), -- 0x82
        131 => to_std_logic_vector("LDI Ra, 0x#$    "), -- 0x83
        132 => to_std_logic_vector("PUSH Rb         "), -- 0x84
        133 => to_std_logic_vector("POP Rb          "), -- 0x85
        134 => to_std_logic_vector("ST Rb, 0x#$     "), -- 0x86
        135 => to_std_logic_vector("LDI Rb, 0x#$    "), -- 0x87
        136 => to_std_logic_vector("PUSH Rc         "), -- 0x88
        137 => to_std_logic_vector("POP Rc          "), -- 0x89
        138 => to_std_logic_vector("ST Rc, 0x#$     "), -- 0x8A
        139 => to_std_logic_vector("LDI Rc, 0x#$    "), -- 0x8B
        140 => to_std_logic_vector("PUSH Rd         "), -- 0x8C
        141 => to_std_logic_vector("POP Rd          "), -- 0x8D
        142 => to_std_logic_vector("ST Rd, 0x#$     "), -- 0x8E
        143 => to_std_logic_vector("LDI Rd, 0x#$    "), -- 0x8F
        144 => to_std_logic_vector("LDR Ra [Ra]     "), -- 0x90
        145 => to_std_logic_vector("LDR Ra [Rb]     "), -- 0x91
        146 => to_std_logic_vector("LDR Ra [Rc]     "), -- 0x92
        147 => to_std_logic_vector("LDR Ra [Rd]     "), -- 0x93
        148 => to_std_logic_vector("LDR Rb [Ra]     "), -- 0x94
        149 => to_std_logic_vector("LDR Rb [Rb]     "), -- 0x95
        150 => to_std_logic_vector("LDR Rb [Rc]     "), -- 0x96
        151 => to_std_logic_vector("LDR Rb [Rd]     "), -- 0x97
        152 => to_std_logic_vector("LDR Rc [Ra]     "), -- 0x98
        153 => to_std_logic_vector("LDR Rc [Rb]     "), -- 0x99
        154 => to_std_logic_vector("LDR Rc [Rc]     "), -- 0x9A
        155 => to_std_logic_vector("LDR Rc [Rd]     "), -- 0x9B
        156 => to_std_logic_vector("LDR Rd [Ra]     "), -- 0x9C
        157 => to_std_logic_vector("LDR Rd [Rb]     "), -- 0x9D
        158 => to_std_logic_vector("LDR Rd [Rc]     "), -- 0x9E
        159 => to_std_logic_vector("LDR Rd [Rd]     "), -- 0x9F
        160 => to_std_logic_vector("STR Ra [Ra]     "), -- 0xA0
        161 => to_std_logic_vector("STR Ra [Rb]     "), -- 0xA1
        162 => to_std_logic_vector("STR Ra [Rc]     "), -- 0xA2
        163 => to_std_logic_vector("STR Ra [Rd]     "), -- 0xA3
        164 => to_std_logic_vector("STR Rb [Ra]     "), -- 0xA4
        165 => to_std_logic_vector("STR Rb [Rb]     "), -- 0xA5
        166 => to_std_logic_vector("STR Rb [Rc]     "), -- 0xA6
        167 => to_std_logic_vector("STR Rb [Rd]     "), -- 0xA7
        168 => to_std_logic_vector("STR Rc [Ra]     "), -- 0xA8
        169 => to_std_logic_vector("STR Rc [Rb]     "), -- 0xA9
        170 => to_std_logic_vector("STR Rc [Rc]     "), -- 0xAA
        171 => to_std_logic_vector("STR Rc [Rd]     "), -- 0xAB
        172 => to_std_logic_vector("STR Rd [Ra]     "), -- 0xAC
        173 => to_std_logic_vector("STR Rd [Rb]     "), -- 0xAD
        174 => to_std_logic_vector("STR Rd [Rc]     "), -- 0xAE
        175 => to_std_logic_vector("STR Rd [Rd]     "), -- 0xAF
        176 => to_std_logic_vector("MOV Ra Ra       "), -- 0xB0
        177 => to_std_logic_vector("MOV Ra Rb       "), -- 0xB1
        178 => to_std_logic_vector("MOV Ra Rc       "), -- 0xB2
        179 => to_std_logic_vector("MOV Ra Rd       "), -- 0xB3
        180 => to_std_logic_vector("MOV Rb Ra       "), -- 0xB4
        181 => to_std_logic_vector("MOV Rb Rb       "), -- 0xB5
        182 => to_std_logic_vector("MOV Rb Rc       "), -- 0xB6
        183 => to_std_logic_vector("MOV Rb Rd       "), -- 0xB7
        184 => to_std_logic_vector("MOV Rc Ra       "), -- 0xB8
        185 => to_std_logic_vector("MOV Rc Rb       "), -- 0xB9
        186 => to_std_logic_vector("MOV Rc Rc       "), -- 0xBA
        187 => to_std_logic_vector("MOV Rc Rd       "), -- 0xBB
        188 => to_std_logic_vector("MOV Rd Ra       "), -- 0xBC
        189 => to_std_logic_vector("MOV Rd Rb       "), -- 0xBD
        190 => to_std_logic_vector("MOV Rd Rc       "), -- 0xBE
        191 => to_std_logic_vector("MOV Rd Rd       "), -- 0xBF
        192 => to_std_logic_vector("JMP 0x#$        "), -- 0xC0
        193 => to_std_logic_vector("JMPR Ra         "), -- 0xC1
        194 => to_std_logic_vector("BZ Ra           "), -- 0xC2
        195 => to_std_logic_vector("BNZ Ra          "), -- 0xC3
        196 => to_std_logic_vector("NOP (0xC4)      "), -- 0xC4
        197 => to_std_logic_vector("JMPR Rb         "), -- 0xC5
        198 => to_std_logic_vector("BZ Rb           "), -- 0xC6
        199 => to_std_logic_vector("BNZ Rb          "), -- 0xC7
        200 => to_std_logic_vector("NOP (0xC8)      "), -- 0xC8
        201 => to_std_logic_vector("JMPR Rc         "), -- 0xC9
        202 => to_std_logic_vector("BZ Rc           "), -- 0xCA
        203 => to_std_logic_vector("BNZ Rc          "), -- 0xCB
        204 => to_std_logic_vector("NOP (0xCC)      "), -- 0xCC
        205 => to_std_logic_vector("JMPR Rd         "), -- 0xCD
        206 => to_std_logic_vector("BZ Rd           "), -- 0xCE
        207 => to_std_logic_vector("BNZ Rd          "), -- 0xCF
        208 => to_std_logic_vector("BCS Ra          "), -- 0xD0
        209 => to_std_logic_vector("BCC Ra          "), -- 0xD1
        210 => to_std_logic_vector("BEQ Ra          "), -- 0xD2
        211 => to_std_logic_vector("BNEQ Ra         "), -- 0xD3
        212 => to_std_logic_vector("BCS Rb          "), -- 0xD4
        213 => to_std_logic_vector("BCC Rb          "), -- 0xD5
        214 => to_std_logic_vector("BEQ Rb          "), -- 0xD6
        215 => to_std_logic_vector("BNEQ Rb         "), -- 0xD7
        216 => to_std_logic_vector("BCS Rc          "), -- 0xD8
        217 => to_std_logic_vector("BCC Rc          "), -- 0xD9
        218 => to_std_logic_vector("BEQ Rc          "), -- 0xDA
        219 => to_std_logic_vector("BNEQ Rc         "), -- 0xDB
        220 => to_std_logic_vector("BCS Rd          "), -- 0xDC
        221 => to_std_logic_vector("BCC Rd          "), -- 0xDD
        222 => to_std_logic_vector("BEQ Rd          "), -- 0xDE
        223 => to_std_logic_vector("BNEQ Rd         "), -- 0xDF
        224 => to_std_logic_vector("BGT Ra          "), -- 0xE0
        225 => to_std_logic_vector("BLT Ra          "), -- 0xE1
        226 => to_std_logic_vector("BNEG Ra         "), -- 0xE2
        227 => to_std_logic_vector("NOP (0xE3)      "), -- 0xE3
        228 => to_std_logic_vector("BGT Rb          "), -- 0xE4
        229 => to_std_logic_vector("BLT Rb          "), -- 0xE5
        230 => to_std_logic_vector("BNEG Rb         "), -- 0xE6
        231 => to_std_logic_vector("NOP (0xE7)      "), -- 0xE7
        232 => to_std_logic_vector("BGT Rc          "), -- 0xE8
        233 => to_std_logic_vector("BLT Rc          "), -- 0xE9
        234 => to_std_logic_vector("BNEG Rc         "), -- 0xEA
        235 => to_std_logic_vector("NOP (0xEB)      "), -- 0xEB
        236 => to_std_logic_vector("BGT Rd          "), -- 0xEC
        237 => to_std_logic_vector("BLT Rd          "), -- 0xED
        238 => to_std_logic_vector("BNEG Rd         "), -- 0xEE
        239 => to_std_logic_vector("NOP (0xEF)      "), -- 0xEF
        240 => to_std_logic_vector("NOP             "), -- 0xF0
        241 => to_std_logic_vector("NOP (0xF1)      "), -- 0xF1
        242 => to_std_logic_vector("NOP (0xF2)      "), -- 0xF2
        243 => to_std_logic_vector("NOP (0xF3)      "), -- 0xF3
        244 => to_std_logic_vector("NOP (0xF4)      "), -- 0xF4
        245 => to_std_logic_vector("NOP (0xF5)      "), -- 0xF5
        246 => to_std_logic_vector("NOP (0xF6)      "), -- 0xF6
        247 => to_std_logic_vector("NOP (0xF7)      "), -- 0xF7
        248 => to_std_logic_vector("NOP (0xF8)      "), -- 0xF8
        249 => to_std_logic_vector("NOP (0xF9)      "), -- 0xF9
        250 => to_std_logic_vector("NOP (0xFA)      "), -- 0xFA
        251 => to_std_logic_vector("NOP (0xFB)      "), -- 0xFB
        252 => to_std_logic_vector("NOP (0xFC)      "), -- 0xFC
        253 => to_std_logic_vector("NOP (0xFD)      "), -- 0xFD
        254 => to_std_logic_vector("NOP (0xFE)      "), -- 0xFE
        255 => to_std_logic_vector("HALT            ") -- 0xFF
    );

    constant TXT_RESET : rom_str := to_std_logic_vector("RESET           ");
    constant TXT_MEM   : rom_str := to_std_logic_vector("MEM[255] = 000  ");

    constant MARCA_ALTO  : std_logic_vector(7 downto 0) := x"23"; -- '#'
    constant MARCA_BAIXO : std_logic_vector(7 downto 0) := x"24"; -- '$'
    constant TRACO       : std_logic_vector(7 downto 0) := x"2D"; -- '-'

begin

    p_linha1 : process(IR, ARG, IR_OK, ARG_OK)
        variable modelo : rom_str;
        variable c      : std_logic_vector(7 downto 0);
    begin
        modelo := TEXTO_IR(to_integer(unsigned(IR)));
        for i in 0 to 15 loop
            c := modelo(2 * i) & modelo(2 * i + 1);
            if c = MARCA_ALTO or c = MARCA_BAIXO then
                if ARG_OK = '0' then
                    c := TRACO;
                elsif c = MARCA_ALTO then
                    c := hex_ascii(ARG(7 downto 4));
                else
                    c := hex_ascii(ARG(3 downto 0));
                end if;
            end if;
            modelo(2 * i)     := c(7 downto 4);
            modelo(2 * i + 1) := c(3 downto 0);
        end loop;
        if IR_OK = '0' then
            LINHA1 <= TXT_RESET;
        else
            LINHA1 <= modelo;
        end if;
    end process p_linha1;

    -- "MEM[255] = " + 3 digitos BCD (posicoes 11, 12 e 13): '0' + digito = 0x3 & digito
    p_linha2 : process(POS_255)
        variable bcd : unsigned(11 downto 0);
        variable t   : rom_str;
    begin
        bcd := to_bcd(unsigned(POS_255));
        t := TXT_MEM;
        t(22) := x"3"; t(23) := std_logic_vector(bcd(11 downto 8));
        t(24) := x"3"; t(25) := std_logic_vector(bcd(7 downto 4));
        t(26) := x"3"; t(27) := std_logic_vector(bcd(3 downto 0));
        LINHA2 <= t;
    end process p_linha2;

end architecture Behavioral;

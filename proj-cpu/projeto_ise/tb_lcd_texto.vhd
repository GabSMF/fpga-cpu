library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.lcd_pkg.all;

-- Testbench da formatacao do LCD (lcd_texto.vhd + funcoes do lcd_pkg).
-- Compara as duas linhas com tb/dados/lcd_texto.txt, gerado pelo modelo de
-- referencia (tools/cpu8.py lcdref): os 256 valores de IR com e sem o byte
-- adicional lido, a tela de RESET e os 256 valores de MEM[255] (BCD).
-- Formato de cada linha: TIPO IR ARG ARG_OK TEXTO(16 caracteres)
--   TIPO 1: linha 1 com IR_OK = 1;  TIPO 0: linha 1 com IR_OK = 0;  TIPO 2: linha 2.
entity tb_lcd_texto is
    generic (DIR_DADOS : string := "dados/");
end entity tb_lcd_texto;

architecture sim of tb_lcd_texto is

    signal ir, arg, pos : std_logic_vector(7 downto 0) := (others => '0');
    signal ir_ok, arg_ok : std_logic := '0';
    signal l1, l2 : rom_str;

    function texto(r : rom_str) return string is
        variable s : string(1 to 16);
    begin
        for i in 0 to 15 loop
            s(i + 1) := character'val(to_integer(unsigned(std_logic_vector'(r(2 * i) & r(2 * i + 1)))));
        end loop;
        return s;
    end function;

begin

    u_texto : entity work.lcd_texto(Behavioral)
        port map (IR => ir, ARG => arg, IR_OK => ir_ok, ARG_OK => arg_ok,
                  POS_255 => pos, LINHA1 => l1, LINHA2 => l2);

    p_teste : process
        file f : text;
        variable l : line;
        variable tipo, v_ir, v_arg, v_ok : integer;
        variable ch : character;
        variable esperado : string(1 to 16);
        variable obtido : string(1 to 16);
        variable erros, casos : natural := 0;
    begin
        file_open(f, DIR_DADOS & "lcd_texto.txt", read_mode);
        while not endfile(f) loop
            readline(f, l);
            next when l'length = 0;
            read(l, tipo); read(l, v_ir); read(l, v_arg); read(l, v_ok);
            read(l, ch);                       -- espaco
            read(l, esperado);
            if tipo = 2 then
                pos <= std_logic_vector(to_unsigned(v_ir, 8));
            else
                ir     <= std_logic_vector(to_unsigned(v_ir, 8));
                arg    <= std_logic_vector(to_unsigned(v_arg, 8));
                if v_ok = 1 then arg_ok <= '1'; else arg_ok <= '0'; end if;
                if tipo = 1 then ir_ok <= '1'; else ir_ok <= '0'; end if;
            end if;
            wait for 10 ns;
            if tipo = 2 then
                obtido := texto(l2);
            else
                obtido := texto(l1);
            end if;
            casos := casos + 1;
            if obtido /= esperado then
                erros := erros + 1;
                if erros <= 10 then
                    report "FAIL: tipo " & integer'image(tipo) & " valor " & integer'image(v_ir)
                           & ": """ & obtido & """ esperado """ & esperado & """" severity error;
                end if;
            end if;
        end loop;
        file_close(f);
        if erros = 0 then
            report "tb_lcd_texto: TODOS OS TESTES PASSARAM! (" & integer'image(casos) & " casos)" severity note;
        else
            report "tb_lcd_texto: " & integer'image(erros) & " ERROS" severity error;
        end if;
        assert false report "fim da simulacao" severity failure;
        wait;
    end process p_teste;

end architecture sim;

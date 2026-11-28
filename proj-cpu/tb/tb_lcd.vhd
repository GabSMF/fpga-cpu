library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench do controlador do LCD (lcd.vhd) com o modelo do display (lcd_modelo.vhd).
-- Confere inicializacao e tempos do UG230 e o texto exibido para varias entradas,
-- trocadas com o LCD ja funcionando (a tela e reescrita continuamente).
entity tb_lcd is
end entity tb_lcd;

architecture sim of tb_lcd is

    signal clk    : std_logic := '0';
    signal ir, arg, pos : std_logic_vector(7 downto 0) := (others => '0');
    signal ir_ok, arg_ok : std_logic := '0';
    signal e, rs, rw, ce : std_logic;
    signal db : std_logic_vector(3 downto 0);
    signal l1, l2 : string(1 to 16);
    signal pronto : boolean;
    signal telas, erros_lcd : natural;
    signal fim : boolean := false;

begin

    clk <= not clk after 10 ns when not fim else '0';

    u_lcd : entity work.lcd(Behavioral)
        port map (CLK => clk, IR => ir, ARG => arg, IR_OK => ir_ok, ARG_OK => arg_ok,
                  POS_255 => pos, LCD_E => e, LCD_RS => rs, LCD_RW => rw, LCD_DB => db, SF_CE0 => ce);

    u_display : entity work.lcd_modelo(sim)
        port map (LCD_E => e, LCD_RS => rs, LCD_RW => rw, LCD_DB => db, SF_CE0 => ce,
                  LINHA1 => l1, LINHA2 => l2, PRONTO => pronto, TELAS => telas, ERROS => erros_lcd);

    p_teste : process
        variable erros : natural := 0;

        -- espera duas telas completas (a primeira pode ter comecado antes da mudanca)
        procedure espera_telas is
            variable t0 : natural;
        begin
            t0 := telas;
            wait until telas >= t0 + 2 for 10 ms;
            if telas < t0 + 2 then
                report "FAIL: o LCD parou de atualizar a tela" severity error;
                erros := erros + 1;
            end if;
        end procedure;

        procedure confere(e1, e2 : string(1 to 16)) is
        begin
            espera_telas;
            if l1 /= e1 or l2 /= e2 then
                report "FAIL: tela """ & l1 & """ / """ & l2 & """, esperado """ & e1 & """ / """ & e2 & """"
                    severity error;
                erros := erros + 1;
            else
                report "tela ok: """ & l1 & """ / """ & l2 & """" severity note;
            end if;
        end procedure;
    begin
        -- inicializacao com a CPU em reset
        wait until pronto for 30 ms;
        if not pronto then
            report "FAIL: inicializacao do LCD nao terminou corretamente" severity error;
            erros := erros + 1;
        else
            report "inicializacao ok em " & time'image(now) severity note;
        end if;
        confere("RESET           ", "MEM[255] = 000  ");

        -- ldi Ra, 0x64 logo apos o fetch (byte adicional ainda nao lido)
        ir <= x"83"; arg <= x"10"; ir_ok <= '1'; arg_ok <= '0'; pos <= x"1C";
        confere("LDI Ra, 0x--    ", "MEM[255] = 028  ");
        -- depois do decode2
        arg <= x"64"; arg_ok <= '1';
        confere("LDI Ra, 0x64    ", "MEM[255] = 028  ");
        ir <= x"09"; pos <= x"FF";
        confere("ADD Rc Rb       ", "MEM[255] = 255  ");
        ir <= x"86"; arg <= x"FF";
        confere("ST Rb, 0xFF     ", "MEM[255] = 255  ");
        ir <= x"C0"; arg <= x"AB";
        confere("JMP 0xAB        ", "MEM[255] = 255  ");
        ir <= x"9E"; pos <= x"07";
        confere("LDR Rd [Rc]     ", "MEM[255] = 007  ");
        ir <= x"FF"; pos <= x"E9";
        confere("HALT            ", "MEM[255] = 233  ");
        ir_ok <= '0';
        confere("RESET           ", "MEM[255] = 233  ");

        if erros = 0 and erros_lcd = 0 then
            report "tb_lcd: TODOS OS TESTES PASSARAM! (" & integer'image(telas) & " telas escritas)" severity note;
        else
            report "tb_lcd: " & integer'image(erros + erros_lcd) & " ERROS" severity error;
        end if;
        fim <= true;
        assert false report "fim da simulacao" severity failure;
        wait;
    end process p_teste;

end architecture sim;

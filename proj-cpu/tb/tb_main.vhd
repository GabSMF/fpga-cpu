library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Testbench integrado do topo (main = divisor + CPU + RAM_8x256 real + LEDs + LCD).
--
-- Usa o programa gravado em rtl/RAM_8x256.vhd (nome em tb/dados/carregado.txt,
-- escrito por "tools/cpu8.py carregar NOME") e os resultados esperados do modelo
-- de referencia em programs/gen/NOME.trace e NOME.lcd.
--
-- Duas copias do topo rodam juntas, cada uma com seu modelo de LCD:
--   u_rapido (CLK_DIV_MAX = 499): programa inteiro. Confere LD6..LD1 (flags) ao fim
--            de cada instrucao, LD7 = clock da CPU, LD0 = 0, a tela "RESET" com a
--            chave em 1 e, no halt, a tela final (linha 1 = HALT, linha 2 = MEM[255]).
--   u_lento  (CLK_DIV_MAX = 99999, 20 ms por instrucao): confere as duas linhas do
--            LCD ao fim de cada uma das N_LENTO primeiras instrucoes.
-- Com o generic padrao 9999999 a placa leva 2 s por instrucao; aqui so o generic muda.
entity tb_main is
    generic (
        DIR_GEN   : string  := "../programs/gen/";
        DIR_DADOS : string  := "../tb/dados/";
        N_LENTO   : natural := 16
    );
end entity tb_main;

architecture sim of tb_main is

    signal clk     : std_logic := '0';
    signal fim     : boolean := false;
    signal rst_r, rst_l : std_logic := '1';
    signal led_r, led_l : std_logic_vector(7 downto 0);
    signal e_r, rs_r, rw_r, ce_r, e_l, rs_l, rw_l, ce_l : std_logic;
    signal d_r, d_l : std_logic_vector(11 downto 8);
    signal l1_r, l2_r, l1_l, l2_l : string(1 to 16);
    signal pronto_r, pronto_l : boolean;
    signal telas_r, telas_l, erros_r, erros_l : natural;
    signal fim_r, fim_l : boolean := false;
    signal erros_tb_r, erros_tb_l : natural := 0;

    -- nome do programa carregado (lido em tempo de simulacao)
    impure function carregado return string is
        file f : text;
        variable l : line;
    begin
        file_open(f, DIR_DADOS & "carregado.txt", read_mode);
        readline(f, l);
        file_close(f);
        return l.all;
    end function;

begin

    clk <= not clk after 10 ns when not fim else '0';

    u_rapido : entity work.main(Behavioral)
        generic map (CLK_DIV_MAX => 499)
        port map (CLK_50MHZ => clk, RESET => rst_r, LED => led_r, LCD_E => e_r, LCD_RS => rs_r,
                  LCD_RW => rw_r, SF_CE0 => ce_r, SF_D => d_r);
    u_lcd_r : entity work.lcd_modelo(sim)
        port map (LCD_E => e_r, LCD_RS => rs_r, LCD_RW => rw_r, LCD_DB => d_r, SF_CE0 => ce_r,
                  LINHA1 => l1_r, LINHA2 => l2_r, PRONTO => pronto_r, TELAS => telas_r, ERROS => erros_r);

    u_lento : entity work.main(Behavioral)
        generic map (CLK_DIV_MAX => 99999)
        port map (CLK_50MHZ => clk, RESET => rst_l, LED => led_l, LCD_E => e_l, LCD_RS => rs_l,
                  LCD_RW => rw_l, SF_CE0 => ce_l, SF_D => d_l);
    u_lcd_l : entity work.lcd_modelo(sim)
        port map (LCD_E => e_l, LCD_RS => rs_l, LCD_RW => rw_l, LCD_DB => d_l, SF_CE0 => ce_l,
                  LINHA1 => l1_l, LINHA2 => l2_l, PRONTO => pronto_l, TELAS => telas_l, ERROS => erros_l);

    -- ------------------------------------------------------------------ rapido --
    p_rapido : process
        constant NOME : string := carregado;
        file f : text;
        variable l : line;
        variable e_ir, e_fl, e_pc, e_wa, e_wd, k : integer;
        variable fl : std_logic_vector(5 downto 0);
        variable erros : natural := 0;
        variable ultima : string(1 to 16);
        variable t0 : natural;
        procedure falha(msg : string) is
        begin
            if erros < 8 then report "FAIL (rapido): " & msg severity error; end if;
            erros := erros + 1;
        end procedure;
    begin
        report "tb_main: programa carregado = " & NOME severity note;
        -- chave de reset em 1 enquanto o LCD inicializa
        wait until pronto_r for 40 ms;
        if not pronto_r then falha("LCD nao inicializou"); end if;
        t0 := telas_r;
        wait until telas_r >= t0 + 2 for 10 ms;
        if l1_r /= "RESET           " then falha("tela em reset: """ & l1_r & """"); end if;
        if led_r(6 downto 0) /= "0000000" then falha("LEDs de flag devem estar apagados em reset"); end if;

        -- solta o reset logo apos uma borda de subida do clock da CPU (LD7)
        wait until rising_edge(led_r(7));
        wait for 100 ns;
        rst_r <= '0';
        file_open(f, DIR_GEN & NOME & ".trace", read_mode);
        k := 0;
        while not endfile(f) loop
            readline(f, l);
            read(l, e_ir); read(l, e_fl); read(l, e_pc); read(l, e_wa); read(l, e_wd);
            k := k + 1;
            for c in 1 to 5 loop
                wait until rising_edge(led_r(7));
            end loop;
            wait for 1 us;
            fl := std_logic_vector(to_unsigned(e_fl, 6));
            if led_r(6 downto 1) /= fl then
                falha("instrucao " & integer'image(k) & " (IR=" & integer'image(e_ir) & "): LEDs de flag errados");
            end if;
            if led_r(0) /= '0' then falha("LD0 deve ficar apagado"); end if;
        end loop;
        file_close(f);

        -- programa terminou no halt: a tela final precisa aparecer
        t0 := telas_r;
        wait until telas_r >= t0 + 2 for 10 ms;
        file_open(f, DIR_GEN & NOME & ".lcd", read_mode);
        while not endfile(f) loop
            readline(f, l);
            read(l, ultima);
        end loop;
        file_close(f);
        if l1_r /= ultima then
            falha("tela final linha 1 = """ & l1_r & """, esperado """ & ultima & """");
        end if;
        report "tela final: """ & l1_r & """ / """ & l2_r & """" severity note;
        -- linha 2 esperada: ultima linha do arquivo, depois do '|'
        file_open(f, DIR_GEN & NOME & ".lcd", read_mode);
        while not endfile(f) loop
            readline(f, l);
            read(l, ultima);
            read(l, ultima(1));              -- '|'
            read(l, ultima);
        end loop;
        file_close(f);
        if l2_r /= ultima then
            falha("tela final linha 2 = """ & l2_r & """, esperado """ & ultima & """");
        end if;
        if erros = 0 then
            report "rapido: " & integer'image(k) & " instrucoes, LEDs e tela final ok" severity note;
        end if;
        erros_tb_r <= erros;
        fim_r <= true;
        wait;
    end process p_rapido;

    -- ------------------------------------------------------------------- lento --
    p_lento : process
        constant NOME : string := carregado;
        file f : text;
        variable l : line;
        variable e1, e2 : string(1 to 16);
        variable sep : character;
        variable erros : natural := 0;
        variable k : natural := 0;
        procedure falha(msg : string) is
        begin
            if erros < 8 then report "FAIL (lento): " & msg severity error; end if;
            erros := erros + 1;
        end procedure;
    begin
        wait until pronto_l for 40 ms;
        wait until rising_edge(led_l(7));
        wait for 100 ns;
        rst_l <= '0';
        wait until rising_edge(led_l(7));    -- fetch da instrucao 1
        file_open(f, DIR_GEN & NOME & ".lcd", read_mode);
        while not endfile(f) and k < N_LENTO loop
            readline(f, l);
            read(l, e1); read(l, sep); read(l, e2);
            k := k + 1;
            -- confere na borda do fetch da proxima instrucao (o LCD ainda mostra a atual)
            for c in 1 to 5 loop
                wait until rising_edge(led_l(7));
            end loop;
            if l1_l /= e1 or l2_l /= e2 then
                falha("instrucao " & integer'image(k) & ": """ & l1_l & """ / """ & l2_l
                      & """, esperado """ & e1 & """ / """ & e2 & """");
            end if;
        end loop;
        file_close(f);
        if erros = 0 then
            report "lento: LCD correto ao fim de cada uma das " & integer'image(k) & " primeiras instrucoes"
                severity note;
        end if;
        erros_tb_l <= erros;
        fim_l <= true;
        wait;
    end process p_lento;

    p_fim : process
    begin
        wait until fim_r and fim_l;
        if erros_tb_r + erros_tb_l + erros_r + erros_l = 0 then
            report "tb_main: SIMULACAO INTEGRADA PASSOU COM SUCESSO!" severity note;
        else
            report "tb_main: " & integer'image(erros_tb_r + erros_tb_l + erros_r + erros_l) & " ERROS"
                severity error;
        end if;
        fim <= true;
        assert false report "fim da simulacao" severity failure;
        wait;
    end process p_fim;

end architecture sim;

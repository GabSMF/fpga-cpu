library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Testbench da ISA completa (secoes 5 do ROADMAP).
--
-- Executa na CPU real (cpu.vhd + alu.vhd) cada programa listado em
-- DIR_DADOS/programas.txt e compara, instrucao a instrucao, com o traco do
-- modelo de referencia (tools/cpu8.py, escrito a partir do ENUNCIADO):
--   IR executado, as 6 flags, o proximo PC (MAR) e a escrita na RAM (endereco
--   e dado, no maximo uma por instrucao). No fim, compara a RAM inteira.
-- Lista padrao: fibonacci, bubble_sort, reservados, secao43, demo_flags e
-- 24 programas aleatorios (todos os 256 opcodes, inclusive reservados).
--
-- A RAM aqui e um modelo com o mesmo comportamento de RAM_8x256 (escrita e
-- registro do endereco na borda de DESCIDA, DOUT = ram(endereco registrado)),
-- mas carregado de arquivo para trocar de programa sem recompilar.
-- O teste da RAM real esta em tb_ram.vhd e tb_main.vhd.
--
-- Executar com o diretorio de trabalho na pasta do projeto (dados/ ao lado do .xise).
entity tb_cpu_programas is
    generic (
        DIR_GEN   : string := "dados/";
        DIR_DADOS : string := "dados/"
    );
end entity tb_cpu_programas;

architecture sim of tb_cpu_programas is

    constant MEIO : time := 10 ns; -- 50 MHz

    signal clk      : std_logic := '0';
    signal rst      : std_logic := '1';
    signal ram_din  : std_logic_vector(7 downto 0);
    signal ram_dout : std_logic_vector(7 downto 0) := (others => '0');
    signal ram_addr : std_logic_vector(7 downto 0);
    signal we       : std_logic;
    signal ir, arg  : std_logic_vector(7 downto 0);
    signal ir_ok    : std_logic;
    signal arg_ok   : std_logic;
    signal fz, fn, fo, fe, fg, fs : std_logic;

    type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);

begin

    u_cpu : entity work.cpu(Behavioral)
        port map (
            CLK => clk, RESET => rst,
            RAM_DIN => ram_din, RAM_DOUT => ram_dout, RAM_ADDR => ram_addr, WE => we,
            IR_OUT => ir, ARG_OUT => arg, IR_OK => ir_ok, ARG_OK => arg_ok,
            FLAG_Z => fz, FLAG_N => fn, FLAG_OVF => fo,
            FLAG_EQ => fe, FLAG_GT => fg, FLAG_SM => fs
        );

    -- Um unico processo gera o clock, modela a RAM e confere os resultados.
    p_teste : process
        variable ram       : ram_t;
        variable rd_addr   : integer range 0 to 255 := 0;
        variable lista     : line;
        variable l         : line;
        variable nome      : string(1 to 40);
        variable nlen      : natural;
        variable ch        : character;
        variable ok_ch     : boolean;
        variable ninst     : integer;
        variable e_ir, e_fl, e_pc, e_wa, e_wd : integer;
        variable w_cnt, w_a, w_d : integer;
        variable bv        : bit_vector(7 downto 0);
        variable fl        : integer;
        variable erros     : natural := 0;
        variable erros_prog: natural;
        variable nprog     : natural := 0;
        variable ninst_tot : natural := 0;
        file f_lista       : text;
        file f_dados       : text;

        -- meio periodo com borda de subida (CPU) seguido da borda de descida (RAM)
        procedure ciclo is
        begin
            clk <= '1';
            wait for MEIO;
            clk <= '0';
            -- RAM_8x256: na borda de descida escreve (WE) e registra o endereco
            if we = '1' then
                ram(to_integer(unsigned(ram_addr))) := ram_din;
            end if;
            rd_addr  := to_integer(unsigned(ram_addr));
            ram_dout <= ram(rd_addr);
            wait for MEIO;
        end procedure;

        procedure falha(msg : string) is
        begin
            if erros_prog < 5 then
                report "FAIL " & nome(1 to nlen) & ": " & msg severity error;
            end if;
            erros_prog := erros_prog + 1;
        end procedure;

    begin
        file_open(f_lista, DIR_DADOS & "programas.txt", read_mode);
        while not endfile(f_lista) loop
            readline(f_lista, lista);
            next when lista'length = 0;
            -- nome do programa (ate o espaco) e numero de instrucoes do traco
            nlen := 0;
            loop
                read(lista, ch, ok_ch);
                exit when not ok_ch or ch = ' ';
                nlen := nlen + 1;
                nome(nlen) := ch;
            end loop;
            read(lista, ninst);
            erros_prog := 0;

            -- carrega a imagem do programa
            file_open(f_dados, DIR_GEN & nome(1 to nlen) & ".mem", read_mode);
            for i in 0 to 255 loop
                readline(f_dados, l);
                read(l, bv);
                ram(i) := to_stdlogicvector(bv);
            end loop;
            file_close(f_dados);

            -- reset por 2 ciclos: PC=0, SP=254, flags=0, estado FETCH
            rst <= '1';
            ciclo;
            ciclo;
            assert ir_ok = '0' and arg_ok = '0'
                report "FAIL: IR_OK/ARG_OK devem ser 0 em reset" severity error;
            if (fz or fn or fo or fe or fg or fs) /= '0' then
                falha("flags devem ser 0 em reset");
            end if;
            if ram_addr /= x"00" then
                falha("PC deve ser 0 em reset");
            end if;
            rst <= '0';

            -- executa e confere instrucao por instrucao
            file_open(f_dados, DIR_GEN & nome(1 to nlen) & ".trace", read_mode);
            for k in 1 to ninst loop
                readline(f_dados, l);
                read(l, e_ir); read(l, e_fl); read(l, e_pc); read(l, e_wa); read(l, e_wd);
                w_cnt := 0;
                w_a := -1;
                w_d := 0;
                for c in 1 to 5 loop          -- 5 ciclos por instrucao
                    if we = '1' then
                        w_cnt := w_cnt + 1;
                        w_a := to_integer(unsigned(ram_addr));
                        w_d := to_integer(unsigned(ram_din));
                    end if;
                    ciclo;
                    if c = 1 and ir_ok /= '1' then
                        falha("IR_OK deveria ser 1 depois do fetch");
                    end if;
                end loop;
                fl := 0;
                if fz = '1' then fl := fl + 32; end if;
                if fn = '1' then fl := fl + 16; end if;
                if fo = '1' then fl := fl + 8;  end if;
                if fe = '1' then fl := fl + 4;  end if;
                if fg = '1' then fl := fl + 2;  end if;
                if fs = '1' then fl := fl + 1;  end if;
                if to_integer(unsigned(ir)) /= e_ir then
                    falha("instrucao " & integer'image(k) & ": IR=" & integer'image(to_integer(unsigned(ir)))
                          & " esperado " & integer'image(e_ir));
                end if;
                if fl /= e_fl then
                    falha("instrucao " & integer'image(k) & " (IR=" & integer'image(e_ir) & "): flags="
                          & integer'image(fl) & " esperado " & integer'image(e_fl) & " (ZNOEGS)");
                end if;
                if to_integer(unsigned(ram_addr)) /= e_pc then
                    falha("instrucao " & integer'image(k) & " (IR=" & integer'image(e_ir) & "): proximo PC="
                          & integer'image(to_integer(unsigned(ram_addr))) & " esperado " & integer'image(e_pc));
                end if;
                if w_cnt > 1 then
                    falha("instrucao " & integer'image(k) & ": WE ativo em mais de um ciclo");
                end if;
                if w_a /= e_wa or (e_wa >= 0 and w_d /= e_wd) then
                    falha("instrucao " & integer'image(k) & " (IR=" & integer'image(e_ir) & "): escrita MEM["
                          & integer'image(w_a) & "]=" & integer'image(w_d) & " esperado MEM["
                          & integer'image(e_wa) & "]=" & integer'image(e_wd));
                end if;
                if arg_ok /= '1' then
                    falha("ARG_OK deveria ser 1 no fim da instrucao");
                end if;
            end loop;
            file_close(f_dados);

            -- RAM final
            file_open(f_dados, DIR_GEN & nome(1 to nlen) & ".ram", read_mode);
            for i in 0 to 255 loop
                readline(f_dados, l);
                read(l, e_wd);
                if to_integer(unsigned(ram(i))) /= e_wd then
                    falha("RAM final: MEM[" & integer'image(i) & "]=" & integer'image(to_integer(unsigned(ram(i))))
                          & " esperado " & integer'image(e_wd));
                end if;
            end loop;
            file_close(f_dados);

            nprog := nprog + 1;
            ninst_tot := ninst_tot + ninst;
            if erros_prog = 0 then
                report "PASSOU " & nome(1 to nlen) & " (" & integer'image(ninst) & " instrucoes)" severity note;
            else
                report "FALHOU " & nome(1 to nlen) & " (" & integer'image(erros_prog) & " erros)" severity error;
            end if;
            erros := erros + erros_prog;
        end loop;
        file_close(f_lista);

        if erros = 0 then
            report "tb_cpu_programas: TODOS OS " & integer'image(nprog) & " PROGRAMAS PASSARAM ("
                   & integer'image(ninst_tot) & " instrucoes conferidas)" severity note;
        else
            report "tb_cpu_programas: " & integer'image(erros) & " ERROS" severity error;
        end if;
        assert false report "fim da simulacao" severity failure;
        wait;
    end process p_teste;

end architecture sim;

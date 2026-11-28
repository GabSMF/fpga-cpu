library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

-- Testbench isolado da RAM_8x256 real (rtl/RAM_8x256.vhd), secao 3 do ROADMAP.
--
-- 1. Imagem inicial: os 256 enderecos batem com programs/gen/<carregado>.mem
--    (o programa gravado em RAM_8x256.vhd por "tools/cpu8.py carregar").
-- 2. Leitura sincrona: DOUT so muda depois da borda de DESCIDA que registra ADDR.
-- 3. Escrita: com WE=1 grava na borda de descida; com WE=0 nada muda.
-- 4. POS_255 acompanha MEM[255] logo apos a escrita, e so ela.
-- 5. Leitura do mesmo endereco escrito devolve o dado novo.
entity tb_ram is
    generic (
        DIR_GEN   : string := "dados/";
        DIR_DADOS : string := "dados/"
    );
end entity tb_ram;

architecture sim of tb_ram is

    constant MEIO : time := 10 ns;

    signal clk     : std_logic := '1';
    signal din     : std_logic_vector(7 downto 0) := (others => '0');
    signal addr    : std_logic_vector(7 downto 0) := (others => '0');
    signal we      : std_logic := '0';
    signal dout    : std_logic_vector(7 downto 0);
    signal pos_255 : std_logic_vector(7 downto 0);

    type ram_t is array (0 to 255) of std_logic_vector(7 downto 0);

begin

    u_memory : entity work.RAM_8x256(rtl)
        port map (CLK => clk, DIN => din, ADDR => addr, WE => we, DOUT => dout, POS_255 => pos_255);

    p_teste : process
        variable img    : ram_t;
        variable l      : line;
        variable bv     : bit_vector(7 downto 0);
        variable nome   : line;
        variable erros  : natural := 0;
        file f          : text;

        procedure confere(cond : boolean; msg : string) is
        begin
            if not cond then
                if erros < 10 then
                    report "FAIL: " & msg severity error;
                end if;
                erros := erros + 1;
            end if;
        end procedure;

        function h(v : std_logic_vector(7 downto 0)) return string is
        begin
            return integer'image(to_integer(unsigned(v)));
        end function;

        -- borda de descida seguida de subida (um ciclo comecando com clk = '1')
        procedure descida is
        begin
            clk <= '0';
            wait for MEIO;
        end procedure;
        procedure subida is
        begin
            clk <= '1';
            wait for MEIO;
        end procedure;

    begin
        file_open(f, DIR_DADOS & "carregado.txt", read_mode);
        readline(f, nome);
        file_close(f);
        file_open(f, DIR_GEN & nome.all & ".mem", read_mode);
        for i in 0 to 255 loop
            readline(f, l);
            read(l, bv);
            img(i) := to_stdlogicvector(bv);
        end loop;
        file_close(f);
        report "tb_ram: imagem esperada = programs/gen/" & nome.all & ".mem" severity note;

        wait for 1 ns;
        confere(pos_255 = img(255), "POS_255 inicial = " & h(pos_255) & ", esperado " & h(img(255)));

        -- 1 e 2: imagem inicial e latencia de leitura
        for i in 0 to 255 loop
            addr <= std_logic_vector(to_unsigned(i, 8));
            subida;                                  -- ADDR novo, ainda sem borda de descida
            if i > 0 and img(i) /= img(i - 1) then
                confere(dout = img(i - 1), "DOUT mudou antes da borda de descida (endereco " & integer'image(i) & ")");
            end if;
            descida;                                 -- RAM registra ADDR
            confere(dout = img(i), "imagem inicial MEM[" & integer'image(i) & "] = " & h(dout)
                    & ", esperado " & h(img(i)));
        end loop;

        -- 3: WE=0 nao grava
        addr <= x"10";
        din  <= not img(16);
        we   <= '0';
        subida;
        descida;
        confere(dout = img(16), "escrita com WE=0 alterou MEM[16]");

        -- 3 e 5: grava todos os enderecos (exceto 255) com um padrao e le de volta
        for i in 0 to 254 loop
            addr <= std_logic_vector(to_unsigned(i, 8));
            din  <= std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8));
            we   <= '1';
            subida;
            descida;                                 -- grava e registra o mesmo endereco
            confere(dout = std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8)),
                    "leitura logo apos escrita em MEM[" & integer'image(i) & "]");
            confere(pos_255 = img(255), "POS_255 mudou com escrita em MEM[" & integer'image(i) & "]");
        end loop;
        we <= '0';
        for i in 0 to 254 loop
            addr <= std_logic_vector(to_unsigned(i, 8));
            subida;
            descida;
            confere(dout = std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8)),
                    "releitura de MEM[" & integer'image(i) & "] = " & h(dout));
        end loop;

        -- 4: POS_255 so muda na borda de descida da escrita em 255
        addr <= x"FF";
        din  <= x"1C";                               -- 28 decimal, exemplo do enunciado
        we   <= '1';
        subida;
        confere(pos_255 = img(255), "POS_255 mudou antes da borda de descida");
        descida;
        confere(pos_255 = x"1C", "POS_255 = " & h(pos_255) & " apos st 0xFF, esperado 28");
        we   <= '0';
        din  <= x"00";
        addr <= x"00";
        subida;
        descida;
        confere(pos_255 = x"1C", "POS_255 deve manter o valor sem nova escrita");

        if erros = 0 then
            report "tb_ram: TODOS OS TESTES PASSARAM!" severity note;
        else
            report "tb_ram: " & integer'image(erros) & " ERROS" severity error;
        end if;
        assert false report "fim da simulacao" severity failure;
        wait;
    end process p_teste;

end architecture sim;

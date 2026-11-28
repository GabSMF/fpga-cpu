library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Modelo do LCD 16x2 (controlador HD44780/ST7066U) para testbench. Nao sintetizavel.
--
-- Le LCD_E/LCD_RS/LCD_DB como o display: o nibble e capturado na descida de E.
-- Confere os tempos do UG230 (cap. 5):
--   * RS e DB estaveis >= 40 ns antes da subida de E; E alto >= 230 ns;
--     RS/DB sem mudar ate 10 ns depois da descida de E; RW = 0; SF_CE0 = 1.
--   * inicializacao: >= 15 ms ate o 1o pulso; nibbles 3, 3, 3, 2 com >= 4,1 ms,
--     100 us, 40 us e 40 us depois de cada; comandos 28, 06, 0C, 01 nessa ordem.
--   * >= 1 us entre os nibbles de um byte, >= 40 us entre bytes e >= 1,64 ms depois
--     de Clear Display.
-- Mantem a DDRAM e devolve o texto visivel das duas linhas. TELAS conta quantas
-- vezes o ultimo caractere da linha 2 (DDRAM 0x4F) foi escrito.
entity lcd_modelo is
    port (
        LCD_E   : in  std_logic;
        LCD_RS  : in  std_logic;
        LCD_RW  : in  std_logic;
        LCD_DB  : in  std_logic_vector(3 downto 0);
        SF_CE0  : in  std_logic;
        LINHA1  : out string(1 to 16);
        LINHA2  : out string(1 to 16);
        PRONTO  : out boolean;      -- inicializacao completa e correta
        TELAS   : out natural;
        ERROS   : out natural
    );
end entity lcd_modelo;

architecture sim of lcd_modelo is
begin

    p_modelo : process
        type ddram_t is array (0 to 127) of character;
        variable ddram     : ddram_t := (others => ' ');
        variable endereco  : natural range 0 to 127 := 0;
        variable t_mud     : time := 0 ns;      -- ultima mudanca de RS/DB
        variable t_sobe    : time := 0 ns;
        variable t_desce   : time := -1 sec;    -- ultima descida de E
        variable t_fim_byte: time := 0 ns;      -- fim da ultima transferencia completa
        variable espera_min: time := 15 ms;     -- espera exigida antes do proximo byte
        variable n_init    : natural := 0;      -- nibbles soltos da inicializacao (4)
        variable alto      : std_logic_vector(3 downto 0);
        variable tem_alto  : boolean := false;
        variable rs_byte   : std_logic;
        variable b         : std_logic_vector(7 downto 0);
        variable n_cmd     : natural := 0;
        variable erros_v   : natural := 0;
        variable telas_v   : natural := 0;
        variable pronto_v  : boolean := false;
        variable e_ant     : std_logic := '0';
        variable rs_ant    : std_logic := '0';
        variable db_ant    : std_logic_vector(3 downto 0) := "0000";
        type cmds_t is array (0 to 3) of std_logic_vector(7 downto 0);
        constant CMDS      : cmds_t := (x"28", x"06", x"0C", x"01");
        type nib_t is array (0 to 3) of std_logic_vector(3 downto 0);
        constant NIBS      : nib_t := (x"3", x"3", x"3", x"2");
        type t_t is array (0 to 3) of time;
        constant ESPERAS   : t_t := (4.1 ms, 100 us, 40 us, 40 us);

        procedure erro(msg : string) is
        begin
            if erros_v < 10 then
                report "FAIL LCD: " & msg severity error;
            end if;
            erros_v := erros_v + 1;
        end procedure;

        procedure publica is
            variable s1, s2 : string(1 to 16);
        begin
            for i in 0 to 15 loop
                s1(i + 1) := ddram(i);
                s2(i + 1) := ddram(64 + i);
            end loop;
            LINHA1 <= s1;
            LINHA2 <= s2;
            TELAS  <= telas_v;
            ERROS  <= erros_v;
            PRONTO <= pronto_v;
        end procedure;

    begin
        publica;
        loop
            wait on LCD_E, LCD_RS, LCD_DB, LCD_RW, SF_CE0;

            if SF_CE0 /= '1' then
                erro("SF_CE0 deve ficar em 1");
            end if;
            if LCD_RW /= '0' then
                erro("LCD_RW deve ficar em 0");
            end if;

            -- mudanca de dados/RS
            if LCD_RS /= rs_ant or LCD_DB /= db_ant then
                if LCD_E = '1' then
                    erro("RS/DB mudaram com E alto");
                elsif now - t_desce < 10 ns then
                    erro("hold de RS/DB menor que 10 ns apos a descida de E");
                end if;
                t_mud := now;
            end if;

            -- subida de E
            if LCD_E = '1' and e_ant = '0' then
                if now - t_mud < 40 ns then
                    erro("setup de RS/DB = " & time'image(now - t_mud) & " (minimo 40 ns)");
                end if;
                if tem_alto then
                    if now - t_desce < 1 us then
                        erro("intervalo entre nibbles = " & time'image(now - t_desce) & " (minimo 1 us)");
                    end if;
                elsif now - t_fim_byte < espera_min then
                    erro("transferencia " & integer'image(n_cmd + n_init) & " cedo demais: "
                         & time'image(now - t_fim_byte) & " (minimo " & time'image(espera_min) & ")");
                end if;
                t_sobe := now;
            end if;

            -- descida de E: o LCD le o nibble
            if LCD_E = '0' and e_ant = '1' then
                if now - t_sobe < 230 ns then
                    erro("pulso de E = " & time'image(now - t_sobe) & " (minimo 230 ns)");
                end if;
                t_desce := now;
                if n_init < 4 then
                    -- inicializacao: nibbles soltos, sempre comando
                    if LCD_DB /= NIBS(n_init) or LCD_RS /= '0' then
                        erro("inicializacao: nibble " & integer'image(n_init) & " errado");
                    end if;
                    espera_min := ESPERAS(n_init);
                    t_fim_byte := now;
                    n_init := n_init + 1;
                elsif not tem_alto then
                    alto := LCD_DB;
                    rs_byte := LCD_RS;
                    tem_alto := true;
                else
                    tem_alto := false;
                    if LCD_RS /= rs_byte then
                        erro("RS mudou entre os nibbles de um byte");
                    end if;
                    b := alto & LCD_DB;
                    t_fim_byte := now;
                    espera_min := 40 us;
                    if rs_byte = '0' then
                        if n_cmd < 4 then
                            if b /= CMDS(n_cmd) then
                                erro("comando de configuracao " & integer'image(n_cmd) & " = "
                                     & integer'image(to_integer(unsigned(b))));
                            end if;
                            n_cmd := n_cmd + 1;
                            if n_cmd = 4 then
                                pronto_v := erros_v = 0;
                            end if;
                        end if;
                        if b = x"01" then
                            ddram := (others => ' ');
                            endereco := 0;
                            espera_min := 1.64 ms;
                        elsif b(7) = '1' then
                            endereco := to_integer(unsigned(b(6 downto 0)));
                        end if;
                    else
                        if n_cmd < 4 then
                            erro("caractere escrito antes de terminar a configuracao");
                        end if;
                        ddram(endereco) := character'val(to_integer(unsigned(b)));
                        if endereco = 16#4F# then
                            telas_v := telas_v + 1;
                        end if;
                        endereco := (endereco + 1) mod 128;
                    end if;
                end if;
            end if;

            e_ant := LCD_E;
            rs_ant := LCD_RS;
            db_ant := LCD_DB;
            publica;
        end loop;
    end process p_modelo;

end architecture sim;

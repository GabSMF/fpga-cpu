library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.lcd_pkg.all;

-- Controlador do LCD 16x2 da Spartan-3E Starter Kit (UG230, cap. 5), modo 4 bits.
-- Roda no clock de 50 MHz da placa (secao 3, item 7 do enunciado), independente
-- do clock lento da CPU.
--
-- 1. Sincroniza IR, ARG, IR_OK, ARG_OK e POS_255 (vem do clock da CPU): dois
--    flip-flops e so aceita o valor quando duas amostras seguidas sao iguais.
-- 2. Inicializa o LCD como no UG230: 15 ms, 0x3, 4,1 ms, 0x3, 100 us, 0x3, 40 us,
--    0x2, 40 us; depois Function Set 0x28, Entry Mode 0x06, Display On 0x0C (sem
--    cursor) e Clear 0x01 (1,64 ms).
-- 3. Reescreve as duas linhas sem parar: 0x80 + 16 caracteres da linha 1,
--    0xC0 + 16 caracteres da linha 2 (cerca de 1,8 ms por tela). O texto e
--    copiado no inicio de cada tela, para uma linha nunca misturar dois estados.
--
-- Tempos de cada transferencia de 4 bits: dados/RS estaveis 60 ns antes de E
-- (minimo 40 ns), E alto 240 ns (minimo 230 ns), 1 us entre os dois nibbles de
-- um byte e 50 us entre bytes (minimo 40 us). Esperas com margem sobre o UG230.
entity lcd is
    port (
        CLK     : in  std_logic;                     -- 50 MHz
        IR      : in  std_logic_vector(7 downto 0);
        ARG     : in  std_logic_vector(7 downto 0);
        IR_OK   : in  std_logic;
        ARG_OK  : in  std_logic;
        POS_255 : in  std_logic_vector(7 downto 0);
        LCD_E   : out std_logic;
        LCD_RS  : out std_logic;
        LCD_RW  : out std_logic;
        LCD_DB  : out std_logic_vector(3 downto 0);  -- SF_D<11:8> = DB7..DB4
        SF_CE0  : out std_logic                      -- '1' desliga a StrataFlash
    );
end entity lcd;

architecture Behavioral of lcd is

    -- tempos em ciclos de 50 MHz (20 ns)
    constant T_LIGA    : natural := 800000;  -- 16 ms   (>= 15 ms)
    constant T_INIT1   : natural := 210000;  -- 4,2 ms  (>= 4,1 ms)
    constant T_INIT2   : natural := 5500;    -- 110 us  (>= 100 us)
    constant T_CMD     : natural := 2500;    -- 50 us   (>= 40 us)
    constant T_CLEAR   : natural := 100000;  -- 2 ms    (>= 1,64 ms)
    constant T_SETUP   : natural := 3;       -- 60 ns   (>= 40 ns)
    constant T_PULSO   : natural := 12;      -- 240 ns  (>= 230 ns)
    constant T_NIBBLE  : natural := 50;      -- 1 us    (>= 1 us)

    constant N_INIT    : natural := 8;       -- transferencias da inicializacao
    constant N_TELA    : natural := 34;      -- 0x80 + 16 + 0xC0 + 16

    -- sincronizacao (26 bits: IR, ARG, POS_255, IR_OK, ARG_OK)
    signal s1, s2, s3  : std_logic_vector(25 downto 0) := (others => '0');
    signal estavel     : std_logic_vector(25 downto 0) := (others => '0');

    signal linha1, linha2     : rom_str;
    signal copia1, copia2     : rom_str;                     -- texto da tela em envio

    type estado_t is (S_LIGA, S_CARREGA, S_SETUP, S_PULSO, S_ENTRE, S_ESPERA);
    signal estado   : estado_t := S_LIGA;
    signal cnt      : unsigned(19 downto 0) := (others => '0');
    signal em_init  : std_logic := '1';
    signal passo    : natural range 0 to N_TELA - 1 := 0;
    signal segundo  : std_logic := '0';                      -- enviando o nibble baixo
    signal baixo_r  : std_logic_vector(3 downto 0) := (others => '0'); -- nibble baixo pendente
    signal so_alto  : std_logic := '0';                      -- transferencia de 1 nibble
    signal espera_r : unsigned(19 downto 0) := (others => '0');

    signal e_r, rs_r : std_logic := '0';
    signal db_r      : std_logic_vector(3 downto 0) := (others => '0');

begin

    -- 1. sincronizacao do dominio da CPU para 50 MHz
    p_sinc : process(CLK)
    begin
        if rising_edge(CLK) then
            s1 <= IR & ARG & POS_255 & IR_OK & ARG_OK;
            s2 <= s1;
            s3 <= s2;
            if s2 = s3 then
                estavel <= s3;
            end if;
        end if;
    end process p_sinc;

    u_texto : entity work.lcd_texto(Behavioral)
        port map (
            IR      => estavel(25 downto 18),
            ARG     => estavel(17 downto 10),
            POS_255 => estavel(9 downto 2),
            IR_OK   => estavel(1),
            ARG_OK  => estavel(0),
            LINHA1  => linha1,
            LINHA2  => linha2
        );

    -- 2 e 3. sequenciador de transferencias
    p_lcd : process(CLK)
        variable b    : std_logic_vector(7 downto 0);
        variable rs   : std_logic;
        variable so   : std_logic;
        variable esp  : natural;
    begin
        if rising_edge(CLK) then
            case estado is

                when S_LIGA =>                       -- espera o LCD ligar
                    e_r <= '0';
                    if cnt = T_LIGA then
                        cnt     <= (others => '0');
                        em_init <= '1';
                        passo   <= 0;
                        estado  <= S_CARREGA;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_CARREGA =>                    -- escolhe a proxima transferencia
                    rs := '0';
                    so := '0';
                    esp := T_CMD;
                    b := x"00";
                    if em_init = '1' then
                        case passo is
                            when 0 => b := x"30"; so := '1'; esp := T_INIT1;
                            when 1 => b := x"30"; so := '1'; esp := T_INIT2;
                            when 2 => b := x"30"; so := '1';
                            when 3 => b := x"20"; so := '1';
                            when 4 => b := x"28";            -- Function Set: 4 bits, 2 linhas
                            when 5 => b := x"06";            -- Entry Mode: incrementa endereco
                            when 6 => b := x"0C";            -- Display On, sem cursor
                            when others => b := x"01"; esp := T_CLEAR; -- Clear Display
                        end case;
                    else
                        if passo = 0 then
                            b := x"80";                      -- DDRAM 0x00: linha 1
                            copia1 <= linha1;                -- congela o texto desta tela
                            copia2 <= linha2;
                        elsif passo <= 16 then
                            b := copia1(2 * (passo - 1)) & copia1(2 * (passo - 1) + 1);
                            rs := '1';
                        elsif passo = 17 then
                            b := x"C0";                      -- DDRAM 0x40: linha 2
                        else
                            b := copia2(2 * (passo - 18)) & copia2(2 * (passo - 18) + 1);
                            rs := '1';
                        end if;
                    end if;
                    baixo_r  <= b(3 downto 0);
                    so_alto  <= so;
                    espera_r <= to_unsigned(esp, 20);
                    rs_r     <= rs;
                    db_r     <= b(7 downto 4);               -- nibble alto primeiro
                    e_r      <= '0';
                    segundo  <= '0';
                    cnt      <= (others => '0');
                    estado   <= S_SETUP;

                when S_SETUP =>                      -- dados estaveis antes de E
                    if cnt = T_SETUP - 1 then
                        cnt    <= (others => '0');
                        e_r    <= '1';
                        estado <= S_PULSO;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_PULSO =>                      -- E alto (LCD le na descida)
                    if cnt = T_PULSO - 1 then
                        cnt <= (others => '0');
                        e_r <= '0';
                        if so_alto = '1' or segundo = '1' then
                            estado <= S_ESPERA;
                        else
                            estado <= S_ENTRE;
                        end if;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_ENTRE =>                      -- 1 us entre os nibbles
                    if cnt = T_NIBBLE - 1 then
                        cnt     <= (others => '0');
                        db_r    <= baixo_r;
                        segundo <= '1';
                        estado  <= S_SETUP;
                    else
                        cnt <= cnt + 1;
                    end if;

                when S_ESPERA =>                     -- tempo de execucao do comando
                    if cnt = espera_r then
                        cnt <= (others => '0');
                        if em_init = '1' and passo = N_INIT - 1 then
                            em_init <= '0';
                            passo   <= 0;
                        elsif em_init = '0' and passo = N_TELA - 1 then
                            passo   <= 0;
                        else
                            passo   <= passo + 1;
                        end if;
                        estado <= S_CARREGA;
                    else
                        cnt <= cnt + 1;
                    end if;

            end case;
        end if;
    end process p_lcd;

    LCD_E  <= e_r;
    LCD_RS <= rs_r;
    LCD_RW <= '0';     -- so escrita
    LCD_DB <= db_r;
    SF_CE0 <= '1';     -- StrataFlash desabilitada (barramento compartilhado)

end architecture Behavioral;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Entidade de topo (main) para a placa Spartan-3E Starter Kit (xc3s500e-4fg320).
-- Integra divisor de clock (~2s por instrucao completa), CPU, RAM e LEDs.
entity main is
    generic (
        -- A 50 MHz, cada instrucao leva 5 ciclos de clk_cpu.
        -- Para 2,0 s por instrucao: periodo de clk_cpu = 0,4 s (meio-periodo = 0,2 s).
        -- 50_000_000 * 0,2 = 10_000_000 ciclos -> CLK_DIV_MAX = 9_999_999.
        -- Em simulacao (testbench), sobrescreva CLK_DIV_MAX para um valor pequeno (ex.: 1).
        CLK_DIV_MAX : natural := 9999999
    );
    port (
        CLK_50MHZ : in  std_logic;
        RESET     : in  std_logic;                     -- Chave SW0 (1 = reset, 0 = executa)
        LED       : out std_logic_vector(7 downto 0)   -- LD7..LD0 conforme Secao 3.1
    );
end entity main;

architecture Behavioral of main is

    -- Sinais do divisor de clock
    signal div_cnt : natural range 0 to CLK_DIV_MAX := 0;
    signal clk_cpu : std_logic := '0';

    -- Barramento CPU <-> RAM
    signal ram_din  : std_logic_vector(7 downto 0);
    signal ram_dout : std_logic_vector(7 downto 0);
    signal ram_addr : std_logic_vector(7 downto 0);
    signal ram_we   : std_logic;
    signal pos_255  : std_logic_vector(7 downto 0);

    -- Sinais de observacao da CPU (para LEDs e futuro LCD)
    signal ir_sig   : std_logic_vector(7 downto 0);
    signal arg_sig  : std_logic_vector(7 downto 0);
    signal flag_z   : std_logic;
    signal flag_n   : std_logic;
    signal flag_ovf : std_logic;
    signal flag_eq  : std_logic;
    signal flag_gt  : std_logic;
    signal flag_sm  : std_logic;

begin

    -- Divisor de clock: 50 MHz -> 2,5 Hz (5 ciclos por instrucao = 2,0 s/instrucao)
    p_clk_div : process(CLK_50MHZ)
    begin
        if rising_edge(CLK_50MHZ) then
            if div_cnt = CLK_DIV_MAX then
                div_cnt <= 0;
                clk_cpu <= not clk_cpu;
            else
                div_cnt <= div_cnt + 1;
            end if;
        end if;
    end process p_clk_div;

    -- Instancia da CPU
    u_cpu : entity work.cpu(Behavioral)
        port map (
            CLK      => clk_cpu,
            RESET    => RESET,
            RAM_DIN  => ram_din,
            RAM_DOUT => ram_dout,
            RAM_ADDR => ram_addr,
            WE       => ram_we,
            IR_OUT   => ir_sig,
            ARG_OUT  => arg_sig,
            FLAG_Z   => flag_z,
            FLAG_N   => flag_n,
            FLAG_OVF => flag_ovf,
            FLAG_EQ  => flag_eq,
            FLAG_GT  => flag_gt,
            FLAG_SM  => flag_sm
        );

    -- Instancia da RAM (mesma interface da RAM fornecida)
    u_memory : entity work.RAM_8x256(rtl)
        port map (
            CLK     => clk_cpu,
            DIN     => ram_din,
            ADDR    => ram_addr,
            WE      => ram_we,
            DOUT    => ram_dout,
            POS_255 => pos_255
        );

    -- Mapeamento dos LEDs conforme Secao 3.1 do Enunciado (da esquerda para a direita):
    -- LD7: CLOCK, LD6: ZERO, LD5: NEGATIVE, LD4: OVERFLOW,
    -- LD3: EQUAL, LD2: GREATER, LD1: SMALLER, LD0: livre
    LED(7) <= clk_cpu;
    LED(6) <= flag_z;
    LED(5) <= flag_n;
    LED(4) <= flag_ovf;
    LED(3) <= flag_eq;
    LED(2) <= flag_gt;
    LED(1) <= flag_sm;
    LED(0) <= '0';

end architecture Behavioral;

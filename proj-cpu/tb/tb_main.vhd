library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench integrado para o sistema completo (main = divisor + CPU + RAM_8x256 + LEDs).
-- Usa CLK_DIV_MAX => 0 para acelerar a simulacao (1 ciclo de clk_cpu = 40 ns; 1 instrucao = 200 ns).
entity tb_main is
end entity tb_main;

architecture sim of tb_main is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    signal clk_50mhz : std_logic := '0';
    signal reset     : std_logic := '1';
    signal led       : std_logic_vector(7 downto 0);

begin

    -- Gera clock de 50 MHz
    clk_50mhz <= not clk_50mhz after CLK_PERIOD / 2;

    -- Instancia do topo com divisor minimo para simulacao rapida
    uut : entity work.main(Behavioral)
        generic map (
            CLK_DIV_MAX => 0
        )
        port map (
            CLK_50MHZ => clk_50mhz,
            RESET     => reset,
            LED       => led
        );

    -- Verifica a sequencia de flags do programa de demonstracao carregado em RAM_8x256.vhd
    p_test : process
        -- Avanca N instrucoes completas (5 ciclos de clk_cpu = 10 ciclos de clk_50mhz por instrucao)
        procedure wait_instr(n : positive) is
        begin
            for i in 1 to n * 10 loop
                wait until rising_edge(clk_50mhz);
            end loop;
        end procedure;
    begin
        -- 1. Mantem reset ativo por 2 ciclos de clk_cpu (4 ciclos de 50 MHz)
        reset <= '1';
        for i in 1 to 4 loop
            wait until rising_edge(clk_50mhz);
        end loop;
        assert led(6 downto 1) = "000000"
            report "FAIL: flags devem estar zeradas durante reset" severity error;

        -- 2. Libera reset
        reset <= '0';

        -- Instrucoes 1 e 2: ldi Ra, 0xFF; ldi Rb, 0x01 (flags ainda zeradas)
        wait_instr(2);
        assert led(6 downto 1) = "000000"
            report "FAIL: ldi nao deve alterar flags" severity error;

        -- Instrucao 3: add Ra, Rb (255 + 1 = 0 -> Z=1, N=0, OVF=1, EQ=0, GT=1, SM=0)
        wait_instr(1);
        assert led(6 downto 1) = "101010"
            report "FAIL: flags esperadas apos add 255+1 = 101010" severity error;

        -- Instrucoes 4 e 5: ldi Ra, 3; ldi Rb, 5 (flags preservadas)
        wait_instr(2);
        assert led(6 downto 1) = "101010"
            report "FAIL: flags deveriam ser preservadas durante ldi" severity error;

        -- Instrucao 6: sub Ra, Rb (3 - 5 = 0xFE -> Z=0, N=1, OVF=1, EQ=0, GT=0, SM=1)
        wait_instr(1);
        assert led(6 downto 1) = "011001"
            report "FAIL: flags esperadas apos sub 3-5 = 011001" severity error;

        -- Instrucoes 7 e 8: ldi Ra, 10; mov Rb, Ra (flags preservadas)
        wait_instr(2);
        assert led(6 downto 1) = "011001"
            report "FAIL: flags deveriam ser preservadas durante ldi/mov" severity error;

        -- Instrucao 9: sub Ra, Rb (10 - 10 = 0 -> Z=1, N=0, OVF=0, EQ=1, GT=0, SM=0)
        wait_instr(1);
        assert led(6 downto 1) = "100100"
            report "FAIL: flags esperadas apos sub 10-10 = 100100" severity error;

        -- Instrucoes 10, 11 e 12: ldi Ra, 10; st Ra, 0xFF; halt (flags preservadas em 100100)
        wait_instr(4);
        assert led(6 downto 1) = "100100"
            report "FAIL: flags deveriam permanecer estaveis em halt" severity error;

        -- 3. Testa reset novamente pela chave
        reset <= '1';
        for i in 1 to 4 loop
            wait until rising_edge(clk_50mhz);
        end loop;
        assert led(6 downto 1) = "000000"
            report "FAIL: reset deveria zerar todas as flags" severity error;

        report "tb_main: SIMULACAO INTEGRADA PASSOU COM SUCESSO!" severity note;
        wait;
    end process p_test;

end architecture sim;

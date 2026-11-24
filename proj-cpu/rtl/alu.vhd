library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ALU assincrona (puramente combinacional) de 8 bits conforme Secao 2.3 do Enunciado.
-- Todas as operacoes aritmeticas e logicas da CPU ocorrem aqui.
entity alu is
    port (
        ALU_A    : in  std_logic_vector(7 downto 0);
        ALU_B    : in  std_logic_vector(7 downto 0);
        CMD      : in  std_logic_vector(3 downto 0);
        ALU_R    : out std_logic_vector(7 downto 0);
        ZERO     : out std_logic;
        NEGATIVE : out std_logic;
        OVERFLOW : out std_logic;
        EQUAL    : out std_logic;
        GREATER  : out std_logic;
        SMALLER  : out std_logic
    );
end entity alu;

architecture Behavioral of alu is

    -- Codificacao interna de comandos entre UC e ALU
    constant CMD_ADD : std_logic_vector(3 downto 0) := "0000"; -- add, inc (B=1)
    constant CMD_SUB : std_logic_vector(3 downto 0) := "0001"; -- sub, dec (B=1)
    constant CMD_AND : std_logic_vector(3 downto 0) := "0010"; -- and
    constant CMD_OR  : std_logic_vector(3 downto 0) := "0011"; -- or
    constant CMD_NOT : std_logic_vector(3 downto 0) := "0100"; -- not (B=0)
    constant CMD_XOR : std_logic_vector(3 downto 0) := "0101"; -- xor
    constant CMD_ROL : std_logic_vector(3 downto 0) := "0110"; -- rol (B=0)
    constant CMD_ROR : std_logic_vector(3 downto 0) := "0111"; -- ror (B=0)
    constant CMD_LSL : std_logic_vector(3 downto 0) := "1000"; -- lsl (B=0)
    constant CMD_LSR : std_logic_vector(3 downto 0) := "1001"; -- lsr (B=0)

begin

    p_alu : process(ALU_A, ALU_B, CMD)
        variable a9   : unsigned(8 downto 0);
        variable b9   : unsigned(8 downto 0);
        variable r9   : unsigned(8 downto 0);
        variable res  : std_logic_vector(7 downto 0);
        variable ovf  : std_logic;
    begin
        -- Extensao com zero para 9 bits (unsigned) para obter carry/borrow no bit 8
        a9  := '0' & unsigned(ALU_A);
        b9  := '0' & unsigned(ALU_B);
        r9  := (others => '0');
        res := (others => '0');
        ovf := '0';

        case CMD is
            when CMD_ADD =>
                r9  := a9 + b9;
                res := std_logic_vector(r9(7 downto 0));
                ovf := r9(8); -- carry-out do bit 7

            when CMD_SUB =>
                r9  := a9 - b9;
                res := std_logic_vector(r9(7 downto 0));
                ovf := r9(8); -- borrow (1 se A < B)

            when CMD_AND =>
                res := ALU_A and ALU_B;
                ovf := '0';

            when CMD_OR =>
                res := ALU_A or ALU_B;
                ovf := '0';

            when CMD_NOT =>
                res := not ALU_A;
                ovf := '0';

            when CMD_XOR =>
                res := ALU_A xor ALU_B;
                ovf := '0';

            when CMD_ROL =>
                res := ALU_A(6 downto 0) & ALU_A(7);
                ovf := ALU_A(7); -- bit que saiu pela esquerda

            when CMD_ROR =>
                res := ALU_A(0) & ALU_A(7 downto 1);
                ovf := ALU_A(0); -- bit que saiu pela direita

            when CMD_LSL =>
                res := ALU_A(6 downto 0) & '0';
                ovf := ALU_A(7); -- bit que saiu pela esquerda

            when CMD_LSR =>
                res := '0' & ALU_A(7 downto 1);
                ovf := ALU_A(0); -- bit que saiu pela direita

            when others =>
                res := (others => '0');
                ovf := '0';
        end case;

        -- Saida principal
        ALU_R <= res;

        -- Flags calculadas sobre o resultado
        if res = x"00" then
            ZERO <= '1';
        else
            ZERO <= '0';
        end if;
        NEGATIVE <= res(7);
        OVERFLOW <= ovf;

        -- Flags de comparacao unsigned entre ALU_A e ALU_B
        if unsigned(ALU_A) = unsigned(ALU_B) then
            EQUAL <= '1';
        else
            EQUAL <= '0';
        end if;

        if unsigned(ALU_A) > unsigned(ALU_B) then
            GREATER <= '1';
        else
            GREATER <= '0';
        end if;

        if unsigned(ALU_A) < unsigned(ALU_B) then
            SMALLER <= '1';
        else
            SMALLER <= '0';
        end if;
    end process p_alu;

end architecture Behavioral;

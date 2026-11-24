library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- CPU de 8 bits conforme especificacao do Enunciado (Secoes 2 e 3).
-- Implementa todas as 32 instrucoes da ISA, tratamento de opcodes reservados como NOP,
-- 6 flags armazenadas em flip-flops da UC e FSM de 5 estados sincronizada com a RAM
-- de borda de descida (RAM_8x256).
entity cpu is
    port (
        CLK       : in  std_logic;
        RESET     : in  std_logic;
        -- Interface com a RAM_8x256
        RAM_DIN   : out std_logic_vector(7 downto 0);
        RAM_DOUT  : in  std_logic_vector(7 downto 0);
        RAM_ADDR  : out std_logic_vector(7 downto 0);
        WE        : out std_logic;
        -- Saidas para interface com usuario (LEDs e futuro LCD)
        IR_OUT    : out std_logic_vector(7 downto 0);
        ARG_OUT   : out std_logic_vector(7 downto 0);
        FLAG_Z    : out std_logic;
        FLAG_N    : out std_logic;
        FLAG_OVF  : out std_logic;
        FLAG_EQ   : out std_logic;
        FLAG_GT   : out std_logic;
        FLAG_SM   : out std_logic
    );
end entity cpu;

architecture Behavioral of cpu is

    -- Comandos da ALU (devem coincidir com alu.vhd)
    constant CMD_ADD : std_logic_vector(3 downto 0) := "0000";
    constant CMD_SUB : std_logic_vector(3 downto 0) := "0001";
    constant CMD_AND : std_logic_vector(3 downto 0) := "0010";
    constant CMD_OR  : std_logic_vector(3 downto 0) := "0011";
    constant CMD_NOT : std_logic_vector(3 downto 0) := "0100";
    constant CMD_XOR : std_logic_vector(3 downto 0) := "0101";
    constant CMD_ROL : std_logic_vector(3 downto 0) := "0110";
    constant CMD_ROR : std_logic_vector(3 downto 0) := "0111";
    constant CMD_LSL : std_logic_vector(3 downto 0) := "1000";
    constant CMD_LSR : std_logic_vector(3 downto 0) := "1001";

    -- Banco de 4 registradores de proposito geral: Ra(0), Rb(1), Rc(2), Rd(3)
    type reg_t is array (0 to 3) of std_logic_vector(7 downto 0);
    signal REG : reg_t := (others => (others => '0'));

    -- Registradores especiais
    signal PC  : unsigned(7 downto 0) := (others => '0');
    signal SP  : unsigned(7 downto 0) := to_unsigned(254, 8); -- Obrigatorio: 254 (0xFE)
    signal IR  : std_logic_vector(7 downto 0) := (others => '0');
    signal MAR : std_logic_vector(7 downto 0) := (others => '0');
    signal MBR : std_logic_vector(7 downto 0) := (others => '0');
    signal ARG : std_logic_vector(7 downto 0) := (others => '0'); -- Byte adicional (para LCD)

    -- Controle de escrita na RAM
    signal we_reg : std_logic := '0';

    -- Flip-Flops de flags dentro da UC
    signal f_z   : std_logic := '0';
    signal f_n   : std_logic := '0';
    signal f_ovf : std_logic := '0';
    signal f_eq  : std_logic := '0';
    signal f_gt  : std_logic := '0';
    signal f_sm  : std_logic := '0';

    -- Sinais de ligacao com a ALU assincrona
    signal alu_a   : std_logic_vector(7 downto 0) := (others => '0');
    signal alu_b   : std_logic_vector(7 downto 0) := (others => '0');
    signal alu_cmd : std_logic_vector(3 downto 0) := (others => '0');
    signal alu_r   : std_logic_vector(7 downto 0);
    signal alu_z   : std_logic;
    signal alu_n   : std_logic;
    signal alu_ovf : std_logic;
    signal alu_eq  : std_logic;
    signal alu_gt  : std_logic;
    signal alu_sm  : std_logic;

    -- Maquina de estados da Unidade de Controle (5 ciclos fixos por instrucao)
    type fsm_t is (S_FETCH, S_DECODE1, S_DECODE2, S_EXECUTE, S_WRITE);
    signal state : fsm_t := S_FETCH;

begin

    -- Instancia da ALU assincrona
    u_alu : entity work.alu(Behavioral)
        port map (
            ALU_A    => alu_a,
            ALU_B    => alu_b,
            CMD      => alu_cmd,
            ALU_R    => alu_r,
            ZERO     => alu_z,
            NEGATIVE => alu_n,
            OVERFLOW => alu_ovf,
            EQUAL    => alu_eq,
            GREATER  => alu_gt,
            SMALLER  => alu_sm
        );

    -- Processo principal da Unidade de Controle (borda de subida; RAM opera na borda de descida)
    p_uc : process(CLK)
        variable op  : std_logic_vector(3 downto 0);
        variable rx  : integer range 0 to 3;
        variable ry  : integer range 0 to 3;
        variable fn  : std_logic_vector(1 downto 0);
        variable is_alu_op : boolean;
        variable next_pc   : unsigned(7 downto 0);
    begin
        if rising_edge(CLK) then
            if RESET = '1' then
                REG     <= (others => (others => '0'));
                PC      <= (others => '0');
                SP      <= to_unsigned(254, 8); -- SP = 254 (0xFE)
                IR      <= (others => '0');
                MAR     <= (others => '0');
                MBR     <= (others => '0');
                ARG     <= (others => '0');
                we_reg  <= '0';
                alu_a   <= (others => '0');
                alu_b   <= (others => '0');
                alu_cmd <= (others => '0');
                f_z     <= '0';
                f_n     <= '0';
                f_ovf   <= '0';
                f_eq    <= '0';
                f_gt    <= '0';
                f_sm    <= '0';
                state   <= S_FETCH;
            else
                op := IR(7 downto 4);
                rx := to_integer(unsigned(IR(3 downto 2)));
                ry := to_integer(unsigned(IR(1 downto 0)));
                fn := IR(1 downto 0);

                case state is

                    -- =========================================================
                    -- 1. FETCH: captura opcode em IR (RAM_DOUT ja contem MEM[PC])
                    -- =========================================================
                    when S_FETCH =>
                        IR     <= RAM_DOUT;
                        we_reg <= '0';
                        state  <= S_DECODE1;

                    -- =========================================================
                    -- 2. DECODE1: prepara entradas da ALU ou coloca MAR para leitura extra
                    -- =========================================================
                    when S_DECODE1 =>
                        we_reg <= '0';

                        case op is
                            -- add Rx, Ry
                            when "0000" =>
                                alu_a   <= REG(rx);
                                alu_b   <= REG(ry);
                                alu_cmd <= CMD_ADD;

                            -- sub Rx, Ry
                            when "0001" =>
                                alu_a   <= REG(rx);
                                alu_b   <= REG(ry);
                                alu_cmd <= CMD_SUB;

                            -- inc Rx (fn=00) / dec Rx (fn=01) / reservados (10,11 -> nop)
                            when "0010" =>
                                if fn = "00" then
                                    alu_a   <= REG(rx);
                                    alu_b   <= x"01";
                                    alu_cmd <= CMD_ADD;
                                elsif fn = "01" then
                                    alu_a   <= REG(rx);
                                    alu_b   <= x"01";
                                    alu_cmd <= CMD_SUB;
                                end if;

                            -- and Rx, Ry
                            when "0011" =>
                                alu_a   <= REG(rx);
                                alu_b   <= REG(ry);
                                alu_cmd <= CMD_AND;

                            -- or Rx, Ry
                            when "0100" =>
                                alu_a   <= REG(rx);
                                alu_b   <= REG(ry);
                                alu_cmd <= CMD_OR;

                            -- not Rx (fn=00) / reservados (01,10,11 -> nop)
                            when "0101" =>
                                if fn = "00" then
                                    alu_a   <= REG(rx);
                                    alu_b   <= x"00";
                                    alu_cmd <= CMD_NOT;
                                end if;

                            -- xor Rx, Ry
                            when "0110" =>
                                alu_a   <= REG(rx);
                                alu_b   <= REG(ry);
                                alu_cmd <= CMD_XOR;

                            -- rol (00), ror (01), lsl (10), lsr (11)
                            when "0111" =>
                                alu_a <= REG(rx);
                                alu_b <= x"00";
                                case fn is
                                    when "00"   => alu_cmd <= CMD_ROL;
                                    when "01"   => alu_cmd <= CMD_ROR;
                                    when "10"   => alu_cmd <= CMD_LSL;
                                    when others => alu_cmd <= CMD_LSR;
                                end case;

                            -- Memoria grupo 1000: push(00), pop(01), st(10), ldi(11)
                            when "1000" =>
                                if fn = "01" then
                                    -- pop Rx: ler MEM[SP + 1]
                                    MAR <= std_logic_vector(SP + 1);
                                elsif fn = "10" or fn = "11" then
                                    -- st / ldi: ler byte adicional em MEM[PC + 1]
                                    MAR <= std_logic_vector(PC + 1);
                                end if;

                            -- ldr Rx, [Ry]: ler MEM[Ry]
                            when "1001" =>
                                MAR <= REG(ry);

                            -- jmp 0x-- (somente 1100 00 00)
                            when "1100" =>
                                if IR = x"C0" then
                                    MAR <= std_logic_vector(PC + 1);
                                end if;

                            when others =>
                                null;
                        end case;

                        state <= S_DECODE2;

                    -- =========================================================
                    -- 3. DECODE2: captura dado lido da RAM em MBR (apos borda de descida)
                    -- =========================================================
                    when S_DECODE2 =>
                        we_reg <= '0';

                        case op is
                            when "1000" =>
                                if fn = "01" then
                                    -- pop Rx
                                    MBR <= RAM_DOUT;
                                elsif fn = "10" or fn = "11" then
                                    -- st / ldi: captura byte adicional
                                    MBR <= RAM_DOUT;
                                    ARG <= RAM_DOUT;
                                end if;

                            when "1001" =>
                                -- ldr Rx, [Ry]
                                MBR <= RAM_DOUT;

                            when "1100" =>
                                if IR = x"C0" then
                                    -- jmp 0x--
                                    MBR <= RAM_DOUT;
                                    ARG <= RAM_DOUT;
                                end if;

                            when others =>
                                null;
                        end case;

                        state <= S_EXECUTE;

                    -- =========================================================
                    -- 4. EXECUTE: grava registrador/flags ou dispara escrita na RAM
                    -- =========================================================
                    when S_EXECUTE =>
                        we_reg <= '0';

                        -- Verifica se o opcode eh uma instrucao valida de ALU
                        is_alu_op := false;
                        if op = "0000" or op = "0001" or op = "0011" or
                           op = "0100" or op = "0110" or op = "0111" then
                            is_alu_op := true;
                        elsif op = "0010" and (fn = "00" or fn = "01") then
                            is_alu_op := true;
                        elsif op = "0101" and fn = "00" then
                            is_alu_op := true;
                        end if;

                        if is_alu_op then
                            REG(rx) <= alu_r;
                            f_z     <= alu_z;
                            f_n     <= alu_n;
                            f_ovf   <= alu_ovf;
                            f_eq    <= alu_eq;
                            f_gt    <= alu_gt;
                            f_sm    <= alu_sm;
                        else
                            case op is
                                when "1000" =>
                                    case fn is
                                        when "00" =>
                                            -- push Rx: MEM[SP] <- Rx; SP <- SP - 1
                                            MAR    <= std_logic_vector(SP);
                                            MBR    <= REG(rx);
                                            we_reg <= '1';
                                            SP     <= SP - 1;
                                        when "01" =>
                                            -- pop Rx: Rx <- MEM[SP+1]; SP <- SP + 1
                                            REG(rx) <= MBR;
                                            SP      <= SP + 1;
                                        when "10" =>
                                            -- st Rx, ADDR: MEM[ADDR] <- Rx
                                            MAR    <= MBR;
                                            MBR    <= REG(rx);
                                            we_reg <= '1';
                                        when others =>
                                            -- ldi Rx, IMM: Rx <- IMM
                                            REG(rx) <= MBR;
                                    end case;

                                when "1001" =>
                                    -- ldr Rx, [Ry]
                                    REG(rx) <= MBR;

                                when "1010" =>
                                    -- str Rx, [Ry]: MEM[Ry] <- Rx
                                    MAR    <= REG(ry);
                                    MBR    <= REG(rx);
                                    we_reg <= '1';

                                when "1011" =>
                                    -- mov Rx, Ry
                                    REG(rx) <= REG(ry);

                                when others =>
                                    null;
                            end case;
                        end if;

                        state <= S_WRITE;

                    -- =========================================================
                    -- 5. WRITE: desliga WE, atualiza PC e posiciona MAR para o proximo FETCH
                    -- =========================================================
                    when S_WRITE =>
                        we_reg  <= '0';
                        next_pc := PC + 1;

                        case op is
                            -- st e ldi avancam PC em 2 bytes
                            when "1000" =>
                                if fn = "10" or fn = "11" then
                                    next_pc := PC + 2;
                                end if;

                            -- jmp (1100 00 00), jmpr (01), bz (10), bnz (11)
                            when "1100" =>
                                if IR = x"C0" then
                                    next_pc := unsigned(MBR);
                                elsif fn = "01" then
                                    next_pc := unsigned(REG(rx));
                                elsif fn = "10" then
                                    if f_z = '1' then
                                        next_pc := unsigned(REG(rx));
                                    end if;
                                elsif fn = "11" then
                                    if f_z = '0' then
                                        next_pc := unsigned(REG(rx));
                                    end if;
                                end if;

                            -- bcs (00), bcc (01), beq (10), bneq (11)
                            when "1101" =>
                                case fn is
                                    when "00" =>
                                        if f_ovf = '1' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when "01" =>
                                        if f_ovf = '0' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when "10" =>
                                        if f_eq = '1' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when others =>
                                        if f_eq = '0' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                end case;

                            -- bgt (00), blt (01), bneg (10), reservado (11 -> nop)
                            when "1110" =>
                                case fn is
                                    when "00" =>
                                        if f_gt = '1' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when "01" =>
                                        if f_sm = '1' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when "10" =>
                                        if f_n = '1' then
                                            next_pc := unsigned(REG(rx));
                                        end if;
                                    when others =>
                                        next_pc := PC + 1;
                                end case;

                            -- halt (1111 11 11) mantem PC parado; demais sao nop (PC + 1)
                            when "1111" =>
                                if IR = x"FF" then
                                    next_pc := PC;
                                end if;

                            when others =>
                                next_pc := PC + 1;
                        end case;

                        PC    <= next_pc;
                        MAR   <= std_logic_vector(next_pc);
                        state <= S_FETCH;

                end case;
            end if;
        end if;
    end process p_uc;

    -- Saidas para a RAM
    RAM_ADDR <= MAR;
    RAM_DIN  <= MBR;
    WE       <= we_reg;

    -- Saidas de observacao / interface com usuario
    IR_OUT   <= IR;
    ARG_OUT  <= ARG;
    FLAG_Z   <= f_z;
    FLAG_N   <= f_n;
    FLAG_OVF <= f_ovf;
    FLAG_EQ  <= f_eq;
    FLAG_GT  <= f_gt;
    FLAG_SM  <= f_sm;

end architecture Behavioral;

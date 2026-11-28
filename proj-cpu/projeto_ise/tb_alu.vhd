library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Testbench auto-verificavel para a ALU assincrona (alu.vhd).
-- Cobre todas as operacoes e casos de borda do Enunciado (255+1, 0-1, 3-5, 200+100, 200-10, etc.).
entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is

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

    signal a        : std_logic_vector(7 downto 0) := (others => '0');
    signal b        : std_logic_vector(7 downto 0) := (others => '0');
    signal cmd      : std_logic_vector(3 downto 0) := (others => '0');
    signal r        : std_logic_vector(7 downto 0);
    signal z        : std_logic;
    signal n        : std_logic;
    signal ovf      : std_logic;
    signal eq       : std_logic;
    signal gt       : std_logic;
    signal sm       : std_logic;

begin

    uut : entity work.alu(Behavioral)
        port map (
            ALU_A    => a,
            ALU_B    => b,
            CMD      => cmd,
            ALU_R    => r,
            ZERO     => z,
            NEGATIVE => n,
            OVERFLOW => ovf,
            EQUAL    => eq,
            GREATER  => gt,
            SMALLER  => sm
        );

    p_stim : process
        procedure check(
            va, vb     : std_logic_vector(7 downto 0);
            vcmd       : std_logic_vector(3 downto 0);
            exp_r      : std_logic_vector(7 downto 0);
            exp_z      : std_logic;
            exp_n      : std_logic;
            exp_ovf    : std_logic;
            exp_eq     : std_logic;
            exp_gt     : std_logic;
            exp_sm     : std_logic;
            msg        : string
        ) is
        begin
            a   <= va;
            b   <= vb;
            cmd <= vcmd;
            wait for 10 ns;
            assert r = exp_r
                report "FAIL (" & msg & "): ALU_R mismatch" severity error;
            assert z = exp_z
                report "FAIL (" & msg & "): ZERO mismatch" severity error;
            assert n = exp_n
                report "FAIL (" & msg & "): NEGATIVE mismatch" severity error;
            assert ovf = exp_ovf
                report "FAIL (" & msg & "): OVERFLOW mismatch" severity error;
            assert eq = exp_eq
                report "FAIL (" & msg & "): EQUAL mismatch" severity error;
            assert gt = exp_gt
                report "FAIL (" & msg & "): GREATER mismatch" severity error;
            assert sm = exp_sm
                report "FAIL (" & msg & "): SMALLER mismatch" severity error;
        end procedure;
    begin
        -- 1. ADD / INC: 255 + 1 = 0, Z=1, N=0, OVF=1, GT=1
        check(x"FF", x"01", CMD_ADD, x"00", '1', '0', '1', '0', '1', '0', "255 + 1");

        -- 2. ADD: 200 + 100 = 300 -> 0x2C (44), Z=0, N=0, OVF=1, GT=1
        check(x"C8", x"64", CMD_ADD, x"2C", '0', '0', '1', '0', '1', '0', "200 + 100");

        -- 3. SUB / DEC: 0 - 1 = 0xFF (255), Z=0, N=1, OVF=1, SM=1
        check(x"00", x"01", CMD_SUB, x"FF", '0', '1', '1', '0', '0', '1', "0 - 1");

        -- 4. SUB: 3 - 5 = 0xFE (254), Z=0, N=1, OVF=1, SM=1
        check(x"03", x"05", CMD_SUB, x"FE", '0', '1', '1', '0', '0', '1', "3 - 5");

        -- 5. SUB: 5 - 3 = 0x02, Z=0, N=0, OVF=0, GT=1
        check(x"05", x"03", CMD_SUB, x"02", '0', '0', '0', '0', '1', '0', "5 - 3");

        -- 6. SUB: 200 - 10 = 190 (0xBE), Z=0, N=1, OVF=0, GT=1
        check(x"C8", x"0A", CMD_SUB, x"BE", '0', '1', '0', '0', '1', '0', "200 - 10");

        -- 7. SUB igualdade: 10 - 10 = 0, Z=1, N=0, OVF=0, EQ=1
        check(x"0A", x"0A", CMD_SUB, x"00", '1', '0', '0', '1', '0', '0', "10 - 10");

        -- 8. AND / OR / XOR / NOT (OVERFLOW sempre 0)
        check(x"F0", x"0F", CMD_AND, x"00", '1', '0', '0', '0', '1', '0', "AND F0 & 0F");
        check(x"F0", x"0F", CMD_OR,  x"FF", '0', '1', '0', '0', '1', '0', "OR F0 | 0F");
        check(x"AA", x"AA", CMD_XOR, x"00", '1', '0', '0', '1', '0', '0', "XOR AA ^ AA");
        check(x"0F", x"00", CMD_NOT, x"F0", '0', '1', '0', '0', '1', '0', "NOT 0F");

        -- 9. ROL / ROR / LSL / LSR (B=0, OVERFLOW = bit expulso)
        check(x"81", x"00", CMD_ROL, x"03", '0', '0', '1', '0', '1', '0', "ROL 81 (msb=1)");
        check(x"41", x"00", CMD_ROL, x"82", '0', '1', '0', '0', '1', '0', "ROL 41 (msb=0)");
        check(x"81", x"00", CMD_ROR, x"C0", '0', '1', '1', '0', '1', '0', "ROR 81 (lsb=1)");
        check(x"82", x"00", CMD_ROR, x"41", '0', '0', '0', '0', '1', '0', "ROR 82 (lsb=0)");
        check(x"80", x"00", CMD_LSL, x"00", '1', '0', '1', '0', '1', '0', "LSL 80 (msb=1)");
        check(x"01", x"00", CMD_LSR, x"00", '1', '0', '1', '0', '1', '0', "LSR 01 (lsb=1)");

        report "tb_alu: TODOS OS TESTES PASSARAM!" severity note;
        wait;
    end process p_stim;

end architecture sim;

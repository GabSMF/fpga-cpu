# ISA da CPU de 8 bits

Resumo da seção 2 do [enunciado](../../ENUNCIADO.pdf), na forma usada pela CPU (`rtl/cpu.vhd`), pela ALU (`rtl/alu.vhd`), pelo modelo de referência (`tools/cpu8.py`) e pelo texto do LCD (`rtl/lcd_texto.vhd`). Se algo aqui divergir do enunciado, vale o enunciado.

## Formato

Toda instrução tem 1 byte. `ldi`, `st` e `jmp` têm um segundo byte (ADDR, em PC+1), que é dado e nunca é executado.

| bits 7..4 | bits 3..2 | bits 1..0 |
| --- | --- | --- |
| opcode | Rx | Ry, ou função nas instruções de um operando |

Registradores: Ra = `00`, Rb = `01`, Rc = `10`, Rd = `11`.

## Tabela

`f` = atualiza as seis flags. Nos desvios, Rx contém o **endereço de destino**; a condição vem das flags salvas pela última instrução de ALU.

| Assembly | Byte | Operação | Flags | LCD linha 1 |
| --- | --- | --- | :-: | --- |
| `add Rx, Ry` | `0000 xx yy` | Rx ← Rx + Ry | f | `ADD Ra Rb` |
| `sub Rx, Ry` | `0001 xx yy` | Rx ← Rx − Ry | f | `SUB Ra Rb` |
| `inc Rx` | `0010 xx 00` | Rx ← Rx + 1 (ALU_B = 1) | f | `INC Ra` |
| `dec Rx` | `0010 xx 01` | Rx ← Rx − 1 (ALU_B = 1) | f | `DEC Ra` |
| `and Rx, Ry` | `0011 xx yy` | Rx ← Rx & Ry | f | `AND Ra Rb` |
| `or Rx, Ry` | `0100 xx yy` | Rx ← Rx \| Ry | f | `OR Ra Rb` |
| `not Rx` | `0101 xx 00` | Rx ← ~Rx (ALU_B = 0) | f | `NOT Ra` |
| `xor Rx, Ry` | `0110 xx yy` | Rx ← Rx ^ Ry | f | `XOR Ra Rb` |
| `rol Rx` | `0111 xx 00` | Rx ← Rx[6:0] Rx[7] | f | `ROL Ra` |
| `ror Rx` | `0111 xx 01` | Rx ← Rx[0] Rx[7:1] | f | `ROR Ra` |
| `lsl Rx` | `0111 xx 10` | Rx ← Rx[6:0] 0 | f | `LSL Ra` |
| `lsr Rx` | `0111 xx 11` | Rx ← 0 Rx[7:1] | f | `LSR Ra` |
| `push Rx` | `1000 xx 00` | MEM[SP] ← Rx; SP ← SP − 1 | | `PUSH Ra` |
| `pop Rx` | `1000 xx 01` | SP ← SP + 1; Rx ← MEM[SP] | | `POP Ra` |
| `st Rx, ADDR` | `1000 xx 10` + ADDR | MEM[ADDR] ← Rx; PC ← PC + 2 | | `ST Ra, 0xFF` |
| `ldi Rx, ADDR` | `1000 xx 11` + ADDR | Rx ← ADDR; PC ← PC + 2 | | `LDI Ra, 0x64` |
| `ldr Rx, [Ry]` | `1001 xx yy` | Rx ← MEM[Ry] | | `LDR Ra [Rb]` |
| `str Rx, [Ry]` | `1010 xx yy` | MEM[Ry] ← Rx | | `STR Ra [Rb]` |
| `mov Rx, Ry` | `1011 xx yy` | Rx ← Ry | | `MOV Ra Rb` |
| `jmp ADDR` | `1100 00 00` + ADDR | PC ← ADDR | | `JMP 0x40` |
| `jmpr Rx` | `1100 xx 01` | PC ← Rx | | `JMPR Ra` |
| `bz Rx` | `1100 xx 10` | se ZERO: PC ← Rx | | `BZ Ra` |
| `bnz Rx` | `1100 xx 11` | se não ZERO: PC ← Rx | | `BNZ Ra` |
| `bcs Rx` | `1101 xx 00` | se OVERFLOW: PC ← Rx | | `BCS Ra` |
| `bcc Rx` | `1101 xx 01` | se não OVERFLOW: PC ← Rx | | `BCC Ra` |
| `beq Rx` | `1101 xx 10` | se EQUAL: PC ← Rx | | `BEQ Ra` |
| `bneq Rx` | `1101 xx 11` | se não EQUAL: PC ← Rx | | `BNEQ Ra` |
| `bgt Rx` | `1110 xx 00` | se GREATER: PC ← Rx | | `BGT Ra` |
| `blt Rx` | `1110 xx 01` | se SMALLER: PC ← Rx | | `BLT Ra` |
| `bneg Rx` | `1110 xx 10` | se NEGATIVE: PC ← Rx | | `BNEG Ra` |
| `nop` | `1111 00 00` (`F0`) | nada | | `NOP` |
| `halt` | `1111 11 11` (`FF`) | PC ← PC | | `HALT` |

Quando não há salto, PC ← PC + 1 (ou + 2 em `ldi`/`st`).

### Códigos reservados (41)

Executam como `nop`: nada muda e PC ← PC + 1. No LCD aparecem como `NOP (0xNN)`.

- `0010 xx 10` e `0010 xx 11`: `22 23 26 27 2A 2B 2E 2F`
- `0101 xx 01..11`: `51 52 53 55 56 57 59 5A 5B 5D 5E 5F`
- `1100 xx 00` com xx ≠ 00: `C4 C8 CC`
- `1110 xx 11`: `E3 E7 EB EF`
- `1111 xxxx` exceto `F0` e `FF`: `F1` a `FE`

## Flags (seção 2.3.1)

A = ALU_A (Rx), B = ALU_B (Ry, 1 em `inc`/`dec`, 0 em `not` e deslocamentos). Todas unsigned.

| Flag | LED | Valor |
| --- | --- | --- |
| ZERO | LD6 | resultado = 0 |
| NEGATIVE | LD5 | bit 7 do resultado |
| OVERFLOW | LD4 | `add`/`inc`: carry (A + B > 255); `sub`/`dec`: borrow (A < B); `rol`/`lsl`: bit 7 original; `ror`/`lsr`: bit 0 original; `and`/`or`/`xor`/`not`: 0 |
| EQUAL | LD3 | A = B |
| GREATER | LD2 | A > B |
| SMALLER | LD1 | A < B |

LD7 é o clock da CPU e LD0 fica apagado. Só as 12 instruções de ALU atualizam as flags, e sempre as seis.

## Vetores de conferência (do enunciado)

| Fonte | Bytes |
| --- | --- |
| `add Rc, Rb` | `09` |
| `dec Rd` | `2D` |
| `jmp 64` | `C0 40` |
| `ldi Ra, 10` / `st Ra, 255` / `halt` | `83 0A 82 FF FF` |

Conferidos com o `nasm.exe` do professor (Wine) em 27/11/2026.

## Ciclo de instrução (rtl/cpu.vhd)

Sempre 5 ciclos do clock da CPU, inclusive nas instruções de 2 bytes. A RAM é síncrona: registra o endereço e escreve na **borda de descida**, e a CPU age na **borda de subida**.

| Estado | O que faz |
| --- | --- |
| FETCH | IR ← DOUT (= MEM[PC], endereço posto em MAR no WRITE anterior) |
| DECODE1 | prepara ALU_A/ALU_B/CMD, ou MAR ← PC+1 / SP+1 / Ry para a leitura extra |
| DECODE2 | MBR ← DOUT (e ARG ← DOUT em `ldi`/`st`/`jmp`, para o LCD) |
| EXECUTE | grava registrador e flags, ou liga WE por um ciclo (MAR e MBR com endereço e dado) |
| WRITE | desliga WE, calcula o próximo PC, MAR ← PC |

Com o divisor de 50 MHz para 2,5 Hz, cada estado dura 0,4 s e cada instrução 2,0 s.

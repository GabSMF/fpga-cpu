# Critérios de pronto

Cada critério sai de uma frase do [`ENUNCIADO.pdf`](../../ENUNCIADO.pdf) (seção entre parênteses). O projeto está pronto quando todas as linhas estão ✅.

Legenda da coluna "Verificado em":

- **ISim**: testbench automático, rodado com `tools/ise.sh sim`.
- **XST/PAR**: síntese e implementação, `tools/ise.sh impl`.
- **Placa**: depende de uma pessoa gravar e observar. O roteiro está em [`TESTE_NA_PLACA.md`](TESTE_NA_PLACA.md).
- **Revisão**: leitura do código ou do documento.

Situação em 27/11/2026. Tudo que dá para provar sem a placa está ✅. Os itens ⏳ dependem da placa ou de material que só a dupla tem (fotos e vídeo).

## A. Arquitetura (seção 2.1)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| A1 | 4 registradores de uso geral Ra, Rb, Rc, Rd de 8 bits | Revisão (`cpu.vhd`, `REG`) + ISim | ✅ |
| A2 | Registradores especiais IR, PC, SP, MBR e MAR, todos de 8 bits | Revisão (`cpu.vhd`) | ✅ |
| A3 | RAM de 256 × 8 bits com o programa carregado como valor inicial do array | ISim (`tb_ram`, `tb_main`) | ✅ |
| A4 | ALU assíncrona (sem clock) com operações aritméticas e lógicas | Revisão (`alu.vhd` é combinacional) + ISim (`tb_alu`) | ✅ |
| A5 | UC com máquina de estados fetch, decode1, decode2, execute, write | Revisão (`cpu.vhd`, `fsm_t`) | ✅ |
| A6 | Palavra de 8 bits em tudo (instruções, dados, endereços, PC, SP) | Revisão | ✅ |

## B. ISA (seções 2.1.1 e 2.2)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| B1 | Formato `opcode[7:4] Rx[3:2] Ry/função[1:0]`, Ra=00..Rd=11 | ISim (`tb_cpu_programas`) + vetores do PDF (`09`, `2D`, `C0 40`) | ✅ |
| B2 | As 32 instruções da tabela executam conforme a descrição | ISim: 29 programas, traço instrução a instrução contra o modelo | ✅ |
| B3 | Os 9 desvios testados tomados e não tomados | ISim (`fibonacci` + `bubble_sort`, cobertura medida por `cpu8.py`) | ✅ |
| B4 | `ldi`, `st` e `jmp` leem o byte em PC+1; `ldi`/`st` avançam PC em 2; o complemento nunca é executado | ISim | ✅ |
| B5 | Nos desvios, Rx é o endereço de destino e a condição vem das flags salvas | ISim | ✅ |
| B6 | Os 41 códigos fora da tabela agem como `nop` (nada muda, PC+1) | ISim (`reservados` + aleatórios) | ✅ |
| B7 | `halt` mantém o PC parado | ISim (o traço confere 3 execuções seguidas de `halt`) | ✅ |
| B8 | `push`: MEM[SP] ← Rx, SP−1. `pop`: Rx ← MEM[SP+1], SP+1 | ISim | ✅ |

## C. ALU e flags (seção 2.3)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| C1 | Toda conta é feita na ALU; somadores fora dela só para PC e SP | Revisão (`cpu.vhd`) | ✅ |
| C2 | `inc`/`dec` usam ALU_B = 1; `not`/`rol`/`ror`/`lsl`/`lsr` usam ALU_B = 0 | Revisão + ISim | ✅ |
| C3 | Seis flags: ZERO, NEGATIVE, OVERFLOW, EQUAL, GREATER, SMALLER | ISim (`tb_alu`, `tb_cpu_programas`) | ✅ |
| C4 | OVERFLOW = carry/borrow unsigned em 9 bits, ou bit expulso, ou 0 nas lógicas | ISim (`tb_alu` cobre 255+1, 0−1, 3−5, 200+100, 200−10) | ✅ |
| C5 | Comparações (EQ/GT/SM) entre ALU_A e ALU_B, unsigned | ISim | ✅ |
| C6 | Só as 12 instruções de ALU atualizam as flags, e sempre as seis | ISim | ✅ |
| C7 | Flags guardadas em flip-flops da UC no fim do execute | Revisão + ISim | ✅ |

## D. Pilha, reset e clock (seções 2.4 e 3)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| D1 | SP inicializado em 254 dentro da UC | ISim (`push` grava em 254) | ✅ |
| D2 | Reset por chave da placa (SW0), não por botão | Revisão (UCF) + Placa (feito em 25/11) | ✅ |
| D3 | Reset leva a PC=0, SP=254, flags=0 e UC em fetch; a CPU executa ao soltar | ISim (`tb_cpu_programas` reseta entre programas) + Placa | ✅ |
| D4 | Cerca de 2 s por instrução completa (do fetch ao write) | Revisão (5 ciclos × 0,4 s) + Placa (feito em 25/11) | ✅ |
| D5 | Só o clock da CPU é reduzido; o LCD usa 50 MHz | Revisão (`main.vhd`) | ✅ |
| D6 | UC respeita a RAM síncrona (endereço num estado, dado no seguinte) | ISim | ✅ |
| D7 | Código estruturado: componentes instanciados `u_cpu`, `u_alu`, `u_memory`, `u_lcd`, com comentários | Revisão | ✅ |

## E. Interface com o usuário (seção 3.1)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| E1 | LEDs LD7..LD0 = CLOCK, Z, N, OVF, EQ, GT, SM, livre | ISim (`tb_main`) + Placa (feito em 25/11) | ✅ |
| E2 | LEDs mostram as flags da última operação de ALU e não mudam até a próxima | ISim + Placa | ✅ |
| E3 | LCD linha 1 = instrução atual (assembly), espelhando o IR permanentemente | ISim (`tb_lcd_texto`, `tb_lcd`, `tb_main`) | ✅ ISim, ⏳ Placa |
| E4 | LCD linha 2 = `MEM[255] = ddd` | ISim | ✅ ISim, ⏳ Placa |
| E5 | Escrever no LCD é `st Rx, 0xFF` | ISim (`fibonacci`, `bubble_sort`) | ✅ ISim, ⏳ Placa |
| E6 | Inicialização e tempos do LCD conforme o UG230 | ISim (`tb_lcd` mede os tempos) | ✅ ISim, ⏳ Placa |

## F. Programa na memória (seção 4.3)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| F1 | Interface da RAM igual à do professor: `RAM_8x256(rtl)`, `CLK, DIN, ADDR, WE, DOUT, POS_255` | Revisão + ISim | ✅ |
| F2 | Trocar só o bloco `signal ram` (ou o arquivo inteiro gerado pelo montador) basta | ISim: `tb_main` roda com o arquivo gerado pelo `nasm.exe` | ✅ |
| F3 | Exemplo da seção 4.3 monta em `83 0A 82 FF FF` e deixa MEM[255]=10 | `nasm.exe` + ISim (`secao43`) | ✅ |
| F4 | Programa surpresa: qualquer combinação de instruções funciona | ISim (24 programas aleatórios) | ✅ ISim, ⏳ Placa |

## G. Testes pedidos pelo professor

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| G1 | Fibonacci correto | ISim + `tb_main` com a imagem gravada | ✅ ISim, ⏳ Placa |
| G2 | Bubble sort correto (repetidos, valores ≥ 128, já ordenado, invertido) | ISim | ✅ ISim, ⏳ Placa |

## H. Entrega (seção 4)

| # | Critério | Verificado em | Status |
| --- | --- | --- | --- |
| H1 | Relatório PDF de ~15 páginas ou mais com: diagrama do caminho de dados, descrição de cada unidade, FSM da UC, assembly comentado (Fibonacci), explicação dos testes, LCD e LEDs | Revisão (`docs/relatorio.pdf`) | ✅ rascunho, ⏳ fotos |
| H2 | ZIP com VHDL completo, constraints e testbench pronto para simular | Revisão + conferência do ZIP extraído | ✅ |
| H3 | Projeto limpo antes de zipar (sem arquivos gerados) | Revisão do ZIP | ✅ |
| H4 | Fotos e/ou vídeo (YouTube não listado, se for o caso) | Dupla | ⏳ |
| H5 | Apresentação: programa demonstrativo + tabela passo a passo (Passo, PC, LCD, flags, MEM[255]) | `programs/gen/*.md` | ✅ tabela, ⏳ ensaio |

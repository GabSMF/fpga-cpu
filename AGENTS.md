# AGENTS.md

CPU de 8 bits em VHDL para FPGA, trabalho final de Computação Digital (ENG4448, PUC-Rio, prof. Felipe Calliari). Dupla: Gabriel e Danilo.
Placa: Spartan-3E Starter Kit, `xc3s500e-4fg320`. Ferramenta: Xilinx ISE 14.7. Comentários, documentação e commits em português.

## Fontes de verdade, em ordem

1. [`ENUNCIADO.pdf`](ENUNCIADO.pdf): ISA, flags, interface e entrega. Se algo divergir dele, o enunciado vence.
2. [`docs/Spartan-3E_FPGA_Starter_Kit_Board.pdf`](docs/Spartan-3E_FPGA_Starter_Kit_Board.pdf) (UG230): pinos e tempos da placa.
3. [`proj-cpu/ROADMAP.md`](proj-cpu/ROADMAP.md): o que falta e em que ordem.
4. [`proj-cpu/docs/CRITERIOS_DE_PRONTO.md`](proj-cpu/docs/CRITERIOS_DE_PRONTO.md): cada exigência do enunciado e como foi verificada.
5. Este arquivo: estado verificado, armadilhas e comandos.

Os projetos em `refs/` **não** são fonte de verdade (ver "Referências").

## Mapa do repositório

| Caminho | O que é |
| --- | --- |
| `proj-cpu/rtl/` | VHDL: `main.vhd` (topo), `cpu.vhd`, `alu.vhd`, `RAM_8x256.vhd` (imagem do programa), `lcd.vhd`, `lcd_texto.vhd`, `lcd_pkg.vhd` |
| `proj-cpu/tb/` | Testbenches `tb_alu`, `tb_ram`, `tb_lcd_texto`, `tb_lcd`, `tb_cpu_programas`, `tb_main`; `lcd_modelo.vhd` (modelo do display); `dados/` (referências geradas) |
| `proj-cpu/constraints/spartan3e.ucf` | Clock, reset (SW0), LEDs e LCD |
| `proj-cpu/programs/` | `.asm` (`fibonacci`, `bubble_sort` e variantes, `reservados`, `secao43`, `demo_flags`) e `gen/` (imagens, traços, tabelas passo a passo). Ver o `README.md` dela |
| `proj-cpu/tools/` | `cpu8.py` (montador, modelo de referência, geração de testes), `ise.sh` (ISim/XST/PAR no Docker), `gera_bits.sh`, `relatorio.py`, `empacotar.sh`, `criar_projeto_ise.tcl` |
| `proj-cpu/projeto_ise/` | **Projeto do ISE numa pasta só** (formato de projeto exportado, como `test_proj_dan_gab.zip`): é o que a dupla copia para o PC do laboratório, abre e grava. **Gerado** por `tools/exportar_ise.sh`: nunca editar à mão |
| `proj-cpu/ise/cpu8.xise` | O mesmo projeto apontando para `../rtl`, `../tb`, `../constraints` (uso com os scripts) |
| `proj-cpu/docs/` | `ISA.md`, `CRITERIOS_DE_PRONTO.md`, `TESTE_NA_PLACA.md`, `relatorio.pdf` |
| `proj-cpu/build/`, `proj-cpu/entrega/` | Saídas (relatórios do ISE, `.bit`, ZIP). Ignoradas pelo git |
| `proj-cpu/cpu.vhd`, `proj-cpu/RAM_8x256.vhd`, `proj-cpu/character_to_slv_v2.txt` | Originais do professor. **Não editar nem compilar**: as entidades têm o mesmo nome das de `rtl/` |
| `NASM/` | Montador do professor (`nasm.exe`) e exemplos `.asm` (não usados nos testes: têm trechos inalcançáveis) |
| `Passo_atual_test.md` | Roteiro do primeiro teste na placa (25/11, sem LCD). Substituído por `proj-cpu/docs/TESTE_NA_PLACA.md` |
| `test_proj_dan_gab.zip` | Projeto ISE testado na placa em 25/11/2026, antes do LCD. Histórico: não alterar |
| `docs/` | UG230, DS312 e manuais de periféricos que o enunciado não pede |

Tudo que for criado fica dentro de `proj-cpu/`, para a pasta ser arquivada sozinha na entrega.

## Estado verificado em 27/11/2026

| Item | Situação |
| --- | --- |
| CPU, ALU, RAM, divisor, LEDs | Prontos. Testados na placa em 25/11 (`demo_flags`) |
| LCD | Pronto em simulação (`tb_lcd_texto`, `tb_lcd`, `tb_main`). **Falta ver na placa** |
| ISA | `tb_cpu_programas`: 34 programas, 12.247 instruções idênticas ao modelo de referência, incluindo 41 reservados e os 9 desvios nos dois sentidos |
| Fibonacci + bubble sort | Juntos executam as 32 instruções. Passam em simulação; **falta a placa** |
| Síntese/implementação | 0 erros, timing atendido, cerca de 51% dos slices, 3 BRAMs (texto do LCD). `ise/cpu8.xise` gera o `.bit` pelo fluxo do ISE |
| Relatório | `docs/relatorio.pdf` (23 páginas); **faltam fotos/vídeo** |
| ZIP | `tools/empacotar.sh`; testado a partir da cópia extraída |

O que falta é da dupla: rodar [`proj-cpu/docs/TESTE_NA_PLACA.md`](proj-cpu/docs/TESTE_NA_PLACA.md), pôr as fotos em `proj-cpu/docs/fotos/`, regenerar o relatório e o ZIP e entregar.

### Correções ao ROADMAP original

- O montador da seção 4.3 é `NASM/nasm.exe` (v0.5, Felipe Calliari, Python empacotado com PyInstaller). Roda no Linux pelo Wine.
- A RAM **não** vira block RAM no XST: são 2048 flip-flops, por causa da leitura assíncrona `POS_255 <= ram(255)`. O arquivo original do professor faz o mesmo. Manter.

## Arquitetura

```
main (topo)
├── divisor 50 MHz → clk_cpu (2,5 Hz)
├── u_cpu : cpu            UC (FSM 5 estados), registradores, flags; saídas IR/ARG/IR_OK/ARG_OK
│   └── u_alu : alu        combinacional, CMD de 4 bits
├── u_memory : RAM_8x256   mesmo clk_cpu, borda de DESCIDA
└── u_lcd : lcd            50 MHz: sincroniza, formata (lcd_texto) e escreve o LCD
```

FSM sempre com 5 ciclos por instrução, inclusive nas de 2 bytes. A CPU age na borda de subida:

| Estado | Ação |
| --- | --- |
| `S_FETCH` | `IR <= RAM_DOUT` (o `MAR` já contém o `PC`); `IR_OK <= 1`, `ARG_OK <= 0` |
| `S_DECODE1` | Prepara as entradas da ALU, ou põe em `MAR` o endereço da leitura extra (`PC+1`, `SP+1` ou `Ry`) |
| `S_DECODE2` | `MBR <= RAM_DOUT`; em `ldi`/`st`/`jmp` também `ARG`; `ARG_OK <= 1` |
| `S_EXECUTE` | Grava registrador e flags, ou liga `WE` por um ciclo |
| `S_WRITE` | Desliga `WE`, calcula o próximo `PC` e carrega `MAR` |

Sequência de acesso à RAM: `MAR` muda na subida, a RAM captura na descida, `DOUT` é lido na subida seguinte. Preservar essa janela em qualquer mudança.

## Regras da ISA que costumam dar erro

Tabela completa em [`proj-cpu/docs/ISA.md`](proj-cpu/docs/ISA.md). Formato: `opcode[7:4] Rx[3:2] Ry/função[1:0]`, com Ra=00, Rb=01, Rc=10, Rd=11.

- **Só a ALU faz conta.** Somadores fora dela são permitidos apenas para `PC` e `SP`. `inc`/`dec` usam a ALU com `B=1`; `not`, `rol`, `ror`, `lsl` e `lsr` usam `B=0`.
- Só as 12 instruções de ALU alteram flags, e alteram **todas as seis**. Memória, `mov`, saltos, `nop` e `halt` preservam (e `pop` também, o que permite `push`/`sub`/`pop` para comparar sem perder o registrador).
- `OVERFLOW` é carry/borrow **unsigned** em 9 bits, ou o bit expulso, ou 0 nas lógicas. `EQ`/`GT`/`SM` comparam **as entradas A e B** da ALU.
- Nos desvios, `Rx` é o **endereço de destino**; a condição vem das flags salvas. `ldi` não muda flags, então dá para carregar o destino entre a conta e o salto.
- `nop` = `0xF0`, `halt` = `0xFF`. Os 41 códigos fora da tabela agem como `nop`. `jmp` só vale como `0xC0` exato.

## Invariantes do projeto

- **Interface da RAM intocável**: entidade `RAM_8x256`, arquitetura `rtl`, portas `CLK, DIN, ADDR, WE, DOUT, POS_255`, sinal `ram : RAM_t`. O professor troca o bloco inicializador ou o arquivo inteiro.
- Não adaptar a CPU a um programa específico.
- Reset pela **chave SW0** (1 = reset). Síncrono ao `clk_cpu`: manter em 1 por cerca de 1 s. **Reset não restaura a RAM.**
- **2 s por instrução**: `CLK_DIV_MAX = 9999999`. Testbenches sobrescrevem o generic, nunca o valor padrão.
- LEDs: LD7 clock, LD6 Z, LD5 N, LD4 OVF, LD3 EQ, LD2 GT, LD1 SM, LD0 apagado.
- `CMD_*` está duplicado em `alu.vhd`, `cpu.vhd` e `tb_alu.vhd`: mudar nos três.
- Texto do LCD: a tabela de `rtl/lcd_texto.vhd` é **gerada** por `tools/cpu8.py lcdrom` a partir da mesma função que gera as referências dos testes. Mudar o texto em `cpu8.py` (`modelo_lcd`), regenerar a tabela e rodar `cpu8.py all`.
- Depois de mudar `cpu.vhd`, `alu.vhd` ou `lcd*.vhd`: `tools/ise.sh sim` (todos os testbenches) antes de dar como pronto.
- Depois de mudar qualquer coisa em `rtl/`, `tb/`, `constraints/` ou o programa carregado: `tools/exportar_ise.sh`, para `projeto_ise/` não ficar desatualizada (o `empacotar.sh` já roda o exportar).

## LCD (implementado)

- Pinos (UG230 e Lab 7): `LCD_E` M18, `LCD_RS` L18, `LCD_RW` L17, `SF_D<8..11>` R15/R16/P17/M15, `SF_CE0` D16 (fixo em 1). `LCD_RW` fixo em 0.
- Inicialização do UG230 com margem; depois reescreve a tela sem parar (`0x80` + 16 caracteres, `0xC0` + 16, cerca de 1,8 ms). Setup de 60 ns antes de `E`, `E` de 240 ns, 1 µs entre nibbles, 50 µs entre bytes. `tb/lcd_modelo.vhd` acusa qualquer violação.
- Texto: `LDI Ra, 0x64`, `ADD Ra Rb`, `LDR Rd [Rc]`, `HALT`, `NOP (0x2A)` nos reservados; `RESET` antes do primeiro fetch. O byte adicional aparece como `--` até o DECODE2 (`ARG_OK`). Linha 2: `MEM[255] = 028`.
- Funções do professor (`rom_str`, `to_std_logic_vector`, `to_bcd`) estão em `lcd_pkg.vhd`, com `decimal_size` escrita por nós.

## Aceite: os dois testes do professor

Fibonacci (`programs/fibonacci.asm`, 470 instruções, cerca de 16 min na placa) e bubble sort (`programs/bubble_sort.asm`, 303 instruções, cerca de 10 min). Resultados conferidos também por definição (`cpu8.py all` compara com a sequência de Fibonacci e com `sorted()`). Pontos de controle na placa em `docs/TESTE_NA_PLACA.md`.

## Próximas etapas: sempre seguir o ROADMAP

**Toda implementação segue o [`proj-cpu/ROADMAP.md`](proj-cpu/ROADMAP.md).**

- Antes de começar, ler o ROADMAP e pegar o primeiro item `[ ]`, na ordem das seções. Não criar ordem, etapa ou escopo paralelo.
- Só pular item se a dupla pedir ou se ele depender de algo que falta; nesse caso, avisar.
- Se o ROADMAP divergir do enunciado ou do estado real, apontar e propor a correção nele.
- Ao concluir, marcar `[x]` com o arquivo e **onde foi verificado** (ISim, XST/PAR ou placa). Item que depende da placa só é marcado com confirmação de uma pessoa.

Em 27/11 restam só os itens da placa e das fotos (seções 4 e 6).

## Comandos

O ISE roda só dentro do Docker (`xilinx-ise:14.7`); na máquina do Gabriel há a skill global **`xilinx-ise`**. Tudo a partir de `proj-cpu/`:

```bash
python3 tools/cpu8.py all            # monta os programas (nasm.exe via Wine), gera referências e cobertura
python3 tools/cpu8.py carregar fibonacci   # grava o programa em rtl/RAM_8x256.vhd
tools/ise.sh sim                     # todos os testbenches no ISim (~4 min; tb_main leva ~2,5 min)
tools/ise.sh sim tb_cpu_programas    # um testbench
tools/ise.sh impl                    # XST, MAP, PAR, trce, bitgen -> build/main.bit
tools/gera_bits.sh                   # build/bits/{demo_flags,fibonacci,bubble_sort}.bit
tools/exportar_ise.sh                # projeto_ise/ (pasta única para abrir no ISE do laboratório)
python3 tools/relatorio.py           # docs/relatorio.html e .pdf (Chrome headless)
tools/empacotar.sh                   # entrega/ENG4448_TF_2210442_2211700.zip
```

`ise.sh` imprime `PASSOU`/`TODOS OS TESTES PASSARAM` e termina com código ≠ 0 se algum testbench falhar; os logs ficam em `build/`. Os testbenches leem arquivos com caminho relativo a `proj-cpu/ise/`, que também é o diretório do projeto da GUI.

- `tb_ram` e `tb_main` usam o programa gravado em `rtl/RAM_8x256.vhd` (nome em `tb/dados/carregado.txt`). Trocar a RAM à mão sem `carregar` quebra esses dois.
- ISim: leitura de arquivo em valor inicial de `signal`/`constant` ocorre no `fuse`; para trocar dados sem recompilar, ler dentro de um `process`. VHDL-93: sem `when ... else` dentro de processo.
- O `nasm.exe` precisa de pseudo-terminal no Wine (`script -qc "wine nasm.exe ..." /dev/null`); sem isso falha com `Invalid handle`. Ele **não** acusa valores acima de 255 nem aceita `@símbolo` em `.byte`; `cpu8.py` confere tudo e compara byte a byte.
- Simulação pós-roteamento (netlist do `netgen` com SDF) **não é viável** aqui: o ISim da licença WebPACK (modo Lite) passa a rodar degradado quando o netlist excede o limite de tamanho (a RAM vira 2048 FFs). Tentado em 27/11; em 30 min o simulador usou só 11 s de CPU. A verificação de hardware fica na placa.
- A gravação na placa é feita por uma pessoa; um agente não deve afirmar que algo "funciona na placa" sem essa confirmação.

## Referências: o que aproveitar

- `refs/CPU-VHDL`: outro professor, CPU de 16 bits e outra ISA. Só organização.
- `refs/8-bit-processor-FPGA-VHDL`: outra ISA e memória, Vivado. Só leitura.
- Não copiar código de `refs/`.
- Lab 7 da dupla (`../lab7/`, fora do repositório): base do controlador do LCD.

## Convenções

- VHDL-93 compatível com XST 14.7: só `std_logic_1164` e `numeric_std`. Um componente por arquivo, instância por `entity work.x(arch)`, processos `p_*`, instâncias `u_*`, constantes em maiúsculas. Fontes VHDL em ASCII, comentários sem acento (documentos em português normal).
- Sem latches. A RAM na borda de descida é a exceção ao clock único por processo.
- Testbench com `assert`/`report` de cada resultado esperado, mensagem final `tb_x: TODOS OS TESTES PASSARAM!` e `assert false ... severity failure` para encerrar.
- Commit, push e exclusões só quando pedidos. Outra pessoa também envia commits: atualizar antes de começar.

## Entrega

- Relatório PDF (`docs/relatorio.pdf`, gerado por `tools/relatorio.py`): fotos entram sozinhas a partir de `docs/fotos/`.
- ZIP (`tools/empacotar.sh`): VHDL, UCF, testbenches, projeto ISE, programas, ferramentas, `nasm.exe` e o relatório; sem arquivos gerados.
- Apresentação: tabelas passo a passo em `programs/gen/*.md`.

## Em aberto (perguntar à dupla, não supor)

- O professor entrega `.asm`, só o inicializador ou o `RAM_8x256.vhd` inteiro? (Os três casos estão em `programs/README.md`.)
- Modo rápido para testes longos na placa (ex.: SW1)? O enunciado só prevê ~2 s por instrução; não foi criado.
- Texto exato do LCD: seguimos os exemplos do enunciado (`ADD Ra Rb` sem vírgula, `LDI Ra, 0x64` com vírgula).
- Data de entrega.

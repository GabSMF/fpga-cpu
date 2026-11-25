# AGENTS.md

CPU de 8 bits em VHDL para FPGA, trabalho final de Computação Digital (ENG4448, PUC-Rio, prof. Felipe Calliari). Dupla: Gabriel e Danilo.
Placa: Spartan-3E Starter Kit, `xc3s500e-4fg320`. Ferramenta: Xilinx ISE 14.7. Comentários, documentação e commits em português.

## Fontes de verdade, em ordem

1. [`ENUNCIADO.pdf`](ENUNCIADO.pdf): ISA, flags, interface e entrega. Se algo divergir dele, o enunciado vence.
2. [`docs/Spartan-3E_FPGA_Starter_Kit_Board.pdf`](docs/Spartan-3E_FPGA_Starter_Kit_Board.pdf) (UG230): pinos e tempos da placa.
3. [`proj-cpu/ROADMAP.md`](proj-cpu/ROADMAP.md): o que falta e em que ordem.
4. Este arquivo: estado verificado, armadilhas e comandos.

Os projetos em `refs/` **não** são fonte de verdade (ver "Referências").

## Mapa do repositório

| Caminho | O que é |
| --- | --- |
| `proj-cpu/rtl/` | VHDL do projeto: `alu.vhd`, `cpu.vhd`, `RAM_8x256.vhd`, `main.vhd` (topo) |
| `proj-cpu/tb/` | `tb_alu.vhd`, `tb_main.vhd` |
| `proj-cpu/constraints/spartan3e.ucf` | Pinos de clock, reset e LEDs |
| `proj-cpu/ROADMAP.md` | Checklist de implementação |
| `proj-cpu/cpu.vhd`, `proj-cpu/RAM_8x256.vhd` | Originais do professor. **Não editar nem compilar**: as entidades têm o mesmo nome das de `rtl/` |
| `proj-cpu/character_to_slv_v2.txt` | Trechos do professor para montar o texto do LCD. Não editar; adaptar em `rtl/` (ver "Guia para o LCD") |
| `NASM/` | Montador do professor (`nasm.exe`) e três exemplos `.asm` |
| `Passo_atual_test.md` | Roteiro do programa demo na placa, com a tabela de LEDs esperada |
| `test_proj_dan_gab.zip` | Projeto ISE testado na placa em 25/11/2026. Fontes idênticas a `rtl/`, `tb/` e `constraints/` (só difere a quebra de linha final). **Baseline que funciona: não alterar** |
| `docs/` | UG230, DS312 e manuais de FX2, teclado, 7 segmentos e encoder. Só o UG230 (e o DS312) interessa: o enunciado não pede os outros periféricos |

Tudo que for criado fica dentro de `proj-cpu/` (`rtl/`, `tb/`, `tools/`, `programs/`, `constraints/`, `docs/`), para a pasta ser arquivada sozinha na entrega.

## Estado verificado em 25/11/2026

| Item | Situação |
| --- | --- |
| ALU, UC, RAM, divisor de clock, LEDs | Prontos. Testados pela dupla na placa com o programa demo, funcionando |
| Pinos de clock, reset (SW0) e LEDs | Confirmados na placa |
| `tb_alu` e `tb_main` no ISim | Passam (o ROADMAP ainda os lista como pendentes) |
| XST, MAP, PAR, bitgen | 0 erros, timing atendido |
| ISA completa em simulação | 42 imagens (Fibonacci, bubble sort e 40 programas aleatórios) com traço idêntico ao de um emulador escrito a partir do PDF: `IR`, flags, próximo `PC` e escritas na RAM. Os 256 bytes de opcode foram executados, inclusive reservados. O ambiente de teste era temporário e não está no repositório |
| Fibonacci e bubble sort na placa | **Não testados** |
| LCD | **Não existe.** É o principal item que falta |
| Montador, `programs/`, TB da ISA versionado, relatório, tabela passo a passo, ZIP | Não existem |

Uso do FPGA sem LCD: 1992 slices (42%), 2264 FFs (24%), 1804 LUTs (19%), 0 BRAM.

### Correções ao ROADMAP

- O "montador Python mencionado na seção 4.3" **já existe**: é `NASM/nasm.exe` (v0.5, Felipe Calliari, Python empacotado com PyInstaller). Não precisa escrever outro para cumprir o enunciado.
- A RAM **não** vira block RAM no XST: são inferidos 2048 flip-flops, por causa da leitura assíncrona `POS_255 <= ram(255)`. O arquivo original do professor dá o mesmo resultado, então não é defeito nosso. Manter como está.

## Arquitetura atual

```
main (topo)
├── divisor 50 MHz → clk_cpu (2,5 Hz)
├── u_cpu : cpu
│   └── u_alu : alu        combinacional, CMD de 4 bits
├── u_memory : RAM_8x256   mesmo clk_cpu, borda de DESCIDA
└── u_lcd : lcd            A FAZER, no clock de 50 MHz
```

A hierarquia pedida no enunciado (seção 3) é essa, com os nomes `u_cpu`, `u_alu`, `u_memory`, `u_lcd`.

FSM de 5 estados, sempre 5 ciclos por instrução, inclusive as de 2 bytes. A CPU age na borda de subida:

| Estado | Ação |
| --- | --- |
| `S_FETCH` | `IR <= RAM_DOUT` (o `MAR` já contém o `PC`) |
| `S_DECODE1` | Prepara entradas da ALU, ou põe em `MAR` o endereço da leitura extra (`PC+1`, `SP+1` ou `Ry`) |
| `S_DECODE2` | `MBR <= RAM_DOUT`; em `ldi`/`st`/`jmp` também `ARG` |
| `S_EXECUTE` | Grava registrador e flags, ou liga `WE` por um ciclo |
| `S_WRITE` | Desliga `WE`, calcula o próximo `PC` e carrega `MAR` |

Sequência de acesso à RAM: `MAR` muda na subida, a RAM captura na descida, `DOUT` é lido na subida seguinte. Preservar essa janela em qualquer mudança.

## Regras da ISA que costumam dar erro

Detalhes nas seções 2.2 e 2.3 do enunciado. Formato: `opcode[7:4] Rx[3:2] Ry/função[1:0]`, com Ra=00, Rb=01, Rc=10, Rd=11.

- **Só a ALU faz conta.** Somadores fora dela são permitidos apenas para `PC` e `SP`. `inc`/`dec` usam a ALU com `B=1`; `not`, `rol`, `ror`, `lsl` e `lsr` usam `B=0`.
- Só as 12 instruções de ALU alteram flags, e alteram **todas as seis**. Memória, `mov`, saltos, `nop` e `halt` preservam.
- `OVERFLOW` é carry/borrow **unsigned** em 9 bits (nunca `signed`), ou o bit expulso nos deslocamentos e rotações, ou 0 nas lógicas. `EQ`/`GT`/`SM` comparam **as entradas A e B** da ALU, não o resultado.
- Nos branches, `Rx` é o **endereço de destino**. A condição vem das flags já salvas. `ldi` não muda flags, então dá para carregar o destino entre a conta e o salto.
- Não existe `cmp`: comparar com `sub` destrói `Rx`. Não existe load direto: usar `ldi` + `ldr`.
- `bcs`/`bcc` testam `OVERFLOW`; `bgt`/`blt` são unsigned; `bneg` testa o bit 7 do resultado.
- `push`: `MEM[SP] <- Rx`, depois `SP-1`. `pop`: lê `MEM[SP+1]`, depois `SP+1`. `SP` inicia em 254.
- `nop` = `0xF0`, `halt` = `0xFF`. Todo código fora da tabela é `nop` (avança 1 byte, sem efeitos). `jmp` só vale como `0xC0` exato.
- Vetores de conferência: `add Rc,Rb` = `09`; `dec Rd` = `2D`; `jmp 64` = `C0 40`; `ldi Ra,10; st Ra,255; halt` = `83 0A 82 FF FF`.

## Invariantes do projeto

- **Interface da RAM intocável**: entidade `RAM_8x256`, arquitetura `rtl`, portas `CLK, DIN, ADDR, WE, DOUT, POS_255`, sinal `ram : RAM_t`. O professor vai trocar o bloco inicializador (ou o arquivo inteiro gerado pelo montador), e isso tem que funcionar sem outra mudança.
- Não adaptar a CPU a um programa específico. O programa surpresa pode usar qualquer instrução.
- Reset pela **chave SW0** (1 = reset, 0 = executa), nunca por botão. Ao resetar: `PC=0`, `SP=254`, flags em 0, estado `S_FETCH`. O reset é síncrono ao `clk_cpu`: manter SW0 em 1 por cerca de 1 s.
- **Reset não restaura a RAM.** Após rodar bubble sort, o vetor continua ordenado e `MEM[255]` mantém o valor. Para repetir do zero, regravar o `.bit`.
- Cerca de **2 s por instrução completa**: `CLK_DIV_MAX = 9999999`. Nos testbenches, sobrescrever o generic (ex.: 0), não o valor padrão.
- LEDs: LD7 clock, LD6 Z, LD5 N, LD4 OVF, LD3 EQ, LD2 GT, LD1 SM, LD0 apagado. Vêm dos FFs da UC.
- O LCD roda a 50 MHz; só a CPU é lenta.
- Não mudar `CMD_*` em um arquivo só: as constantes estão duplicadas em `alu.vhd`, `cpu.vhd` e `tb_alu.vhd`.

## Aceite: os dois testes do professor

1. **Fibonacci**: exercita `ldi`, `add`, `mov`, `st 0xFF`, `jmp`/`bcs`. A sequência unsigned de 8 bits vai até 233; a soma seguinte estoura e liga `OVERFLOW`.
2. **Bubble sort**: exercita `ldr`/`str`, `sub` + `bcc`/`bcs`/`bgt`/`blt`, `inc`/`dec`, `push`/`pop`, `bnz`/`bneq`. Testar vetor com repetidos, já ordenado, invertido e com valores acima de 127 (comparação unsigned).

Cada programa precisa passar em simulação (RAM final e sequência de `MEM[255]`) e na placa (LCD e LEDs a cada instrução). Conservar ambos em `proj-cpu/programs/` com `.asm`, inicializador gerado e resultado esperado.

**Tempo real na placa**: a 2 s/instrução, um Fibonacci até 233 leva cerca de 4 min. O bubble sort de 8 elementos simulado levou cerca de 826 instruções, ou 27 min. Para a demonstração, usar vetor curto.

## Próximas etapas: sempre seguir o ROADMAP

**Toda implementação segue o [`proj-cpu/ROADMAP.md`](proj-cpu/ROADMAP.md).** Regra da dupla:

- Antes de começar, ler o ROADMAP e pegar o primeiro item `[ ]`, na ordem das seções. Não criar ordem, etapa ou escopo paralelo.
- Só pular item se a dupla pedir ou se ele depender de algo que falta; nesse caso, avisar.
- Se o ROADMAP divergir do enunciado ou do estado real, apontar e propor a correção nele, sem desviar em silêncio.
- Ao concluir, marcar `[x]` com o arquivo e **onde foi verificado** (ISim, XST/PAR ou placa). Item que depende da placa só é marcado com confirmação de uma pessoa.

Itens abertos em 25/11/2026 (o ROADMAP é que vale):

| Seção | Falta |
| --- | --- |
| 1. ISA e carga | Documentar a tabela, validar o montador do professor (já existe), procedimento de troca da imagem, vetores de teste fixos |
| 3. RAM | Validação isolada de `RAM_8x256` |
| 4. LCD e placa | **Formatação das duas linhas**, **controlador do LCD**, síntese e teste final na placa |
| 5. Validação | TB integrado da ISA, programas, demonstração com tabela, ensaio do programa surpresa |
| 6. Entregáveis | Relatório, ZIP, conferência do ZIP extraído |

### Guia para o LCD (seção 4 do ROADMAP)

Parte mais desafiadora do projeto. Dividir em blocos e validar cada um em simulação antes da placa: (a) texto da linha 1, (b) BCD da linha 2, (c) controlador físico, (d) integração no `main`.

#### Hardware

Pinos do UG230 (cap. 5 e StrataFlash), ainda não usados neste projeto e iguais aos do UCF do Lab 7 da dupla:

| Sinal | Pino | | Sinal | Pino |
| --- | --- | --- | --- | --- |
| `LCD_E` | M18 | | `SF_D<8>` (DB4) | R15 |
| `LCD_RS` | L18 | | `SF_D<9>` (DB5) | R16 |
| `LCD_RW` | L17 | | `SF_D<10>` (DB6) | P17 |
| `SF_CE0` | D16 | | `SF_D<11>` (DB7) | M15 |

Todos `IOSTANDARD = LVCMOS33 | DRIVE = 4 | SLEW = SLOW`. Fixar `SF_CE0 = '1'` (desliga a StrataFlash, que divide o barramento) e `LCD_RW = '0'`.

- **Base do controlador (bloco c)**: o da própria dupla em `../lab7/lab7/` (fora do repositório: `lcd_init.vhd`, `lcd_write.vhd`, `top.vhd`). Segundo o relatório do lab, funcionou na placa com estes mesmos pinos (gravado com uma versão anterior da tabela de tempos); a versão atual foi simulada. Ocupa 130 slices. Copiar para `proj-cpu/rtl/` e adaptar. Faltam nele: segunda linha, Set DDRAM Address (`0x80` linha 1, `0xC0` linha 2), reescrita contínua (hoje escreve 16 letras fixas e para) e cursor desligado (`0x0C` no lugar de `0x0F`). Além disso, dado/RS devem estar estáveis ao menos 40 ns antes de `LCD_E` subir (UG230): em `lcd_write` o setup é nulo, e em `lcd_init` também fica abaixo de 40 ns, como o próprio relatório do lab aponta. A placa tolerou, mas corrigir.
- Inicialização 4 bits: 15 ms → `3` → 4,1 ms → `3` → 100 µs → `3` → 40 µs → `2` → 40 µs → `28`, `06`, `0C`, `01` (1,64 ms após o clear). `E` alto por 12 ciclos; 1 µs entre nibbles; 40 µs entre bytes.
- Linha 1: espelho do `IR`, ex.: `LDI Ra, 0x64`, `ADD Ra Rb`, `HALT`. Linha 2: `MEM[255] = 028` (decimal, 3 dígitos, com zeros à esquerda). Completar 16 colunas com espaços.
- Os dados já estão no topo: `ir_sig`, `arg_sig` e `pos_255`. Hoje o XST os remove por falta de uso; os avisos 646/2677 são esperados até o LCD entrar.
- `IR` muda em `S_FETCH`, mas `ARG` só em `S_DECODE2`, 0,8 s depois. Sem tratamento, `LDI`/`ST`/`JMP` mostram por um instante o operando da instrução anterior. Em reset, `IR = 0x00` apareceria como `ADD Ra Ra`.
- Sincronizar esses sinais (2 FFs) ao cruzar de `clk_cpu` para 50 MHz.
- A conversão binário→BCD é só de exibição e não viola a regra "só a ALU faz conta", mas deve ficar no módulo do LCD.

#### Base do professor: `character_to_slv_v2.txt`

É o **ponto de partida da formatação** (blocos a e b). Só trata de texto: não tem FSM, tempos nem inicialização do LCD, que vêm do Lab 7. Trechos testados no ISE em 25/11/2026:

| Trecho | Resultado | Uso |
| --- | --- | --- |
| `rom_str` e a 1ª `to_std_logic_vector` (32 nibbles de 4 bits) | Compila e simula sem mudança. Já sai na ordem do LCD de 4 bits: nibble alto, depois baixo | **Usar** |
| 2ª `to_std_logic_vector` (vetor de 128 bits) | Falha: `Index 128 is not in range` (`i` começa em 1) | Evitar. Se precisar, usar `(i-1)*8` |
| `TEXT_MAP_ROM` (256 textos indexados pelo `IR`) | A ideia funciona. Só há 9 entradas e `halt` | **Usar a ideia**, com elementos `rom_str` e as 256 entradas |
| `to_bcd` | Com `DIGITS = 3` no lugar de `decimal_size` (inexistente), acerta de 0 a 255 | **Usar** |
| Lista `STR_*` | Outra revisão da ISA: tem `incc`, `decc`, `ld`, `bgez`, `blez`, e faltam `ldi`, `st`, `mov`, `nop`, `bneg` | Não copiar |

Conteúdo a corrigir na tabela: `240` (`0xF0`) é `NOP`; `HALT` é `255` (`0xFF`); reservados executam como `NOP`, portanto não mostrar `invalid instr.` sem a dupla decidir; trocar `0x--` pelo `ARG` em hex nas instruções de 2 bytes.

Custo medido da tabela completa (256 × 16 caracteres) com o BCD: 160 slices se lida de forma assíncrona, ou 45 slices e 3 BRAMs se registrada no clock. Cabe nos dois casos.


## Comandos

O ISE roda só dentro do Docker (`xilinx-ise:14.7`). Na máquina do Gabriel, carregar a skill global **`xilinx-ise`** antes de compilar, simular ou abrir a GUI; ela traz os detalhes e erros conhecidos.

Da raiz do repositório, sem sujar o projeto (montagem somente leitura). Comando já executado com sucesso, leva pouco mais de 1 min:

```bash
docker run --rm -u xilinx -e HOME=/home/xilinx -v "$PWD/proj-cpu:/proj:ro" xilinx-ise:14.7 /bin/bash -lc '
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
mkdir -p /tmp/w && cd /tmp/w
cp /proj/rtl/*.vhd /proj/tb/*.vhd /proj/constraints/*.ucf .
# simulacao (ordem de dependencia)
for f in alu RAM_8x256 cpu main tb_alu tb_main; do vhpcomp $f.vhd 2>&1 | grep ERROR; done
printf "run 10 us\nquit\n" > c.tcl
for t in tb_alu tb_main; do fuse -o $t.exe $t 2>&1 | grep ERROR; ./$t.exe -tclbatch c.tcl 2>&1 | grep -E "Note|Error|FAIL"; done
# sintese, implementacao e bitstream
printf "vhdl work %s.vhd\n" alu RAM_8x256 cpu main > p.prj
printf "run\n-ifn p.prj\n-ifmt mixed\n-top main\n-ofn o.ngc\n-ofmt NGC\n-p xc3s500e-4-fg320\n" > x.xst
xst -ifn x.xst -ofn r.syr >/dev/null 2>&1
grep -E "^ERROR|Number of (Slices|errors|warnings)" r.syr
ngdbuild -p xc3s500e-4fg320 -uc spartan3e.ucf o.ngc o.ngd | grep ERROR
map -p xc3s500e-4fg320 -o m.ncd o.ngd o.pcf | grep ERROR
par -w m.ncd f.ncd o.pcf | grep -E "ERROR|All constraints"
bitgen -w f.ncd main.bit o.pcf | tail -1
'
```

Saída esperada: `TODOS OS TESTES PASSARAM!`, `SIMULACAO INTEGRADA PASSOU COM SUCESSO!`, `Number of errors : 0`, `All constraints were met.`, `Bitstream generation is complete.`. Um TB pode imprimir a mensagem final mesmo com `Error`: exigir também a **ausência** de linhas `Error`/`FAIL`. Ao criar arquivo novo, incluí-lo nas duas listas.

- `tb_main` depende do programa demo em `rtl/RAM_8x256.vhd`. Trocar a imagem quebra esse teste.
- ISim: leitura de arquivo em valor inicial de `signal`/`constant` ocorre no `fuse`, não na execução. Para trocar a imagem sem recompilar, ler dentro de um `process`.
- GUI, criação do projeto ISE e gravação por iMPACT: [`Passo_atual_test.md`](Passo_atual_test.md). A gravação na placa é feita por uma pessoa; um agente não deve afirmar que algo "funciona na placa" sem essa confirmação.

### Montador do professor

```
nasm.exe -i prog.asm -o RAM_8x256.vhd -r --overwrite
```

`-r` gera o arquivo VHDL completo da RAM; sem ele, só o código montado. Opções e tabela de opcodes foram lidas por análise estática do executável; **ele ainda não foi executado nesta máquina** (é um `.exe` de Windows).

- A tabela de opcodes dele bate com a seção 2.2. Não diferencia maiúsculas; comentário com `;`; rótulo `nome:`, referência `@nome`; números decimais, `0x..` ou `0b..`.
- Diretivas: `.equ nome, valor`; `.org endereço` (não volta para trás; preenche com `00`); `.byte valor` (um por linha); `.global @rótulo` (emite um `jmp` de 2 bytes).
- `00` é `add Ra, Ra`, **não** `nop`: um `.org` não pode deixar o fluxo cair no preenchimento.
- Os exemplos `.asm` têm trechos inalcançáveis ou sem `halt`; não usá-los como teste sem adaptar.

## Referências: o que aproveitar

- `refs/CPU-VHDL`: período 2024.2, outro professor, CPU de 16 bits e outra ISA. Incompleto: `B`/`JMP` sem ação, LCD que não faz a inicialização do UG230 nem mostra `pos_255`. Só como ideia de organização.
- `refs/8-bit-processor-FPGA-VHDL`: tese, 2 registradores, ISA e memória diferentes, Vivado. Só leitura sobre sequenciamento `PC`/`MAR`/`IR`.
- Não copiar código de `refs/`: nenhum segue a ISA atual, e é trabalho de terceiros.

## Convenções

- VHDL-93 compatível com XST 14.7: só `std_logic_1164` e `numeric_std` (sem `std_logic_arith`/`unsigned`). Um componente por arquivo, instância por `entity work.x(arch)`, processos `p_*`, instâncias `u_*`, constantes em maiúsculas. Fontes em ASCII, comentários sem acento.
- Sem latches. `process` combinacional com valores padrão; sequencial com borda única. A RAM na descida é a exceção.
- Mudança mínima: `alu.vhd` e `cpu.vhd` estão verificados, então alterá-los exige rodar de novo toda a verificação da ISA.
- Testbench com `assert` em cada resultado esperado e clock de 50 MHz (20 ns).
- Não versionar produtos do ISE (`*.ngc`, `*.ncd`, `*.bit`, `_xmsgs/`, `isim/`, `xst/`, `iseconfig/`...). O repositório ainda não tem `.gitignore`.
- Commit, push e exclusões só quando pedidos. Outra pessoa também envia commits: atualizar antes de começar.

## Entrega

- Relatório PDF (~15 páginas ou mais): diagrama do caminho de dados, descrição de cada unidade, FSM da UC, assembly comentado, explicação de testes, LCD e LEDs.
- ZIP: VHDL completo, UCF e testbench pronto. Antes: `Project → Cleanup Project Files...` e `Project → Archive...`.
- Apresentação: programa demonstrativo e tabela com `Passo | PC | LCD linha 1 | Z | N | OVF | EQ | GT | SM | MEM[255]`. Na linha de cada passo, `PC` é o da instrução executada.

## Em aberto (perguntar à dupla, não supor)

- O professor entrega `.asm`, só o inicializador ou o arquivo `RAM_8x256.vhd` inteiro? Bubble sort: quantos elementos, e o resultado aparece na RAM ou em `MEM[255]`?
- Haverá modo rápido para testes longos? O enunciado só prevê ~2 s por instrução. Padrão atual: não criar.
- Texto exato do LCD. Padrão: seguir os exemplos do enunciado ao pé da letra (`ADD Ra Rb` sem vírgula, `LDI Ra, 0x64` com vírgula).
- Data de entrega.

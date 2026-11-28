# Teste na placa: o que falta para fechar o projeto

Tudo o que dá para provar em simulação já passou (ver [`CRITERIOS_DE_PRONTO.md`](CRITERIOS_DE_PRONTO.md)). Falta a dupla confirmar na Spartan-3E o que só a placa mostra: **o LCD** (novo desde o teste de 25/11) e os dois programas do professor rodando inteiros.

Placa: Spartan-3E Starter Kit, `xc3s500e-4fg320`. Comandos: SW0 (chave da direita), 1 = reset, 0 = executa.

## 0. Gerar e gravar o bitstream

Escolha **uma** das formas:

- **ISE (GUI), o jeito mais simples**: copiar a pasta `proj-cpu/projeto_ise/` (ex.: para `C:\Temp`), abrir `cpu8.xise` → selecionar `main` → Generate Programming File → Configure Target Device (iMPACT) → Initialize Chain → `main.bit` no `xc3s500e` (Bypass nos outros) → Program.
- **Linha de comando**: `python3 tools/cpu8.py carregar NOME` e depois `tools/ise.sh impl`. O bitstream sai em `proj-cpu/build/main.bit`; gravar pelo iMPACT.

Bitstreams prontos (gerados em 27/11/2026, não versionados): `proj-cpu/build/bits/{demo_flags,fibonacci,bubble_sort}.bit`. Para regenerar: `tools/gera_bits.sh`.

Antes de cada teste: SW0 em 1 por ~1 s, depois SW0 em 0.

## 1. LCD e reset (programa `demo_flags`, ~24 s)

O programa que já funcionou em 25/11, agora com LCD. Tabela completa: [`programs/gen/demo_flags.md`](../programs/gen/demo_flags.md).

| # | O que fazer | O que deve aparecer | OK? |
| --- | --- | --- | --- |
| 1.1 | Gravar com SW0 em 1 | LCD: `RESET` / `MEM[255] = 000`, sem cursor piscando. LD6..LD1 apagados, LD7 piscando | ☐ |
| 1.2 | SW0 em 0 | Linha 1 passa a mostrar a instrução. Em `LDI`, por ~0,8 s aparece `LDI Ra, 0x--` e depois o valor (`LDI Ra, 0xFF`) | ☐ |
| 1.3 | Acompanhar (2 s por instrução) | `ADD Ra Rb` acende Z, OVF, GT; `SUB Ra Rb` (3−5) acende N, OVF, SM; o segundo `SUB Ra Rb` acende Z, EQ (mesma tabela de LEDs de `Passo_atual_test.md`) | ☐ |
| 1.4 | Fim | `ST Ra, 0xFF` muda a linha 2 para `MEM[255] = 010`; termina em `HALT` / `MEM[255] = 010`, LEDs Z e EQ | ☐ |
| 1.5 | SW0 em 1 no meio da execução | `RESET` na linha 1, flags apagadas. A linha 2 **mantém** o último valor (o reset não limpa a RAM) | ☐ |
| 1.6 | SW0 em 0 | Recomeça do início | ☐ |
| 1.7 | Texto legível, sem caracteres trocados nem tremendo | | ☐ |

Se o LCD ficar em branco: conferir se o `spartan3e.ucf` usado tem as linhas do LCD (`LCD_E`, `LCD_RS`, `LCD_RW`, `SF_D<8..11>`, `SF_CE0`) e girar o trimpot de contraste. Se aparecerem blocos pretos na linha 1, a inicialização falhou: anotar e me avisar.

## 2. Fibonacci (~16 min; a sequência termina aos ~4 min)

Programa `programs/fibonacci.asm`. Tabela completa passo a passo: [`programs/gen/fibonacci.md`](../programs/gen/fibonacci.md).

Pontos de controle (tempo contado a partir de SW0 em 0):

| Passo | Tempo | LCD linha 1 | LCD linha 2 | LD6..LD1 (Z N OVF EQ GT SM) | OK? |
| ---: | ---: | --- | --- | --- | --- |
| 4 | 0 min 08 s | `ST Ra, 0xFF` | `MEM[255] = 000` | 0 0 0 0 0 0 | ☐ |
| 7 | 0 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 001` | 0 1 0 0 1 0 | ☐ |
| 17 | 0 min 34 s | `ST Rb, 0xFF` | `MEM[255] = 001` | 0 0 0 0 0 1 | ☐ |
| 27 | 0 min 54 s | `ST Rb, 0xFF` | `MEM[255] = 002` | 0 0 0 1 0 0 | ☐ |
| 37 | 1 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 003` | 0 0 0 0 0 1 | ☐ |
| 47 | 1 min 34 s | `ST Rb, 0xFF` | `MEM[255] = 005` | 0 0 0 0 0 1 | ☐ |
| 57 | 1 min 54 s | `ST Rb, 0xFF` | `MEM[255] = 008` | 0 0 0 0 0 1 | ☐ |
| 67 | 2 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 013` | 0 0 0 0 0 1 | ☐ |
| 77 | 2 min 34 s | `ST Rb, 0xFF` | `MEM[255] = 021` | 0 0 0 0 0 1 | ☐ |
| 87 | 2 min 54 s | `ST Rb, 0xFF` | `MEM[255] = 034` | 0 0 0 0 0 1 | ☐ |
| 97 | 3 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 055` | 0 0 0 0 0 1 | ☐ |
| 107 | 3 min 34 s | `ST Rb, 0xFF` | `MEM[255] = 089` | 0 0 0 0 0 1 | ☐ |
| 117 | 3 min 54 s | `ST Rb, 0xFF` | `MEM[255] = 144` | 0 1 0 0 0 1 | ☐ |
| 127 | 4 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 233` | 0 1 0 0 0 1 | ☐ |
| 131 | 4 min 22 s | `ADD Rd Rb` (144+233) | `MEM[255] = 233` | 0 0 1 0 0 1 (OVF acende: estouro) | ☐ |
| 313 | 10 min 26 s | `ST Rb, 0xFF` | `MEM[255] = 009` (termos ímpares) | 1 0 0 1 0 0 | ☐ |
| 457 | 15 min 14 s | `ST Rb, 0xFF` | `MEM[255] = 002` (termos ≥ 128) | 1 0 0 1 0 0 | ☐ |
| 469 | 15 min 38 s | `ST Ra, 0xFF` | `MEM[255] = 170` (autoteste OK) | 1 0 0 1 0 0 | ☐ |
| 470 | 15 min 40 s | `HALT` | `MEM[255] = 170` | 1 0 0 1 0 0 | ☐ |

Se aparecer `MEM[255] = 238` no fim, o autoteste (ROL/ROR/NOT) falhou.

## 3. Bubble sort (~10 min)

Programa `programs/bubble_sort.asm`, vetor 200 3 77 3 128 em `0xE0`. Tabela completa: [`programs/gen/bubble_sort.md`](../programs/gen/bubble_sort.md). Durante a ordenação a linha 2 fica em `000`; o resultado aparece no fim.

| Passo | Tempo | LCD linha 1 | LCD linha 2 | LD6..LD1 (Z N OVF EQ GT SM) | OK? |
| ---: | ---: | --- | --- | --- | --- |
| 202 | 6 min 44 s | `ST Ra, 0xFF` | `MEM[255] = 003` | 1 0 0 1 0 0 | ☐ |
| 217 | 7 min 14 s | `ST Ra, 0xFF` | `MEM[255] = 003` | 0 1 1 0 0 1 | ☐ |
| 232 | 7 min 44 s | `ST Ra, 0xFF` | `MEM[255] = 077` | 0 1 1 0 0 1 | ☐ |
| 247 | 8 min 14 s | `ST Ra, 0xFF` | `MEM[255] = 128` | 0 1 1 0 0 1 | ☐ |
| 265 | 8 min 50 s | `ST Ra, 0xFF` | `MEM[255] = 200` | 0 1 1 0 0 1 | ☐ |
| 290 | 9 min 40 s | `ST Ra, 0xFF` | `MEM[255] = 077` (mediana) | 0 1 0 0 0 1 | ☐ |
| 298 | 9 min 56 s | `ST Ra, 0xFF` | `MEM[255] = 002` (elementos ≥ 128) | 0 1 0 0 0 1 | ☐ |
| 302 | 10 min 04 s | `ST Ra, 0xFF` | `MEM[255] = 212` (checksum) | 0 1 0 0 0 1 | ☐ |
| 303 | 10 min 06 s | `HALT` | `MEM[255] = 212` | 0 1 0 0 0 1 | ☐ |

Para repetir o bubble sort do zero é preciso **regravar** a placa: o reset não restaura a RAM, e o vetor continua ordenado.

## 4. Ensaio do programa surpresa

| # | O que fazer | OK? |
| --- | --- | --- |
| 4.1 | Pegar um `.asm` que a dupla não usou (ex.: `programs/bubble_invertido.asm`), seguir [`programs/README.md`](../programs/README.md) ("Como trocar o programa"), gravar e conferir com `programs/gen/NOME.md` | ☐ |
| 4.2 | Repetir colando **só o bloco** `signal ram` em `rtl/RAM_8x256.vhd`, como o professor fará | ☐ |

## 5. Registro para o relatório

| # | Item | OK? |
| --- | --- | --- |
| 5.1 | Fotos do LCD e dos LEDs em 3 momentos do Fibonacci (ex.: passos 7, 127 e 470) | ☐ |
| 5.2 | Vídeo curto (YouTube não listado, se for usar) | ☐ |
| 5.3 | Inserir as fotos no relatório (`docs/relatorio.html`, seção "Teste na placa") e gerar o PDF de novo | ☐ |

## Se algo falhar

Anote o passo, o texto do LCD e os LEDs e compare com a tabela `programs/gen/NOME.md` (mesmo passo). Em simulação, `tools/ise.sh sim tb_main` roda o mesmo programa no topo real e acusa a primeira instrução que diverge.

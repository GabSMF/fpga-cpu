# Programas

| Arquivo | Para que serve | Instruções executadas | MEM[255] final |
| --- | --- | ---: | ---: |
| `fibonacci.asm` | Teste do professor (1). Sequência até 233, conta ímpares, conta ≥ 128, autoteste | 470 | 170 (`0xAA`) |
| `bubble_sort.asm` | Teste do professor (2). Ordena 200 3 77 3 128, mostra vetor, mediana, contagem e checksum | 303 | 212 |
| `reservados.asm` | Os 41 códigos fora da tabela agem como `nop` | 63 | 90 |
| `secao43.asm` | Exemplo da seção 4.3 do enunciado (`83 0A 82 FF FF`) | 3 | 10 |
| `demo_flags.asm` | Programa do primeiro teste na placa (25/11/2026), ver `Passo_atual_test.md` | 12 | 10 |

Juntos, `fibonacci` e `bubble_sort` executam as **32 instruções** e os **9 desvios tomados e não tomados** (o `tools/cpu8.py all` mede e imprime a cobertura).

Tempo na placa, a 2 s por instrução: `fibonacci` cerca de 16 min (a fase 1, que mostra a sequência, termina por volta da instrução 140, aos 4,7 min); `bubble_sort` cerca de 10 min.

## Arquivos gerados (`gen/`)

Gerados por `python3 tools/cpu8.py all` (não editar à mão):

| Extensão | Conteúdo |
| --- | --- |
| `.vhd` | `RAM_8x256.vhd` completo com a imagem, gerado pelo `nasm.exe` do professor (`-r`) |
| `.lst` | listagem do `nasm.exe` |
| `.mem` | imagem em binário, 256 linhas (testbenches) |
| `.trace` | por instrução: IR, flags (ZNOEGS), próximo PC, endereço e dado escritos (ou −1) |
| `.ram` | RAM final esperada |
| `.lcd` | texto esperado no LCD ao fim de cada instrução |
| `.md` | **tabela passo a passo para a apresentação** (PC, LCD, flags, MEM[255], registradores) |

`aleatorio00..23`: 256 bytes aleatórios, 400 instruções cada, para exercitar todos os opcodes (inclusive reservados e código que se modifica).

## Como trocar o programa da placa

O `nasm.exe` roda no Windows ou, no Linux, pelo Wine. `tools/cpu8.py` chama o Wine com um pseudo-terminal (sem ele o executável falha com `Invalid handle`) e confere o resultado byte a byte com o montador próprio.

1. Escreva `programs/NOME.asm` (sintaxe do `nasm.exe`: `rotulo:`, `@rotulo`, `.equ`, `.org`, `.byte`; comentário com `;`).
2. `python3 tools/cpu8.py all` (monta todos e regenera os arquivos de teste).
3. `python3 tools/cpu8.py carregar NOME` (copia `gen/NOME.vhd` para `rtl/RAM_8x256.vhd` e registra o nome para `tb_ram`/`tb_main`).
4. `tools/ise.sh sim` (todos os testbenches) e `tools/ise.sh impl` (gera `build/main.bit`), ou no ISE: `tools/exportar_ise.sh`, abrir `projeto_ise/cpu8.xise` e Generate Programming File.

### Programa surpresa do professor

- **Arquivo `RAM_8x256.vhd` inteiro** (gerado pelo `nasm.exe -r`): substitua `rtl/RAM_8x256.vhd` por ele. A interface é a mesma.
- **Só o bloco `signal ram : RAM_t := (...)`**: cole sobre o bloco equivalente de `rtl/RAM_8x256.vhd`.
- **O `.asm`**: siga os passos 1 a 4.

Depois, Generate Programming File e gravar. Para conferir em simulação antes, a partir do `.asm`: passos 1 a 4. O `tb_main` mostra se o programa termina no `halt` e se os LEDs e o LCD batem com o modelo em cada instrução.

Atenção às armadilhas do montador: `.byte` não aceita `@símbolo`, e valores acima de 255 não dão erro no `nasm.exe` (`cpu8.py` acusa). O preenchimento de `.org` é `00` (= `add Ra, Ra`), não `nop`.

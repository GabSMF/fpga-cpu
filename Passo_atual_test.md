# Passo a Passo de Teste — CPU 8 bits (Spartan-3E Starter Kit)

> **Atualizado em 27/11/2026.** Este roteiro é do primeiro teste (25/11, sem LCD) e foi mantido como histórico. O projeto agora tem LCD, projeto ISE pronto (`proj-cpu/ise/cpu8.xise`) e um roteiro completo em [`proj-cpu/docs/TESTE_NA_PLACA.md`](proj-cpu/docs/TESTE_NA_PLACA.md). O programa gravado em `rtl/RAM_8x256.vhd` agora é o Fibonacci; o programa deste roteiro é `proj-cpu/programs/demo_flags.asm` (bitstream em `proj-cpu/build/bits/demo_flags.bit`).


## 1. Criar o projeto no Xilinx ISE
1. Abra o **Xilinx ISE Project Navigator** → **File → New Project**.
2. Configure o dispositivo da placa:
   - **Family:** `Spartan3E`
   - **Device:** `XC3S500E`
   - **Package:** `FG320`
   - **Speed:** `-4`
   - **Preferred Language:** `VHDL`
3. Em **Project → Add Source**, adicione:
   - `proj-cpu/rtl/alu.vhd`
   - `proj-cpu/rtl/RAM_8x256.vhd`
   - `proj-cpu/rtl/cpu.vhd`
   - `proj-cpu/rtl/main.vhd`
   - `proj-cpu/constraints/spartan3e.ucf`
4. Na aba **Implementation**, clique com o botão direito em `main.vhd` e garanta que está marcado como **Set as Top Module**.

---

## 2. Simular no ISim (antes de gravar na placa)
1. Adicione `proj-cpu/tb/tb_alu.vhd` e `proj-cpu/tb/tb_main.vhd` via **Project → Add Source** (marque ambos como **Simulation**).
2. Mude a visualização no painel esquerdo de **Implementation** para **Simulation**.
3. Teste da ALU:
   - Selecione `tb_alu` → no painel de processos, dê duplo clique em **Simulate Behavioral Model**.
   - Confirme no console do ISim a mensagem: `tb_alu: TODOS OS TESTES PASSARAM!` (sem erros de `assert`).
4. Teste integrado da CPU + RAM + LEDs:
   - Selecione `tb_main` → duplo clique em **Simulate Behavioral Model**.
   - Rode a simulação por pelo menos **4 us** (`run 4 us`) e confirme no console: `tb_main: SIMULACAO INTEGRADA PASSOU COM SUCESSO!`.
   - *(Opcional)* No waveform, observe `led(7 downto 0)` e os sinais internos de `uut/u_cpu` (`pc`, `ir`, `state`, `reg`) e `uut/u_memory/pos_255` (deve ir para `0x0A` = `10`).

---

## 3. Sintetizar e gravar na FPGA
1. Volte a visualização para **Implementation** e selecione `main`.
2. Dê duplo clique em **Generate Programming File** (o ISE executará *Synthesize*, *Translate*, *Map*, *Place & Route* e gerará `main.bit`).
3. Conecte a placa **Spartan-3E Starter Kit** via cabo USB e ligue a alimentação.
4. Abra **Configure Target Device (iMPACT)**:
   - Faça **Boundary Scan → Initialize Chain**.
   - Associe o arquivo `main.bit` ao dispositivo **`xc3s500e`** (clique em *Bypass* nos demais chips da cadeia, como PROM/CPLD).
   - Clique com o botão direito no `xc3s500e` → **Program**.

---

## 4. Testar na placa e mostrar ao professor

### Controles e LEDs
- **`SW0` (chave da direita):** `1` (para cima) = **RESET** | `0` (para baixo) = **EXECUTA**.
- **Ordem dos LEDs (esquerda → direita):**
  - `LD7`: **CLOCK** (pisca a ~2,5 Hz; 5 piscadas = 1 instrução ≈ 2 s)
  - `LD6`: **ZERO**
  - `LD5`: **NEGATIVE**
  - `LD4`: **OVERFLOW**
  - `LD3`: **EQUAL**
  - `LD2`: **GREATER**
  - `LD1`: **SMALLER**
  - `LD0`: apagado (livre)

### Sequência esperada (programa carregado em `RAM_8x256.vhd`)
1. Suba **`SW0` (`1`)** por ~1 segundo → `LD6..LD1` devem ficar **todos apagados** (`000000`).
2. Abaixe **`SW0` (`0`)** e acompanhe a sequência:

| Tempo aprox. | PC | Instrução | LD6 (Z) | LD5 (N) | LD4 (OVF) | LD3 (EQ) | LD2 (GT) | LD1 (SM) | Observação |
| --- | --- | --- | :---: | :---: | :---: | :---: | :---: | :---: | --- |
| 0–4 s | `0x00–0x02` | `ldi Ra, 0xFF`; `ldi Rb, 0x01` | 0 | 0 | 0 | 0 | 0 | 0 | Carrega operandos |
| **4–6 s** | `0x04` | `add Ra, Rb` (`255 + 1 = 0`) | **1** | 0 | **1** | 0 | **1** | 0 | Acendem **Z, OVF, GT** |
| 6–10 s | `0x05–0x07` | `ldi Ra, 3`; `ldi Rb, 5` | 1 | 0 | 1 | 0 | 1 | 0 | Flags preservadas |
| **10–12 s** | `0x09` | `sub Ra, Rb` (`3 - 5 = 0xFE`) | 0 | **1** | **1** | 0 | 0 | **1** | Acendem **N, OVF, SM** |
| 12–16 s | `0x0A–0x0C` | `ldi Ra, 10`; `mov Rb, Ra` | 0 | 1 | 1 | 0 | 0 | 1 | Flags preservadas |
| **16–18 s** | `0x0D` | `sub Ra, Rb` (`10 - 10 = 0`) | **1** | 0 | 0 | **1** | 0 | 0 | Acendem **Z, EQ** |
| 18–24 s | `0x0E–0x12` | `ldi Ra, 10`; `st Ra, 0xFF`; `halt` | 1 | 0 | 0 | 1 | 0 | 0 | Grava `MEM[255] = 10` e trava em `halt` |

3. Ao final (`halt`), os LEDs permanecem travados em **`Z` e `EQ` acesos** (`LD6` e `LD3`), enquanto `LD7` continua piscando.
4. Suba e abaixe **`SW0`** novamente para demonstrar o reinício completo do programa.

---

## 5. Verificação rápida se algo não sair como esperado
- **`LD7` não pisca:** verifique se `spartan3e.ucf` foi associado ao projeto (`CLK_50MHZ` no pino `C9`).
- **LEDs ficam sempre zerados:** verifique se a chave `SW0` está na posição **para baixo (`0`)**.
- **Erro de síntese no ISE:** anote a mensagem exata do XST (especialmente se reclamar de alguma sintaxe ou sinal) para ajustarmos rapidamente.

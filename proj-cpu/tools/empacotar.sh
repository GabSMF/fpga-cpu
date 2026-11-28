#!/usr/bin/env bash
# Gera o ZIP de entrega (secao 4.4 do enunciado) em proj-cpu/entrega/:
#   ENG4448_TF_2210442_2211700/
#     relatorio.pdf
#     projeto_ise/  projeto do ISE numa pasta so (abrir cpu8.xise e gravar)
#     proj-cpu/  rtl, tb (+ dados), constraints, ise/cpu8.xise, programs (+ gen), tools, docs
#     NASM/nasm.exe  (montador do professor, usado por tools/cpu8.py)
# So entram fontes: nada de build/, produtos do ISE ou caches (equivale ao Cleanup Project Files).
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(dirname "$PROJ")"
NOME=ENG4448_TF_2210442_2211700
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/$NOME/proj-cpu" "$TMP/$NOME/NASM" "$PROJ/entrega"
cd "$PROJ"
tools/exportar_ise.sh > /dev/null
cp -r projeto_ise "$TMP/$NOME/projeto_ise"
for d in rtl tb constraints programs tools docs; do cp -r "$d" "$TMP/$NOME/proj-cpu/"; done
mkdir -p "$TMP/$NOME/proj-cpu/ise" && cp ise/cpu8.xise ise/cpu8.gise "$TMP/$NOME/proj-cpu/ise/"
cp ROADMAP.md "$TMP/$NOME/proj-cpu/"
cp "$REPO/NASM/nasm.exe" "$TMP/$NOME/NASM/"
cp docs/relatorio.pdf "$TMP/$NOME/relatorio.pdf"
find "$TMP" -name __pycache__ -prune -exec rm -rf {} +
rm -f "$TMP/$NOME/proj-cpu/docs/relatorio.html"
cat > "$TMP/$NOME/LEIA-ME.txt" <<'T'
CPU de 8 bits em FPGA - ENG4448 Computacao Digital - Trabalho Final
Gabriel da Silva Marques Ferreira (2210442) e Danilo da Cruz Barbosa (2211700)

relatorio.pdf                 relatorio
projeto_ise/                  PROJETO DO ISE NUMA PASTA SO: abrir cpu8.xise, Generate Programming File,
                              gravar pelo iMPACT; simular pela aba Simulation (ver projeto_ise/LEIA-ME.txt)
proj-cpu/                     fontes organizados, ferramentas e testes (projeto_ise e gerado a partir daqui)
proj-cpu/ise/cpu8.xise        mesmo projeto, apontando para proj-cpu/rtl, tb e constraints
proj-cpu/rtl/                 VHDL (main, cpu, alu, RAM_8x256, lcd, lcd_texto, lcd_pkg)
proj-cpu/constraints/         spartan3e.ucf
proj-cpu/tb/                  testbenches (tb_main, tb_cpu_programas, tb_alu, tb_ram, tb_lcd, tb_lcd_texto)
proj-cpu/programs/            programas .asm (fibonacci, bubble_sort, ...) e arquivos gerados em gen/
proj-cpu/tools/               cpu8.py (montador/modelo de referencia), ise.sh (simulacao/implementacao)
proj-cpu/docs/                ISA, criterios de pronto, roteiro de teste na placa

Simular no ISE: abrir projeto_ise/cpu8.xise (ou proj-cpu/ise/cpu8.xise), aba Simulation, escolher um tb_* e "Simulate Behavioral Model"
(o projeto ja vem com "Simulation Run Time = all"). Os testbenches leem arquivos com caminho relativo
a proj-cpu/ise, entao mantenha a estrutura de pastas.
Trocar o programa: proj-cpu/programs/README.md.
T
rm -f "$PROJ/entrega/$NOME.zip"
(cd "$TMP" && zip -qr "$PROJ/entrega/$NOME.zip" "$NOME")
echo "$PROJ/entrega/$NOME.zip"
unzip -l "$PROJ/entrega/$NOME.zip" | tail -1

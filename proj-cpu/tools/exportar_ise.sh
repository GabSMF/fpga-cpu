#!/usr/bin/env bash
# Gera proj-cpu/projeto_ise/: projeto do ISE 14.7 numa pasta so, no formato de um
# projeto exportado pelo ISE (como test_proj_dan_gab.zip). Basta copiar a pasta
# (ex.: para C:\Temp), abrir cpu8.xise, Generate Programming File e gravar.
#
#   projeto_ise/
#     cpu8.xise, cpu8.gise        projeto (xc3s500e-4fg320, topo main)
#     *.vhd, spartan3e.ucf        fontes, constraints e testbenches
#     dados/                      arquivos lidos pelos testbenches
#     LEIA-ME.txt
#
# A pasta e GERADA a partir de rtl/, tb/, constraints/ e programs/gen/: nao edite
# os arquivos dela; edite os originais e rode este script de novo.
# Precisa do Docker com a imagem xilinx-ise:14.7 (xtclsh cria o .xise).
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$PROJ/projeto_ise"
cd "$PROJ"
PROG="$(cat tb/dados/carregado.txt)"

RTL="alu lcd_pkg lcd_texto lcd RAM_8x256 cpu main"
TBS="lcd_modelo tb_alu tb_ram tb_lcd_texto tb_lcd tb_cpu_programas tb_main"

rm -rf "$DEST"
mkdir -p "$DEST/dados"
for f in $RTL; do cp "rtl/$f.vhd" "$DEST/"; done
cp constraints/spartan3e.ucf "$DEST/"
# testbenches: os dados passam a ficar em dados/, ao lado do .xise
for f in $TBS; do
    sed -e 's|"\.\./programs/gen/"|"dados/"|' -e 's|"\.\./tb/dados/"|"dados/"|' \
        -e 's|Executar com o diretorio de trabalho em proj-cpu/ise (caminhos relativos).|Executar com o diretorio de trabalho na pasta do projeto (dados/ ao lado do .xise).|' \
        "tb/$f.vhd" > "$DEST/$f.vhd"
done
cp tb/dados/programas.txt tb/dados/lcd_texto.txt tb/dados/carregado.txt "$DEST/dados/"
while read -r nome _; do
    cp "programs/gen/$nome.mem" "programs/gen/$nome.trace" "programs/gen/$nome.ram" "$DEST/dados/"
done < tb/dados/programas.txt
cp "programs/gen/$PROG.lcd" "$DEST/dados/"

cat > "$DEST/LEIA-ME.txt" <<T
Projeto ISE 14.7 da CPU de 8 bits (ENG4448) - Spartan-3E Starter Kit, xc3s500e-4fg320
Gerado por proj-cpu/tools/exportar_ise.sh em $(date +%d/%m/%Y). Nao edite estes arquivos:
os originais ficam em proj-cpu/rtl, tb e constraints.

Programa na RAM (RAM_8x256.vhd): $PROG

GRAVAR NA PLACA
  1. Copie esta pasta inteira (ex.: C:\\Temp\\projeto_ise) e abra cpu8.xise no ISE.
  2. Aba Implementation, selecione "main", duplo clique em Generate Programming File.
  3. Configure Target Device (iMPACT) > Boundary Scan > Initialize Chain >
     main.bit no xc3s500e (Bypass nos outros) > Program.
  4. SW0 em 1 (reset) por ~1 s, depois SW0 em 0. Roteiro: proj-cpu/docs/TESTE_NA_PLACA.md

SIMULAR
  Aba Simulation, selecione um testbench e duplo clique em Simulate Behavioral Model
  (o projeto ja usa "Simulation Run Time = all"; a simulacao para sozinha).
  Procure no console a mensagem "TODOS OS TESTES PASSARAM" ou "PASSOU COM SUCESSO".
    tb_alu            ALU                                       instantaneo
    tb_ram            RAM com o programa gravado                instantaneo
    tb_lcd_texto      texto do LCD (770 casos)                  instantaneo
    tb_cpu_programas  34 programas, 12.247 instrucoes           segundos
    tb_lcd            controlador do LCD e tempos do UG230      ~1 min
    tb_main           topo inteiro: LEDs e LCD a cada instrucao  ~3 min
  Os testbenches leem a pasta dados/ (precisa estar ao lado do cpu8.xise).

TROCAR O PROGRAMA (programa surpresa)
  Substitua o bloco "signal ram : RAM_t := (...)" em RAM_8x256.vhd pelo do professor
  (ou o arquivo inteiro gerado pelo nasm.exe -r) e rode Generate Programming File.
  tb_ram e tb_main conferem o programa listado em dados/carregado.txt; para outro
  programa use proj-cpu/tools/cpu8.py carregar NOME e gere esta pasta de novo.
T

docker run --rm -u xilinx -e HOME=/home/xilinx -v "$DEST:/dest" -v "$PROJ/tools:/tools:ro" \
    xilinx-ise:14.7 /bin/bash -lc '
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
mkdir -p /tmp/p && cp -r /dest/. /tmp/p/ && cd /tmp/p
xtclsh /tools/criar_projeto_ise.tcl plano > xtclsh.log 2>&1 || { tail -20 xtclsh.log; exit 1; }
cp cpu8.xise cpu8.gise /dest/'
echo "$DEST ($(ls "$DEST" | wc -l) itens, $(ls "$DEST/dados" | wc -l) arquivos em dados/)"

#!/usr/bin/env bash
# Roda simulacao (ISim) e/ou implementacao (XST, MAP, PAR, bitgen) do proj-cpu
# no Xilinx ISE 14.7 da imagem Docker xilinx-ise:14.7, sem sujar o repositorio.
#
#   tools/ise.sh sim [TB...]   simula os testbenches (padrao: todos)
#   tools/ise.sh impl          sintese + implementacao + bitstream (copia main.bit para build/)
#   tools/ise.sh tudo          sim de todos + impl
#
# Os relatorios ficam em proj-cpu/build/ (ignorado pelo git).
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$PROJ/build"
MODO="${1:-tudo}"; shift || true

# Ordem de compilacao (dependencias primeiro)
RTL="${RTL:-alu lcd_pkg lcd_texto lcd RAM_8x256 cpu main}"
TB_AUX="lcd_modelo"
TBS_PADRAO="tb_alu tb_ram tb_lcd_texto tb_cpu_programas tb_lcd tb_main"
TBS="${*:-$TBS_PADRAO}"

docker run --rm -u xilinx -e HOME=/home/xilinx \
    -v "$PROJ:/proj:ro" -v "$PROJ/build:/saida" \
    -e MODO="$MODO" -e RTL="$RTL" -e TBS="$TBS" -e TB_AUX="$TB_AUX" \
    xilinx-ise:14.7 /bin/bash -lc '
source /opt/Xilinx/14.7/ISE_DS/settings64.sh >/dev/null 2>&1
set -u
mkdir -p /tmp/w && cp -r /proj /tmp/w/proj-cpu && mkdir -p /tmp/w/proj-cpu/ise && cd /tmp/w/proj-cpu/ise
falhou=0
if [ "$MODO" = sim ] || [ "$MODO" = tudo ]; then
    for f in $RTL; do
        vhpcomp ../rtl/$f.vhd > c.log 2>&1 || { cat c.log; exit 1; }
    done
    for f in $TB_AUX; do
        vhpcomp ../tb/$f.vhd > c.log 2>&1 || { cat c.log; exit 1; }
    done
    for t in $TBS; do
        vhpcomp ../tb/$t.vhd > c.log 2>&1 || { grep -E "ERROR" c.log; falhou=1; continue; }
        fuse -o $t.exe work.$t > f.log 2>&1 || { grep -E "ERROR" f.log; falhou=1; continue; }
        printf "run all\nquit\n" > run.tcl
        inicio=$(date +%s)
        ./$t.exe -tclbatch run.tcl > $t.log 2>&1 || true
        cp $t.log /saida/
        echo "== $t ($(( $(date +%s) - inicio )) s)"
        grep -P "Note: (PASSOU|tb_)|Error:|Failure: (?!fim)|FAIL|FALHOU|ERROS" $t.log | sed -E "s/ \(\/[a-z_]+\/\)\.?//" | head -60
        if grep -qE "Error:|FAIL|FALHOU|ERROS" $t.log || ! grep -qE "Note: tb_[a-z_]+: .*(PASS|SUCESSO)" $t.log; then
            echo "   >>> $t FALHOU"; falhou=1
        fi
    done
fi
if [ "$MODO" = impl ] || [ "$MODO" = tudo ]; then
    : > p.prj
    for f in $RTL; do echo "vhdl work ../rtl/$f.vhd" >> p.prj; done
    printf "run\n-ifn p.prj\n-ifmt mixed\n-top main\n-ofn main.ngc\n-ofmt NGC\n-p xc3s500e-4-fg320\n-opt_mode Speed\n-opt_level 1\n" > x.xst
    xst -ifn x.xst -ofn main.syr > /dev/null 2>&1 || true
    cp main.syr /saida/
    echo "== XST"; grep -E "^ERROR|Number of (Slices|Slice Flip|4 input|bonded|BRAMs|GCLKs|errors|warnings)|Minimum period" main.syr
    ngdbuild -p xc3s500e-4fg320 -uc ../constraints/spartan3e.ucf main.ngc main.ngd > ngd.log 2>&1 || { grep ERROR ngd.log; exit 1; }
    map -p xc3s500e-4fg320 -o main_map.ncd main.ngd main.pcf > map.log 2>&1 || { grep ERROR map.log; exit 1; }
    par -w main_map.ncd main.ncd main.pcf > par.log 2>&1 || { grep ERROR par.log; exit 1; }
    trce -v 3 main.ncd main.pcf -o main.twr > /dev/null 2>&1 || true
    bitgen -w main.ncd main.bit main.pcf > bit.log 2>&1 || { tail bit.log; exit 1; }
    cp main_map.mrp main.par main.twr main.bit /saida/
    echo "== MAP/PAR"; grep -E "Number of (Slices|Slice Flip|4 input LUTs|bonded IOBs|RAMB16s|BUFGMUXs):" main_map.mrp
    grep -E "^ERROR|Timing Score|All constraints were met|constraints not met" main.par | head -5
    grep -E "^ERROR|WARNING:(Place|Route|Pack)" map.log par.log | head -10
    tail -1 bit.log
fi
exit $falhou
'

#!/usr/bin/env bash
# Gera um bitstream por programa em build/bits/NOME.bit (para gravar direto pelo iMPACT).
# Uso: tools/gera_bits.sh [NOME...]   (padrao: demo_flags fibonacci bubble_sort)
# No fim, rtl/RAM_8x256.vhd volta a ter o programa que estava carregado antes.
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ"
ANTES="$(cat tb/dados/carregado.txt)"
mkdir -p build/bits
for nome in ${*:-demo_flags fibonacci bubble_sort}; do
    python3 tools/cpu8.py carregar "$nome"
    tools/ise.sh impl | grep -E "All constraints|ERROR|complete"
    cp build/main.bit "build/bits/$nome.bit"
    echo "build/bits/$nome.bit"
done
python3 tools/cpu8.py carregar "$ANTES"

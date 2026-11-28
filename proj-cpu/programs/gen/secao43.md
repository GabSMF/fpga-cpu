# Passo a passo: secao43

Gerado por `tools/cpu8.py` a partir do modelo de referencia. Cada linha e o estado
**depois** da instrucao. `PC` e o endereco da instrucao executada; Ra..Rd e SP sao
internos (nao aparecem na placa) e ajudam a acompanhar.

| Passo | PC | LCD linha 1 | Z | N | OVF | EQ | GT | SM | MEM[255] | Ra | Rb | Rc | Rd | SP |
| ---: | ---: | --- | :-: | :-: | :-: | :-: | :-: | :-: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | `LDI Ra, 0x0A` | 0 | 0 | 0 | 0 | 0 | 0 | 000 | 10 | 0 | 0 | 0 | 254 |
| 2 | 2 | `ST Ra, 0xFF` | 0 | 0 | 0 | 0 | 0 | 0 | 010 | 10 | 0 | 0 | 0 | 254 |
| 3 | 4 | `HALT` | 0 | 0 | 0 | 0 | 0 | 0 | 010 | 10 | 0 | 0 | 0 | 254 |

# Passo a passo: demo_flags

Gerado por `tools/cpu8.py` a partir do modelo de referencia. Cada linha e o estado
**depois** da instrucao. `PC` e o endereco da instrucao executada; Ra..Rd e SP sao
internos (nao aparecem na placa) e ajudam a acompanhar.

| Passo | PC | LCD linha 1 | Z | N | OVF | EQ | GT | SM | MEM[255] | Ra | Rb | Rc | Rd | SP |
| ---: | ---: | --- | :-: | :-: | :-: | :-: | :-: | :-: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 0 | `LDI Ra, 0xFF` | 0 | 0 | 0 | 0 | 0 | 0 | 000 | 255 | 0 | 0 | 0 | 254 |
| 2 | 2 | `LDI Rb, 0x01` | 0 | 0 | 0 | 0 | 0 | 0 | 000 | 255 | 1 | 0 | 0 | 254 |
| 3 | 4 | `ADD Ra Rb` | 1 | 0 | 1 | 0 | 1 | 0 | 000 | 0 | 1 | 0 | 0 | 254 |
| 4 | 5 | `LDI Ra, 0x03` | 1 | 0 | 1 | 0 | 1 | 0 | 000 | 3 | 1 | 0 | 0 | 254 |
| 5 | 7 | `LDI Rb, 0x05` | 1 | 0 | 1 | 0 | 1 | 0 | 000 | 3 | 5 | 0 | 0 | 254 |
| 6 | 9 | `SUB Ra Rb` | 0 | 1 | 1 | 0 | 0 | 1 | 000 | 254 | 5 | 0 | 0 | 254 |
| 7 | 10 | `LDI Ra, 0x0A` | 0 | 1 | 1 | 0 | 0 | 1 | 000 | 10 | 5 | 0 | 0 | 254 |
| 8 | 12 | `MOV Rb Ra` | 0 | 1 | 1 | 0 | 0 | 1 | 000 | 10 | 10 | 0 | 0 | 254 |
| 9 | 13 | `SUB Ra Rb` | 1 | 0 | 0 | 1 | 0 | 0 | 000 | 0 | 10 | 0 | 0 | 254 |
| 10 | 14 | `LDI Ra, 0x0A` | 1 | 0 | 0 | 1 | 0 | 0 | 000 | 10 | 10 | 0 | 0 | 254 |
| 11 | 16 | `ST Ra, 0xFF` | 1 | 0 | 0 | 1 | 0 | 0 | 010 | 10 | 10 | 0 | 0 | 254 |
| 12 | 18 | `HALT` | 1 | 0 | 0 | 1 | 0 | 0 | 010 | 10 | 10 | 0 | 0 | 254 |

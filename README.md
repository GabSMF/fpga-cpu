# fpga-cpu

CPU de 8 bits em VHDL para a Spartan-3E Starter Kit (`xc3s500e-4fg320`), trabalho final de ENG4448 Computação Digital (PUC-Rio). Gabriel da Silva Marques Ferreira e Danilo da Cruz Barbosa.

- 4 registradores, IR/PC/SP/MAR/MBR, RAM de 256 bytes, ALU assíncrona com 6 flags, UC com 5 estados, 32 instruções.
- 2 s por instrução; LEDs com as flags; LCD com a instrução atual e `MEM[255]`.
- Verificado no ISim contra um modelo de referência escrito a partir do enunciado: 34 programas, 12.247 instruções.

| Onde | O quê |
| --- | --- |
| [`proj-cpu/`](proj-cpu/) | O projeto (VHDL, testbenches, programas, ferramentas, projeto ISE) |
| [`proj-cpu/docs/TESTE_NA_PLACA.md`](proj-cpu/docs/TESTE_NA_PLACA.md) | O que falta testar na placa |
| [`proj-cpu/docs/CRITERIOS_DE_PRONTO.md`](proj-cpu/docs/CRITERIOS_DE_PRONTO.md) | Exigências do enunciado e como cada uma foi verificada |
| [`proj-cpu/docs/relatorio.pdf`](proj-cpu/docs/relatorio.pdf) | Relatório |
| [`proj-cpu/ROADMAP.md`](proj-cpu/ROADMAP.md) | Andamento |
| [`AGENTS.md`](AGENTS.md) | Orientações para quem (pessoa ou agente) for mexer no projeto |

Uso rápido, de dentro de `proj-cpu/`, com o ISE 14.7 no Docker (`xilinx-ise:14.7`):

```bash
tools/ise.sh sim     # todos os testbenches
tools/ise.sh impl    # gera build/main.bit
```

Na GUI do ISE: abrir `proj-cpu/ise/cpu8.xise`.

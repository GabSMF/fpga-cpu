#!/usr/bin/env python3
"""Gera docs/relatorio.html e docs/relatorio.pdf (Chrome headless).

O texto esta aqui; tabelas, listagens e numeros vem dos arquivos do projeto:
  programs/*.asm, programs/gen/*.md, build/*.log (testbenches), build/main_map.mrp,
  build/main.twr. Fotos em docs/fotos/*.jpg|png entram na secao "Teste na placa"
  (o nome do arquivo vira a legenda).
Uso: python3 tools/relatorio.py
"""
import glob
import html
import os
import re
import shutil
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, 'tools'))
import cpu8  # noqa: E402

DOCS = os.path.join(RAIZ, 'docs')
BUILD = os.path.join(RAIZ, 'build')


def ler(*p):
    caminho = os.path.join(RAIZ, *p)
    return open(caminho, encoding='utf-8', errors='replace').read() if os.path.exists(caminho) else ''


def esc(s):
    return html.escape(s)


def md_tabela(md, maximo=None, cortar_ate=None):
    """Converte as linhas de tabela Markdown de um arquivo .md em <table>."""
    linhas = [l for l in md.splitlines() if l.startswith('|')]
    if not linhas:
        return '<p><em>(tabela ainda não gerada)</em></p>'
    cab = [c.strip() for c in linhas[0].strip('|').split('|')]
    corpo = linhas[2:]
    if cortar_ate:
        corpo = corpo[:cortar_ate]
    out = ['<table class="dados"><thead><tr>' + ''.join('<th>%s</th>' % esc(c) for c in cab) + '</tr></thead><tbody>']
    for l in corpo[:maximo] if maximo else corpo:
        cel = [c.strip().strip('`') for c in l.strip('|').split('|')]
        out.append('<tr>' + ''.join('<td>%s</td>' % esc(c) for c in cel) + '</tr>')
    out.append('</tbody></table>')
    return '\n'.join(out)


def listagem(nome):
    return '<pre class="asm">%s</pre>' % esc(ler('programs', nome + '.asm'))


def resultados_tb():
    tbs = [('tb_alu', 'ALU: 17 casos das seções 2.3 e 2.3.2 (255+1, 0-1, 3-5, 200+100, 200-10, deslocamentos)'),
           ('tb_ram', 'RAM_8x256 real: imagem inicial, leitura na borda de descida, escrita, POS_255'),
           ('tb_lcd_texto', 'Texto do LCD: 256 IRs com e sem o byte adicional, RESET, 256 valores de MEM[255]'),
           ('tb_cpu_programas', 'ISA completa: traço instrução a instrução contra o modelo de referência'),
           ('tb_lcd', 'Controlador do LCD: inicialização e tempos do UG230, texto exibido'),
           ('tb_main', 'Topo real: LEDs a cada instrução do programa gravado e LCD a cada instrução (modo lento)')]
    linhas = []
    for tb, desc in tbs:
        log = ler('build', tb + '.log')
        fim = re.findall(r'Note: (tb_\w+: .*?)(?: \(/[^)]*\))?\.?\s*$', log, re.M)
        ok = bool(fim) and not re.search(r'Error:|FAIL|FALHOU', log)
        res = fim[-1] if fim else 'não executado'
        linhas.append('<tr><td><code>%s</code></td><td>%s</td><td class="%s">%s</td></tr>' % (
            tb, esc(desc), 'ok' if ok else 'nok', esc(res)))
    return ('<table class="dados"><thead><tr><th>Testbench</th><th>O que verifica</th><th>Resultado no ISim</th>'
            '</tr></thead><tbody>%s</tbody></table>' % ''.join(linhas))


def programas_tb():
    log = ler('build', 'tb_cpu_programas.log')
    ok = re.findall(r'PASSOU (\w+) \((\d+) instrucoes\)', log)
    nao_aleat = [(n, i) for n, i in ok if not n.startswith('aleatorio')]
    aleat = [(n, int(i)) for n, i in ok if n.startswith('aleatorio')]
    linhas = ''.join('<tr><td><code>%s</code></td><td>%s</td></tr>' % (n, i) for n, i in nao_aleat)
    if aleat:
        linhas += '<tr><td><code>aleatorio00..%02d</code> (%d programas)</td><td>%d</td></tr>' % (
            len(aleat) - 1, len(aleat), sum(i for _, i in aleat))
    total = sum(int(i) for _, i in ok)
    return ('<table class="dados"><thead><tr><th>Programa</th><th>Instruções conferidas</th></tr></thead>'
            '<tbody>%s<tr><th>Total</th><th>%d</th></tr></tbody></table>' % (linhas, total))


def utilizacao():
    mrp = ler('build', 'main_map.mrp')
    itens = []
    for rotulo, rx in [('Slices', r'Number of occupied Slices:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%'),
                       ('Flip-flops', r'Number of Slice Flip Flops:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%'),
                       ('LUTs de 4 entradas', r'Total Number of 4 input LUTs:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%'),
                       ('IOBs', r'Number of bonded IOBs:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%'),
                       ('Block RAMs (RAMB16)', r'Number of RAMB16s:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%'),
                       ('Buffers de clock (BUFGMUX)', r'Number of BUFGMUXs:\s+([\d,]+) out of\s+([\d,]+)\s+(\d+)%')]:
        m = re.search(rx, mrp)
        if m:
            itens.append('<tr><td>%s</td><td>%s</td><td>%s</td><td>%s%%</td></tr>' % ((rotulo,) + m.groups()))
    twr = ler('build', 'main.twr')
    per = re.search(r'Minimum period:\s+([\d.]+)ns', twr)
    t = ('<p>Análise de timing após o roteamento (<code>trce</code>): todas as restrições atendidas; '
         'período mínimo %s ns para o clock de 50 MHz (20 ns).</p>' % per.group(1)) if per else ''
    return ('<table class="dados"><thead><tr><th>Recurso</th><th>Usado</th><th>Disponível</th><th>%%</th></tr></thead>'
            '<tbody>%s</tbody></table>%s' % (''.join(itens), t))


def fotos():
    arqs = sorted(glob.glob(os.path.join(DOCS, 'fotos', '*.jp*g')) + glob.glob(os.path.join(DOCS, 'fotos', '*.png')))
    if not arqs:
        return ('<div class="pendente"><strong>Pendente:</strong> fotos e/ou video da placa. Coloque as imagens em '
                '<code>proj-cpu/docs/fotos/</code> (o nome do arquivo vira a legenda) e rode '
                '<code>python3 tools/relatorio.py</code> de novo. Roteiro: <code>docs/TESTE_NA_PLACA.md</code>.</div>')
    out = []
    for a in arqs:
        leg = os.path.splitext(os.path.basename(a))[0].replace('_', ' ')
        out.append('<figure><img src="fotos/%s" style="max-width:100%%;max-height:9cm"><figcaption>%s</figcaption></figure>'
                   % (os.path.basename(a), esc(leg)))
    return '\n'.join(out)


def tabela_isa():
    linhas = []
    for l in ler('docs', 'ISA.md').splitlines():
        if l.startswith('| `') and '|' in l[2:]:
            c = [x.strip() for x in l.strip('|').split('|')]
            if len(c) == 5:
                c = [re.sub(r'`([^`]*)`', r'<code>\1</code>', esc(x).replace('\\|', '|')) for x in c]
                linhas.append('<tr>' + ''.join('<td>%s</td>' % x for x in c) + '</tr>')
    return ('<table class="dados isa"><thead><tr><th>Assembly</th><th>Código</th><th>Operação</th><th>Flags</th>'
            '<th>LCD linha 1</th></tr></thead><tbody>%s</tbody></table>' % ''.join(linhas))


# --------------------------------------------------------------------- figuras --
FIG_BLOCOS = '''<svg viewBox="0 0 760 330" class="fig">
<defs><marker id="s" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect x="5" y="5" width="750" height="320" rx="8" class="caixa0"/><text x="15" y="25" class="t">main (topo, xc3s500e)</text>
<rect x="20" y="60" width="120" height="50" class="caixa"/><text x="80" y="82" class="c">Divisor</text><text x="80" y="100" class="c p">50 MHz &#8594; 2,5 Hz</text>
<rect x="200" y="45" width="260" height="170" class="caixa"/><text x="215" y="65" class="t">u_cpu : cpu</text>
<text x="215" y="85" class="p">UC (FSM 5 estados), Ra..Rd, PC, SP,</text><text x="215" y="100" class="p">IR, MAR, MBR, ARG, 6 FFs de flags</text>
<rect x="240" y="120" width="180" height="70" class="caixa2"/><text x="330" y="148" class="c">u_alu : alu</text><text x="330" y="168" class="c p">combinacional</text>
<rect x="540" y="45" width="190" height="100" class="caixa"/><text x="635" y="75" class="c">u_memory</text><text x="635" y="95" class="c">RAM_8x256</text><text x="635" y="118" class="c p">256 x 8, borda de descida</text>
<rect x="540" y="200" width="190" height="90" class="caixa"/><text x="635" y="230" class="c">u_lcd : lcd</text><text x="635" y="250" class="c p">50 MHz, sincroniza e</text><text x="635" y="266" class="c p">escreve o LCD 16x2</text>
<rect x="200" y="250" width="260" height="45" class="caixa2"/><text x="330" y="278" class="c">LEDs LD7..LD0</text>
<line x1="80" y1="40" x2="80" y2="58" class="l" marker-end="url(#s)"/><text x="80" y="36" class="c p">CLK_50MHZ</text>
<path d="M140,85 H198" class="l" marker-end="url(#s)"/><text x="168" y="78" class="c p">clk_cpu</text>
<path d="M170,85 V20 H600 V43" class="l" marker-end="url(#s)"/>
<path d="M460,80 H538" class="l" marker-end="url(#s)"/><text x="500" y="73" class="c p">ADDR DIN WE</text>
<path d="M538,115 H460" class="l" marker-end="url(#s)"/><text x="500" y="130" class="c p">DOUT</text>
<path d="M330,215 V248" class="l" marker-end="url(#s)"/><text x="400" y="235" class="c p">flags</text>
<path d="M170,95 V272 H198" class="l" marker-end="url(#s)"/><text x="176" y="290" class="p">LD7</text>
<path d="M460,190 H500 V240 H538" class="l" marker-end="url(#s)"/><text x="498" y="182" class="c p">IR ARG</text>
<path d="M690,145 V198" class="l" marker-end="url(#s)"/><text x="720" y="175" class="c p">POS_255</text>
<path d="M730,245 H750" class="l"/><text x="740" y="310" class="c p">LCD</text><path d="M745,245 V295" class="l" marker-end="url(#s)"/>
<text x="20" y="160" class="p">SW0 = RESET</text><path d="M60,165 V180 H230 V217" class="l" marker-end="url(#s)"/>
</svg>'''

FIG_DATAPATH = '''<svg viewBox="0 0 780 490" class="fig">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 z"/></marker></defs>
<text x="20" y="18" class="p">PC e SP: únicos somadores fora da ALU (exceção prevista no enunciado)</text>
<rect x="20" y="40" width="100" height="36" class="caixa"/><text x="70" y="63" class="c">PC</text>
<rect x="20" y="100" width="100" height="36" class="caixa"/><text x="70" y="123" class="c">SP (= 254)</text>
<polygon points="170,30 195,45 195,185 170,200" class="caixa2"/><text x="183" y="120" class="c p">mux</text>
<path d="M120,58 H168" class="l" marker-end="url(#a)"/><path d="M120,118 H168" class="l" marker-end="url(#a)"/>
<text x="183" y="216" class="c p">PC, PC+1, SP, SP+1, Ry, MBR</text>
<rect x="230" y="95" width="90" height="36" class="caixa"/><text x="275" y="118" class="c">MAR</text>
<path d="M195,113 H228" class="l" marker-end="url(#a)"/>
<rect x="400" y="40" width="170" height="180" class="caixa"/><text x="485" y="62" class="c">RAM 256 x 8</text><text x="485" y="80" class="c p">escrita e endereço na descida</text>
<text x="408" y="117" class="p">ADDR</text><text x="408" y="182" class="p">DIN</text><text x="408" y="209" class="p">WE (da UC)</text><text x="562" y="117" class="p" text-anchor="end">DOUT</text>
<path d="M320,113 H398" class="l" marker-end="url(#a)"/>
<rect x="230" y="160" width="90" height="36" class="caixa"/><text x="275" y="183" class="c">MBR</text>
<path d="M320,178 H398" class="l" marker-end="url(#a)"/>
<path d="M570,113 H610 V230 H290 V198" class="l" marker-end="url(#a)"/><text x="450" y="245" class="c p">DOUT &#8594; MBR (2o byte, ldr, pop)</text>
<path d="M610,113 V48 H638" class="l" marker-end="url(#a)"/><path d="M610,103 H638" class="l" marker-end="url(#a)"/>
<rect x="640" y="30" width="110" height="36" class="caixa"/><text x="695" y="53" class="c">IR</text>
<rect x="640" y="85" width="110" height="36" class="caixa"/><text x="695" y="108" class="c">ARG (LCD)</text>
<text x="695" y="140" class="c p">IR &#8594; UC e LCD</text>
<rect x="20" y="270" width="160" height="130" class="caixa"/><text x="100" y="295" class="c">Banco REG</text>
<text x="100" y="318" class="c p">Ra  Rb  Rc  Rd</text><text x="100" y="345" class="c p">lê REG(Rx), REG(Ry)</text><text x="100" y="365" class="c p">escreve REG(Rx)</text>
<path d="M230,190 H215 V252 H100 V268" class="l" marker-end="url(#a)"/><text x="108" y="246" class="p">MBR &#8594; Rx</text>
<path d="M180,285 H255 V198" class="l" marker-end="url(#a)"/><text x="262" y="270" class="p">Rx &#8594; MBR</text>
<polygon points="300,290 400,320 400,390 300,420 300,370 318,355 300,340" class="caixa2"/><text x="362" y="360" class="c">ALU</text>
<path d="M180,310 H298" class="l" marker-end="url(#a)"/><text x="240" y="303" class="c p">ALU_A = Rx</text>
<path d="M180,400 H298" class="l" marker-end="url(#a)"/><text x="240" y="393" class="c p">ALU_B = Ry, 1 ou 0</text>
<path d="M350,440 V408" class="l" marker-end="url(#a)"/><text x="360" y="448" class="p">CMD (da UC)</text>
<path d="M400,355 H440 V468 H100 V402" class="l" marker-end="url(#a)"/><text x="270" y="482" class="c p">ALU_R &#8594; Rx (no EXECUTE)</text>
<rect x="470" y="295" width="130" height="70" class="caixa"/><text x="535" y="318" class="c">FFs de flags</text><text x="535" y="338" class="c p">Z N OVF EQ GT SM</text><text x="535" y="355" class="c p">(dentro da UC)</text>
<path d="M400,325 H468" class="l" marker-end="url(#a)"/><text x="434" y="317" class="c p">6 flags</text>
<path d="M600,330 H650" class="l" marker-end="url(#a)"/><text x="655" y="334" class="p">LEDs e desvios</text>
</svg>'''

FIG_FSM = '''<svg viewBox="0 0 760 250" class="fig">
<defs><marker id="f" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 z"/></marker></defs>
<g class="est"><ellipse cx="80" cy="90" rx="62" ry="32"/><ellipse cx="230" cy="90" rx="62" ry="32"/><ellipse cx="380" cy="90" rx="62" ry="32"/><ellipse cx="530" cy="90" rx="62" ry="32"/><ellipse cx="680" cy="90" rx="62" ry="32"/></g>
<text x="80" y="95" class="c">FETCH</text><text x="230" y="95" class="c">DECODE1</text><text x="380" y="95" class="c">DECODE2</text><text x="530" y="95" class="c">EXECUTE</text><text x="680" y="95" class="c">WRITE</text>
<path d="M142,90 H166" class="l" marker-end="url(#f)"/><path d="M292,90 H316" class="l" marker-end="url(#f)"/><path d="M442,90 H466" class="l" marker-end="url(#f)"/><path d="M592,90 H616" class="l" marker-end="url(#f)"/>
<path d="M680,122 V160 H80 V124" class="l" marker-end="url(#f)"/>
<text x="380" y="178" class="c p">próxima instrução (MAR = PC novo)</text>
<path d="M80,20 V56" class="l" marker-end="url(#f)"/><text x="88" y="30" class="p">RESET: PC=0, SP=254, flags=0</text>
<text x="80" y="205" class="c p">IR &#8592; DOUT</text>
<text x="230" y="205" class="c p">ALU_A/B/CMD ou</text><text x="230" y="219" class="c p">MAR &#8592; PC+1/SP+1/Ry</text>
<text x="380" y="205" class="c p">MBR &#8592; DOUT</text><text x="380" y="219" class="c p">(ARG &#8592; DOUT)</text>
<text x="530" y="205" class="c p">Rx &#8592; ALU_R + flags,</text><text x="530" y="219" class="c p">Rx &#8592; MBR ou WE = 1</text>
<text x="680" y="205" class="c p">WE = 0, PC &#8592; prox.</text><text x="680" y="219" class="c p">MAR &#8592; PC</text>
</svg>'''

FIG_RAM = '''<svg viewBox="0 0 760 235" class="fig">
<text x="10" y="35" class="p">clk_cpu</text>
<path d="M90,45 h40 v-25 h80 v25 h80 v-25 h80 v25 h80 v-25 h80 v25 h80 v-25 h80" class="onda"/>
<text x="10" y="80" class="p">MAR (ADDR)</text>
<path d="M90,70 h40 l5,-10 h150 l5,10 l-5,10 h-150 l-5,-10" class="onda"/><path d="M290,70 h455" class="onda"/>
<text x="210" y="74" class="c p">PC+1</text>
<text x="10" y="120" class="p">read_address</text>
<path d="M90,110 h120 l5,-10 h300 l5,10 l-5,10 h-300 l-5,-10" class="onda"/><text x="360" y="114" class="c p">PC+1 (registrado na descida)</text>
<text x="10" y="160" class="p">DOUT</text>
<path d="M90,150 h120 l5,-10 h300 l5,10 l-5,10 h-300 l-5,-10" class="onda"/><text x="360" y="154" class="c p">MEM[PC+1] válido</text>
<line x1="130" y1="10" x2="130" y2="185" class="guia"/><line x1="210" y1="10" x2="210" y2="200" class="guia"/><line x1="290" y1="10" x2="290" y2="215" class="guia"/>
<text x="134" y="195" class="p">1: subida, DECODE1 (MAR muda)</text><text x="214" y="210" class="p">2: descida, RAM registra o endereço</text><text x="294" y="225" class="p">3: subida, DECODE2 lê DOUT</text>
</svg>'''

FIG_LCD = '''<svg viewBox="0 0 760 172" class="fig">
<defs><marker id="b" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect x="10" y="40" width="130" height="80" class="caixa"/><text x="75" y="70" class="c">Sincronização</text><text x="75" y="90" class="c p">2 FFs + valor</text><text x="75" y="105" class="c p">estável</text>
<rect x="180" y="40" width="150" height="80" class="caixa"/><text x="255" y="65" class="c">lcd_texto</text><text x="255" y="85" class="c p">TEXTO_IR(IR), hex do ARG,</text><text x="255" y="101" class="c p">to_bcd(MEM[255])</text>
<rect x="370" y="40" width="120" height="80" class="caixa"/><text x="430" y="70" class="c">Cópia da tela</text><text x="430" y="90" class="c p">2 x 16 caracteres</text>
<rect x="530" y="20" width="220" height="120" class="caixa"/><text x="640" y="45" class="c">Sequenciador</text>
<text x="545" y="70" class="p">LIGA (16 ms) &#8594; 3,3,3,2</text><text x="545" y="88" class="p">28 06 0C 01 &#8594; tela: 80 + 16 car.</text><text x="545" y="106" class="p">+ C0 + 16 car. (repete)</text><text x="545" y="124" class="p">SETUP 60 ns, E 240 ns, 1 us, 50 us</text>
<path d="M140,80 H178" class="l" marker-end="url(#b)"/><path d="M330,80 H368" class="l" marker-end="url(#b)"/><path d="M490,80 H528" class="l" marker-end="url(#b)"/>
<text x="10" y="30" class="p">IR, ARG, IR_OK, ARG_OK, POS_255 (clock da CPU)</text>
<text x="750" y="162" class="p" text-anchor="end">LCD_E, LCD_RS, SF_D&lt;11:8&gt;; LCD_RW = 0; SF_CE0 = 1</text>
</svg>'''


CSS = '''
@page { size: A4; margin: 2.2cm 2cm 2.2cm 2.2cm; }
body { font-family: "DejaVu Serif", Georgia, serif; font-size: 11pt; line-height: 1.45; color: #111; background: #fff; }
h1 { font-size: 20pt; margin: 0 0 .3em; } h2 { font-size: 15pt; border-bottom: 1px solid #999; padding-bottom: 3px; margin-top: 1.6em; break-after: avoid; }
h3 { font-size: 12.5pt; margin-top: 1.2em; break-after: avoid; }
p, li { text-align: justify; }
code, pre { font-family: "DejaVu Sans Mono", monospace; font-size: 8.6pt; }
pre.asm { background: #f6f6f6; border: 1px solid #ddd; padding: 6px 8px; white-space: pre-wrap; line-height: 1.25; }
table.dados { border-collapse: collapse; width: 100%; margin: .6em 0 1em; font-size: 9pt; break-inside: auto; }
table.dados th, table.dados td { border: 1px solid #bbb; padding: 2px 5px; vertical-align: top; }
table.dados th { background: #eee; } table.dados tr { break-inside: avoid; }
table.isa td:nth-child(2) { white-space: nowrap; }
td.ok { color: #0a6b2b; } td.nok { color: #a40000; font-weight: bold; }
.capa { height: 24cm; display: flex; flex-direction: column; justify-content: center; text-align: center; break-after: page; }
.capa .sub { font-size: 14pt; margin: .4em 0; } .capa .nomes { margin-top: 3em; font-size: 13pt; line-height: 1.8; }
.sumario { break-after: page; } .sumario li { text-align: left; }
.quebra { break-before: page; }
figure { margin: 1em 0; text-align: center; break-inside: avoid; } figcaption { font-size: 9.5pt; color: #333; margin-top: .3em; }
svg.fig { width: 100%; height: auto; font-family: "DejaVu Sans", sans-serif; }
svg .caixa { fill: #f4f7fb; stroke: #234; stroke-width: 1.3; } svg .caixa0 { fill: none; stroke: #666; stroke-dasharray: 6 4; }
svg .caixa2 { fill: #fdf6e8; stroke: #7a5200; stroke-width: 1.3; } svg .est ellipse { fill: #f4f7fb; stroke: #234; stroke-width: 1.4; }
svg .l { fill: none; stroke: #222; stroke-width: 1.3; } svg marker path { fill: #222; }
svg .onda { fill: none; stroke: #124; stroke-width: 1.6; } svg .guia { stroke: #999; stroke-dasharray: 3 3; }
svg text { font-size: 12px; fill: #111; } svg .c { text-anchor: middle; } svg .p { font-size: 10.5px; fill: #333; } svg .t { font-weight: bold; }
.pendente { border: 2px dashed #a66; padding: .8em; background: #fff6f6; }
.nota { font-size: 9.5pt; color: #333; }
'''


def gerar():
    fib = cpu8.Cpu(cpu8.montar(ler('programs', 'fibonacci.asm'))[0]); fib.executa(halts_extras=0)
    bub = cpu8.Cpu(cpu8.montar(ler('programs', 'bubble_sort.asm'))[0]); bub.executa(halts_extras=0)
    n_prog = len([l for l in ler('tb', 'dados', 'programas.txt').splitlines() if l.strip()])

    corpo = f'''
<div class="capa">
  <div class="sub">Pontifícia Universidade Católica do Rio de Janeiro</div>
  <div class="sub">ENG4448 - Computação Digital</div>
  <h1 style="margin-top:2em">Trabalho Final</h1>
  <div class="sub">CPU de 8 bits em FPGA (Spartan-3E)</div>
  <div class="nomes">Gabriel da Silva Marques Ferreira (2210442)<br>Danilo da Cruz Barbosa (2211700)</div>
  <div class="sub" style="margin-top:2em">Professor: Felipe Calliari</div>
  <div class="sub">Rio de Janeiro, novembro de 2026</div>
</div>

<div class="sumario"><h2>Sumário</h2><ol>
<li>Objetivo e visão geral</li><li>Arquitetura e caminho de dados</li><li>Conjunto de instruções</li>
<li>Unidade de controle</li><li>ALU</li><li>Memória RAM</li><li>Clock, reset e LEDs</li><li>LCD</li>
<li>Programas de teste</li><li>Metodologia de verificação</li><li>Resultados</li>
<li>Tabela passo a passo (demonstração)</li><li>Teste na placa</li><li>Conclusão</li>
<li>Apêndice: arquivos do projeto</li></ol></div>

<h2>1. Objetivo e visão geral</h2>
<p>Este trabalho implementa, em VHDL, uma CPU de 8 bits na FPGA Xilinx Spartan-3E (XC3S500E, placa Spartan-3E
Starter Kit), conforme o enunciado do trabalho final. A CPU executa um programa gravado na memória RAM de
256 bytes, tem quatro registradores de uso geral (Ra, Rb, Rc e Rd), os registradores especiais IR, PC, SP, MBR e
MAR, uma ALU assíncrona com seis flags e uma unidade de controle (UC) implementada como máquina de estados. O
usuário acompanha a execução pelos LEDs, que mostram as flags e o clock da CPU, e pelo display LCD, que mostra a
instrução atual e o conteúdo da posição 255 da memória, reservada para E/S.</p>
<p>O clock da CPU foi reduzido para que cada instrução leve cerca de 2 segundos, enquanto o LCD continua no
clock de 50 MHz da placa. A Figura 1 mostra a hierarquia: o topo <code>main</code> instancia a CPU
(<code>u_cpu</code>, que contém a ALU <code>u_alu</code>), a memória (<code>u_memory</code>) e o controlador do
display (<code>u_lcd</code>), com os nomes sugeridos pelo enunciado.</p>
<figure>{FIG_BLOCOS}<figcaption>Figura 1 - Diagrama de blocos do topo <code>main</code>.</figcaption></figure>
<p>Além do hardware, o projeto inclui um modelo de referência da CPU escrito em Python a partir do enunciado
(<code>tools/cpu8.py</code>), seis testbenches executados no ISim do ISE 14.7 e programas de teste, entre eles o
Fibonacci e o bubble sort, que juntos executam as 32 instruções e os 9 desvios nos dois sentidos. Os programas
são montados com o montador fornecido pelo professor (<code>nasm.exe</code>), executado no Linux pelo Wine.</p>

<h2>2. Arquitetura e caminho de dados</h2>
<p>A palavra da CPU é sempre de 8 bits: instruções, dados, endereços e todos os registradores, inclusive PC e SP.
A arquitetura é de von Neumann: a mesma RAM guarda instruções e dados. A Figura 2 mostra o caminho de dados.</p>
<figure>{FIG_DATAPATH}<figcaption>Figura 2 - Caminho de dados (simplificado). Os multiplexadores são controlados pela UC
conforme o estado e o opcode em IR.</figcaption></figure>
<ul>
<li><strong>Banco de registradores</strong> (<code>REG</code>): quatro registradores de 8 bits. Cada instrução lê
REG(Rx) e REG(Ry), com os índices tirados dos bits 3..2 e 1..0 de IR, e escreve no máximo em REG(Rx).</li>
<li><strong>PC</strong>: endereço da próxima instrução. Avança 1 (ou 2 em <code>ldi</code>/<code>st</code>), recebe o byte
adicional em <code>jmp</code> ou o valor de Rx em <code>jmpr</code> e nos desvios tomados; fica parado em <code>halt</code>.</li>
<li><strong>SP</strong>: ponteiro da pilha, iniciado em 254 (a posição 255 é de E/S). <code>push</code> grava em MEM[SP] e
decrementa; <code>pop</code> lê MEM[SP+1] e incrementa.</li>
<li><strong>MAR</strong>: endereço aplicado a RAM. Recebe PC, PC+1, SP, SP+1, Ry ou o byte adicional (MBR), conforme a instrução.</li>
<li><strong>MBR</strong>: dado lido da RAM (byte adicional, <code>ldr</code>, <code>pop</code>) ou dado a escrever (Rx).
Está ligado à entrada DIN da RAM.</li>
<li><strong>IR</strong>: instrução atual. Fica estável do FETCH até o próximo FETCH e é espelhado no LCD.</li>
<li><strong>ARG</strong>: copia do byte adicional de <code>ldi</code>, <code>st</code> e <code>jmp</code>, usada só pelo LCD.</li>
<li><strong>Flags</strong>: seis flip-flops dentro da UC (Z, N, OVF, EQ, GT, SM), gravados no fim do EXECUTE das
instruções de ALU e ligados aos LEDs e aos desvios.</li>
</ul>
<p>Os únicos somadores fora da ALU são os de PC e SP (PC+1, PC+2, SP+1, SP-1), exceção prevista no enunciado.
Todas as contas das instruções, inclusive <code>inc</code> e <code>dec</code>, passam pela ALU.</p>

<h2 class="quebra">3. Conjunto de instruções</h2>
<p>Cada instrução ocupa um byte: opcode nos bits 7..4, Rx nos bits 3..2 e Ry (ou a função, nas instruções de um
operando) nos bits 1..0, com Ra = 00, Rb = 01, Rc = 10 e Rd = 11. <code>ldi</code>, <code>st</code> e <code>jmp</code> usam o
byte seguinte (PC+1), que é dado e nunca é executado. Nos desvios, Rx contém o endereço de destino e a condição
vem das flags salvas pela última instrução de ALU. A última coluna mostra o texto exibido no LCD.</p>
{tabela_isa()}
<p>Os 41 códigos fora da tabela (<code>22 23 26 27 2A 2B 2E 2F</code>, <code>51..5F</code> com função diferente de 00,
<code>C4 C8 CC</code>, <code>E3 E7 EB EF</code> e <code>F1</code> a <code>FE</code>) executam como <code>nop</code>: nenhum
registrador, flag ou posição de memória muda e PC avança 1. No LCD aparecem como <code>NOP (0xNN)</code>.</p>
<p>Os vetores de conferência do enunciado foram montados com o <code>nasm.exe</code> e conferem: <code>add Rc, Rb</code> =
<code>09</code>, <code>dec Rd</code> = <code>2D</code>, <code>jmp 64</code> = <code>C0 40</code> e o exemplo da seção 4.3 =
<code>83 0A 82 FF FF</code>.</p>

<h2>4. Unidade de controle</h2>
<p>A UC (<code>rtl/cpu.vhd</code>, processo <code>p_uc</code>) é uma máquina de estados com cinco estados: FETCH,
DECODE1, DECODE2, EXECUTE e WRITE, a variante com duas etapas de decodificação prevista no enunciado. Todas as
instruções usam os cinco estados, inclusive as de dois bytes, o que da a mesma duração (2 s) a qualquer instrução.
A CPU age na borda de subida do clock; a RAM, na de descida.</p>
<figure>{FIG_FSM}<figcaption>Figura 3 - Máquina de estados da UC.</figcaption></figure>
<table class="dados"><thead><tr><th>Grupo</th><th>DECODE1</th><th>DECODE2</th><th>EXECUTE</th><th>WRITE (próximo PC)</th></tr></thead><tbody>
<tr><td>ALU (<code>add</code>..<code>lsr</code>)</td><td>ALU_A = Rx; ALU_B = Ry, 1 ou 0; CMD</td><td>-</td><td>Rx &#8592; ALU_R; 6 flags &#8592; ALU</td><td>PC+1</td></tr>
<tr><td><code>ldi</code></td><td>MAR &#8592; PC+1</td><td>MBR, ARG &#8592; DOUT</td><td>Rx &#8592; MBR</td><td>PC+2</td></tr>
<tr><td><code>st</code></td><td>MAR &#8592; PC+1</td><td>MBR, ARG &#8592; DOUT</td><td>MAR &#8592; MBR; MBR &#8592; Rx; WE = 1</td><td>PC+2</td></tr>
<tr><td><code>ldr</code></td><td>MAR &#8592; Ry</td><td>MBR &#8592; DOUT</td><td>Rx &#8592; MBR</td><td>PC+1</td></tr>
<tr><td><code>str</code></td><td>-</td><td>-</td><td>MAR &#8592; Ry; MBR &#8592; Rx; WE = 1</td><td>PC+1</td></tr>
<tr><td><code>push</code></td><td>-</td><td>-</td><td>MAR &#8592; SP; MBR &#8592; Rx; WE = 1; SP &#8592; SP-1</td><td>PC+1</td></tr>
<tr><td><code>pop</code></td><td>MAR &#8592; SP+1</td><td>MBR &#8592; DOUT</td><td>Rx &#8592; MBR; SP &#8592; SP+1</td><td>PC+1</td></tr>
<tr><td><code>mov</code></td><td>-</td><td>-</td><td>Rx &#8592; Ry</td><td>PC+1</td></tr>
<tr><td><code>jmp</code></td><td>MAR &#8592; PC+1</td><td>MBR, ARG &#8592; DOUT</td><td>-</td><td>MBR</td></tr>
<tr><td><code>jmpr</code>, desvios</td><td>-</td><td>-</td><td>-</td><td>Rx se a condição (flags) vale, senão PC+1</td></tr>
<tr><td><code>nop</code>, reservados</td><td>-</td><td>-</td><td>-</td><td>PC+1</td></tr>
<tr><td><code>halt</code></td><td>-</td><td>-</td><td>-</td><td>PC (parado)</td></tr>
</tbody></table>
<p>Em WRITE a UC também desliga WE e copia o novo PC para MAR, de modo que o endereço da próxima instrução chegue
à RAM antes da borda de descida e o FETCH seguinte já encontre MEM[PC] em DOUT. WE fica ativo durante um único
ciclo (entre EXECUTE e WRITE), e a escrita acontece na borda de descida desse ciclo, com endereço e dado
estáveis desde a borda de subida anterior.</p>
<p>A UC também gera dois sinais de estado para o LCD: <code>IR_OK</code>, que vai a 1 no primeiro FETCH depois do reset, e
<code>ARG_OK</code>, que vai a 0 no FETCH e a 1 no DECODE2, quando o byte adicional já foi lido. Assim o LCD nunca mostra
o operando da instrução anterior.</p>
<p><strong>Reset.</strong> Com a chave SW0 em 1, a UC zera os registradores e as flags, faz PC = 0 e SP = 254 e volta ao
FETCH. A execução começa quando a chave volta a 0. O reset é síncrono ao clock da CPU; por isso a chave deve ficar em
1 por pelo menos um período (0,4 s). O reset não altera a RAM.</p>

<h2>5. ALU</h2>
<p>A ALU (<code>rtl/alu.vhd</code>) é um circuito puramente combinacional, sem clock: recebe ALU_A, ALU_B e CMD (4 bits)
e produz o resultado e as seis flags. A UC prepara as entradas no DECODE1 e grava resultado e flags no EXECUTE, dois
ciclos depois, quando as saídas já estabilizaram.</p>
<table class="dados"><thead><tr><th>CMD</th><th>Operação</th><th>Instruções</th><th>OVERFLOW</th></tr></thead><tbody>
<tr><td>0000</td><td>A + B (9 bits)</td><td>add, inc (B=1)</td><td>carry (bit 8)</td></tr>
<tr><td>0001</td><td>A - B (9 bits)</td><td>sub, dec (B=1)</td><td>borrow (bit 8, 1 se A &lt; B)</td></tr>
<tr><td>0010 / 0011 / 0101</td><td>A and B / A or B / A xor B</td><td>and, or, xor</td><td>0</td></tr>
<tr><td>0100</td><td>not A</td><td>not (B=0)</td><td>0</td></tr>
<tr><td>0110 / 1000</td><td>rol / lsl</td><td>rol, lsl (B=0)</td><td>bit 7 original</td></tr>
<tr><td>0111 / 1001</td><td>ror / lsr</td><td>ror, lsr (B=0)</td><td>bit 0 original</td></tr>
</tbody></table>
<p>Como sugerido na seção 2.3.2 do enunciado, soma e subtração são feitas em 9 bits com os operandos estendidos
com zero (unsigned); o bit 8 é o carry na soma e o borrow na subtração. ZERO e NEGATIVE são calculadas sobre o
resultado; EQUAL, GREATER e SMALLER comparam ALU_A e ALU_B como unsigned. Exemplos verificados pelo
<code>tb_alu</code>: 255 + 1 = 0 com Z, OVF e GT; 3 - 5 = 254 com N, OVF e SM; 200 + 100 = 44 com OVF; 200 - 10 = 190 com N e
GT (o caso do enunciado em que NEGATIVE = 1 embora 200 &gt; 10).</p>

<h2>6. Memória RAM</h2>
<p>A memória é o arquivo <code>RAM_8x256.vhd</code> fornecido pelo professor, com a interface original (CLK, DIN, ADDR, WE,
DOUT, POS_255). O programa é o valor inicial do array <code>ram</code>; para trocar de programa basta trocar esse bloco,
gerado pelo montador. A RAM é síncrona: na borda de descida escreve DIN (se WE = 1) e registra o endereço de
leitura; DOUT só é válido depois dessa borda (Figura 4). Por isso a UC coloca o endereço em MAR em um estado
(borda de subida) e lê DOUT no estado seguinte. POS_255 é ligado diretamente a MEM[255] e alimenta a linha 2 do LCD.</p>
<figure>{FIG_RAM}<figcaption>Figura 4 - Leitura do byte adicional: MAR muda no DECODE1, a RAM registra o endereço na
descida e o DECODE2 captura DOUT.</figcaption></figure>
<p class="nota">Observação: por causa da leitura assíncrona de POS_255, o XST implementa a RAM em flip-flops (2048 FFs)
em vez de block RAM. O arquivo original do professor gera o mesmo resultado; o projeto cabe com folga na FPGA (Seção 11).</p>

<h2>7. Clock, reset e LEDs</h2>
<p>O topo divide os 50 MHz da placa por um contador de 0 a <code>CLK_DIV_MAX</code> = 9.999.999, que inverte
<code>clk_cpu</code> a cada 0,2 s: clock de 2,5 Hz, 5 ciclos por instrução = 2,0 s por instrução completa. Só a CPU e a RAM
usam esse clock; o LCD continua em 50 MHz. Nos testbenches o generic e sobrescrito para acelerar a simulação.</p>
<table class="dados"><thead><tr><th>LED</th><th>LD7</th><th>LD6</th><th>LD5</th><th>LD4</th><th>LD3</th><th>LD2</th><th>LD1</th><th>LD0</th></tr></thead>
<tbody><tr><td>Sinal</td><td>CLOCK</td><td>ZERO</td><td>NEGATIVE</td><td>OVERFLOW</td><td>EQUAL</td><td>GREATER</td><td>SMALLER</td><td>apagado</td></tr>
<tr><td>Pino</td><td>F9</td><td>E9</td><td>D11</td><td>C11</td><td>F11</td><td>E11</td><td>E12</td><td>F12</td></tr></tbody></table>
<p>As flags dos LEDs vêm dos flip-flops da UC e só mudam no EXECUTE de uma instrução de ALU. A chave SW0 (pino L13)
e o reset.</p>

<h2>8. LCD</h2>
<p>O display 16x2 da placa e controlado em modo de 4 bits pelos sinais LCD_E, LCD_RS, LCD_RW e SF_D&lt;11:8&gt;, que
compartilham o barramento com a memória StrataFlash; por isso SF_CE0 fica em 1 e LCD_RW em 0 (so escrita). O
controlador (<code>rtl/lcd.vhd</code>) roda no clock de 50 MHz e tem três partes (Figura 5).</p>
<figure>{FIG_LCD}<figcaption>Figura 5 - Estrutura do controlador do LCD.</figcaption></figure>
<ol>
<li><strong>Sincronização.</strong> IR, ARG, IR_OK, ARG_OK e POS_255 vem do domínio do clock lento. Passam por dois
flip-flops, e o valor só é aceito quando duas amostras seguidas são iguais, o que evita ler um barramento no meio
de uma mudança.</li>
<li><strong>Texto</strong> (<code>rtl/lcd_texto.vhd</code>). A linha 1 vem de uma tabela de 256 modelos indexada pelo IR, a
mesma ideia da <code>TEXT_MAP_ROM</code> do arquivo <code>character_to_slv_v2.txt</code> fornecido pelo professor, de onde
também vem o tipo <code>rom_str</code> (32 nibbles) e a função <code>to_std_logic_vector</code>. Nas instruções de dois bytes
os caracteres <code>#</code> e <code>$</code> do modelo são trocados pelos dígitos hexadecimais do byte adicional, ou por
<code>-</code> enquanto ARG_OK = 0. A linha 2 é <code>MEM[255] = ddd</code>, com os três dígitos decimais obtidos pela função
<code>to_bcd</code> (double dabble) do mesmo arquivo. Antes do primeiro FETCH a linha 1 mostra <code>RESET</code>.</li>
<li><strong>Sequenciador.</strong> Faz a inicialização do UG230 (espera de 16 ms; nibbles 3, 3, 3 e 2 com 4,2 ms, 110 us,
50 us e 50 us; comandos 28, 06, 0C e 01, este com 2 ms) e depois reescreve a tela sem parar: Set DDRAM Address 80,
16 caracteres da linha 1, C0 e 16 caracteres da linha 2, cerca de 1,8 ms por tela. O texto é copiado no início de
cada tela, para que uma linha nunca misture dois estados. Cada transferência de 4 bits põe RS e o dado 60 ns antes
de subir E (mínimo 40 ns), mantém E alto por 240 ns (mínimo 230 ns), espera 1 us entre os nibbles e 50 us entre
bytes (mínimo 40 us).</li>
</ol>
<p>Exemplos de tela: <code>LDI Ra, 0x--</code> logo após o FETCH de um <code>ldi</code> e <code>LDI Ra, 0x64</code> a partir do DECODE2;
<code>ADD Ra Rb</code>; <code>LDR Rd [Rc]</code>; <code>HALT</code>; e, na linha 2, <code>MEM[255] = 028</code>. O formato segue os
exemplos da seção 3.1 do enunciado.</p>

<h2 class="quebra">9. Programas de teste</h2>
<p>Os programas ficam em <code>programs/</code>. São montados pelo <code>nasm.exe</code> do professor, e o resultado é conferido
byte a byte com o montador próprio de <code>tools/cpu8.py</code>. O professor anunciou dois testes, um Fibonacci e um bubble
sort; os nossos foram escritos para que, juntos, executem as 32 instruções da ISA e os 9 desvios tomados e não
tomados (cobertura medida pelo modelo de referência). Assim, rodar só esses dois programas na placa já exercita a
ISA inteira.</p>
<h3>9.1 Fibonacci</h3>
<p>Calcula a sequência de Fibonacci em 8 bits até o maior termo que cabe (233), mostra cada termo em MEM[255] e
guarda o vetor em 0xC0. O fim é detectado pela flag OVERFLOW da soma 144 + 233. Depois conta os termos ímpares (AND
com máscara), os termos &#8805; 128 (bit 7 sai pelo LSL) e faz um autoteste de ROL/ROR e NOT. Resultado em MEM[255]:
{', '.join(str(p['escrita'][1]) for p in fib.passos if p['escrita'] and p['escrita'][0] == 255)}
({len(fib.passos)} instruções).</p>
{listagem('fibonacci')}
<h3>9.2 Bubble sort</h3>
<p>Ordena em ordem crescente (unsigned) o vetor 200, 3, 77, 3, 128 em 0xE0, com parada antecipada quando uma passada
não troca nada. A comparação usa SUB e as flags GREATER e SMALLER sem perder v[i] (PUSH/POP não alteram flags).
Depois mostra o vetor ordenado, a mediana (N/2 com LSR), a quantidade de elementos &#8805; 128 (BNEG) e um checksum
(ROL e XOR). A exibição usa uma sub-rotina com retorno por JMPR. Resultado em MEM[255]:
{', '.join(str(p['escrita'][1]) for p in bub.passos if p['escrita'] and p['escrita'][0] == 255)}
({len(bub.passos)} instruções).</p>
{listagem('bubble_sort')}
<p>Variantes com outros vetores (ja ordenado, invertido com 8 elementos, todos iguais, um elemento e 8 elementos
com repetidos e valores &#8805; 128) e o programa <code>reservados.asm</code> (os 41 códigos fora da tabela) também fazem parte
dos testes.</p>

<h2 class="quebra">10. Metodologia de verificação</h2>
<p>A verificação foi feita em três camadas, todas no ISim do ISE 14.7 (os comandos estão em <code>tools/ise.sh</code>).</p>
<ol>
<li><strong>Modelo de referência.</strong> <code>tools/cpu8.py</code> contém um emulador da CPU escrito diretamente a partir
das seções 2 e 3 do enunciado, sem consultar o VHDL. Para cada programa ele gera o traço esperado: por instrução, o
IR, as seis flags, o próximo PC e a escrita na RAM (endereço e dado), além da RAM final e do texto do LCD. Os
resultados dos programas são conferidos também por definição: a sequência de Fibonacci calculada em Python e a
função <code>sorted()</code> sobre os dados originais do bubble sort.</li>
<li><strong>Testes de unidade.</strong> ALU (casos do enunciado), RAM real (imagem, latência, escrita, POS_255), texto
do LCD (todas as 256 instruções e os 256 valores de MEM[255]) e controlador do LCD, verificado por um modelo do
display (<code>tb/lcd_modelo.vhd</code>) que decodifica os sinais como o HD44780 e acusa qualquer violação dos tempos mínimos
do UG230.</li>
<li><strong>Testes integrados.</strong> <code>tb_cpu_programas</code> executa {n_prog} programas na CPU real e compara o traço
instrução a instrução: os programas do projeto e 24 programas de 256 bytes aleatórios, que executam todos os 256
códigos, inclusive os reservados e código que modifica a si mesmo. <code>tb_main</code> simula o topo real (divisor,
CPU, RAM com o programa gravado, LEDs e LCD) e confere os LEDs a cada instrução e o texto do LCD ao fim de cada uma
das primeiras instruções.</li>
</ol>
<p><strong>Os testes detectam erros?</strong> Para garantir que os testbenches não passam por acaso, foram injetados
defeitos de propósito em cópias do projeto: <code>bgt</code> testando SMALLER, <code>pop</code> somando 2 ao SP, OVERFLOW errado no
<code>ror</code>, LEDs GT/SM trocados e tempos do LCD abaixo do mínimo. Todos foram acusados pelos testbenches.</p>

<h2>11. Resultados</h2>
<h3>11.1 Simulação</h3>
{resultados_tb()}
<p>Programas conferidos pelo <code>tb_cpu_programas</code>:</p>
{programas_tb()}
<h3>11.2 Síntese e implementação</h3>
<p>Síntese (XST), mapeamento, roteamento e geração do bitstream sem erros, para o dispositivo xc3s500e-4fg320:</p>
{utilizacao()}
<h3>11.3 Critérios do enunciado</h3>
<p>A lista completa, com a forma de verificação de cada item, está em <code>docs/CRITERIOS_DE_PRONTO.md</code>. Todos os
critérios verificáveis em simulação estão atendidos; os que dependem da placa estão na Seção 13.</p>

<h2 class="quebra">12. Tabela passo a passo (demonstração)</h2>
<p>Tabela gerada pelo modelo de referência (<code>programs/gen/*.md</code>) e conferida pelo <code>tb_main</code>. Cada linha é o
estado depois da instrução; PC é o endereço da instrução executada. Ra..Rd e SP não aparecem na placa e estão
aqui para acompanhar a execução.</p>
<h3>12.1 Programa de demonstração das flags (demo_flags.asm)</h3>
{md_tabela(ler('programs', 'gen', 'demo_flags.md'))}
<h3>12.2 Fibonacci: primeiras 40 instruções</h3>
{md_tabela(ler('programs', 'gen', 'fibonacci.md'), maximo=40)}
<p class="nota">Tabela completa (470 instruções) em <code>programs/gen/fibonacci.md</code>; bubble sort em
<code>programs/gen/bubble_sort.md</code>.</p>

<h2 class="quebra">13. Teste na placa</h2>
<p>O primeiro teste na placa (25/11/2026) validou o divisor de clock, o reset pela chave SW0, a CPU, a RAM e os
LEDs com o programa <code>demo_flags.asm</code>: as flags acenderam na sequência da tabela 12.1. O LCD e os programas
Fibonacci e bubble sort completos seguem o roteiro de <code>docs/TESTE_NA_PLACA.md</code>, com pontos de controle de tempo,
texto e LEDs.</p>
{fotos()}

<h2>14. Conclusão</h2>
<p>A CPU implementa as 32 instruções da ISA, os 41 códigos reservados como nop, as seis flags com as convenções do
enunciado, a pilha, o reset por chave, o clock reduzido para 2 segundos por instrução, os LEDs e o LCD. O uso de um
modelo de referência independente permitiu comparar a CPU instrução a instrução em mais de dez mil instruções,
incluindo programas aleatórios, e os testes de mutação mostraram que os testbenches de fato detectam erros. O
cuidado com a RAM síncrona (endereço em um estado, dado no seguinte), com a passagem dos sinais do clock lento
para o clock do LCD e com os tempos mínimos do display foi o ponto mais delicado do projeto.</p>

<h2>Apêndice: arquivos do projeto</h2>
<table class="dados"><thead><tr><th>Arquivo</th><th>Conteúdo</th></tr></thead><tbody>
<tr><td><code>rtl/main.vhd</code></td><td>Topo: divisor de clock, instâncias, LEDs</td></tr>
<tr><td><code>rtl/cpu.vhd</code></td><td>UC, banco de registradores, PC, SP, IR, MAR, MBR, flags</td></tr>
<tr><td><code>rtl/alu.vhd</code></td><td>ALU combinacional</td></tr>
<tr><td><code>rtl/RAM_8x256.vhd</code></td><td>RAM do professor com o programa (gerada pelo <code>nasm.exe</code>)</td></tr>
<tr><td><code>rtl/lcd.vhd</code>, <code>lcd_texto.vhd</code>, <code>lcd_pkg.vhd</code></td><td>Controlador, formatação do texto e funções do LCD</td></tr>
<tr><td><code>constraints/spartan3e.ucf</code></td><td>Pinos e clock da placa</td></tr>
<tr><td><code>tb/*.vhd</code>, <code>tb/dados/</code></td><td>Testbenches, modelo do LCD e dados de referência</td></tr>
<tr><td><code>programs/*.asm</code>, <code>programs/gen/</code></td><td>Programas e arquivos gerados (imagens, traços, tabelas)</td></tr>
<tr><td><code>tools/cpu8.py</code></td><td>Montador, modelo de referência, geração dos testes e das tabelas</td></tr>
<tr><td><code>tools/ise.sh</code>, <code>gera_bits.sh</code>, <code>criar_projeto_ise.tcl</code></td><td>Simulação, implementação e projeto ISE por linha de comando</td></tr>
<tr><td><code>ise/cpu8.xise</code></td><td>Projeto do ISE 14.7</td></tr>
<tr><td><code>docs/</code></td><td>ISA, critérios de pronto, roteiro de teste na placa, este relatório</td></tr>
</tbody></table>
'''
    doc = ('<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>CPU de 8 bits - Relatório</title>'
           '<style>%s</style></head><body>%s</body></html>' % (CSS, corpo))
    caminho = os.path.join(DOCS, 'relatorio.html')
    open(caminho, 'w', encoding='utf-8').write(doc)
    print(caminho)
    chrome = shutil.which('google-chrome') or shutil.which('chromium') or shutil.which('chromium-browser')
    if chrome:
        pdf = os.path.join(DOCS, 'relatorio.pdf')
        subprocess.run([chrome, '--headless=new', '--disable-gpu', '--no-pdf-header-footer',
                        '--print-to-pdf=' + pdf, 'file://' + caminho],
                       check=True, capture_output=True, timeout=180)
        print(pdf)
    else:
        print('Chrome nao encontrado: abra relatorio.html no navegador e imprima em PDF.')


if __name__ == '__main__':
    gerar()

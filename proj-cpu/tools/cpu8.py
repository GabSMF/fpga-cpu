#!/usr/bin/env python3
"""Ferramentas da CPU de 8 bits (ENG4448).

Modelo de referencia ("golden") escrito a partir do ENUNCIADO.pdf, secoes 2 e 3.
Nao depende de nenhum arquivo VHDL: serve para conferir a CPU em simulacao.

Subcomandos:
  asm   ARQ.asm                montador proprio (mesma sintaxe do nasm.exe do professor)
  build NOME [NOME...]         monta programs/NOME.asm e gera programs/gen/NOME.*
  all                          build de todos os programs/*.asm + arquivos de teste
  lcdref                       gera tb/dados/lcd_texto.txt (referencia do texto do LCD)
  lcdrom                       imprime a tabela de texto do LCD em VHDL (para rtl/lcd_pkg.vhd)
  table NOME                   imprime a tabela passo a passo (Markdown)

Arquivos gerados por build (programs/gen/):
  NOME.lst    listagem no formato do nasm.exe (bits // linha: fonte)
  NOME.vhd    RAM_8x256.vhd completo com a imagem do programa (formato da secao 4.3)
  NOME.mem    256 linhas com os bytes da imagem, em binario (lido pelos testbenches)
  NOME.trace  uma linha por instrucao executada: IR FLAGS PROX_PC END_ESCRITA DADO_ESCRITO
  NOME.ram    conteudo final esperado da RAM (256 linhas, decimal)
  NOME.md     tabela passo a passo (PC, LCD, flags, MEM[255]) para a apresentacao
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # proj-cpu/
PROGS = os.path.join(RAIZ, 'programs')
GEN = os.path.join(PROGS, 'gen')
NASM_EXE = os.path.join(os.path.dirname(RAIZ), 'NASM', 'nasm.exe')

REGS = {'ra': 0, 'rb': 1, 'rc': 2, 'rd': 3}
NOME_REG = ['Ra', 'Rb', 'Rc', 'Rd']

# Tabela da secao 2.2: mnemonico -> (opcode, formato, bits[1:0])
#   RR: Rx, Ry   R: Rx   RX: Rx, valor (2 bytes)   RP: Rx, [Ry]   J: valor (2 bytes)   '': sem operando
ISA = {
    'add': (0x0, 'RR', None), 'sub': (0x1, 'RR', None),
    'inc': (0x2, 'R', 0), 'dec': (0x2, 'R', 1),
    'and': (0x3, 'RR', None), 'or': (0x4, 'RR', None), 'not': (0x5, 'R', 0),
    'xor': (0x6, 'RR', None),
    'rol': (0x7, 'R', 0), 'ror': (0x7, 'R', 1), 'lsl': (0x7, 'R', 2), 'lsr': (0x7, 'R', 3),
    'push': (0x8, 'R', 0), 'pop': (0x8, 'R', 1), 'st': (0x8, 'RX', 2), 'ldi': (0x8, 'RX', 3),
    'ldr': (0x9, 'RP', None), 'str': (0xA, 'RP', None), 'mov': (0xB, 'RR', None),
    'jmp': (0xC, 'J', 0), 'jmpr': (0xC, 'R', 1), 'bz': (0xC, 'R', 2), 'bnz': (0xC, 'R', 3),
    'bcs': (0xD, 'R', 0), 'bcc': (0xD, 'R', 1), 'beq': (0xD, 'R', 2), 'bneq': (0xD, 'R', 3),
    'bgt': (0xE, 'R', 0), 'blt': (0xE, 'R', 1), 'bneg': (0xE, 'R', 2),
    'nop': (0xF, '', 0x0), 'halt': (0xF, '', 0xF),
}
TODAS = list(ISA)  # as 32 instrucoes
DESVIOS = ['bz', 'bnz', 'bcs', 'bcc', 'beq', 'bneq', 'bgt', 'blt', 'bneg']
TAM2 = ('st', 'ldi', 'jmp')


class ErroAsm(Exception):
    pass


# ---------------------------------------------------------------------------
# Montador proprio (para conferir o nasm.exe e para maquinas sem Wine)
# ---------------------------------------------------------------------------
def _limpa(linha):
    return linha.split(';', 1)[0].strip().lower()


def montar(texto, nome='prog.asm'):
    """Retorna (mem[256], fonte_por_endereco, simbolos). Mesmas regras do nasm.exe v0.5."""
    linhas = texto.splitlines()
    sim, end, itens = {}, 0, []
    for n, bruta in enumerate(linhas, 1):
        l = _limpa(bruta)
        if ':' in l:
            rot, l = l.split(':', 1)
            rot, l = rot.strip(), l.strip()
            if not re.fullmatch(r'[a-z_][a-z0-9_]*', rot):
                raise ErroAsm('%s:%d: rotulo invalido %r' % (nome, n, rot))
            if rot in sim:
                raise ErroAsm('%s:%d: rotulo %r repetido' % (nome, n, rot))
            sim[rot] = end
        if not l:
            continue
        tok = l.split(None, 1)
        mn = tok[0]
        ops = [o.strip() for o in tok[1].split(',')] if len(tok) > 1 else []
        if mn == '.equ':
            sim[ops[0]] = _num(ops[1], nome, n)
            continue
        if mn == '.org':
            novo = _num(ops[0], nome, n)
            if novo < end:
                raise ErroAsm('%s:%d: .org volta o endereco' % (nome, n))
            end = novo
            continue
        if mn == '.global':
            itens.append((end, n, 'jmp', ops))
            end += 2
            continue
        if mn == '.byte':
            itens.append((end, n, '.byte', ops))
            end += 1
            continue
        if mn not in ISA:
            raise ErroAsm('%s:%d: mnemonico desconhecido %r' % (nome, n, mn))
        itens.append((end, n, mn, ops))
        end += 2 if mn in TAM2 else 1
    if end > 256:
        raise ErroAsm('%s: programa passa de 256 bytes (%d)' % (nome, end))

    mem = [0] * 256
    fonte = {}

    def valor(op, n):
        v = sim[op[1:]] if op.startswith('@') and op[1:] in sim else None
        if op.startswith('@') and v is None:
            raise ErroAsm('%s:%d: simbolo %r nao definido' % (nome, n, op))
        v = _num(op, nome, n) if v is None else v
        if not 0 <= v <= 255:
            raise ErroAsm('%s:%d: valor %d fora de 0..255' % (nome, n, v))
        return v

    def reg(op, n):
        op = op.strip('[] ')
        if op not in REGS:
            raise ErroAsm('%s:%d: registrador invalido %r' % (nome, n, op))
        return REGS[op]

    for a, n, mn, ops in itens:
        src = linhas[n - 1].split(';', 1)[0].strip()
        fonte[a] = (n, src)
        if mn == '.byte':
            if ops[0].startswith('@'):
                raise ErroAsm('%s:%d: .byte nao aceita @simbolo no nasm.exe' % (nome, n))
            mem[a] = valor(ops[0], n)
            continue
        op, fmt, fn = ISA[mn]
        esperado = {'RR': 2, 'R': 1, 'RX': 2, 'RP': 2, 'J': 1, '': 0}[fmt]
        if len(ops) != esperado:
            raise ErroAsm('%s:%d: %s precisa de %d operando(s)' % (nome, n, mn, esperado))
        if fmt in ('RR', 'RP'):
            if fmt == 'RP' and not ops[1].startswith('['):
                raise ErroAsm('%s:%d: %s usa [Ry]' % (nome, n, mn))
            mem[a] = op << 4 | reg(ops[0], n) << 2 | reg(ops[1], n)
        elif fmt == 'R':
            mem[a] = op << 4 | reg(ops[0], n) << 2 | fn
        elif fmt == 'RX':
            mem[a] = op << 4 | reg(ops[0], n) << 2 | fn
            mem[a + 1] = valor(ops[1], n)
            fonte[a + 1] = (n, src)
        elif fmt == 'J':
            mem[a] = 0xC0
            mem[a + 1] = valor(ops[0], n)
            fonte[a + 1] = (n, src)
        else:
            mem[a] = op << 4 | fn
    return mem, fonte, sim


def _num(s, nome, n):
    try:
        return int(s, 0)
    except ValueError:
        raise ErroAsm('%s:%d: numero invalido %r' % (nome, n, s))


# ---------------------------------------------------------------------------
# nasm.exe do professor via Wine (precisa de pseudo-terminal: usa `script`)
# ---------------------------------------------------------------------------
def nasm_disponivel():
    return shutil.which('wine') and shutil.which('script') and os.path.exists(NASM_EXE)


def nasm(asm_path, ram=False):
    """Executa nasm.exe e devolve o texto gerado (listagem ou RAM_8x256.vhd)."""
    with tempfile.TemporaryDirectory() as d:
        shutil.copy(NASM_EXE, d)
        shutil.copy(asm_path, os.path.join(d, 'prog.asm'))
        cmd = 'wine nasm.exe -i prog.asm -o saida.txt' + (' -r' if ram else '')
        env = dict(os.environ, WINEDEBUG='-all')
        r = subprocess.run(['script', '-qc', cmd, '/dev/null'], cwd=d, env=env,
                           stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=180)
        saida = os.path.join(d, 'saida.txt')
        if not os.path.exists(saida):
            raise ErroAsm('nasm.exe falhou:\n' + re.sub(r'\x1b\[[?0-9;]*[a-zA-Z]', '', r.stdout))
        return open(saida, encoding='latin-1').read().replace('\r\n', '\n')


def mem_da_listagem(lst):
    mem = []
    for l in lst.splitlines():
        if l.strip():
            mem.append(int(l.split('//')[0].strip(), 2))
    if len(mem) > 256 or any(b > 255 for b in mem):
        raise ErroAsm('listagem do nasm.exe com byte invalido ou mais de 256 enderecos')
    return mem + [0] * (256 - len(mem))


# ---------------------------------------------------------------------------
# Emulador de referencia (ENUNCIADO, secoes 2.2, 2.3 e 2.4)
# ---------------------------------------------------------------------------
def decodifica(ir):
    """Mnemonico executado para um byte de instrucao ('reservado' = tratado como nop)."""
    op, x, f = ir >> 4, ir >> 2 & 3, ir & 3
    if op in (0x0, 0x1, 0x3, 0x4, 0x6, 0x9, 0xA, 0xB):
        return {0: 'add', 1: 'sub', 3: 'and', 4: 'or', 6: 'xor', 9: 'ldr', 10: 'str', 11: 'mov'}[op]
    if op == 0x2:
        return ['inc', 'dec', 'reservado', 'reservado'][f]
    if op == 0x5:
        return 'not' if f == 0 else 'reservado'
    if op == 0x7:
        return ['rol', 'ror', 'lsl', 'lsr'][f]
    if op == 0x8:
        return ['push', 'pop', 'st', 'ldi'][f]
    if op == 0xC:
        if f == 0:
            return 'jmp' if x == 0 else 'reservado'
        return ['', 'jmpr', 'bz', 'bnz'][f]
    if op == 0xD:
        return ['bcs', 'bcc', 'beq', 'bneq'][f]
    if op == 0xE:
        return ['bgt', 'blt', 'bneg', 'reservado'][f]
    if ir == 0xF0:
        return 'nop'
    if ir == 0xFF:
        return 'halt'
    return 'reservado'


class Cpu:
    def __init__(self, mem):
        self.mem = list(mem)
        self.r = [0, 0, 0, 0]
        self.pc, self.sp = 0, 254
        self.z = self.n = self.ovf = self.eq = self.gt = self.sm = 0
        self.passos = []          # um dicionario por instrucao executada
        self.cobertura = set()
        self.desvios = {}         # mnemonico -> {True, False}

    def flags(self):
        return (self.z, self.n, self.ovf, self.eq, self.gt, self.sm)

    def _alu(self, x, a, b, res, ovf):
        res &= 0xFF
        self.r[x] = res
        self.z, self.n, self.ovf = int(res == 0), res >> 7, int(ovf)
        self.eq, self.gt, self.sm = int(a == b), int(a > b), int(a < b)

    def passo(self):
        m, pc = self.mem, self.pc
        ir = m[pc]
        arg = m[(pc + 1) & 0xFF]
        mn = decodifica(ir)
        x, y = ir >> 2 & 3, ir & 3
        A, B = self.r[x], self.r[y]
        prox = (pc + 1) & 0xFF
        escrita = None
        if mn == 'add':
            self._alu(x, A, B, A + B, A + B > 255)
        elif mn == 'sub':
            self._alu(x, A, B, A - B, A < B)
        elif mn == 'inc':
            self._alu(x, A, 1, A + 1, A + 1 > 255)
        elif mn == 'dec':
            self._alu(x, A, 1, A - 1, A < 1)
        elif mn == 'and':
            self._alu(x, A, B, A & B, 0)
        elif mn == 'or':
            self._alu(x, A, B, A | B, 0)
        elif mn == 'not':
            self._alu(x, A, 0, ~A, 0)
        elif mn == 'xor':
            self._alu(x, A, B, A ^ B, 0)
        elif mn == 'rol':
            self._alu(x, A, 0, A << 1 | A >> 7, A >> 7)
        elif mn == 'ror':
            self._alu(x, A, 0, A >> 1 | (A & 1) << 7, A & 1)
        elif mn == 'lsl':
            self._alu(x, A, 0, A << 1, A >> 7)
        elif mn == 'lsr':
            self._alu(x, A, 0, A >> 1, A & 1)
        elif mn == 'push':
            escrita = (self.sp, A)
            self.sp = (self.sp - 1) & 0xFF
        elif mn == 'pop':
            self.sp = (self.sp + 1) & 0xFF
            self.r[x] = m[self.sp]
        elif mn == 'st':
            escrita = (arg, A)
            prox = (pc + 2) & 0xFF
        elif mn == 'ldi':
            self.r[x] = arg
            prox = (pc + 2) & 0xFF
        elif mn == 'ldr':
            self.r[x] = m[B]
        elif mn == 'str':
            escrita = (B, A)
        elif mn == 'mov':
            self.r[x] = B
        elif mn == 'jmp':
            prox = arg
        elif mn == 'jmpr':
            prox = A
        elif mn in DESVIOS:
            cond = {'bz': self.z, 'bnz': not self.z, 'bcs': self.ovf, 'bcc': not self.ovf,
                    'beq': self.eq, 'bneq': not self.eq, 'bgt': self.gt, 'blt': self.sm,
                    'bneg': self.n}[mn]
            self.desvios.setdefault(mn, set()).add(bool(cond))
            if cond:
                prox = A
        elif mn == 'halt':
            prox = pc
        if escrita:
            m[escrita[0]] = escrita[1]
        self.cobertura.add(mn)
        self.passos.append(dict(pc=pc, ir=ir, arg=arg, mn=mn, flags=self.flags(), prox=prox,
                                escrita=escrita, r=list(self.r), sp=self.sp, io=m[255]))
        self.pc = prox
        return mn

    def executa(self, limite=20000, halts_extras=2):
        """Executa ate halt (+ halts_extras repeticoes para conferir que o PC fica parado)."""
        extras = 0
        while len(self.passos) < limite:
            if self.passo() == 'halt':
                if extras == halts_extras:
                    return True
                extras += 1
        return False


# ---------------------------------------------------------------------------
# Texto do LCD (secao 3.1). Mesma tabela usada em rtl/lcd_pkg.vhd.
#   '#' = nibble alto do byte adicional, '$' = nibble baixo (viram '-' ate o byte ser lido)
# ---------------------------------------------------------------------------
def modelo_lcd(ir):
    mn = decodifica(ir)
    x, y = NOME_REG[ir >> 2 & 3], NOME_REG[ir & 3]
    if mn in ('add', 'sub', 'and', 'or', 'xor', 'mov'):
        t = '%s %s %s' % (mn.upper(), x, y)
    elif mn in ('ldr', 'str'):
        t = '%s %s [%s]' % (mn.upper(), x, y)
    elif mn in ('st', 'ldi'):
        t = '%s %s, 0x#$' % (mn.upper(), x)
    elif mn == 'jmp':
        t = 'JMP 0x#$'
    elif mn in ('nop', 'halt'):
        t = mn.upper()
    elif mn == 'reservado':
        t = 'NOP (0x%02X)' % ir
    else:
        t = '%s %s' % (mn.upper(), x)
    return t.ljust(16)


def linha1(ir, arg, arg_ok=True):
    h = '%02X' % arg if arg_ok else '--'
    return modelo_lcd(ir).replace('#', h[0]).replace('$', h[1])


def linha2(v):
    return ('MEM[255] = %03d' % v).ljust(16)


LINHA_RESET = 'RESET'.ljust(16)


# ---------------------------------------------------------------------------
# Geracao dos arquivos de um programa
# ---------------------------------------------------------------------------
def vhdl_ram(mem, fonte, nome):
    """RAM_8x256.vhd completo, no mesmo formato do nasm.exe -r (interface do professor)."""
    linhas = []
    for a in range(256):
        if a in fonte or mem[a]:
            com = fonte.get(a, (0, ''))[1]
            linhas.append('        %-3d => "%s", -- %s' % (a, format(mem[a], '08b'), com))
    corpo = '\n'.join(linhas)
    return CAB_RAM + '    -- %s\n    signal ram : RAM_t := (\n%s\n        others => (others => \'0\')\n    );\n' % (nome, corpo) + ROD_RAM


CAB_RAM = """library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- RAM de 256 x 8 bits com a interface fornecida pelo professor
-- (CLK, DIN, ADDR, WE, DOUT, POS_255). Arquivo gerado por proj-cpu/tools/cpu8.py.
-- Para trocar o programa basta substituir o bloco "signal ram" (secao 4.3).
entity RAM_8x256 is
    port(
        CLK     : in  std_logic;
        DIN     : in  std_logic_vector(7 downto 0);
        ADDR    : in  std_logic_vector(7 downto 0);
        WE      : in  std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
    );
end RAM_8x256;

architecture rtl of RAM_8x256 is

    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');

"""
ROD_RAM = """
begin

    process(CLK) is
    begin
        if falling_edge(CLK) then
            if WE = '1' then
                ram(to_integer(unsigned(ADDR))) <= DIN;
            end if;
            read_address <= ADDR;
        end if;
    end process;

    DOUT    <= ram(to_integer(unsigned(read_address)));
    POS_255 <= ram(255);

end architecture;
"""


def tabela_md(cpu, nome, maximo=None):
    out = ['# Passo a passo: %s' % nome, '',
           'Gerado por `tools/cpu8.py` a partir do modelo de referencia. Cada linha e o estado',
           '**depois** da instrucao. `PC` e o endereco da instrucao executada; Ra..Rd e SP sao',
           'internos (nao aparecem na placa) e ajudam a acompanhar.', '',
           '| Passo | PC | LCD linha 1 | Z | N | OVF | EQ | GT | SM | MEM[255] | Ra | Rb | Rc | Rd | SP |',
           '| ---: | ---: | --- | :-: | :-: | :-: | :-: | :-: | :-: | ---: | ---: | ---: | ---: | ---: | ---: |']
    passos = cpu.passos if maximo is None else cpu.passos[:maximo]
    for i, p in enumerate(passos, 1):
        f = p['flags']
        out.append('| %d | %d | `%s` | %d | %d | %d | %d | %d | %d | %03d | %d | %d | %d | %d | %d |' % (
            (i, p['pc'], linha1(p['ir'], p['arg']).rstrip()) + f + (p['io'],) + tuple(p['r']) + (p['sp'],)))
    return '\n'.join(out) + '\n'


def build(nome, exigir_nasm=False, verbose=True):
    asm_path = os.path.join(PROGS, nome + '.asm')
    texto = open(asm_path).read()
    mem, fonte, _ = montar(texto, nome + '.asm')
    origem = 'cpu8.py'
    if nasm_disponivel():
        lst = nasm(asm_path)
        mem_n = mem_da_listagem(lst)
        if mem_n != mem:
            dif = [a for a in range(256) if mem_n[a] != mem[a]]
            raise ErroAsm('%s: nasm.exe e cpu8.py divergem nos enderecos %s' % (nome, dif[:8]))
        vhd = nasm(asm_path, ram=True)
        origem = 'nasm.exe (conferido com cpu8.py)'
    elif exigir_nasm:
        raise ErroAsm('nasm.exe/Wine indisponivel')
    else:
        lst = ''.join('%s // %3d: %s\n' % (format(mem[a], '08b'), *fonte.get(a, (0, '')))
                      for a in range(max(fonte) + 1))
        vhd = vhdl_ram(mem, fonte, nome + '.asm')
    cpu = Cpu(mem)
    if not cpu.executa():
        raise ErroAsm('%s: nao chegou ao halt em 20000 instrucoes' % nome)
    os.makedirs(GEN, exist_ok=True)
    base = os.path.join(GEN, nome)
    open(base + '.lst', 'w').write(lst)
    open(base + '.vhd', 'w').write(vhd)
    escreve_mem(base + '.mem', mem)
    escreve_trace(base + '.trace', cpu)
    open(base + '.ram', 'w').write(''.join('%d\n' % b for b in cpu.mem))
    open(base + '.md', 'w').write(tabela_md(cpu, nome))
    if verbose:
        print('%-14s %4d bytes  %5d instrucoes  MEM[255]=%3d  montado por %s' % (
            nome, max(fonte) + 1, len(cpu.passos), cpu.mem[255], origem))
    return cpu


def escreve_mem(path, mem):
    open(path, 'w').write(''.join(format(b, '08b') + '\n' for b in mem))


def escreve_trace(path, cpu):
    with open(path, 'w') as f:
        for p in cpu.passos:
            fl = int(''.join(map(str, p['flags'])), 2)
            wa, wd = p['escrita'] if p['escrita'] else (-1, 0)
            f.write('%d %d %d %d %d\n' % (p['ir'], fl, p['prox'], wa, wd))


def relatorio_cobertura(cpus):
    cob, desv = set(), {}
    for c in cpus:
        cob |= c.cobertura
        for k, v in c.desvios.items():
            desv.setdefault(k, set()).update(v)
    faltam = [m for m in TODAS if m not in cob]
    parciais = [d for d in DESVIOS if desv.get(d, set()) != {True, False}]
    return faltam, parciais, desv, cob


def lcdref(path):
    """Referencia para tb_lcd_texto: para cada IR e ARG de teste, a linha 1 esperada."""
    with open(path, 'w') as f:
        for ir in range(256):
            arg = (ir * 37 + 11) & 0xFF
            f.write('%d %d 1 %s\n' % (ir, arg, linha1(ir, arg)))
            f.write('%d %d 0 %s\n' % (ir, arg, linha1(ir, arg, False)))
        for v in range(256):
            f.write('L2 %d %s\n' % (v, linha2(v)))


def lcdrom():
    """Tabela VHDL: 256 modelos de linha 1 indexados pelo IR (ideia da TEXT_MAP_ROM do professor)."""
    out = []
    for ir in range(256):
        sep = ',' if ir < 255 else ''
        out.append('        %3d => to_std_logic_vector("%s")%s -- 0x%02X' % (ir, modelo_lcd(ir), sep, ir))
    return '\n'.join(out)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    cmd = argv[1]
    try:
        if cmd == 'asm':
            mem, fonte, _ = montar(open(argv[2]).read(), argv[2])
            for a in range(max(fonte) + 1):
                print('%s // %3d: %s' % (format(mem[a], '08b'), *fonte.get(a, (0, ''))))
        elif cmd == 'build':
            for n in argv[2:]:
                build(n)
        elif cmd == 'all':
            nomes = sorted(f[:-4] for f in os.listdir(PROGS) if f.endswith('.asm'))
            cpus = {n: build(n) for n in nomes}
            faltam, parciais, desv, _ = relatorio_cobertura(
                [cpus[n] for n in ('fibonacci', 'bubble_sort') if n in cpus])
            print('\nCobertura de fibonacci + bubble_sort:')
            print('  instrucoes nao executadas:', faltam or 'nenhuma (32/32)')
            print('  desvios sem os dois resultados:', parciais or 'nenhum (9/9 com tomado e nao tomado)')
            _, _, _, cob = relatorio_cobertura(cpus.values())
            print('  todos os programas: %d/32 instrucoes, reservados %s' % (
                len([m for m in TODAS if m in cob]), 'sim' if 'reservado' in cob else 'nao'))
            gera_aleatorios()
            lcdref(os.path.join(RAIZ, 'tb', 'dados', 'lcd_texto.txt'))
            lista = nomes + ['aleatorio%02d' % i for i in range(N_ALEATORIOS)]
            with open(os.path.join(RAIZ, 'tb', 'dados', 'programas.txt'), 'w') as f:
                for n in lista:
                    f.write('%s %d\n' % (n, sum(1 for _ in open(os.path.join(GEN, n + '.trace')))))
            print('tb/dados/programas.txt: %d programas' % len(lista))
        elif cmd == 'lcdref':
            lcdref(os.path.join(RAIZ, 'tb', 'dados', 'lcd_texto.txt'))
        elif cmd == 'lcdrom':
            print(lcdrom())
        elif cmd == 'table':
            cpu = Cpu(montar(open(os.path.join(PROGS, argv[2] + '.asm')).read())[0])
            cpu.executa(halts_extras=0)
            print(tabela_md(cpu, argv[2]))
        else:
            print(__doc__)
            return 1
    except ErroAsm as e:
        print('ERRO:', e, file=sys.stderr)
        return 2
    return 0


# ---------------------------------------------------------------------------
# Programas aleatorios: 256 bytes quaisquer, 400 instrucoes. Exercitam todos os
# opcodes (inclusive reservados), codigo auto-modificavel e desvios para qualquer lugar.
# ---------------------------------------------------------------------------
N_ALEATORIOS = 24


def gera_aleatorios():
    import random
    rnd = random.Random(4448)
    os.makedirs(GEN, exist_ok=True)
    feitos = 0
    while feitos < N_ALEATORIOS:
        mem = [rnd.randrange(256) if rnd.random() < 0.5 else rnd.randrange(0xF0) for _ in range(256)]
        cpu = Cpu(mem)
        for _ in range(400):
            cpu.passo()
        if len({(p['pc'], p['ir']) for p in cpu.passos}) < 60:
            continue  # descarta lacos curtos demais
        nome = os.path.join(GEN, 'aleatorio%02d' % feitos)
        escreve_mem(nome + '.mem', mem)
        escreve_trace(nome + '.trace', cpu)
        open(nome + '.ram', 'w').write(''.join('%d\n' % b for b in cpu.mem))
        feitos += 1


if __name__ == '__main__':
    sys.exit(main(sys.argv))

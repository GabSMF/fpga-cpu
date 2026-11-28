; reservados.asm - os 41 codigos fora da tabela devem agir como nop
; (secao 2.2: nenhum registrador, flag ou memoria muda; PC <- PC + 1).
; Prepara registradores e flags, executa os 41 codigos e grava os registradores
; em 0xF0..0xF3. Esperado: MEM[0xF0..0xF3] = 0x11 0x22 0x33 0xF3, flags de
; 0x11 - 0x22 (N=1 OVF=1 SM=1) preservadas e MEM[255] = 0x5A (90).
        ldi Ra, 0x11
        ldi Rb, 0x22
        ldi Rc, 0x33
        mov Rd, Ra
        sub Rd, Rb          ; flags: N=1 OVF=1 SM=1 (Rd = 0xEF)
        ldi Rd, 0x44
        .byte 0x22          ; reservado
        .byte 0x23          ; reservado
        .byte 0x26          ; reservado
        .byte 0x27          ; reservado
        .byte 0x2A          ; reservado
        .byte 0x2B          ; reservado
        .byte 0x2E          ; reservado
        .byte 0x2F          ; reservado
        .byte 0x51          ; reservado
        .byte 0x52          ; reservado
        .byte 0x53          ; reservado
        .byte 0x55          ; reservado
        .byte 0x56          ; reservado
        .byte 0x57          ; reservado
        .byte 0x59          ; reservado
        .byte 0x5A          ; reservado
        .byte 0x5B          ; reservado
        .byte 0x5D          ; reservado
        .byte 0x5E          ; reservado
        .byte 0x5F          ; reservado
        .byte 0xC4          ; reservado
        .byte 0xC8          ; reservado
        .byte 0xCC          ; reservado
        .byte 0xE3          ; reservado
        .byte 0xE7          ; reservado
        .byte 0xEB          ; reservado
        .byte 0xEF          ; reservado
        .byte 0xF1          ; reservado
        .byte 0xF2          ; reservado
        .byte 0xF3          ; reservado
        .byte 0xF4          ; reservado
        .byte 0xF5          ; reservado
        .byte 0xF6          ; reservado
        .byte 0xF7          ; reservado
        .byte 0xF8          ; reservado
        .byte 0xF9          ; reservado
        .byte 0xFA          ; reservado
        .byte 0xFB          ; reservado
        .byte 0xFC          ; reservado
        .byte 0xFD          ; reservado
        .byte 0xFE          ; reservado
        ldi Rd, 0xF3
        str Rd, [Rd]        ; MEM[F3] = 0xF3
        ldi Rd, 0xF0
        str Ra, [Rd]        ; MEM[F0] = Ra
        inc Rd
        str Rb, [Rd]        ; MEM[F1] = Rb (inc nao mexe em Ra..Rc)
        inc Rd
        str Rc, [Rd]        ; MEM[F2] = Rc
        ldi Ra, @fim
        ldi Rb, 0x22
        ldi Rc, 0x11
        sub Rc, Rb          ; refaz as flags de 0x11 - 0x22 depois dos inc
        bcs Ra              ; OVF=1: salta
        halt                ; (nao deve chegar aqui)
fim:    ldi Ra, 0x5A
        st  Ra, 255
        halt

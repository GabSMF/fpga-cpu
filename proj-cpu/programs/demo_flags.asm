; demo_flags.asm - programa usado no primeiro teste na placa (25/11/2026)
; Acende cada combinacao de flags e grava 10 em MEM[255]. Ver Passo_atual_test.md.
        ldi Ra, 0xFF
        ldi Rb, 0x01
        add Ra, Rb          ; 255 + 1 = 0     -> Z=1 OVF=1 GT=1
        ldi Ra, 0x03
        ldi Rb, 0x05
        sub Ra, Rb          ; 3 - 5 = 0xFE    -> N=1 OVF=1 SM=1
        ldi Ra, 0x0A
        mov Rb, Ra
        sub Ra, Rb          ; 10 - 10 = 0     -> Z=1 EQ=1
        ldi Ra, 0x0A
        st  Ra, 0xFF        ; MEM[255] = 10
        halt

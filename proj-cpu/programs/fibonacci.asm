; =============================================================================
; fibonacci.asm - Sequencia de Fibonacci em 8 bits (unsigned)
;
; Fase 1: calcula F(0)=0, F(1)=1, F(2)=1, ... ate o maior termo que cabe em
;         8 bits (233). Cada termo aparece em MEM[255] (linha 2 do LCD) e e
;         guardado no vetor VET. O fim e detectado pela flag OVERFLOW (carry)
;         da soma: 144 + 233 = 377 > 255.
; Fase 2: percorre o vetor e conta os termos impares (mascara com AND).
; Fase 3: percorre o vetor e conta os termos >= 128 (bit 7 sai pelo LSL).
; Fase 4: autoteste: confere ROL/ROR e NOT/NOT sobre o ultimo termo.
;
; Resultado esperado em MEM[255], nesta ordem:
;   0 1 1 2 3 5 8 13 21 34 55 89 144 233   (fase 1, 14 termos)
;   9                                       (fase 2: termos impares)
;   2                                       (fase 3: 144 e 233)
;   170 (0xAA)                              (fase 4: autoteste OK)
; Vetor final: MEM[0xC0..0xCD] = os 14 termos.
;
; Instrucoes usadas: ldi st str ldr mov add sub inc and lsl rol ror not
;                    push pop jmp bcs bcc bz bnz beq bneq halt
; =============================================================================
        .equ IO, 255            ; posicao de E/S (linha 2 do LCD)
        .equ VET, 0xC0          ; vetor com os termos
        .equ OK, 0xAA           ; codigo mostrado se o autoteste passar
        .equ ERRO, 0xEE         ; codigo mostrado se o autoteste falhar

; ---------------------------------------------------------------- fase 1 ----
inicio: ldi Ra, 0               ; Ra = F(n-1)
        ldi Rb, 1               ; Rb = F(n)
        ldi Rc, @VET            ; Rc = ponteiro de escrita no vetor
        st  Ra, @IO             ; mostra F(0)
        str Ra, [Rc]            ; VET[0] = F(0)
        inc Rc
laco:   st  Rb, @IO             ; mostra F(n)
        str Rb, [Rc]            ; guarda F(n)
        inc Rc
        mov Rd, Ra
        add Rd, Rb              ; Rd = F(n+1); OVERFLOW=1 se passou de 255
        ldi Ra, @fase2
        bcs Ra                  ; estourou 8 bits: fim da sequencia
        mov Ra, Rb              ; avanca: F(n-1) <- F(n)
        mov Rb, Rd              ;         F(n)   <- F(n+1)
        jmp @laco

; ---------------------------------------------------------------- fase 2 ----
; Rc = fim do vetor, Rd = ponteiro, Rb = contador de impares
fase2:  ldi Rd, @VET
        ldi Rb, 0
impar:  ldr Ra, [Rd]            ; Ra = termo
        push Rd                 ; libera Rd para a mascara
        ldi Rd, 1
        and Ra, Rd              ; ZERO=1 se o termo e par
        pop Rd                  ; pop nao altera as flags
        ldi Ra, @par
        bz  Ra                  ; par: nao conta
        inc Rb
par:    inc Rd
        mov Ra, Rd
        sub Ra, Rc              ; EQUAL=1 quando o ponteiro chega ao fim
        ldi Ra, @impar
        bneq Ra
        st  Rb, @IO             ; mostra quantos termos sao impares

; ---------------------------------------------------------------- fase 3 ----
; Rd = ponteiro, Rb = contador de termos >= 128
        ldi Rd, @VET
        ldi Rb, 0
grande: ldr Ra, [Rd]
        lsl Ra                  ; OVERFLOW = bit 7 que saiu pela esquerda
        ldi Ra, @pequeno
        bcc Ra                  ; bit 7 = 0: termo < 128
        inc Rb
pequeno: inc Rd
        mov Ra, Rd
        sub Ra, Rc
        ldi Ra, @fase4
        beq Ra                  ; chegou ao fim do vetor
        jmp @grande
fase4:  st  Rb, @IO             ; mostra quantos termos sao >= 128

; ---------------------------------------------------------------- fase 4 ----
; autoteste com o ultimo termo (233): ror(rol(x)) == x e not(not(x)) == x
        dec Rc
        ldr Ra, [Rc]            ; Ra = 233
        mov Rb, Ra
        rol Rb
        ror Rb                  ; Rb volta a ser 233
        not Rb
        not Rb                  ; e continua 233
        sub Rb, Ra              ; ZERO=1 se Rb == Ra
        ldi Rd, @falhou
        bnz Rd
        ldi Ra, @OK
        st  Ra, @IO             ; mostra 0xAA (170): autoteste OK
        halt
falhou: ldi Ra, @ERRO
        st  Ra, @IO             ; mostra 0xEE (238): erro
        halt

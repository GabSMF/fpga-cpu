; =============================================================================
; bubble_um.asm - variante de bubble_sort.asm: um elemento: nada a ordenar (bz no inicio)
; Ordenacao crescente (unsigned) de N bytes com bubble sort
;
; Fase 1: bubble sort com parada antecipada. Cada passada compara v[i] com
;         v[i+1] (SUB + flags GREATER/SMALLER) e troca se v[i] > v[i+1].
;         Se uma passada nao troca nada, o vetor ja esta ordenado.
; Fase 2: mostra o vetor ordenado em MEM[255], um elemento por vez, conta os
;         elementos >= 128 (bit 7 = 1, flag NEGATIVE) e calcula um checksum
;         h = rol(h) xor v[i].
; Fase 3: mostra a mediana v[N/2] (N/2 com LSR), a contagem de elementos
;         >= 128 e o checksum. A exibicao usa uma sub-rotina com retorno por
;         JMPR (endereco de retorno guardado na pilha).
;
; Dados de exemplo: 200 3 77 3 128 (repetidos e valores >= 128).
; Resultado esperado em MEM[255], nesta ordem:
;   3 3 77 128 200   (fase 2)
;   77               (mediana)
;   2                (elementos >= 128)
;   checksum         (valor no comentario do final)
; Vetor final: MEM[0xE0..0xE4] = 3 3 77 128 200.
;
; Para outro vetor: mude N, FIM (= VET + N) e os .byte no fim do arquivo.
;
; Instrucoes usadas: ldi st ldr str mov add sub inc dec or xor rol lsr push
;                    pop jmp jmpr bz bnz bgt blt beq bneg nop halt
; =============================================================================
        .equ IO, 255            ; posicao de E/S (linha 2 do LCD)
        .equ N, 1               ; numero de elementos
        .equ VET, 0xE0          ; inicio do vetor
        .equ FIM, 0xE1          ; VET + N (primeira posicao depois do vetor)
        .equ TROCOU, 0xDF        ; 1 se a passada fez alguma troca
        .equ GRANDES, 0xDE      ; quantidade de elementos >= 128

; ---------------------------------------------------------------- fase 1 ----
inicio: ldi Rd, @N
        dec Rd                  ; Rd = comparacoes por passada (N-1)
        ldi Ra, @fase2
        bz  Ra                  ; N = 1: nada a ordenar
passada: push Rd                ; guarda o tamanho desta passada
        ldi Rb, 0
        st  Rb, @TROCOU          ; ainda nao houve troca
        ldi Rc, @VET            ; Rc = ponteiro para v[i]
compara: ldr Ra, [Rc]           ; Ra = v[i]
        inc Rc
        ldr Rb, [Rc]            ; Rb = v[i+1]
        push Rd                 ; guarda o contador da passada
        push Ra
        sub Ra, Rb              ; GREATER: v[i] > v[i+1]; SMALLER: v[i] < v[i+1]
        pop Ra                  ; restaura v[i] (pop nao altera as flags)
        ldi Rd, @troca
        bgt Rd                  ; fora de ordem: troca
        ldi Rd, @proximo
        blt Rd                  ; em ordem: segue
        nop                     ; iguais: tambem segue (nada a fazer)
        jmp @proximo
troca:  str Ra, [Rc]            ; v[i+1] <- v[i]
        dec Rc
        str Rb, [Rc]            ; v[i]   <- v[i+1]
        inc Rc
        ldi Rd, 1
        st  Rd, @TROCOU          ; marca que houve troca
proximo: pop Rd                 ; contador da passada
        dec Rd
        ldi Ra, @compara
        bnz Ra                  ; ainda ha pares nesta passada
        pop Rd                  ; tamanho desta passada
        ldi Rc, @TROCOU
        ldr Rb, [Rc]
        or  Rb, Rb              ; ZERO=1 se nao houve troca
        ldi Ra, @fase2
        bz  Ra                  ; nenhuma troca: vetor ja ordenado
        dec Rd                  ; proxima passada tem um par a menos
        ldi Ra, @passada
        bnz Ra

; ---------------------------------------------------------------- fase 2 ----
; Rc = ponteiro, Rb = checksum
fase2:  ldi Rb, 0
        st  Rb, @GRANDES
        ldi Rc, @VET
exibe:  ldr Ra, [Rc]
        st  Ra, @IO             ; mostra v[i]
        rol Rb
        xor Rb, Ra              ; h = rol(h) xor v[i]
        or  Ra, Ra              ; NEGATIVE = bit 7 de v[i]
        ldi Rd, @menor
        bneg Rd                 ; bit 7 = 1: v[i] >= 128
        jmp @seguinte
menor:  ldi Rd, @GRANDES
        ldr Ra, [Rd]
        inc Ra
        str Ra, [Rd]            ; GRANDES = GRANDES + 1
seguinte: inc Rc
        ldi Rd, @FIM
        mov Ra, Rc
        sub Ra, Rd              ; EQUAL=1 no fim do vetor
        ldi Ra, @fase3
        beq Ra
        jmp @exibe

; ---------------------------------------------------------------- fase 3 ----
fase3:  push Rb                 ; guarda o checksum
        ldi Ra, @N
        lsr Ra                  ; Ra = N / 2
        ldi Rb, @VET
        add Ra, Rb              ; Ra = endereco de v[N/2]
        ldr Ra, [Ra]            ; Ra = mediana
        ldi Rd, @volta1
        push Rd
        jmp @mostra             ; mostra a mediana
volta1: ldi Rd, @GRANDES
        ldr Ra, [Rd]
        ldi Rd, @volta2
        push Rd
        jmp @mostra             ; mostra quantos sao >= 128
volta2: pop Ra                  ; Ra = checksum
        st  Ra, @IO             ; mostra o checksum
        halt

; sub-rotina: mostra Ra em MEM[255] e volta para o endereco no topo da pilha
mostra: st  Ra, @IO
        pop Rd
        jmpr Rd

; ----------------------------------------------------------------- dados ----
        .org 0xE0
        .byte 42

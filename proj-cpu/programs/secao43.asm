; secao43.asm - exemplo da secao 4.3 do enunciado
; Imagem esperada: 83 0A 82 FF FF. Resultado: MEM[255] = 10, depois halt.
        ldi Ra, 10
        st  Ra, 255
        halt

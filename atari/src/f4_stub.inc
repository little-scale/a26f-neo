; Identical at logical $FF00 in every F4 bank.

        bit $FFFB
        jmp Reset

        ldx SampleBank
        lda $FFF4,x
        lda (SamplePtr),y
        bit $FFFB
        rts


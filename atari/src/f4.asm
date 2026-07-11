        PROCESSOR 6502

F4_BUILD        = 1
F4Reset         = $FF00
FetchSampleByte = $FF06

; Banks 0-6 reserve $F000-$FEFF (3840 bytes) for patchable sample data.

        ORG $0000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $0FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $1000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $1FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $2000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $2FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $3000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $3FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $4000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $4FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $5000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $5FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        ORG $6000
        RORG $F000
        ds $0F00, 0
        INCLUDE "f4_stub.inc"
        ORG $6FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset

        INCLUDE "main.asm"


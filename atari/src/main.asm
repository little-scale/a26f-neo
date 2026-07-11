        PROCESSOR 6502
        INCLUDE "vcs.inc"

        IFCONST VIDEO_NTSC
VBLANK_LINES_REMAINING = 34
VISIBLE_LINES          = 192
OVERSCAN_LINES         = 30
        ELSE
VBLANK_LINES_REMAINING = 42
VISIBLE_LINES          = 228
OVERSCAN_LINES         = 36
        ENDIF

; -----------------------------------------------------------------------------
; A26F NEO PAL/NTSC diagnostic ROM
; PAL:  312 lines: 3 VSYNC + 45 VBLANK + 228 visible + 36 overscan
; NTSC: 262 lines: 3 VSYNC + 37 VBLANK + 192 visible + 30 overscan
; Controller port 1 directions select four AUDF0 values.
; Controller port 1 fire advances AUDC0 on each press.
; -----------------------------------------------------------------------------

        SEG.U RAM
        ORG $80

BgColor        ds 1
ActiveColor    ds 1
ActivityTimer  ds 1
PrevFire       ds 1
LocalActive    ds 1
SoundBank      ds 1
DirectionIndex ds 1
PrevDirection  ds 1

        SEG CODE
        ORG $F000

Reset:
        sei
        cld
        ldx #$FF
        txs

        lda #0
        ldx #$7F
ClearRam:
        sta $80,x
        dex
        bpl ClearRam

        lda #0
        ldx #$2C
ClearTia:
        sta $00,x
        dex
        bpl ClearTia

        ; All controller direction pins are inputs.
        sta SWACNT
        sta AUDV0
        sta AUDV1

        lda #4
        sta AUDF0
        lda #$FF
        sta DirectionIndex
        sta PrevDirection
        lda #$26
        sta ActiveColor

Frame:
        ; Blank the display and keep joystick fire latching disabled.
        lda #2
        sta VBLANK
        sta VSYNC
        sta WSYNC
        sta WSYNC
        sta WSYNC
        lda #0
        sta VSYNC

        ; Three bounded controller polling lines plus the target-specific quiet
        ; lines form vertical blank. Keeping each routine below 76 CPU cycles
        ; ensures frame length remains stable.
        jsr PollDirectionInput
        sta WSYNC
        jsr ApplySoundcheck
        sta WSYNC
        jsr PollFire
        sta WSYNC
        ldx #VBLANK_LINES_REMAINING
VBlankLoop:
        sta WSYNC
        dex
        bne VBlankLoop

        ; Visible area: a single activity colour.
        lda #0
        sta VBLANK
        lda BgColor
        sta COLUBK
        ldx #VISIBLE_LINES
VisibleLoop:
        sta WSYNC
        dex
        bne VisibleLoop

        ; 36 overscan lines.
        lda #2
        sta VBLANK
        ldx #OVERSCAN_LINES
OverscanLoop:
        sta WSYNC
        dex
        bne OverscanLoop

        lda ActivityTimer
        beq SetIdleColor
        dec ActivityTimer
        bne Frame
SetIdleColor:
        lda #0
        sta BgColor
        jmp Frame

; Read controller port 1 directions. Inputs are SWCHA bits 7..4, active low.
; Direction indices run clockwise: up, right, down, left. Fixed priority handles
; diagonals. Sound application is split onto the next scanline.
PollDirectionInput:
        lda SWCHA
        and #$F0
        cmp #$F0
        beq DirectionReleased

        tax
        txa
        and #$80
        beq SelectUp
        txa
        and #$10
        beq SelectRight
        txa
        and #$40
        beq SelectDown
        lda #3
        bne StoreDirection
SelectUp:
        lda #0
        beq StoreDirection
SelectRight:
        lda #1
        bne StoreDirection
SelectDown:
        lda #2
StoreDirection:
        sta DirectionIndex
        rts

DirectionReleased:
        lda #$FF
        sta DirectionIndex
        sta PrevDirection
        lda LocalActive
        beq DirectionInputDone
        lda #0
        sta LocalActive
        sta AUDV0
        sta AUDV1
DirectionInputDone:
        rts

; Banks 0-3 cover AUDC values 0-15. The four directions deliberately span the
; AUDF range. Bank 4 is reserved for sample slots 0-3 in the production F4 ROM.
ApplySoundcheck:
        ldy DirectionIndex
        bmi SoundcheckDone

        lda SoundBank
        cmp #4
        beq LocalSampleBank

        lda TestFrequencies,y
        sta AUDF0
        lda SoundBank
        asl
        asl
        clc
        adc DirectionIndex
        sta AUDC0
        lda #12
        sta AUDV0
        lda #1
        sta LocalActive
        lda #4
        sta ActivityTimer
        lda ActiveColor
        sta BgColor
        jmp SoundcheckDone

LocalSampleBank:
        ; The F4 sample engine replaces this visual edge marker with triggers
        ; for sample slots 0-3. Edge tracking is already exercised here.
        cpy PrevDirection
        beq SoundcheckDone
        sty PrevDirection
        lda #1
        sta LocalActive
        lda #8
        sta ActivityTimer
        lda ActiveColor
        sta BgColor
SoundcheckDone:
        rts

; Poll the port 1 fire button and advance the five-bank selector once per press.
; This routine is also bounded to less than one scanline.
PollFire:
        bit INPT4
        bmi FireReleased
        lda PrevFire
        bne PollDone
        lda #1
        sta PrevFire
        lda SoundBank
        clc
        adc #1
        cmp #5
        bcc StoreSoundBank
        lda #0
StoreSoundBank:
        sta SoundBank
        tay
        lda BankColors,y
        sta ActiveColor
        lda #8
        sta ActivityTimer
        lda ActiveColor
        sta BgColor
        rts
FireReleased:
        lda #0
        sta PrevFire
PollDone:
        rts

TestFrequencies:
        .byte 4, 10, 18, 28

BankColors:
        .byte $26, $46, $66, $86, $C6

        ORG $FFFA
        .word Reset
        .word Reset
        .word Reset

        END

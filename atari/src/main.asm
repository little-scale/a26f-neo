        PROCESSOR 6502
        INCLUDE "vcs.inc"

        IFCONST VIDEO_NTSC
VBLANK_LINES_REMAINING = 7
VISIBLE_LINES          = 192
OVERSCAN_LINES         = 30
        ELSE
VBLANK_LINES_REMAINING = 15
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
LineCounter    ds 1

PortSnapshot   ds 1
LastClock      ds 1
RxByte         ds 1
RxBits         ds 1
RxReady        ds 1
RxRead         ds 1
RxWrite        ds 1
RxNext         ds 1
RxCommand      ds 1
RxQueue        ds 16

Voice0Audc     ds 1
Voice0Audf     ds 1
Voice0Target   ds 1
Voice0Current  ds 1
Voice0Counter  ds 1
Voice1Audc     ds 1
Voice1Audf     ds 1
Voice1Target   ds 1
Voice1Current  ds 1
Voice1Counter  ds 1
EnvelopeParams ds 4
PendingEnv     ds 1

Voice0Attack  = EnvelopeParams
Voice0Release = EnvelopeParams+1
Voice1Attack  = EnvelopeParams+2
Voice1Release = EnvelopeParams+3

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
        sta PendingEnv
        lda #1
        sta Voice0Release
        sta Voice1Release
        sta Voice0Counter
        sta Voice1Counter
        lda #8
        sta RxBits
        lda #64
        sta TIM64T
        lda #$26
        sta ActiveColor
        lda SWCHA
        and #$08
        sta LastClock

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

        ; Controller and command work is separated by receiver polling lines.
        ; The maximum interval between port-2 polls remains below one Pico bit.
        jsr PollDirectionInput
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr ApplySoundcheck
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr PollFire
        sta WSYNC
        jsr PollSerial
        sta WSYNC

        ; Up to eight commands are serviced per frame. Each service line is
        ; followed by a receiver line so incoming bits cannot be missed.
        lda #8
        sta LineCounter
CommandServiceLoop:
        jsr ServiceCommand
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne CommandServiceLoop

        ; Two envelope ticks per frame. Each voice update is followed by a
        ; receiver line, preserving the serial polling bound.
        jsr UpdateEnvelope0
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr UpdateEnvelope1
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr UpdateEnvelope0
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr UpdateEnvelope1
        sta WSYNC
        jsr PollSerial
        sta WSYNC

        lda #VBLANK_LINES_REMAINING
        sta LineCounter
VBlankLoop:
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne VBlankLoop

        ; Visible area: a single activity colour.
        lda #0
        sta VBLANK
        lda BgColor
        sta COLUBK
        lda #VISIBLE_LINES
        sta LineCounter
VisibleLoop:
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne VisibleLoop

        ; 36 overscan lines.
        lda #2
        sta VBLANK
        lda #OVERSCAN_LINES
        sta LineCounter
OverscanLoop:
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne OverscanLoop

        ; A RIOT timer restarted at every serial edge detects a long idle gap.
        ; It resets partial bytes and extended-command selection without
        ; disturbing already queued complete commands.
        bit TIMINT
        bpl SerialIdleChecked
        lda #8
        sta RxBits
        lda #0
        sta RxReady
        lda #$FF
        sta PendingEnv
SerialIdleChecked:
        lda ActivityTimer
        beq SetIdleColor
        dec ActivityTimer
        lda #$66
        sta BgColor
        jmp Frame
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

; Controller port 2 uses SWCHA bit 3 as clock and bit 2 as data. Every clock
; transition shifts one MSB-first bit. Completed bytes are moved to the ring on
; a later no-edge poll so both paths stay bounded to one scanline.
PollSerial:
        lda SWCHA
        sta PortSnapshot
        and #$08
        cmp LastClock
        beq SerialNoEdge

        sta LastClock
        lda #64
        sta TIM64T
        lda RxByte
        asl
        sta RxByte
        lda PortSnapshot
        and #$04
        beq SerialBitZero
        inc RxByte
SerialBitZero:
        dec RxBits
        bne SerialDone
        lda #8
        sta RxBits
        lda #1
        sta RxReady
        rts

SerialNoEdge:
        lda RxReady
        beq SerialDone
        ldx RxWrite
        txa
        clc
        adc #1
        and #$0F
        cmp RxRead
        beq SerialQueueFull
        sta RxNext
        ldx RxWrite
        lda RxByte
        sta RxQueue,x
        lda RxNext
        sta RxWrite
        lda #0
        sta RxReady
SerialDone:
        rts

SerialQueueFull:
        lda #0
        sta RxReady
        lda #$46
        sta BgColor
        rts

; Dequeue and apply at most one command. Direct commands update TIA and RAM
; shadows. Envelope/sample extensions retain this same dispatch point.
ServiceCommand:
        lda RxRead
        cmp RxWrite
        bne ServiceHasCommand
        rts
ServiceHasCommand:
        tax
        lda RxQueue,x
        sta RxCommand
        inx
        txa
        and #$0F
        sta RxRead

        lda RxCommand
        cmp #$E0
        bcs ServiceExtended
        bmi ServiceHighHalf
        and #$60
        beq ServiceVoice0Control
        cmp #$20
        beq ServiceVoice0Pitch
        cmp #$40
        beq ServiceVoice0Volume
        jmp ServiceVoice1Control

ServiceHighHalf:
        and #$60
        beq ServiceVoice1Pitch
        cmp #$20
        beq ServiceVoice1Volume
        cmp #$40
        beq ServiceSample
        jmp ServiceExtended

ServiceVoice0Volume:
        lda RxCommand
        and #$0F
        sta Voice0Target
        lda #1
        sta Voice0Counter
        rts

ServiceVoice0Control:
        lda RxCommand
        and #$0F
        sta Voice0Audc
        sta AUDC0
        jmp ServiceDirectActivity
ServiceVoice0Pitch:
        lda RxCommand
        and #$1F
        sta Voice0Audf
        sta AUDF0
        jmp ServiceDirectActivity

ServiceVoice1Control:
        lda RxCommand
        and #$0F
        sta Voice1Audc
        sta AUDC1
        jmp ServiceDirectActivity
ServiceVoice1Pitch:
        lda RxCommand
        and #$1F
        sta Voice1Audf
        sta AUDF1
        jmp ServiceDirectActivity
ServiceVoice1Volume:
        lda RxCommand
        and #$0F
        sta Voice1Target
        lda #1
        sta Voice1Counter
        rts

ServiceSample:
        ; Production F4 code replaces this marker with sample slot dispatch.
        lda #$C6
        sta BgColor
        rts

ServiceExtended:
        cmp #$F0
        bcs ServiceEnvelopeValueOrSystem
        cmp #$E4
        beq ServiceParserReset
        cmp #$E4
        bcs ServiceDone
        and #$03
        sta PendingEnv
        rts

ServiceEnvelopeValueOrSystem:
        ldx PendingEnv
        cpx #$FF
        beq ServiceSystem
        lda RxCommand
        and #$0F
        sta EnvelopeParams,x
        lda #$FF
        sta PendingEnv
        rts

ServiceSystem:
        lda RxCommand
        cmp #$F0
        beq ServiceSampleGateOff
        rts

ServiceParserReset:
        lda #8
        sta RxBits
        lda #0
        sta RxReady
        lda #$FF
        sta PendingEnv
        rts

ServiceSampleGateOff:
        lda #0
        sta Voice1Target
        lda #1
        sta Voice1Counter
        rts

ServiceDirectActivity:
        lda #$66
        sta BgColor
        rts

ServiceDone:
        rts

; Attack/release indices select ticks per 4-bit volume step. Index 0 snaps to
; the target. These routines are each bounded to one scanline including JSR.
UpdateEnvelope0:
        lda LocalActive
        bne Envelope0Done
        lda Voice0Current
        cmp Voice0Target
        beq Envelope0Done
        bcc Envelope0Attack

        ldx Voice0Release
        beq Envelope0Snap
        dec Voice0Counter
        bne Envelope0Done
        dec Voice0Current
        lda Voice0Current
        sta AUDV0
        lda EnvelopeRateTable,x
        sta Voice0Counter
Envelope0Done:
        rts

Envelope0Attack:
        ldx Voice0Attack
        beq Envelope0Snap
        dec Voice0Counter
        bne Envelope0Done
        inc Voice0Current
        lda Voice0Current
        sta AUDV0
        lda EnvelopeRateTable,x
        sta Voice0Counter
        rts
Envelope0Snap:
        lda Voice0Target
        sta Voice0Current
        sta AUDV0
        rts

UpdateEnvelope1:
        lda Voice1Current
        cmp Voice1Target
        beq Envelope1Done
        bcc Envelope1Attack

        ldx Voice1Release
        beq Envelope1Snap
        dec Voice1Counter
        bne Envelope1Done
        dec Voice1Current
        lda Voice1Current
        sta AUDV1
        lda EnvelopeRateTable,x
        sta Voice1Counter
Envelope1Done:
        rts

Envelope1Attack:
        ldx Voice1Attack
        beq Envelope1Snap
        dec Voice1Counter
        bne Envelope1Done
        inc Voice1Current
        lda Voice1Current
        sta AUDV1
        lda EnvelopeRateTable,x
        sta Voice1Counter
        rts
Envelope1Snap:
        lda Voice1Target
        sta Voice1Current
        sta AUDV1
        rts

TestFrequencies:
        .byte 4, 10, 18, 28

BankColors:
        .byte $26, $46, $66, $86, $C6

EnvelopeRateTable:
        .byte 1, 1, 2, 3, 4, 6, 8, 12
        .byte 16, 24, 32, 48, 64, 96, 128, 192

        ORG $FFFA
        .word Reset
        .word Reset
        .word Reset

        END

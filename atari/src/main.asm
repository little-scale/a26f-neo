        PROCESSOR 6502
        INCLUDE "vcs.inc"

        IFCONST VIDEO_NTSC
COMMAND_GROUPS = 4
VISIBLE_PAIRS  = 96
OVERSCAN_PAIRS = 15
RX_BAND_NORMAL_PAIRS = 5
        ELSE
COMMAND_GROUPS = 6
VISIBLE_PAIRS  = 114
OVERSCAN_PAIRS = 18
RX_BAND_NORMAL_PAIRS = 6
        ENDIF

; RIOT SWCHA direction-input map. DB9 pins 1, 2, 3, 4 are respectively
; up, down, left, right. Port 1 occupies bits 4..7 and port 2 bits 0..3.
PORT1_UP_MASK    = $10
PORT1_DOWN_MASK  = $20
PORT1_LEFT_MASK  = $40
PORT1_RIGHT_MASK = $80
PORT2_UP_MASK    = $01
PORT2_DOWN_MASK  = $02
PORT2_LEFT_MASK  = $04
PORT2_RIGHT_MASK = $08

PORT2_CLOCK_MASK = PORT2_UP_MASK
PORT2_DATA_MASK  = PORT2_DOWN_MASK

        IFCONST LINK_ULTRASLOW
; 200 * 1024 clocks is approximately 173 ms. Ultra-slow transitions are 100 ms
; apart and its inter-byte gap is 500 ms.
SERIAL_TIMER      = T1024T
SERIAL_IDLE_TICKS = 200
        ELSE
; 48 * 64 RIOT clocks is approximately 2.6 ms. Normal serial transitions are
; 1 ms apart; the Pico leaves a 5 ms inter-byte gap.
SERIAL_TIMER      = TIM64T
SERIAL_IDLE_TICKS = 48
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
VisualLastRxRead ds 1
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
EnvelopeParams ds 6
Voice0EnvPhase ds 1
Voice1EnvPhase ds 1
PendingEnv     ds 1
SampleBank     ds 1
SamplePtr      ds 2
SampleDirectoryIndex ds 1
PendingSampleSlot ds 1
SampleLoadStep ds 1
SampleActive   ds 1
SampleByte     ds 1
SamplePhase    ds 1
SampleLength   ds 2
SampleFlags    ds 1
SampleOutput   ds 1

Voice0Attack  = EnvelopeParams
Voice0Release = EnvelopeParams+1
Voice1Attack  = EnvelopeParams+2
Voice1Release = EnvelopeParams+3
Voice0EnvMode = EnvelopeParams+4
Voice1EnvMode = EnvelopeParams+5

        SEG CODE
        IFCONST F4_BUILD
        ORG $7000
        RORG $F000
        ELSE
        ORG $F000
        ENDIF

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

        IFCONST AUDIO_ONLY
        ; A fixed high-contrast playfield gives RF demodulators a stable video
        ; signal without performing any MIDI-driven visual work.
        lda #$84
        sta COLUBK
        lda #$0E
        sta COLUPF
        lda #1
        sta CTRLPF
        lda #$F0
        sta PF0
        lda #$81
        sta PF1
        lda #$FF
        sta PF2
        lda #0
        ENDIF

        ; All controller direction pins are inputs.
        sta SWACNT
        sta AUDV0
        sta AUDV1

        ; Useful audible defaults: pure-tone control and a low divider on both
        ; voices. MIDI CC1 can replace AUDC at any time; volume remains zero
        ; until a note or local sound-check gate opens it.
        lda #4
        sta Voice0Audc
        sta Voice1Audc
        sta AUDC0
        sta AUDC1
        sta Voice0Audf
        sta Voice1Audf
        sta AUDF0
        sta AUDF1
        lda #$FF
        sta DirectionIndex
        sta PrevDirection
        sta PendingEnv
        sta SamplePhase
        lda #1
        sta Voice0Release
        sta Voice1Release
        sta Voice0Counter
        sta Voice1Counter
        lda #8
        sta RxBits
        lda #SERIAL_IDLE_TICKS
        sta SERIAL_TIMER
        lda #$26
        sta ActiveColor
        lda SWCHA
        and #PORT2_CLOCK_MASK
        sta LastClock

Frame:
        ; Blank the display and keep joystick fire latching disabled.
        lda #2
        sta VBLANK
        sta VSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        lda #0
        sta VSYNC

        ; Every second scanline is a sample tick. Alternating lines poll the
        ; serial receiver or perform one bounded foreground task.
        IFCONST AUDIO_ONLY
        ; The audio-only diagnostic ignores controller port 1 completely so
        ; any joystick-correlated picture movement must be outside the ROM.
        lda #0
        ELSE
        jsr PollDirectionInput
        ENDIF
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr ApplySoundcheck
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        IFCONST AUDIO_ONLY
        lda #0
        ELSE
        jsr PollFire
        ENDIF
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC

        jsr UpdateEnvelope0
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr UpdateEnvelope1
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC

        lda #COMMAND_GROUPS
        sta LineCounter
CommandServiceLoop:
        jsr ServiceCommand
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        jsr SampleTick
        sta WSYNC
        dec LineCounter
        bne CommandServiceLoop
        IFCONST AUDIO_ONLY
        ; Diagnostic target: preserve the complete audio/receiver workload but
        ; remove the variable visualiser path.
        lda #$84
        sta BgColor
        ELSE
        IFCONST RX_VISUALIZER
        ; The receive ring doubles as a 16-entry visual history. Dequeued bytes
        ; remain in their slots until that position is reused by a later byte.
        lda #0
        sta VisualLastRxRead
        lda RxQueue
        ; Force the lowest visible luminance bit on. Raw values whose TIA
        ; luminance is zero would otherwise produce black history bands.
        ora #$02
        sta BgColor
        lda #RX_BAND_NORMAL_PAIRS
        sta LineCounter
        ELSE
        jsr UpdateVisual
        ENDIF
        ENDIF
        sta WSYNC

        ; Visible area: an activity colour, or a fixed RF-friendly image in
        ; audio-only builds.
        lda #0
        sta VBLANK
        IFCONST AUDIO_ONLY
        lda #$84
        ELSE
        IFCONST RX_VISUALIZER
        lda BgColor
        ELSE
        lda BgColor
        ENDIF
        ENDIF
        sta COLUBK
        IFCONST RX_VISUALIZER
VisibleRxNormalLoop:
        ; All but the final pair in a band retain normal sample/poll service.
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne VisibleRxNormalLoop

        ; The final pair retains its sample tick and uses the poll line to load
        ; the next receive-ring colour. Skipping sixteen visible-area polls per
        ; frame leaves ample polling elsewhere while keeping every scanline
        ; and every PCM tick in place.
        jsr SampleTick
        sta WSYNC
        inc VisualLastRxRead
        lda VisualLastRxRead
        cmp #16
        bcs VisibleRxBandsDone
        tax
        lda RxQueue,x
        ; Keep every receive-history band visible, including $x0/$x1 bytes.
        ; This fixed-time transform avoids adding data-dependent scanline
        ; timing at the band boundary.
        ora #$02
        sta COLUBK
        lda #RX_BAND_NORMAL_PAIRS
        sta LineCounter
        sta WSYNC
        jmp VisibleRxNormalLoop

VisibleRxBandsDone:
        ; Complete the final band's colour line. PAL has two remaining pairs
        ; after 16 x 14-line bands; NTSC divides exactly into 16 x 12 lines.
        sta WSYNC
        IFNCONST VIDEO_NTSC
        lda #2
        sta LineCounter
VisibleRxPalRemainder:
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne VisibleRxPalRemainder
        ENDIF
        ELSE
        lda #VISIBLE_PAIRS
        sta LineCounter
VisibleLoop:
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne VisibleLoop
        ENDIF

        ; Overscan retains the same sample/poll alternation.
        lda #2
        sta VBLANK
        lda #OVERSCAN_PAIRS
        sta LineCounter
OverscanLoop:
        jsr SampleTick
        sta WSYNC
        jsr PollSerial
        sta WSYNC
        dec LineCounter
        bne OverscanLoop

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
        and #PORT1_UP_MASK
        beq SelectUp
        txa
        and #PORT1_RIGHT_MASK
        beq SelectRight
        txa
        and #PORT1_DOWN_MASK
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
        IFNCONST F4_BUILD
        sta AUDV1
        ELSE
        lda SoundBank
        cmp #4
        bne DirectionInputDone
        lda SampleFlags
        and #1
        beq DirectionInputDone
        jsr BeginSampleGateOff
        ENDIF
DirectionInputDone:
        rts

; Banks 0-3 cover AUDC values 0-15. The four directions deliberately span the
; AUDF range. Bank 4 is reserved for sample slots 0-3 in the production F4 ROM.
ApplySoundcheck:
        ldy DirectionIndex
        bpl ApplyLocalSoundcheck

        lda Voice0Audc
        sta AUDC0
        lda Voice0Audf
        sta AUDF0
        lda SampleActive
        bne SoundcheckDone
        lda Voice1Audc
        sta AUDC1
        lda Voice1Audf
        sta AUDF1
        rts

ApplyLocalSoundcheck:

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
        IFCONST F4_BUILD
        sty PendingSampleSlot
        lda #1
        sta SampleLoadStep
        ENDIF
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

; Controller port 2 uses DB9 pin 1 / SWCHA bit 0 as clock and DB9 pin 2 /
; SWCHA bit 1 as data. Every clock
; transition shifts one MSB-first bit. Completed bytes are moved to the ring on
; a later no-edge poll so both paths stay bounded to one scanline.
PollSerial:
        lda SWCHA
        sta PortSnapshot
        and #PORT2_CLOCK_MASK
        cmp LastClock
        beq SerialNoEdge

        sta LastClock
        lda #SERIAL_IDLE_TICKS
        sta SERIAL_TIMER
        lda RxByte
        asl
        sta RxByte
        lda PortSnapshot
        and #PORT2_DATA_MASK
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
        beq SerialCheckIdle
        ldx RxWrite
        txa
        clc
        adc #1
        and #$0F
        cmp RxRead
        beq SerialQueueFull
        tay
        lda RxByte
        sta RxQueue,x
        sty RxWrite
        lda #0
        sta RxReady
        ; This path returns with enough margin before the caller's WSYNC.
        ; Do not also perform idle maintenance here or MIDI traffic adds an
        ; unwanted scanline and produces visible tearing.
        rts
SerialCheckIdle:
        ; A long no-edge interval is a byte boundary. Complete bytes have
        ; already been queued above; only partial shift state is discarded.
        ; PendingEnv deliberately survives so a two-byte envelope command can
        ; span the normal inter-byte gap.
        bit TIMINT
        bpl SerialDone
        lda #8
        sta RxBits
        lda #0
        sta RxByte
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
        IFCONST F4_BUILD
        lda SampleLoadStep
        beq ServiceQueuedCommand
        cmp #1
        bne ServiceLoadLater
        jmp ServiceSampleLoad1
ServiceLoadLater:
        cmp #2
        bne ServiceLoadThird
        jmp ServiceSampleLoad2
ServiceLoadThird:
        jmp ServiceSampleLoad3
        ENDIF

ServiceQueuedCommand:
        ldx RxRead
        cpx RxWrite
        bne ServiceHasCommand
        rts
ServiceHasCommand:
        lda RxQueue,x
        sta RxCommand
        inx
        txa
        and #$0F
        sta RxRead

        lda RxCommand
        bmi ServiceCommandHigh
        cmp #$40
        bcc ServiceVoice0Low
        cmp #$60
        bcc ServiceVoice0Volume
        jmp ServiceVoice1Control

ServiceVoice0Low:
        cmp #$20
        bcc ServiceVoice0Control
        jmp ServiceVoice0Pitch

ServiceCommandHigh:
        cmp #$C0
        bcc ServiceVoice1High
        cmp #$E0
        bcc ServiceSample
        jmp ServiceExtended

ServiceVoice1High:
        cmp #$A0
        bcs ServiceVoice1Volume
        jmp ServiceVoice1Pitch

ServiceVoice0Volume:
        lda RxCommand
        and #$0F
        sta Voice0Target
        beq ServiceVoice0ReleaseGate
        ldx Voice0EnvMode
        stx Voice0EnvPhase
        jmp ServiceVoice0GateCounter
ServiceVoice0ReleaseGate:
        sta Voice0EnvPhase
ServiceVoice0GateCounter:
        lda #1
        sta Voice0Counter
        rts

ServiceVoice0Control:
        lda RxCommand
        and #$0F
        sta Voice0Audc
        rts
ServiceVoice0Pitch:
        lda RxCommand
        and #$1F
        sta Voice0Audf
        rts

ServiceVoice1Control:
        lda RxCommand
        and #$0F
        sta Voice1Audc
        rts
ServiceVoice1Pitch:
        lda RxCommand
        and #$1F
        sta Voice1Audf
        rts
ServiceVoice1Volume:
        lda RxCommand
        and #$0F
        sta Voice1Target
        beq ServiceVoice1ReleaseGate
        ldx Voice1EnvMode
        stx Voice1EnvPhase
        jmp ServiceVoice1GateCounter
ServiceVoice1ReleaseGate:
        sta Voice1EnvPhase
ServiceVoice1GateCounter:
        lda #1
        sta Voice1Counter
        rts

ServiceSample:
        IFCONST F4_BUILD
        lda RxCommand
        and #$1F
        sta PendingSampleSlot
        lda #1
        sta SampleLoadStep
        ELSE
        lda #$C6
        sta BgColor
        ENDIF
        rts

ServiceExtended:
        cmp #$F0
        bcs ServiceEnvelopeValueOrSystem
        cmp #$E4
        beq ServiceParserReset
        cmp #$E4
        bcc ServiceEnvelopeSelect
        cmp #$E7
        bcc ServiceEnvelopeModeSelect
        rts
ServiceEnvelopeModeSelect:
        sec
        sbc #1
        jmp ServiceEnvelopeSelect
ServiceEnvelopeSelect:
        and #$07
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
        IFCONST F4_BUILD
        lda SampleActive
        beq ServiceDone
        lda SampleFlags
        and #1
        beq ServiceDone
        jsr BeginSampleGateOff
        ELSE
        lda #0
        sta Voice1Target
        lda #1
        sta Voice1Counter
        ENDIF
        rts

        IFCONST F4_BUILD
ServiceSampleLoad1:
        lda PendingSampleSlot
        asl
        asl
        asl
        tax
        lda SampleDirectory,x
        sta SampleBank
        inx
        lda SampleDirectory,x
        sta SamplePtr
        inx
        lda SampleDirectory,x
        sta SamplePtr+1
        inx
        stx SampleDirectoryIndex
        lda #2
        sta SampleLoadStep
        rts

ServiceSampleLoad2:
        ldx SampleDirectoryIndex
        lda SampleDirectory,x
        sta SampleLength
        inx
        lda SampleDirectory,x
        sta SampleLength+1
        inx
        stx SampleDirectoryIndex
        lda #3
        sta SampleLoadStep
        rts

ServiceSampleLoad3:
        ldx SampleDirectoryIndex
        lda SampleDirectory,x
        sta SampleFlags
        lda SampleBank
        cmp #$FF
        beq ServiceSampleEmpty
        lda SampleLength
        ora SampleLength+1
        beq ServiceSampleEmpty
        lda #1
        sta SampleActive
        lda #0
        sta SamplePhase
        sta SampleLoadStep
        sta AUDC1
        rts
ServiceSampleEmpty:
        lda SampleOutput
        ora #$80
        sta SamplePhase
        lda #0
        sta SampleLoadStep
        rts
        ENDIF

ServiceDone:
        rts

; SamplePhase keeps the hot path compact enough for one scanline:
; $00 fetch/high nibble, $01 low nibble, $80-$8F release ramp, $FF idle.
SampleTick:
        IFCONST F4_BUILD
        lda SamplePhase
        bmi SampleTickNegative
        beq SampleTickHigh

SampleTickLow:
        lda SampleByte
        and #$0F
        sta SampleOutput
        sta AUDV1
        lda #0
        sta SamplePhase
        sec
        lda SampleLength
        sbc #1
        sta SampleLength
        lda SampleLength+1
        sbc #0
        sta SampleLength+1
        ora SampleLength
        beq SampleTickLastByte
        inc SamplePtr
        bne SampleTickDone
        inc SamplePtr+1
        rts
SampleTickLastByte:
        lda SampleOutput
        ora #$80
        sta SamplePhase
SampleTickDone:
        rts

SampleTickHigh:
        ldy #0
        jsr FetchSampleByte
        sta SampleByte
        lsr
        lsr
        lsr
        lsr
        sta SampleOutput
        sta AUDV1
        inc SamplePhase
        rts

SampleTickNegative:
        cmp #$FF
        beq SampleTickDone
        and #$0F
        beq SampleTickFinish
        sec
        sbc #1
        sta SampleOutput
        ora #$80
        sta SamplePhase
        lda SampleOutput
        sta AUDV1
        rts

SampleTickFinish:
        lda #$FF
        sta SamplePhase
        lda #0
        sta SampleActive
        sta SampleOutput
        lda Voice1Audc
        sta AUDC1
        lda Voice1Audf
        sta AUDF1
        lda Voice1Current
        sta AUDV1
        rts
        ELSE
        rts
        ENDIF

        IFCONST F4_BUILD
BeginSampleGateOff:
        lda SamplePhase
        bmi BeginSampleGateDone
        lda SampleOutput
        ora #$80
        sta SamplePhase
BeginSampleGateDone:
        rts
        ENDIF

; Select one stable background colour per frame. Samples choose hue by slot.
; Synth voices use distinct hues, with a third hue when both are active. Audio
; amplitudes may change luminance, but voices never alternate frame-by-frame.
UpdateVisual:
        lda SampleActive
        beq VisualNoSample
        ldx PendingSampleSlot
        lda SampleHueTable,x
        ora #$0C
        sta BgColor
        rts

VisualNoSample:
        lda LocalActive
        beq VisualSynth
        ldx SoundBank
        lda BankColors,x
        sta BgColor
        rts

VisualSynth:
        lda Voice0Current
        ora Voice1Current
        beq VisualActivity
        lda Voice0Current
        beq VisualVoice1
        lda Voice1Current
        beq VisualVoice0
        ora Voice0Current
        and #$0E
        ora #$70
        sta BgColor
        rts
VisualVoice0:
        lda #$30
        sta BgColor
        lda Voice0Current
        bne VisualApplyLuma
VisualVoice1:
        lda #$A0
        sta BgColor
        lda Voice1Current
VisualApplyLuma:
        and #$0E
        ora BgColor
        sta BgColor
        rts

VisualActivity:
        lda RxRead
        cmp VisualLastRxRead
        beq VisualActivityTimer
        sta VisualLastRxRead
        lda #4
        sta ActivityTimer
        lda RxCommand
        and #$E0
        ora #$06
        sta ActiveColor
VisualActivityTimer:
        lda ActivityTimer
        beq VisualIdle
        dec ActivityTimer
        lda ActiveColor
        sta BgColor
        rts
VisualIdle:
        lda #0
        sta BgColor
        rts

; Attack and release/decay indices select ticks per 4-bit volume step. Index 0
; snaps to the target. In attack-decay mode, reaching a nonzero target changes
; the target to zero once; MIDI note-off is filtered by the Pico. These
; routines are each bounded to one scanline including JSR.
UpdateEnvelope0:
        lda LocalActive
        bne Envelope0Done
        lda Voice0Current
        cmp Voice0Target
        bne Envelope0Moving
        lda Voice0EnvPhase
        beq Envelope0Done
        lda #0
        sta Voice0EnvPhase
        sta Voice0Target
        ldx Voice0Release
        beq Envelope0Snap
        jmp Envelope0DecayStep
Envelope0Moving:
        lda Voice0Current
        cmp Voice0Target
        bcc Envelope0Attack

        ldx Voice0Release
        beq Envelope0Snap
        dec Voice0Counter
        bne Envelope0Done
Envelope0DecayStep:
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
        bne Envelope1Moving
        lda Voice1EnvPhase
        beq Envelope1Done
        lda #0
        sta Voice1EnvPhase
        sta Voice1Target
        ldx Voice1Release
        beq Envelope1Snap
        jmp Envelope1DecayStep
Envelope1Moving:
        lda Voice1Current
        cmp Voice1Target
        bcc Envelope1Attack

        ldx Voice1Release
        beq Envelope1Snap
        dec Voice1Counter
        bne Envelope1Done
Envelope1DecayStep:
        dec Voice1Current
        lda Voice1Current
        ldy SampleActive
        bne Envelope1ReleaseStored
        sta AUDV1
Envelope1ReleaseStored:
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
        ldy SampleActive
        bne Envelope1AttackStored
        sta AUDV1
Envelope1AttackStored:
        lda EnvelopeRateTable,x
        sta Voice1Counter
        rts
Envelope1Snap:
        lda Voice1Target
        sta Voice1Current
        ldy SampleActive
        bne Envelope1Done
        sta AUDV1
        rts

TestFrequencies:
        .byte 4, 10, 18, 28

BankColors:
        .byte $26, $46, $66, $86, $C6

SampleHueTable:
        .byte $20, $40, $60, $80, $A0, $C0, $E0, $30
        .byte $50, $70, $90, $B0, $D0, $F0, $10, $60
        .byte $A0, $E0, $40, $80, $C0, $20, $70, $B0
        .byte $F0, $50, $90, $D0, $30, $60, $A0, $E0

EnvelopeRateTable:
        .byte 1, 1, 2, 3, 4, 6, 8, 12
        .byte 16, 24, 32, 48, 64, 96, 128, 192

        IFCONST F4_BUILD
        ; 32 entries x 8 bytes: bank, address, packed length, flags, reserved.
        ORG $7D00
        RORG $FD00
SampleDirectory:
        REPEAT 32
        .byte $FF, 0, 0, 0, 0, 1, 0, 0
        REPEND

        ; Versioned browser-patch manifest at raw ROM offset $7E00.
        ORG $7E00
        RORG $FE00
PatchManifest:
        .byte "A26FSMP", 0
        .byte 1, 1
        IFCONST VIDEO_NTSC
        .byte 1
        ELSE
        .byte 0
        ENDIF
        .byte 4, 8, 32, 1, 1
        IFCONST VIDEO_NTSC
        .byte $FC, $0A, $78, $00     ; 7,867,132 millihertz
        ELSE
        .byte $94, $35, $77, $00     ; 7,812,500 millihertz
        ENDIF
        .byte $00, $80, $00, $00     ; 32768-byte ROM
        .byte $00, $7D, $00, $00     ; directory file offset
        .byte $00, $01, $00, $00     ; directory length
        .byte 7, 8, 0, 0
        .word $0000, $0F00
        .word $1000, $0F00
        .word $2000, $0F00
        .word $3000, $0F00
        .word $4000, $0F00
        .word $5000, $0F00
        .word $6000, $0F00
        ds 64, 0

        ORG $7F00
        RORG $FF00
        INCLUDE "f4_stub.inc"

        ORG $7FFA
        RORG $FFFA
        .word F4Reset, F4Reset, F4Reset
        ELSE
        ORG $FFFA
        .word Reset
        .word Reset
        .word Reset
        ENDIF

        END

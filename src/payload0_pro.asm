; AP-07 Pro-specific Payload-0 visual candidate, not tested.
; Source-level candidate; assemble/validate before any functional claim.
; Based on AS2K Payload-0 flow, but ONLY Pro's driver-derived LCD wiring.
PORTA       EQU $0000
PORTD       EQU $0008
DDRD        EQU $0009
HPRIO       EQU $003C
PACTL       EQU $0026
LCDMODE     EQU $8000

        ORG $0040
PAYLOAD0_ENTRY:
        SEI
        LDS #$00E0
        BSET HPRIO,#$20
        ; D0 reset configures PA7 as input. Enable DDR PA7 via PACTL.
        BSET PACTL,#$80
        ; Preserve unrelated PORTA bits, force LCD0 strobe low.
        BCLR PORTA,#$80
        ; PD5..PD2 output, PD1..PD0 remain SCI.
        LDAA #$3C
        STAA DDRD
        ; LCD instruction, read/write low.
        LDAA #$00
        STAA LCDMODE
        LDAA #$03
        BSR LCD_NIBBLE
        BSR DELAY_LONG
        LDAA #$03
        BSR LCD_NIBBLE
        LDAA #$03
        BSR LCD_NIBBLE
        LDAA #$02
        BSR LCD_NIBBLE
        LDAA #$28
        BSR LCD_BYTE
        LDAA #$01
        BSR LCD_BYTE
        BSR DELAY_LONG
        LDAA #$06
        BSR LCD_BYTE
        LDAA #$0C
        BSR LCD_BYTE
        ; LCD RS=data, RW=write.
        LDAA #$02
        STAA LCDMODE
        LDX #MESSAGE
MSG_LOOP:
        LDAA 0,X
        BEQ PAYLOAD0_HOLD
        BSR LCD_BYTE
        INX
        BRA MSG_LOOP
PAYLOAD0_HOLD:
        BRA PAYLOAD0_HOLD

LCD_BYTE:
        TAB
        LSRA
        LSRA
        LSRA
        LSRA
        BSR LCD_NIBBLE
        TBA
        ANDA #$0F
        BSR LCD_NIBBLE
        RTS
LCD_NIBBLE:
        ASLA
        ASLA
        STAA PORTD
        BSET PORTA,#$80
        BCLR PORTA,#$80
        LDAA #$60
LCD_NIBBLE_DELAY:
        DECA
        BNE LCD_NIBBLE_DELAY
        RTS
DELAY_LONG:
        LDX #$0800
DELAY_LONG_LOOP:
        DEX
        BNE DELAY_LONG_LOOP
        RTS
MESSAGE:
        FCB $42,$4F,$4F,$54,$20,$4F,$4B,$00
PAYLOAD0_END:

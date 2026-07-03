#define __ASSEMBLER__ 1
#define __SFR_OFFSET 0
#include <avr/io.h>

.data
.equ RTCAddr, (0x68 << 1) 
.equ LCDAddr,  (0x27 << 1)
.equ clockSpeed, 16000000UL
Interrupt: .byte 0
LCDBytes: .byte 0,0,0,0
.section .progmem.data
String: .asciz  "Hello, world"

.text
.global main
main:
    ldi r16, (1 << DDB0)
    out DDRB, r16 
    ldi r16, (0 << PB0)
    out PORTB, r16
    cli
    sts EICRA, 0b00000000	; set INT0 to trigger on a logic level 0
    sbi EIMSK, INT0 ; Enable INT0
    sei
    ; I2C Init
    lds r16, TWSR
    andi r16, 0b11111000
    sts TWSR, r16
    ldi r16, 72
    sts TWBR, r16    
    ; LCD Init
    rcall LCD_Init
    ldi r17, 20
    rcall Delay_ms
    rcall LCD_Clear
    ; Move Cursor 
    ldi r18, 0
    ldi r20, 0
    rcall Set_Cursor
    ldi r17, 10
    rcall Delay_ms
    ; Write Data
    rcall LCD_Write_String
    Loop:
        lds r16, Interrupt
        cpi r16, 1
        brne Loop 
        logTime:
            ldi r16, 0
            sts Interrupt, r16 ; reset intterupt flag to 0
        rjmp Loop

I2C_Write:
    push r16
    push r17
    push r26
    push r27

    ldi r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN) ; Send start condition 
    sts TWCR, r16

    wait1: 
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set 
        rjmp wait1 

    lds r16, TWSR
    andi r16, 0xF8 ; Check if START was transmitted, status code should be 0x08
    cpi r16, 0x08 
    brne Error

    ldi r16, LCDAddr 
    sts TWDR, r16 ; Write SLA, from r17 into TWDR
    ldi r16, (1 << TWINT) | (1 << TWEN) 
    sts TWCR, r16 ; Transmit SLA+W

    wait2:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait2

    lds r16, TWSR
    andi r16, 0xF8 ; Check if SLA+W was received, status code should be 0x18
    cpi r16, 0x18
    brne Error
    
    ldi r26, lo8(LCDBytes)
    ldi r27, hi8(LCDBytes)
    ldi r17, 4
    loop:
    
    ld r16, X+
    sts TWDR, r16 ; Write data into TWDR
    ldi r16, (1 << TWINT) | (1 << TWEN) 
    sts TWCR, r16 ; Transmit data

    wait3:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait3

    lds r16, TWSR
    andi r16, 0xF8 ; Check if data was received, status code should be 0x28
    cpi r16, 0x28
    brne Error
    dec r17
    brne loop 

    ldi r16, (1 << TWINT) | (1 << TWEN) | (1 << TWSTO)
    sts TWCR, r16 ; Transmit stop

    wait4:
        lds r16, TWCR 
        sbrc r16, TWSTO
        rjmp wait4

    pop r27
    pop r26
    pop r17
    pop r16
    ret

Error:    
    ldi r16, (1 << PB0)
    out PORTB, r16
    rjmp Error

Write_Command_LCD:
    push r16
    push r17
    push r18
    push r19
    mov r19, r18 ; holds lower 
    mov r17, r18 ; holds upper
    ; Get lower nibble 
    lsl r19
    lsl r19
    lsl r19
    lsl r19
    andi r19, 0xF0
    ; Get upper nibble
    andi r17, 0xF0
    mov r16, r17
    ori r17, 0x0C
    sts LCDBytes, r17 
    ori r16, 0x08
    sts LCDBytes+1, r16
    mov r16, r19
    ori r19, 0x0C
    sts LCDBytes+2, r19
    ori r16, 0x08
    sts LCDBytes+3, r16
    rcall I2C_Write
    pop r19
    pop r18
    pop r17
    pop r16
    ret
    
Write_Data_LCD: 
    push r16
    push r17
    push r18
    push r19
    mov r19, r18 ; holds lower 
    mov r17, r18 ; holds upper
    ; Get lower nibble 
    lsl r19
    lsl r19
    lsl r19
    lsl r19
    andi r19, 0xF0
    ; Get upper nibble
    andi r17, 0xF0
    mov r16, r17
    ori r17, 0x0D
    sts LCDBytes, r17 
    ori r16, 0x09
    sts LCDBytes+1, r16
    mov r16, r19
    ori r19, 0x0D
    sts LCDBytes+2, r19
    ori r16, 0x09
    sts LCDBytes+3, r16
    rcall I2C_Write
    pop r19
    pop r18
    pop r17
    pop r16
    ret

Set_Cursor:
    push r20 ; row
    push r18 ; col
    cpi r20, 0
    brne neq
    ldi r18, 0x80
    rjmp end
    neq:
        ori r18, 0xC0
    end:
        rcall Write_Command_LCD 
        pop r18
        pop r20
        ret

LCD_Write_String:
    push r18
    push r16
    push r26
    push r27
    ldi r30, lo8(String)
    ldi r31, hi8(String)
    loop1:
        lpm r16, Z+
        cpi r16, 0
        breq end1
        mov r18, r16
        rcall Write_Data_LCD
        rjmp loop1
    end1:
    pop r27
    pop r26
    pop r16
    pop r18
    ret

LCD_Init:
    push r17
    push r18
    ldi r17, 16
    rcall Delay_ms
    ldi r18, 0x30
    rcall Write_Command_LCD 
    ldi r17, 5
    rcall Delay_ms
    ldi r18, 0x30
    rcall Write_Command_LCD 
    ldi r17, 1
    rcall Delay_ms
    ldi r18, 0x30
    rcall Write_Command_LCD 
    ldi r17, 10
    rcall Delay_ms
    ldi r18, 0x20
    rcall Write_Command_LCD 
    ldi r17, 10
    rcall Delay_ms
    ldi r18, 0x28
    rcall Write_Command_LCD 
    ldi r17, 1
    rcall Delay_ms
    ldi r18, 0x08
    rcall Write_Command_LCD 
    ldi r17, 1
    rcall Delay_ms
    ldi r18, 0x01
    rcall Write_Command_LCD 
    ldi r17, 2
    rcall Delay_ms
    ldi r18, 0x06
    rcall Write_Command_LCD 
    ldi r17, 1
    rcall Delay_ms
    ldi r18, 0x0C
    rcall Write_Command_LCD 
    ldi r17, 1
    rcall Delay_ms
    pop r18
    pop r17
    ret

LCD_Clear:
    push r18
    push r17
    ldi r18, 0x01
    rcall Write_Command_LCD
    ldi r17, 2
    rcall Delay_ms
    ldi r18, 0x0C
    rcall Write_Command_LCD
    ldi r17, 1
    rcall Delay_ms
    ldi r17, 200
    rcall Delay_ms
    pop r17
    pop r18
    ret

Delay_ms:
    push r18
    push r19
    push r17

    Delay_ms_outer:
        ldi r18, 21

    Delay_ms_mid:
        ldi r19, 250

    Delay_ms_inner:
        dec r19
        brne Delay_ms_inner

        dec r18
        brne Delay_ms_mid

        dec r17
        brne Delay_ms_outer

        pop r17
        pop r19
        pop r18
    ret

.global INT0_vect
INT0_vect:
    push r16
    push r17
    push r0
    in r0, SREG
    push r0
    ldi r16, 1  ; set intterupt flag
    sts Interrupt, r16
    ldi r17, 70
    rcall Delay_ms
    pop r17
    pop r16
    pop r0
    out SREG, r0
    pop r0
    reti

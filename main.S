#define __ASSEMBLER__ 1
#define __SFR_OFFSET 0
#include <avr/io.h>

.data
.equ RTCAddr, (0x68 << 1) 
.equ LCDAddr,  (0x27 << 1)
.equ clockSpeed, 1000000UL
LEDState: .byte 1

.text
.global main
main:
    ldi r16, (1 << DDB0) | (1 << DDB0) | ( 1 << DDB0)
    out DDRB, r16 
    ldi r16, (0 << PB0)
    out PORTB, r16
    cli
    sts EICRA, 0b00001100	; set INT0 to trigger on a logic level 0
    sbi EIMSK, INT0 ; Enable INT0
    sei
    ; I2C Init
    sts TWSR, 0
    ldi r16, (clockSpeed/100000 - 16) / 2 * 1
    sts TWBR, r16    
    ; LCD Init
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
    ; Clear LCD
    ldi r16, 0x01
    rcall Write_Command_LCD
    ldi r17, 2
    rcall Delay_ms
    ldi r16, 0x0C
    rcall Write_Command_LCD
    ldi r17, 1
    rcall Delay_ms
    ldi r17, 200
    rcall Delay_ms
    ; write data
    ldi r18, 'a'
    rcall Write_Data_LCD
Loop:
    rjmp Loop

I2C_Write:
    push r16
    push r18
    ldi r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN) ; Send start condition 
    sts TWCR, r16

    wait1: 
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set 
        rjmp wait1 

    lds r16, TWSR
    andi r16, 0xF8 ; Check if START was transmitted, status code should be 0x08
    cpi r16, 0x08 
    brne Error1

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
    brne Error2

    mov r16, r18 
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
    brne Error3

    ldi r16, (1 << TWINT) | (1 << TWEN) | (1 << TWSTO)
    sts TWCR, r16 ; Transmit stop

    wait4:
        lds r16, TWCR 
        sbrc r16, TWSTO
        rjmp wait4

    pop r18 
    pop r16
    ret

Error1:    
    ldi r16, (1 << PB0)
    out PORTB, r16
    rjmp Error1
Error2:    
    ldi r16, (1 << PB1)
    out PORTB, r16
    rjmp Error2
Error3:    
    ldi r16, (1 << PB2)
    out PORTB, r16
    rjmp Error3

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
    mov r16, r17
    ori r17, 0x0C
    mov r18, r17 
    rcall I2C_Write
    ori r16, 0x08
    mov r18, r16 
    rcall I2C_Write
    mov r16, r19
    ori r19, 0x0C
    mov r18, r19 
    rcall I2C_Write
    ori r16, 0x08
    mov r18, r16 
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
    mov r16, r17
    ori r17, 0x0D
    mov r18, r17 
    rcall I2C_Write
    ori r16, 0x09
    mov r18, r16 
    rcall I2C_Write
    mov r16, r19
    ori r19, 0x0D
    mov r18, r19 
    rcall I2C_Write
    ori r16, 0x09
    mov r18, r16 
    rcall I2C_Write
    pop r19
    pop r18
    pop r17
    pop r16
    ret

Delay_ms:
    push r24
    push r17
    ms_loop:
        ldi r24, 250

    inner_loop:
        dec r24
        brne inner_loop

        dec r17
        brne ms_loop
    pop r17
    pop r24
    ret

.global INT0_vect
INT0_vect:
    push r16
    in r0, SREG
    push r0
    push r17
    ldi r17, (1 << PB0)
    lds r16, LEDState
    eor r16, r17 ; toggle LED
    sts LEDState, r16
    out PORTB, r16
    pop r17
    pop r0
    pop r16
    out SREG, r0
    reti

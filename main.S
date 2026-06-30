#define __ASSEMBLER__ 1
#define __SFR_OFFSET 0
#include <avr/io.h>

.data
LEDState = 0  
RTCAddr = (0x68 << 1) 
LCDAddr =  (0x27 << 1)
LCDData = 0
LCDCommand = 0
I2CData = 0
Delay = 0
clockSpeed = 100000UL

.text
.global main
main:
    ldi r16, (1 << DDB0)
    out DDRB, r16 
    ldi r16, (0 << PB0)
    out PORTB, r16
    cli
    sts EICRA, 0b00001100	; set INT0 to trigger on a logic level 0
    sbi EIMSK, INT0 ; Enable INT0
    sei
    ; LCD Init
    ldi r17, 16
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x30
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 5
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x30
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 1
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x30
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 10
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x20
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 10
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x28
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 1
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x08
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 1
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x01
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 2
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x06
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 1
    sts Delay, r17
    rcall Delay_ms
    ldi r16, 0x0C
    sts LCDCommand, r16
    rcall Write_Command_LCD 
    ldi r17, 1
    sts Delay, r17
    rcall Delay_ms
    ldi r17, 'a'
    sts LCDData, r17
    rcall Write_Data_LCD
Loop:
    rjmp Loop

Delay_ms:
    sts Delay, Delay * 1000
    loop:
        dec (Delay)
        brne loop
    ret

I2C_Write:
    push r16
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

    ldi r16, I2CData 
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

    ldi r16, (1 << TWINT) | (1 << TWEN) | (1 << TWSTO)
    sts TWCR, r16 ; Transmit stop
    
    pop r16
    ret

I2C_Read:
    ret

Error:
    nop
    rjmp Error

Write_Command_LCD:
    push r16
    push r17
    ldi r16, (LCDCommand << 4) & 0xF0 ; Get lower nibble  
    ldi r17, LCDCommand  & 0xF0 ; Get upper nibble  
    ori r17, 0x0C
    sts I2CData, r17 
    rcall I2C_Write
    ori r17, 0x08
    sts I2CData, r17 
    rcall I2C_Write
    ori r16, 0x0C
    sts I2CData, r16 
    rcall I2C_Write
    ori r16, 0x0C
    sts I2CData, r16 
    rcall I2C_Write
    pop r17
    pop r16
    ret
    
Write_Data_LCD: 
    push r16
    push r17
    ldi r16, (LCDData << 4) & 0xF0 ; Get lower nibble  
    ldi r17, LCDData  & 0xF0 ; Get upper nibble  
    ori r17, 0x0D
    sts LCDData, r17
    rcall I2C_Write
    ori r17, 0x09
    sts I2CData, r17
    rcall I2C_Write
    ori r16, 0x0D
    sts I2CData, r16
    rcall I2C_Write
    ori r16, 0x09
    sts I2CData, r16
    rcall I2C_Write
    pop r17
    pop r16
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

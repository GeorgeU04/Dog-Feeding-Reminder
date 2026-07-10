#define __ASSEMBLER__ 1
#define __SFR_OFFSET 0
#include <avr/io.h>

.data
.equ RTCAddr, (0x68 << 1) 
.equ LCDAddr,  (0x27 << 1)
.equ clockSpeed, 16000000UL
Interrupt: .byte 0
LCDBytes: .byte 0,0,0,0
Minutes: .byte 0 
Hours: .byte 0
.section .progmem.data
String: .asciz  "Fed: "

.text
.global main
main:
    cli
    ldi r30, 1
    ldi r16, (1 << DDB0)
    out DDRB, r16 
    ldi r16, (0 << PB0)
    out PORTB, r16
    cbi DDRD, DDD2
    sbi PORTD, PD2		; INT0 pull-up so pin is not floating at power-on
    sts EICRA, 0b00000010	; INT0 falling edge (not level-low)
    ; I2C Init
    lds r16, TWSR
    andi r16, 0b11111000
    sts TWSR, r16
    ldi r16, 72
    sts TWBR, r16
    ldi r17, 50
    rcall Delay_ms		; let LCD/RTC stabilize after power-on
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
    ldi r16, 0
    sts Interrupt, r16	; clear any spurious flag before enabling INT0
    sbi EIMSK, INT0
    sei
    ; Write Data
    Loop:
        lds r16, Interrupt
        cpi r16, 1
        brne Loop 
        logTime:
            rcall Set_Cursor
            rcall LCD_Write_String
            rcall DS3231_Read
            lds r29, Hours
            rcall LCD_Write_Num 
            ldi r18, ':'
            rcall Write_Data_LCD
            ldi r18, 0
            lds r29, Minutes
            rcall LCD_Write_Num 
            ldi r16, 0
            sts Interrupt, r16 ; reset intterupt flag to 0
            eor r20, r30
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


    ldi r16, LCDAddr
    sts TWDR, r16 ; Write SLA, from r16 into TWDR
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

DS3231_Read:
    push r26
    push r27
    push r16
    push r18
    push r19
    rjmp DS3231_Start

DS3231_Err:
    rjmp Error

DS3231_Start:
    ldi r16, (1 << TWINT) | (1 << TWSTA) | (1 << TWEN) ; Send start condition 
    sts TWCR, r16

    wait5: 
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set 
        rjmp wait5 

    lds r16, TWSR
    andi r16, 0xF8 ; Check if START was transmitted, status code should be 0x08
    cpi r16, 0x08 

    ldi r16, RTCAddr
    sts TWDR, r16 ; Write SLA, from r16 into TWDR
    ldi r16, (1 << TWINT) | (1 << TWEN) 
    sts TWCR, r16 ; Transmit SLA+W

    wait6:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait6

    lds r16, TWSR
    andi r16, 0xF8 ; Check if SLA+W was received, status code should be 0x18
    cpi r16, 0x18
    brne DS3231_Err

    ldi r16, 0x01 ; set register pointer to 0x01 for minutes
    sts TWDR, r16 ; Write data into TWDR
    ldi r16, (1 << TWINT) | (1 << TWEN) 
    sts TWCR, r16 ; Transmit data

    wait7:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait7

    lds r16, TWSR
    andi r16, 0xF8 ; Check if data was received, status code should be 0x28
    cpi r16, 0x28
    brne DS3231_Err

    ldi r16, (1 << TWINT) | (1 << TWEN) | (1<<TWSTA)
    sts TWCR, r16 ; Transmit SLA+R repeated start

    wait8:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait8

    lds r16, TWSR
    andi r16, 0xF8 ; Check if repeated start was received, status code should be 0x10
    cpi r16, 0x10
    brne DS3231_Err

    wait9:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait9

    ldi r16, RTCAddr
    ori r16, 0x01
    sts TWDR, r16 ; Write SLA, from r16 into TWDR
    ldi r16, (1 << TWINT) | (1 << TWEN)
    sts TWCR, r16 ; Transmit SLA+R repeated start

    wait10:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait10

    lds r16, TWSR
    andi r16, 0xF8 ; Check if SLA+R was received, status code should be 0x40
    cpi r16, 0x40
    brne DS3231_Err2_Sla
    rjmp DS3231_Read_Minutes

DS3231_Err2_Sla:
    rjmp Error2

DS3231_Read_Minutes:
    ; reading minutes
    ldi r16, (1<<TWINT) |  (1<< TWEN) | (1<< TWEA) ; Clear TWINT bit
    sts TWCR, r16
    wait11:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait11

    lds r16, TWSR
    andi r16, 0xF8 ; Check if data was received, status code should be 0x50
    cpi r16, 0x50
    brne DS3231_Err2

    lds r17, TWDR ; read data
    mov r18, r17
    lsr r17
    lsr r17
    lsr r17
    lsr r17
    ldi r19, 10
    mul r17, r19
    mov r17, r0
    andi r18, 0x0F
    add r17, r18
    sts Minutes, r17

    ; reading hours
    ldi r16, (1<<TWINT) |  (1<< TWEN) ; Clear TWINT bit
    sts TWCR, r16

    wait12:
        lds r16, TWCR 
        sbrs r16, TWINT ; Check if TWINT bit of TWCR is set
        rjmp wait12

    lds r16, TWSR
    andi r16, 0xF8 ; Check if data was received, status code should be 0x50
    cpi r16, 0x58
    brne DS3231_Err2

    lds r17, TWDR ; read data
    mov r18, r17
    lsr r17
    lsr r17
    lsr r17
    lsr r17
    mul r17, r19
    mov r17, r0
    andi r18, 0x0F
    add r17, r18
    sts Hours, r17

    ldi r16, (1 << TWINT) | (1 << TWEN) | (1 << TWSTO)
    sts TWCR, r16 ; Transmit stop

    wait13:
        lds r16, TWCR 
        sbrc r16, TWSTO
        rjmp wait13

    pop r19
    pop r18
    pop r16
    pop r27
    pop r26
    ret

DS3231_Err2:
    rjmp Error2

Error2:    
    ldi r16, (1 << PB0)
    out PORTB, r16
    rjmp Error2

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

LCD_Write_Num:
    push r29
    push r18
    push r16
    push r17
    push r20
    ldi r20, 0
    ldi r16, 0x30 ; add to get ascii value for num
    ; this is a dumb way to do this but it works
    mov r17, r29
    cpi r17, 10
    brlt OneDigit
    loop2:
        mov r17, r29
        loop3:
            subi r17, 10
            inc r20
            cpi r17, 10
            brge loop3
        mov r18, r20
        add r18, r16
        rcall Write_Data_LCD
        mov r29, r20
        cpi r29, 10
        brge loop2
    OneDigit:
    mov r18, r17
    add r18, r16
    rcall Write_Data_LCD
    pop r20
    pop r17
    pop r16
    pop r18
    pop r29
    ret

LCD_Write_String:
    push r18
    push r16
    push r26
    push r27
    push r30
    push r31
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
    pop r31
    pop r30
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
    push r0
    push r16
    push r17
    in r0, SREG
    push r0
    ldi r16, 1  ; set intterupt flag
    sts Interrupt, r16
    ldi r17, 100
    rcall Delay_ms
    pop r0
    pop r17
    pop r16
    out SREG, r0
    pop r0
    reti

.global main
#define __ASSEMBLER__ 1
#define __SFR_OFFSET 0
#include <avr/io.h>

.global INT0_vect

.data
LEDState: .byte 1 

.text
main:
	ldi r16, (1 << DDB0)
	out DDRB, r16 
	ldi r16, (0 << PB0)
	out PORTB, r16
	cli
	sts EICRA, 0b00001100	; set INT0 to trigger on a logic level 0
	sbi EIMSK, INT0	  ; Enable INT0
	sei
loop:
	rjmp loop

INT0_vect:
	push r16
	in r0, SREG
	push r0
	push r17
	ldi r17, (1 << PB0)
	lds r16, LEDState
	eor r16, r17  ; toggle LED
	sts LEDState, r16
	out PORTB, r16
	pop r16
	pop r17
	pop r0
	out SREG, r0
	reti

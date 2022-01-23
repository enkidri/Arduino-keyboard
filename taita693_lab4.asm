;
; lab4.asm
;
; Created: 2021-12-14 08:55:30
; Author : Lawli
;
	jmp		CONFIG


	.equ	FN_SET =	0b00101000		
	.equ	DISP_SET =	0b00001110	
	.equ	LCD_CLR =	0b00000001	
	.equ	E_MODE =	0b00000110	
;Intervals for reading the ADC
ADC_INT:
	.db		207,130,82,43,12,0,$00,$00
;What to map above intervals to
ADC_MAP:
	.db		0,1,2,3,4,5,$00,$00

	.dseg
CUR_POS:
	.byte	1
;Used to store whats written on display since you cant read from display
LINE:
	.byte	16
;1 = If display on
;0 = If display off
DISPLAY_STATUS:
	.byte	1

	.cseg
;
;
;---------------------------------------------------

CONFIG:
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16

	CALL	INIT
	CALL	LCD_INIT
	ldi		r16,1
	sts		DISPLAY_STATUS,r16	;Display is on by default

	ldi		r16,0
	ori		r16,$80
	sts		CUR_POS,r16			;Set current pos to $00

	call	INIT_ASCII			;Fill LINE in SRAM with beginning of letter ASCII

MAIN:
	call	KEY_READ
	;ldi		r16,4

	cpi		r16,2
	breq	MOVE
	cpi		r16,5
	breq	MOVE

	cpi		r16,4
	breq	CHAR
	cpi		r16,3
	breq	CHAR

	cpi		r16,1
	breq	DISPLAY

	jmp		END
CHAR:
	call	DO_CHAR
	jmp		END
MOVE:
	call	DO_MOVE
	jmp		END
DISPLAY:
	call	DO_LIGHT_DISP
END:
	jmp		MAIN

;
;--------------------------------------------------
;ONLY SUBRUTINES BELOW THIS LINE

; ----Init. Pinnar on D0-D7 out, B3-B0 out, C0-C5 in (and more)
INIT:
	ldi		r16,$FF
	out		DDRD, r16
	ldi		r16, $0F
	out		DDRB, r16
	ldi		r16,$00
	out		DDRC,r16
	ret

BACKLIGHT_ON:
	sbi		PORTB,2
	ret

BACKLIGHT_OFF:
	cbi		PORTB,2
	ret

;
;DECREMENTS LOOP 256*256*2 (r16*r17*r18) times eqv. of
;24 ms at 16 MHz
WAIT:
	push	r18
	push	r17 
	push	r16

	ldi		r18, 1			;CHANGE TO INCREASE WAIT. 24 ms = 3.
D_3:
	ldi		r17, 0
D_2:
	ldi		r16, 0
D_1:
	dec		r16
	brne	D_1
	dec		r17
	brne	D_2
	dec		r18
	brne	D_3

	pop		r16
	pop		r17
	pop		r18
	ret
;
;Fills "LINE" in SRAM with beginning of ascii A-Z
INIT_ASCII:
	push	r16
	push	r17

	ldi		XH,HIGH(LINE)
	ldi		XL,LOW(LINE)
	ldi		r16,16
	ldi		r17,$40

SET_ZERO_LOOP:
	st		X+,r17
	dec		r16
	brne	SET_ZERO_LOOP

	pop		r17
	pop		r16
	ret
;
;
;Writes 4 high bits
LCD_WRITE4:
	sbi		PORTB,1
	out		PORTD,r16
	cbi		PORTB,1
	call	WAIT
	ret
;
;Write all 8 bits in two calls
LCD_WRITE8:
	call	LCD_WRITE4
	swap	r16
	call	LCD_WRITE4
	ret
;
;Allow writing of ascii on display
LCD_ASCII:
	;sätt RS rätt
	sbi		PORTB,0
	call	LCD_WRITE8
	ret
;
;Allow commands on display
LCD_COMMAND:
	;sätt RS rätt
	cbi		PORTB,0
	call	LCD_WRITE8
	ret

;
;Display configuration
LCD_INIT:
	; ----turn backlight on
	call	BACKLIGHT_ON
	; --- wait for LCD ready
	call	WAIT
	
	;
	; ----- First initiate 4-bit mode
	; 

	ldi		r16,$30
	call	LCD_WRITE4
	call	LCD_WRITE4
	call	LCD_WRITE4
	ldi		r16,$20
	call	LCD_WRITE4

	;
	; --- Now configure display
	;

	; --- Function set: 4-bit mode, 2 line, 5x8 font
	ldi		r16,FN_SET
	call	LCD_COMMAND

	; --- Display on, cursor on, cursor blink
	ldi		r16,DISP_SET
	call	LCD_COMMAND

	; --- Clear display
	ldi		r16,LCD_CLR
	call	LCD_COMMAND

	; --- Entry mode: Increment cursor, no shift
	ldi		r16,E_MODE
	call	LCD_COMMAND
	ret

LCD_PRINT_HEX:
	call	NIB2HEX
NIB2HEX:
	swap	r16
	push	r16
	andi	r16,$0F
	ori		r16,$30
	cpi		r16,':'
	brlo	NOT_AF
	subi	r16,-$07
NOT_AF:
	call	LCD_ASCII
	pop		r16
	ret		

ADC_READ8:
	ldi		r16,(1<<REFS0)|(1<<ADLAR)|0
	sts		ADMUX,r16
	ldi		r16,(1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
	sts		ADCSRA,r16

CONVERT:
	lds		r16,ADCSRA
	ori		r16,(1<<ADSC)
	sts		ADCSRA,r16

ADC_BUSY:
	lds		r16,ADCSRA
	sbrc	r16,ADSC
	jmp		ADC_BUSY

	lds		r16,ADCH
	ret

;
;IN: r16
;OUT: r16 (val between 0-5)
KEY:
	push	ZH
	push	ZL
	push	r17
	push	r18
	clr		r18

	ldi		ZH,HIGH(ADC_INT*2)
	ldi		ZL,LOW(ADC_INT*2)
KEY_LOOP:
	inc		r18
	call	ADC_READ8
	;ldi		r16,11				;Debugging line, replace with ADC_READ8
	lpm		r17,Z+
	cp		r16,r17
	brcs	KEY_LOOP
	dec		r18					;Compensate for starting the loop at r18 = 1

	ldi		ZH,HIGH(ADC_MAP*2)
	ldi		ZL,LOW(ADC_MAP*2)
	add		ZL,r18				;Carry can be disregarded, table is small enough
	lpm		r16,Z

	pop		r18
	pop		r17
	pop		ZL
	pop		ZH
	ret
;IN: -
;OUT: r16 w/ ADC value
KEY_READ:
	call	KEY
	tst		r16
	brne	KEY_READ
KEY_WAIT_FOR_PRESS:
	call	KEY
	tst		r16
	breq	KEY_WAIT_FOR_PRESS
	ret
;
;IN: r16 w/ hex DDRAM pos
;OUT: Position on screen
LCD_COL:
	push	XH
	push	XL
	push	r16

	ldi		XH,HIGH(CUR_POS)
	ldi		XL,LOW(CUR_POS)
	ori		r16,$80
	st		X,r16

	call	LCD_COMMAND
	
	pop		r16
	pop		XH
	pop		XL
	ret

;IN: Key-value in r16
;OUT: DDRAM adress in r16 and move cursor to the adress, right or left dir
DO_MOVE:
	push	r17
	push	r16

	lds		r17,CUR_POS
	andi	r17,$7F				;Set the first bit to zero

	cpi		r16,2
	breq	DO_LEFT
	cpi		r16,5
	breq	DO_RIGHT
DO_LEFT:
	dec		r17
	brpl	DO_MOVE_FIN			
	ldi		r17,0
	jmp		DO_MOVE_FIN

DO_RIGHT:
	inc		r17
	cpi		r17,15
	brmi	DO_MOVE_FIN			
	ldi		r17,15

DO_MOVE_FIN:
	ori		r17,$80				;Restore the first bit to 1
	mov		r16,r17
	call	LCD_COL

	pop		r16
	pop		r17
	ret	

;IN: Key-value in r16
;OUT: Print ASCII on current DDRAM adress
DO_CHAR:
	push	XH
	push	XL
	push	r17

	ldi		XH,HIGH(LINE)
	ldi		XL,LOW(LINE)
	lds		r17,CUR_POS
	andi	r17,$7F			;Set first bit to zero to get displacement
	add		XL,r17			;Carry disregarded as LINE is small enough
	ld		r17,X			;Find current ascii on current address

	cpi		r16,4
	breq	CHAR_UP
	cpi		r16,3
	breq	CHAR_DOWN
CHAR_UP:
	inc		r17
	jmp		DO_CHAR_END
CHAR_DOWN:
	dec		r17	

DO_CHAR_END:
	st		X,r17
	mov		r16,r17
	call	LCD_ASCII

	lds		r16,CUR_POS			;Restore current position
	call	LCD_COL

	pop		r17
	pop		XL
	pop		XH
	ret

DO_LIGHT_DISP:
	push	XH
	push	XL
	push	r16

	lds		r16,DISPLAY_STATUS
	cpi		r16,1
	breq	DISPLAY_OFF
	call	BACKLIGHT_ON
	ldi		r16,1
	sts		DISPLAY_STATUS,r16
	jmp		DO_DISP_END

DISPLAY_OFF:
	call	BACKLIGHT_OFF
	ldi		r16,0
	sts		DISPLAY_STATUS,r16

DO_DISP_END:
	pop		r16
	pop		XL
	pop		XH
	ret
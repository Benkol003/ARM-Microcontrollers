org &0
;https://en.wikipedia.org/wiki/Hitachi_HD44780_LCD_controller
ldr r0, =PIO_A
ldr r1, =PIO_B ; constant registers

;disable leds - enabled on reset
ldrb r4, [r1]
mov r3, #0b10000
bic r4,r4,r3
strb r4, [r1]

;---- enable LCD backlight ----
mov r3, #0b00100000
ldrb r4, [r1]
orr r4,r4,r3
strb r4, [r1]
;----       ----




;---- wait until LCD is idle ----
lcd_wait
;set flags to read control
ldrb r4, [r1]
mov r3, #0b100
orr r4,r4,r3
mov r3, #0b011
bic r4,r4,r3
strb r4, [r1]

;read status
lcd_wait_loop

;enable
mov r3, #1
ldrb r4, [r1]
orr r4,r4,r3
strb r4,[r1]

;check status bit
ldrb r4, [r1]
tst r4, #0b10000000

;disablees performed.
bic r4,r4,r3
strb r4,[r1]

bne lcd_wait_loop ;wait until not busy

;----   ----

;---- Write char ----

;set flags to write data reg
ldrb r4,[r1]
mov r3, #0b010
orr r4,r4,r3
mov r3, #0b101
bic r4,r4,r3
strb r4,[r1]

;write char code - ROM code: A00
mov r4, #0b00110000
strb r4, [r0]

;enable
mov r3, #1
ldrb r4, [r1]
orr r4,r4,r3
strb r4,[r1]

;disable
ldrb r4, [r1]
bic r4,r4,r3
strb r4,[r1]

;----       ----

;halt program
mov r3, #1
ldr r4, =HALT
str r3,[r4]


ALIGN
PIO_A equ &10000000
PIO_B equ &10000004
HALT equ &10000020

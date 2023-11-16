
; ---- MAIN ----
ORG &0

;PIO_B
LDR r1, =LED_ENABLE
LDR r0, =PIO_B
STR r1, [r0] ;enable LED's

;PIO_A
MOV r1, #traffic_states ; pointer to start of table
LDR r4, PIO_A
traffic_lights
MOV r0, #0 ;table offset
STRB r0, [r4] ;clear leds
traffic_lights_loop0
;fetch bitmask for current LED state
LDRB r2, [r1,r0]
STRB r2, [r4]
ADD r0,r0,#1

;get seconds to wait and then wait
LDRB r2,[r1,r0] ;r2=seconds
ADD r0,r0,#1
MOV r3, #0
;calculate number of instructions to cycle for
traffic_lights_loop1
ADD r3, r3, #0x40000
SUB r2,r2,#1
CMP r2, #0
BNE traffic_lights_loop1 ;r0 should not be zero to begin with (bug otherwise)
traffic_lights_loop2
SUB r3,r3,#1
CMP r3, #0
BNE traffic_lights_loop2

CMP R0, #16 ; compare to size of table
BNE traffic_lights_loop0
B traffic_lights


;End of Program (not that we ever get here ;)
LDR r0, HALT
LDR r1, =1
STRB r1, [r0]
;----   ----

;LED state table
traffic_states
DEFB 0b01000100, 1 ;we have PIO_A bitmask, seconds to wait
DEFB 0b01000110, 1
DEFB 0b01000001, 3
DEFB 0b01000010, 1
DEFB 0b01000100, 1
DEFB 0b01100100, 1
DEFB 0b00010100, 3
DEFB 0b00100100, 1 ;8 rows


ALIGN
LED_ENABLE EQU 0b00010000 ;for PIO_B
PIO_A DEFW &10000000
PIO_B EQU &10000004
DELTA_TIMER DEFW 0x10000008
TIMER_IRQ DEFW 0x1000000C
HALT DEFW 0x10000020

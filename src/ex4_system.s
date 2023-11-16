include ../lib/sys.s

greet_topline
DEFB 72, 101, 108, 108, 111, 0 ;Hello

greet_bottomline
DEFB 84, 104, 101, 114, 101, 46, 0 ;There.

str_top
DEFB 116, 111, 112, 0

str_bottom
DEFB 98, 111, 116, 116, 111, 109, 0 

ALIGN
DEFS 4096 ;4KiB stack - 1024 stack vars
stack

;---- main ----
main
ldr SP, =stack
; you better not change these :D

mov r0, #1
svc 8

svc 9

ldr r0, =greet_topline
svc 11

main_keypoll
svc 3
lsr r1, r1, #6


teq r1, #2
bne main_s1
ldr r0, =str_bottom
svc 9
svc 11

main_s1
teq r1, #1
bne main_keypoll
ldr r0, =str_top
svc 9
svc 11

b main_keypoll

SVC 1
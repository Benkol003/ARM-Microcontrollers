include ../lib/sys.s
include ../lib/user.s

delay EQU 3 ;ms
KEYPAD_DATA_OFFSET equ 2
KEYPAD_CONTROL_OFFSET equ 3

ALIGN
main
svc 10

mov r0, #0 ;S0
bl keypad_init

mov r0, #1
svc 9
svc 10

;start the timer delay loop
mov r0, #delay
svc 4
loop b loop
svc 1

isr_timer_callback
    push {r0, lr}

    bl keypad_poll_handler

    ;set up the next delay
    mov r0, #delay
    svc 4

    pop {r0, lr}
    mov pc, lr

keypad_switched_evhdl
    push{r1,r2}
    cmp r11, #0
    beq keypad_switched_evhdl_end
    adr r2, keypad_symbols
    add r2, r2, r7

    ldrb r1, [r2]
    svc 11

    keypad_switched_evhdl_end
    pop {r1,r2}
    mov pc, lr
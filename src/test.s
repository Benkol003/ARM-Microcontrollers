include ../lib/sys.s
include ../lib/user.s
include ../lib/fifo.s
include ../lib/time_input.s


time DEFW 0x2931a78 ; init to 11:59:55

time_display DEFW 0 ;integer value in seconds
time_alarm DEFW 0xa8c0 ;alarm set to midday by default ; is in seconds
delay EQU 10 ;ms ; 
;TODO might wanna move keypad_saturate here as its time dependent
KEYPAD_DATA_OFFSET equ 4
KEYPAD_CONTROL_OFFSET equ 5

time_str DEFB "hh:mm:ss",0
alarm_sounding DEFB 0 ;boolean to control the alarm sound after it has been triggered
alarm_triggered DEFB 0 ; indicates if the alarm has been triggered - prevents activating the alarm multiple times
;--------------------- FPGA INFO --------------------;
;
;
; 0x200000000, 01 :  16 bit divider value n = 0x[01 ++ 00] ;generates buzzer frequency of 1Mhz / n.
; 0x...02 : buzzer enable (active high). 0x...03 : disconnected.
; 0x...04, 05 : connects to the upper row of S0 / JT2 so you can scan the keypad at the same time
; (0x..06, 07 - back row of JT2 - advise dont try to use this.)
; 0x..09 onwards - connected to S3 and above as expected from exercise 7.
;
;
;----------------------------------------------------;

str_msg DEFB 0xa8,0

ALIGN
main

adr r0, str_msg
svc 12

svc 1


isr_timer_callback
    push {r0-r2, lr}

    bl keypad_poll_handler

    ;calculate correct time
    adr r0, time
    ldr r1, [r0]
    add r1, r1, #delay
    str r1, [r0]

    ;set up the next delay
    mov r0, #delay
    svc 4

    pop {r0-r2, lr}
    mov pc, lr


keypad_switched_evhdl
    push{r0,r2, lr}
    cmp r11, #0
    beq keypad_switched_evhdl_end
    adrl r2, keypad_symbols
    add r2, r2, r7
    ldrb r0, [r2]
    ;from the offset get the ascii code of the key pressed
    bl fifo_push

    keypad_switched_evhdl_end
    pop {r0,r2, lr}
    mov pc, lr
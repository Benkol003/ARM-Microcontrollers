;/////////////////////////////////////////////
;               ALARM CLOCK
;   Author: @h45007bk
;
;   Usage Guide:
;   Setup: a keypad is expected to be connected to the bottom left connector (S0), and my FPGA design has been uploaded (ex9.bit)
;
;   Key Control and Menus:
;   
;   MAIN MENU:
        ;   This displays the current time in a 24 hour format.
        ;   
        ;   Bottom Button / ST2 - If the alarm is sounding, disables it for the current 24 hour period.
        ;
        ;   Top Button / ST3 - Enters the menu to set the alarm time
        ;
        ;   Keypad button '#' - Enters the menu to set the current time
        ;
        ;   keypad button '*' - Enters the menu to set the alarm buzzer tone.
;

;   SET ALARM/CURRENT TIME MENUS:
    ;   
    ;   The wanted time can be set using the 0-9 keys to enter a numeric time. The menu will only accept a valid time from 00:00:00 to 23:59:59.
    ;
;

;   SET BUZZER TONE MENU:
    ;   The currently selected buzzer tone will sound. You can change/select the tone with 0-9 keys to choose one of
    ;   the 10 different tones.
    ;   Press the '*' button to confirm your choice and return to the main time menu.   
;
;////////////////////////////////////////////

;--------------------- FPGA DESIGN INFO --------------------;
;   (for ex9.bit)
;
; 0x200000000, 01 :  16 bit divider value n = 0x[01 ++ 00] ;generates buzzer frequency of 1Mhz / n.
; 0x...02 : buzzer enable (active high). 0x...03 : disconnected.
; 0x...04, 05 : connects to the upper row of S0 / JT2 so you can scan the keypad at the same time
; (0x..06, 07 - back row of JT2 - advise dont try to use this.)
; 0x..09 onwards - connected to S3 and above as expected from exercise 7/default FPGA configuration.
;
;
;-----------------------------------------------------------;






include ../lib/sys.s
include ../lib/fifo.s
include ../lib/time_input.s
include ../lib/user.s

ALIGN
time DEFW 0x2931a78 ; init to 11:59:55

time_display DEFW 0 ;integer value in seconds
time_alarm DEFW 0xa8c0 ;alarm set to 12:00:00 by default ; is in seconds
delay EQU 5 ;ms ; 

KEYPAD_DATA_OFFSET equ 4
KEYPAD_CONTROL_OFFSET equ 5

time_str DEFB "hh:mm:ss",0
time_alarm_str DEFB "hh:mm:ss",0 ;temporary to use to set alarm time
time_set_msg DEFB 0xcf," SET TIME ", 0xcf, 0 ;why not use some japanese characters (0xcf) :) ? the LCD controller rom code is A02.
time_alarm_set_msg DEFB 0xcf," SET ALARM ", 0xcf, 0
buzzer_set_msg DEFB 0xcf, " BUZZER TONE ", 0xcf, 0
alarm_sounding DEFB 0 ;boolean to control the alarm sound after it has been triggered
alarm_triggered DEFB 0 ; indicates if the alarm has been triggered - prevents activating the alarm multiple times

ALIGN
main
bl fifo_init
mov r0, #0 ;keypad is expected to be connected S0
bl keypad_init

mov r0, #1
svc 9
svc 10

;--------
;BUZZER / FPGA initialisation
mov r0, #0
mov r1, #:111101000 ;lower byte for buzzer tone
svc 6

mov r0, #1
mov r1, #:111 ; upper byte for buzzer tone
svc 6

mov r0, #2
mov r1, #0 ;disable on startup
svc 6


;--------

;start the timer delay loop
mov r0, #delay
svc 4

main_loop

;-------- Time Updating --------;
;check if time has gone past the 24hr mark - if this is the case then subtract 24h
adr r1, time
ldr r0, [r1]
adr r3, time_24hr_ms
ldr r2, [r3]
cmp r0, r2
blo main_no_time_24hr_wrap
sub r0, r0, r2
str r0, [r1]
;reset display time to 0
adr r3, time_display
mov r2, #0
str r2, [r3]

;update displayed time
bl display_time

main_no_time_24hr_wrap
;update time if: display time < current time, sec || time wraps round (this is done earlier when we do the wrap caclulation;
;(if we just check that time_display==0 then it will refresh every loop cycle)

;r0 still contains current time
mov r1, #1000
bl divide ;calculate the time that 'should' (but may not be atm) displayed and check for a difference with time_display
adr r2, time_display
ldr r3, [r2] ;displayed time
str r0, [r2] ;update it in memory 
cmp r0, r3 ;choose whether to re-display if different
blne display_time
;------------------------------;





;---- Alarm checking and sounding ----;


;check current time against alarm time
ldr r1, time_alarm
cmp r0, r1

beq main_no_alrm_detrigger
mov r0, #0
;if time != alarm than can safely turn the trigger off - also need to do this if the alarm is to go off very 24 hours
strb r0, alarm_triggered
main_no_alrm_detrigger
;this needs to be before the other conditional branch as alarm_trigger desets the condition flag

bleq alarm_trigger



mov r0, #2
ldrb r1, alarm_sounding ;use this to control buzzer enable/disable
svc 6

;-------------------------------------;



;---- Button checking from event fifo ----;

;button event checking to go into menu's

main_fifo_check_loop

bl fifo_pop

cmp r0, #'*'
bleq menu_set_buzzer

cmp r0, #'#' ;use '#' on keypad instead of ST1
bleq menu_set_time ;top right button press

cmp r0, #2 ;upper button press
bleq menu_set_alarm

cmp r0, #1 ;lower button press
bleq dismiss_alarm

;if !=0 then more events are in fifo and need to continue checking
cmp r0, #0
bne main_fifo_check_loop

;---------------------------------------;


b main_loop


display_time
    push {r0-r1,lr}
    ;now print new time
    svc 10
    adr r2, time_display
    ldr r0, [r2]
    adr r3, time_str
    bl hex_to_time

    mov r0, r3
    svc 12

    pop {r0-r1,lr}
    mov pc, lr


svc 1
;-------- MAIN END --------

isr_timer_callback
    push {r0-r2, lr}

    bl keypad_poll_handler

    ;----------------
    ;this code is commented out because ST1 DOESNT WORK AFTER UPLOADING AN FPGA DESIGN
    ;
    ;poll ST1 / top right button
    ;svc 3
    ;get bit and shift/bit clear into a boolean (0/1)
    ;lsr r0, r0, #3
    ;bic r0, r0, #:11111110
    ;bl st3_poll_hdl
    ;-----------------

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



;-------- MENUS & BUTTON CALLBACKS--------;

alarm_trigger
    push {r0}
    ;check the alarm hasnt already been activated before - this is only really needed due to the mismatch between having 1 sec accuracy with values compared
    ;to the loop running at millisecond accuracy/ called multiple times per second.
    ldrb r0, alarm_triggered
    cmp r0, #1
    beq alarm_trigger_end

    mov r0, #1
    strb r0, alarm_sounding
    strb r0, alarm_triggered
    
    alarm_trigger_end
    pop {r0}
    mov pc, lr

menu_set_alarm
    push {r1-r2, lr}
    adrl r1, time_alarm_str
    adrl r2, time_alarm_set_msg
    bl time_input

    ;set alarm time
    bl time_to_hex
    str r0, time_alarm
    pop {r1-r2, lr}
    mov pc, lr

menu_set_time
    push {r1-r2, lr}
    adrl r2, time_set_msg
    adr r1, time_str
    bl time_input
    
    ;now set the current time based off this
    bl time_to_hex
    mov r1, #1000
    mul r0, r0, r1
    adr r1, time
    str r0, [r1]

    ;alarm fix - reset alarm trigger after setting time
    mov r0, #0
    strb r0, alarm_triggered

    pop {r1-r2, lr}
    mov pc, lr

dismiss_alarm
    push {r0-r1}

    mov r1, #0
    strb r1, alarm_sounding
    mov r0, #2
    svc 6
    pop {r0-r1}
    mov pc, lr

menu_set_buzzer
    push {r0-r1, lr}

    svc 10
    adrl r0, buzzer_set_msg
    svc 12

    mov r0, #2
    mov r1, #1 ;enable buzzer
    svc 6

    ;keys 0-9 indicate the offset for the alarm_tones table
    menu_set_buzzer_fifo_drain

    bl fifo_pop

    ;(similar to time_input code)
    ;use unsigned arithmetic: r0 - 48 > 0 therefore if r0<48 and we do r0-48 then it wraps around to e.g. 0xFFFF
    sub r0, r0, #48 ; need to do r0 - '0' aka 48
    cmp r0, #9 ;this is just the actual number
    blls menu_set_buzzer_wrt
    add r0, r0, #48
    cmp r0, #'*'
    bne menu_set_buzzer_fifo_drain ;only exit the menu once press * key (allow to hear tone first)

    mov r0, #2
    mov r1, #0 ;disable buzzer
    svc 6

    pop {r0-r1, lr}
    mov pc, lr

menu_set_buzzer_wrt
    push {r0-r3}
    adr r2, alarm_tones
    mov r3, #4
    mul r0, r0, r3
    add r2, r2, r0

    ldr r1, [r2]
    mov r0, #0
    ;lower byte for buzzer tone is set
    svc 6

    mov r0, #1
    ldr r1, [r2]
    lsr r1, r1, #8 ;now set the upper byte half
    svc 6 
    pop {r0-r3}
    mov pc, lr


;200 - 1800 hz tones in steps of 200hz. These are values to be passed to the FPGA divider where value = 1Mhz / desired frequency.
alarm_tones
DEFW 0x1388
DEFW 0x9c4
DEFW 0x682
DEFW 0x4e2
DEFW 0x3e8
DEFW 0x341
DEFW 0x2ca
DEFW 0x271
DEFW 0x22b
DEFW 0x1f4

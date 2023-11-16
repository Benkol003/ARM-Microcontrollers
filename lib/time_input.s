
;-------------------------------
;
; function to prompt and then correctly validate/parse keypad input into a 24-hour format into a string.
;
;------------------------------


time_empty_str DEFB "hh:mm:ss",0
ALIGN


time_input
    push{r0-r6, lr}
    ;R1 - time-formatted string to store entry to
    ;R2 - pointer to string to display on the second line
    ;uses keypad numbers (from fifo events) to enter time

    ;initialise the string to empty format
    push {r0,r1} ;preserve registers for later code
    mov r0, r1
    adr r1, time_empty_str
    bl strcpy
    pop {r0,r1}

    mov r6, r1 ;save pointer to beggining of string so that we can print

    bl time_input_disp

    ;digit 1 - 10hr
    ;can be 0,1,2 keys | ascii: 48 - 50
    time_input_d1l
    bl fifo_pop

        cmp r0, #'2'
        moveq r4, #1 ;special validation case if first digit =2, then can only have 20-23 hours (0-3 for second digit)
        
        ;use unsigned arithmetic: r0 - 48 > 0 therefore if r0<48 and we do r0-48 then it wraps around to e.g. 0xFFFF

        sub r0, r0, #48 ; need to do r0 - '0' aka 48
        cmp r0, #2 ;this is just the actual number, but results from doing '2'-'0'
        blls time_input_wrd
        bhi time_input_d1l

    add r1, r1, #1 ;next digit

    bl time_input_disp ;refresh the display with what has been currently entered

    ;digit 2 - 1hr
    ;0-9 | ascii: 48-57
    time_input_d2l
    bl fifo_pop

        ;special validation case - r5 contains max number for second digit - either we have (0|1)(0-9) | (2)(0-3)
        mov r5, #9
        cmp r4, #1
        moveq r5, #3

        sub r0, r0, #48
        cmp r0, r5
        blls time_input_wrd
        bhi time_input_d2l

    add r1, r1, #1 ; next digit + write in ':'

    mov r3, #':'
    strb r3, [r1]
    add r1, r1, #1

    bl time_input_disp

    ;10min
    ;0-5 | ascii: 48-53
    time_input_d3l
    bl fifo_pop

        sub r0, r0, #48
        cmp r0, #5
        blls time_input_wrd
        bhi time_input_d3l

    add r1, r1, #1
    bl time_input_disp

    ;1min
    ;0-9 
    time_input_d4l
    bl fifo_pop

        sub r0, r0, #48
        cmp r0, #9
        blls time_input_wrd
        bhi time_input_d4l

    add r1, r1, #1

    mov r3, #':'
    strb r3, [r1]
    add r1, r1, #1

    bl time_input_disp

    ;10sec
    ;0-5
    time_input_d5l
    bl fifo_pop

        sub r0, r0, #48
        cmp r0, #5
        blls time_input_wrd
        bhi time_input_d5l

    add r1, r1, #1

    bl time_input_disp

    ;1sec
    ;0-9
    time_input_d6l
    bl fifo_pop

        sub r0, r0, #48
        cmp r0, #9
        blls time_input_wrd
        bhi time_input_d6l

    bl time_input_disp

    pop {r0-r6, lr}
    mov pc, lr


time_input_wrd
    ;helper/inline function for time_input: writes the next accepted digit in an input sequence into the time-formatted string
    ;(when i say inline i mean i still consider this to be in the same register space as time_input)
    ;R1 - pointer to digit to write
    ;R0 - ascii value to write
    add r0, r0, #48
    strb r0, [r1] ;man, it would be useful if strb with condition codes existed
    mov pc, lr

time_input_disp
    ;helper function - (still need to save registers even if inline - we're using r0 but so do the SVC's)
    ;inherited registers: r6 - time str, r2: second line str
    push {r0}
    
    svc 10
    mov r0, r6
    svc 12
    mov r0, #LCD_LINE1
    svc 14 ;need to print r2 string on second line
    mov r0, r2
    svc 12

    pop {r0}
    mov pc, lr
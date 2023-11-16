;********
;stopwatch: the stopwatch will start when the bottom button (ST2) is released
;pressing the top button (ST3) pauses the stopwatch
;holding the top button (ST3) for a second or more resets the stopwatch
;********

include ../lib/sys.s

ALIGN
time DEFW 0
t0 DEFW 0
btn_holdtime DEFW 0
;store state of buttons from previous loop

btn_prev DEFB 0
loop_pause DEFB 0

time_BCD DEFS 10

str_sec DEFB " Seconds", 0

greeter DEFB "STOPWATCH :)", 0

ALIGN
main

    ;reset values used in the loop
    adr r12, time
    mov r0, #0
    str r0, [r12]
    str r0, btn_holdtime
    strb r0, btn_prev
    strb r0, loop_pause

    ldr r1, =time_BCD
    bl hex_to_BCD
    mov r0, r1
    svc 12

    mov r0, #1
    svc 8
    svc 9
    adr r0, greeter
    svc 11

    main_timer_starter
    svc 3
    ldr r2, =PIO_B_BTN_LOWER_BIT
    ands r0, r2, r0
    beq main_timer_starter
    ;wait for release
    main_timer_starter2
    svc 3
    ands r0, r2, r0
    bne main_timer_starter2

    ;set t0 value for loop entry
    adr r11, t0
    svc 6
    str r0, [r11]

    ;print out 0 sec
    svc 9
    mov r0, #0
    adr r1, time_BCD
    bl hex_to_BCD
    mov r0, r1
    svc 12
    adr r0, str_sec
    svc 11

    ;given the no. of variables i will use adr to load addresses when needed in the loop, rather than storing them
    ;in registers - doing this may end up running out of them given the number of variables
    main_loop ;this loop needs to run under 256ms :)

        ;refer to psuedo-code in ex5-psuedo.txt

        ;---------- calculate delta t -----------------
        ;load time and t0 values
        adr r2, t0
        ldr r2, [r2]

        svc 6 ;r1 = t1, t0 = r2
        cmp r2, r0
        addhi r5, r0, #256 ; if t0>=t1 then value of timer has wrapped around
        movls r5, r0 ;its possible that that delta_t = 0 given how fast the cpu is wrt the timer
        sub r3, r5, r2 ;calculate delta time into r3
        ;store t1 -> t0
        adr r2, t0
        str r0, [r2]
        ;----------------------------------------------


        ;time_total
        adr r4, time ;total time in previous phase - r4
        ldr r4, [r4]
        add r5, r4, r3 ;r5 is total time for this loop phase
        mov r0, r4
        bl divide
        mov r4, r0

        mov r0, r5
        bl divide
        mov r5, r0

        cmp r4, r5 ;check whether the value in seconds has changed or not
        beq main_loop_key_handling
        ;re-print
        mov r0, r5
        adrl r1, time_BCD
        bl hex_to_BCD
        svc 9
        adrl r0, time_BCD
        svc 12
        adr r0, str_sec
        svc 11

        ;get btn state and btn_prev_phase state into registers
        main_loop_key_handling
        ldrb r4, btn_prev

        svc 3
        ldr r1, =PIO_B_BTN_UPPER_BIT
        ands r5, r1, r0

        ;r4 and r5 now hold values for button press previous/current phase
        ;r4, r5 will flip a bit corresponding to the bitmask, however we can still use and/or 
        ;as its the same bit for both
        tst r4, r5
        bleq stop_reset ;reset button holding timer if button not held (in previous+current phase)
        blne btn_holding ;increment button timer if holding down button
        
        bics r0, r5, r4 ;if previously unpressed and now pressed
        blne flip_pause

        ldr r6, loop_pause
        cmp r6, #0
        bne main_loop_end
        adr r6, time
        ldr r7, [r6]
        add r7, r7, r3
        str r7, [r6]

        main_loop_end
        ;write current status of button
        ldr r4, =btn_prev
        strb r5, [r4]

    b main_loop
    svc 1

;helper inline functions - dont need register saving
stop_reset
    adr r7, btn_holdtime
    mov r6, #0
    str r6, [r7]
    mov pc, lr

btn_holding
    adr r7, btn_holdtime
    ldr r6, [r7]
    add r6, r6, r3
    cmp r6, #1000
    bhi main
    str r6, [r7]

    mov pc, lr

flip_pause
    adrl r6, loop_pause
    ldrb r7, [r6]
    mvn r7, r7
    strb r7, [r6]

    mov pc, lr

increment_timer
    adr r6, time
    ldr r7, [r6]
    add r7, r7, r3
    str r7, [r6]

ten_exp_ten DEFW 10000000000

hex_to_BCD ; you can allocate on stack an array of 5 bytes and pass the pointer to start (below SP) or use DEFS
    ;note we are using unpacked bcd
    ;args: r0 - hex number, r1 - pointer to BCD string to fill; 32 bit number need 10 BCD digits - 5 bytes (packed).
    ;BCD string is big endian - e.g. 001234
    push {r2,r3,r4,r5,r6,r7}



    ;handle the case where all digits of the BCD are used, when we multiply the exponent to get 10^10 this overflows
    mov r2, #10
    ldr r3, ten_exp_ten
    cmp r0, r3
    bhs hex_to_bcd_digits

    ;vars: r2 - bcd digit, r4 - digit exponent (10^n)
    mov r2, #1
    mov r3, #10

    ;find the largest decimal digit position for the value  - r2
    hex_to_bcd_max_digit
        cmp r0, r3
        blo hex_to_bcd_digits
        mov r5, #10
        mul r3, r3, r5
        mov r5, #1
        add r2, r2, #1
    b hex_to_bcd_max_digit

    hex_to_bcd_digits
        mov r7, #10 ;exponent multiplier
        ;push each exponent for every digit onto stack, highest are popped first
        mov r6, r2 ;copy max bcd digit
        mov r5, #1
        hex_to_bcd_digits_loop
        cmp r6, #0
        beq hex_to_bcd_memset
        sub r6, r6, #1
        push {r5}
        mul r5, r5, r7
    b hex_to_bcd_digits_loop

    
    hex_to_bcd_memset
    ;fill the unwritten digits of the BCD with zeros
    rsb r4, r2, #10 ;fill upto this digit
    mov r5, #0

    hex_to_bcd_memset_loop
    cmp r5, r4
    beq hex_to_bcd_subtract
        mov r6, #0
        strb r6, [r1,r5]
        add r5, r5, #1
    b hex_to_bcd_memset_loop


    hex_to_bcd_subtract ;from largest digit exponent first, calculate digit value, subtract, and repeat for next digit exponent  (/10)
        cmp r2, #0
        beq hex_to_bcd_end

        ;accumulator
        pop {r3} ;get digit exponent
        mov r4, #0 ;r4, digit number
        hex_to_bcd_accumulator
            cmp r3, r0
            bhi hex_to_bcd_save_digit
            add r4, r4, #1
            sub r0, r0, r3
        b hex_to_bcd_accumulator
    
        hex_to_bcd_save_digit
            ;BCD's (unpacked) are 10 bytes
            add r5,r1, #10
            sub r5, r5, r2
            ;r5 is the digit we are filling (reverse order due to big endian)
            strb r4, [r5]
            sub r2,r2,#1

    b hex_to_bcd_subtract

    hex_to_bcd_end
    pop {r2,r3,r4,r5,r6,r7}
    mov pc, lr


;the following code is modified from /netopt/info/courses/COMP22712/Code_examples/bcd_convert.s
;but modified so that protects r3 (stack)
;-------------------------------------------------------------------------------

; 32-bit unsigned integer division R0/R1
; Returns quotient in R0 and remainder in R2
; Returns quotient FFFFFFFF in case of division by zero

divide
        push {r3}
		mov	r2, #0			; AccH
		mov	r3, #32			; Number of bits in division
		adds	r0, r0, r0		; Shift dividend

divide1		adc	r2, r2, r2		; Shift AccH, carry into LSB
		cmp	r2, r1			; Will it go?
		subhs	r2, r2, r1		; If so, subtract
		adcs	r0, r0, r0		; Shift dividend & Acc. result
		sub	r3, r3, #1		; Loop count
		tst	r3, r3			; Leaves carry alone
		bne	divide1			; Repeat as required

        pop {r3}
		mov	pc, lr			; Return

;-------------------------------------------------------------------------------
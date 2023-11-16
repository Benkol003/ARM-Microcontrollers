
;----- reusable userspace code functions --------

;-------- DEFINITIONS REQUIRED IN USER PROGRAM FILE: --------;
;
; KEYPAD_DATA_OFFSET, KEYPAD_CONTROL_OFFSET - The respective offset's to address 0x2xxxxxxx for those fpga bytes respectfully.
;
; keypad_switched_evhdl - function callback for when the keypad poller detects a key state switch event 
; - when key has transitioned between key states down -> up or up -> down. See below for arguements passed to the callback.
;
; if you are using this callback/the keypad, you will also need to call / bl keypad_init (for initialisation) at the start of
; your main function.
;------------------------------------------------------------;


ten_exp_ten DEFW 10000000000

hex_to_BCD ;REQUIRED: you allocate an array of 10 bytes and pass the pointer to start address.
    ;note we are using unpacked bcd
    ;args: r0 - hex number, r1 - pointer to BCD string to fill; 32 bit number need 10 BCD digits - 10 BYTES REQUIRED.
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

    divide1		
        adc	r2, r2, r2		; Shift AccH, carry into LSB
		cmp	r2, r1			; Will it go?
		subhs	r2, r2, r1		; If so, subtract
		adcs	r0, r0, r0		; Shift dividend & Acc. result
		sub	r3, r3, #1		; Loop count
		tst	r3, r3			; Leaves carry alone
		bne	divide1			; Repeat as required

        pop {r3}
		mov	pc, lr			; Return

;-------------------------------------------------------------------------------


;-------- stack zeroer --------;

forward_array_zeroer
    ;DO NOT use this to initialise an array declared like this: DEFS n array_label
    ;r0 - (beggining of) byte array pointer; declared in manner: array_label DEFS n
    ;r1 - array size
    push {r0 - r2}

    add r2, r0, r1
    mov r1, #0
    forward_array_zeroer_loop

        strb r1, [r0]
    
    add r0, r0, #1
    cmp r0, r2
    blo forward_array_zeroer_loop

    pop {r0 - r2}
    mov pc, lr


;------------------------------;


;-------- KEYPAD --------;


keypad_symbols DEFB '3','6','9','#','2','5','8','0','1','4','7','*'
keypad_saturate EQU 10

keypad_counter DEFS 12 ;keeps track of each keys value (w saturation)

keypad_status DEFS 12 ;keep track of the previous state of 0 -> not pressed, >=1 pressed

ALIGN
keypad_init
    push {r0 - r1, lr}
    ;initialise fpga control to read S0
    ldr r0, =KEYPAD_CONTROL_OFFSET
    ldr r1, =0b000_1_1111;keypad bit config for scanning
    svc 5

    ;initialise the keypad_counter and keypad_status arrays to 0
    mov r1, #12
    adr r0, keypad_counter
    bl forward_array_zeroer
    adr r0, keypad_status
    bl forward_array_zeroer

    pop {r0 - r1, lr}
    mov pc, lr

keypad_poll_handler
    ;NOTE keypad_init needs to have been called previously.
    push {r0-r11, lr}

    ;iii X oooo xxxxxxxx
    mov r2, #0 ; <= i < 3 
    ;syncing fpga data - can lsl the top 3 bits that do scanning
    ldr r0, =KEYPAD_DATA_OFFSET
    mov r1, #:001_0_0000;select row ; shift this to change row


        keypad_poll_handler_rowscan
        mov r4, #0 ; <= j < 4
        mov r5, #:0001 ; key offset/column select part

        ;sync fpga data
        svc 6

            keypad_poll_handler_columnscan

                mov r6, #4
                mla r7, r6, r2, r4 ; offset for keypad_counter = 4i+j
                
                ldr r10, =keypad_saturate
                ;r8 now used as the address+offset for keypad_counter
                adr r8, keypad_counter
                add r8, r8, r7 ;real address offset
                
                ;test if key pressed
                tst r5, r1
                bne keypad_poll_handler_pressed
                beq keypad_poll_handler_nopress

                ;key saturation value can be between 0 - keypad_saturate.

                keypad_poll_handler_pressed
                    ldrb r9, [r8]
                    cmp r9, r10 ;bounds checking
                    addlo r9, r9, #1
                    strb r9, [r8]
                    b keypad_poll_handler_end1

                keypad_poll_handler_nopress
                    ldrb r9, [r8]
                    cmp r9, #0 ;bounds checking
                    subhi r9, r9, #1 
                    strb r9, [r8]

                keypad_poll_handler_end1

                ;generate events for key being up/down in current poll cycle
                cmp r9, #0
                mov r11, #0
                bleq keypad_status_handler
                
                cmp r9, r10
                mov r11, #1
                blhs keypad_status_handler

                

                add r4, r4, #1
                lsl r5, r5, #1
                cmp r4, #4
            blo keypad_poll_handler_columnscan

        add r2, r2, #1
        lsl r1, r1, #1
        cmp r2, #3
        blo keypad_poll_handler_rowscan

    pop {r0-r11, lr}

    mov pc, lr


;----------------
;
;this function handles the event of when the poll handler detects the key is fully up or down after applying saturation threshold saturation
;ARGS: R11 - button status : 0 -> off/up, 1-> on/down/pressed
;the key being handled has its offset passed through R7 from the code

keypad_status_handler
    push {r0,r1, r7, r11, lr}

    adr r0, keypad_status
    add r0, r0, r7 ; calculate address offset

    ldrb r1, [r0]

    cmp r1, r11
    beq keypad_status_handler_end
    strb r11, [r0]
    bl keypad_switched_evhdl ;DEFINE IN USER CODE FILE. event handler for keypad button switching from on-off / off-on.
    ;r1 - previous state. r11 - current state, r7 - offset

    keypad_status_handler_end
    pop {r0,r1, r7, r11, lr}
    mov pc, lr

;----------------
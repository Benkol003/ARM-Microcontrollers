
fifo_max EQU 256
fifo_start DEFS fifo_max
fifo_end
ALIGN

fifo_head DEFW 0
fifo_tail DEFW 0
fifo_size DEFW 0

;FIFO to store key events - byte values are stored only.

; NOTE: MUST CALL fifo_init at the start of your main function if you use this.

;NOTE: value '0' is a reserved value to indicate when the queue is empty. If you ignore this, you WILL break the implementation.

;-------- FIFO codes --------;
; 0 - FIFO empty / null event - dont push this to the fifo.
; 1 - lower button pressed / ST2
; 2 - upper button pressed / ST3
; 3 - top right button pressed / ST4
; 42, 35, 48 - 57 : these are ascii values for chars 0-9, * and # - these correspond to keypad keys when ONE keypad is connected.
;255 - reserved (used to indicate an accepting event / any key)
;----------------------------;

fifo_init
    push {r0-r2}
    adr r0, fifo_start
    adr r1, fifo_head
    adr r2, fifo_tail

    str r0, [r1]
    str r0, [r2]

    mov r0, #0
    adr r1, fifo_size
    str r0, [r1] 

    pop {r0-r2}
    mov pc, lr

fifo_ptr_decr
    ;handles the case of when the pointer wraps around the beggining
    ;assumes pointer is in r1
    push {r2}
    adr r2, fifo_start

    ;pointer is at start of array; therefore need to wrap around to last element
    cmp r1, r2
    beq fifo_ptr_decr_wrap
    sub r1, r1, #1 ;else just do a normal --r0;
    b fifo_ptr_decr_end
    
    fifo_ptr_decr_wrap
    adr r2, fifo_end
    sub r1, r2, #1 ;ptr = array end - 1 (last element)

    fifo_ptr_decr_end
    pop {r2}
    mov pc, lr

;DONT EVER PUSH A VALUE OF 0.
fifo_push
    ;r0 - value to push to fifo
    push {r1-r7, lr}

    ;check r0 value
    cmp r0, #0
    beq sys_abort_data

    
    adr r2, fifo_head

    adr r4, fifo_tail

    adr r6, fifo_size
    ldr r7, [r6]


    cmp r7, #fifo_max
    bne fifo_push_nodiscard
        ;here the FIFO is full; therefore discard an element by decrementing fifo_tail
        
        ;decrement the tail pointer
        ldr r1, [r4]
        bl fifo_ptr_decr
        str r1, [r4] ;save

        sub r7, r7, #1 ;decrement size

    fifo_push_nodiscard
    ;now to put the value in the fifo

    ;decrement head pointer
    ldr r1, [r2]
    bl fifo_ptr_decr
    strb r0, [r1]

    ;increment size
    add r7, r7, #1

    ;save new values for head pointer and size
    str r1, [r2]
    str r7, [r6] 

    pop {r1-r7, lr}
    mov pc, lr

;AS THIS RETURNS A VALUE OF 0 WHEN FIFO EMPTY
fifo_pop
    ;r0 - return value / 0 when FIFO empty
    push {r1-r2, lr}

    ;if empty return 0
    adr r1, fifo_size
    ldr r1, [r1]
    cmp r1, #0
    bhi fifo_pop_noempty
    mov r0, #0
    b fifo_pop_end

    fifo_pop_noempty
    adr r2, fifo_tail
    ldr r1, [r2]
    bl fifo_ptr_decr
    ldrb r0, [r1]
    str r1, [r2]

    ;decrement size
    adr r1, fifo_size
    ldr r2, [r1]
    sub r2, r2, #1
    str r2, [r1]

    fifo_pop_end
    pop {r1-r2, lr}
    mov pc, lr




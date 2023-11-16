;-------- DEFINITIONS REQUIRED IN USER PROGRAM FILE: --------;
;
; main - entry point for userspace/user-defined code.
; isr_timer_callback - callback for the timer interrupt. You will be required to set up the
; interrupt again in this with SVC 4 for the case of interrupting at regular intervals.
;
;------------------------------------------------------------;


org &0
    b sys_reset
    b sys_undefined
    b sys_SVC
    b sys_abort_prefetch
    b sys_abort_data
    DEFW 0
    b sys_irq
    b sys_fiq

ALIGN
    PIO_A equ &10000000
    PIO_B equ &10000004
    PIO_B_BTN_LOWER_BIT equ :10000000 
    PIO_B_BTN_UPPER_BIT equ :01000000
    ADR_TIMER equ &10000008
    ADR_FPGA equ &20000000
    MODE_MASK DEFW &FFFFFFE0
    MODE_USER DEFW :10000
    MODE_IRQ DEFW :10010
    HALT DEFW &10000020

;--------   stacks  --------;
ALIGN
DEFS 8192 ;8KiB stack - 2048 stack vars
sys_stack

ALIGN
DEFS 8192
irq_stack

ALIGN
DEFS 8192
user_stack ;for user mode

;--------------------------;

;----   SVC CODES ----;
;SVC codes are expected to change between exercises
;(same SVC function may have a different code)

;SVC 0 - reset system
;SVC 1 - halt system
;SVC 2 - read PIO_A
;SVC 3 - read PIO_B
;SVC 4 - set interrupt for timer value
;SVC 5 - set fpga connector control
;SVC 6 - sync fpga connector data
;SVC 7 - read timer value
;SVC 8 - LED's control
;SVC 9 - lcd backlight control
;SVC 10 - clear lcd
;SVC 11 - print char
;SVC 12 - print string (null terminated)
;SVC 13 - print BCD string
;SVC 14 - set LCD cursor position

ALIGN
SVC_TABLE
    b sys_reset
    b sys_halt
    b read_pio_a
    b read_pio_b
    b set_timer_isr
    b fpga_control
    b fpga_data
    b read_timer
    b led_control

    b lcd_backlight_control
    b lcd_cls
    b print_char
    b print_str
    b print_bcd
    b lcd_set_cursor
MAX_SVC

;--------   EXCEPTION HANDLER --------;

ALIGN
sys_reset
    adrl sp, sys_stack
    mov r0, #0
    bl led_control ;disable leds (enabled on reset)

    ;clear IRQ bits
    mov r2, #0
    ldr r0, =&10000018
    strb r2, [r0]

    ;enable ISR's
    mov r0, #:11000000
    ldr r1, =&1000001C
    strb r0, [r1]

    ;enable IRQ
    mrs r0, cpsr
    bic r0, r0, #:10000000
    msr cpsr, r0
    ;----------------------
    ;switch to IRQ mode
    adrl r1, MODE_MASK
    ldr r1, [r1]
    and r0, r0, r1
    adrl r1, MODE_IRQ
    ldr r1, [r1]
    orr r0, r0, r1
    msr CPSR, r0

    ;setup IRQ stack
    ldr sp, =irq_stack

    ;switch to user model
    adrl r1, MODE_MASK
    ldr r1, [r1]
    and r0, r0, r1
    adrl r1, MODE_USER
    ldr r1, [r1]
    orr r0, r0, r1
    msr CPSR, r0

    ;load user stack
    ldr sp, =user_stack
    b main ; **** DEFINE THIS LABEL IN USER CODE ****
    b sys_halt 


sys_halt
    adrl r0, HALT
    ldr r0, [r0]
    mov r1, #1
    str r1,[r0]

sys_SVC

    push {r4, r5}

    ;get SVC code
    ldr r4, [lr, #-4]
    bic r4, r4, #&FF000000

    ;check SVC code is within range
    adr r5, MAX_SVC
    cmp r4, r5
    bhs sys_undefined

    lsl r4, r4, #2

    adr r5, SVC_TABLE
    add r4, r4, r5

    push {lr}

    mov lr, pc
    mov pc, r4 ;branch from SVC table


    pop {lr}
    pop {r4, r5}

    movs pc, lr


sys_undefined
b sys_halt

sys_abort_prefetch
b sys_halt

sys_abort_data
b sys_halt

;----------- INTERRUPT HANDLERS -------
ALIGN
isr_table
    b isr_timer
    b sys_halt
    b sys_halt
    b sys_halt
    b sys_halt
    b sys_halt
    b isr_btn_upper
    b isr_btn_lower

sys_irq
    push {r0, r2, r3, r4, lr}
    ;load table adr
    adr r3, isr_table

    ;get the interrupt bits/byte
    mov r2, #0 ;table offset, do +4 for PC
    ldr r0, =&10000018
    ldrb r0, [r0]

    ;loop and process every bit in turn
    sys_irq_loop
        tst r0, #1
        add r4, r2, r3
        mov lr, pc
        movne pc, r4

        add r2, r2, #4 ;next table entry - one word
        lsr r0, r0, #1 ;shift for the next table entry
        cmp r2, #36
    blo sys_irq_loop

    ;clear IRQ bits
    mov r2, #0
    ldr r0, =&10000018
    strb r2, [r0]

    pop {r0, r2, r3, r4, lr}
    sub lr, lr, #4 ;again PC offset as the instruction interrupted doesnt actually get executed
    movs pc, lr



sys_fiq
    b sys_halt ;apparently there are no FIQ requesters?

;--------------------------------------

;------------ ISR's -------------------

;the code for these is expected to change per exercise

isr_timer
    push {r0, r1, r2, lr}
    ;disable the timer interrupt
    ldr r1, =&1000001C
    mov r0, #1
    ldrb r2, [r1]
    bic r2, r2, r0
    strb r2, [r1]


    ;DEFINE THIS LABEL IN USER CODE
    bl isr_timer_callback

    pop {r0, r1, r2, lr}
    mov pc, lr

;-------- Board Button Interrupts --------

;---------
;check these byte addresses to check if the button has been pressed; the checking program should then reset the value to 0.
;Given that the other buttons/keypad require polling aswell then using callbacks here is not worth it.
;
;these are booleans (0 False, otherwise(or =1) true)
btn_lower_status DEFB 0
btn_upper_status DEFB 0
ALIGN


isr_btn_lower
    push {r0, lr}
    mov r0, #1
    bl fifo_push
    pop {r0, lr}
    mov pc, lr

isr_btn_upper
    push {r0, lr}
    mov r0, #2
    bl fifo_push
    pop {r0, lr}
    mov pc, lr
;--------------------------------------


;-------------------------------------;

;--------   SVC routines    --------

;******** USE LDRB for I/O access - all are bytes - (then ldr for loading I/O address) ********
set_timer_isr
    push {r1, r2}
    ;R0 - how long to wait before interrupting, ms (max delay 255ms)

    cmp r0, #255
    bhi sys_abort_data ;abort if you try to request a delay that is longer than possible

    ;current timer value
    ldr r1, =&10000008
    ldr r1, [r1]
    add r0, r0, r1
    cmp r0, #255
    subhi r0, r0, #256 ;wrap around if past value 255

    ;store value in memory
    ldr r1, =&1000000C
    strb r0, [r1]

    ;enable the interrupt
    ldr r1, =&1000001C
    mov r0, #1
    ldrb r2, [r1]
    orr r2, r2, r0
    strb r2, [r1]

    pop {r1, r2}
    mov pc, lr


read_pio_a
    ;r0 return arg
    ldr r0, =PIO_A
    ldrb r0, [r0]
    mov pc, lr

read_pio_b
    ldr r0, =PIO_B
    ldrb r0, [r0]
    mov pc, lr

read_timer
    ;return value: r0
    ldr r0, =ADR_TIMER
    ldrb r0, [r0]
    mov pc, lr


led_control
    push {r1,r2,r3}
    ;ARGS: r0 = {0->off, 1-> on}
    ldr r1, =PIO_B
    mov r2, #:10000
    ldrb r3, [r1]

    teq r0, #1
    bne led_control_disable
    orr r3, r3, r2
    b led_control_end

    led_control_disable
    bic r3, r3, r2

    led_control_end
    strb r3, [r1]

    pop {r1,r2,r3}
    mov pc, lr

lcd_backlight_control
    ;ARGS: r0 - 0 - off, >=1 - on
    push {r4, r5, r6}

    mov r4, #0b00100000
    ldr r5, =PIO_B
    ldrb r6, [r5]

    TEQ r0, #0
    beq lcd_backlight_control_disable 
    
    ;on
    orr r6,r6,r4
    b lcd_backlight_control_end

    lcd_backlight_control_disable
    bic r6,r6,r4

    lcd_backlight_control_end
    strb r6, [r5]
    pop {r4, r5, r6}
    mov pc,lr

lcd_strobe ;strobe the enable flag
    push {r1,r3,r4}
    ldr r1, =PIO_B
    mov r3, #1
    ldrb r4, [r1]
    orr r4,r4,r3
    strb r4,[r1]

    ;disable
    ldrb r4, [r1]
    bic r4,r4,r3
    strb r4,[r1]

    pop {r1,r3,r4}
    mov pc,lr


lcd_wait
    push {r0,r1,r3,r4}
    ldr r0, =PIO_A
    ldr r1, =PIO_B
    ;set flags to read control - R/W=1. RS=0, (enable=0)
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
        ldrb r4, [r0]
        tst r4, #0b10000000

        ;disable
        ldrb r4, [r1]
        bic r4,r4,r3
        strb r4,[r1]

        bne lcd_wait_loop ;wait until not busy

    pop {r0,r1,r3,r4}
    mov pc,lr

lcd_cls ;clear lcd
    push {r0,r1,r3,r4,lr}
    ldr r0, =PIO_A
    ldr r1, =PIO_B
    bl lcd_wait
    ;R/W=0, RS=0, (enable=0)
    mov r3, #0b111
    ldrb r4, [r1]
    bic r4,r4,r3
    strb r4, [r1]

    ;IR = 1 for clear instruction
    mov r3, #1
    strb r3, [r0]

    bl lcd_strobe

    pop {r0,r1,r3,r4,lr}
    mov pc, lr


print_str ; must be null-terminated
    ;ARGS: R0 - string pointer

    push{r1,lr}

    print_str_loop
    ldrb r1, [r0]
    teq r1, #0
    beq print_str_end
    bl print_char
    add r0, r0, #1
    b print_str_loop

    print_str_end
    pop{r1,lr}
    mov pc, lr

print_char
    ;ARGS: CONST R1 - ascii char to print
    ;vars: r3 r4
    push {r3,r4,r5,r6}

    ldr r5, =PIO_A
    ldr r6, =PIO_B

    push {lr}
    bl lcd_wait
    pop {lr}

    ;set flags to write data reg
    ldrb r4,[r6]
    mov r3, #0b010
    orr r4,r4,r3
    mov r3, #0b101
    bic r4,r4,r3
    strb r4,[r6]

    ;write char code - ROM code: A00
    strb r1, [r5]

    ;---- strobe enable
    push {lr}
    bl lcd_strobe
    pop {lr}

    pop {r3,r4,r5,r6}
    mov pc,lr




print_bcd ;print a 10-byte BCD string (little endian)
    ;args: r0 - pointer to BCD string (10 bytes large)
    ;note this will get rid of leading zeros
    push {r1,r2,r3,lr}

    ;skip over leading zeros
    mov r1, #0
    print_bcd_adjust
        ldrb r2, [r0, r1]
        cmp r1, #9 ;if BCD string = 0 then check to make sure doesnt run off the end
        ;need to test this condition first aswell
        beq print_bcd_zero
        cmp r2, #0
        bne print_bcd_adjusted
        add r1, r1, #1
    b print_bcd_adjust

    print_bcd_zero
    sub r1, r1, #0

    print_bcd_adjusted
    mov r2, r1

    print_bcd_loop
        add r3, r0, r2
        ldrb r1, [r3]
        add r1, r1, #48
        bl print_char
        add r2, r2, #1
        cmp r2, #10
        bge print_bcd_end
    b print_bcd_loop

    print_bcd_end
    pop {r1,r2,r3,lr}
    mov pc, lr

;to print on line one pass value LCD_LINE1 + column offset
LCD_LINE1 equ 0x40

lcd_set_cursor
;R0 - hex cursor offset value. Line 0 from 0x00-0x0f, line 1 from 0x40-0x4f.(16x2 display)
    push {r0-r4, lr}
    ;R/W=0, R/S=0, (enable=0)
    ldr r1, =PIO_A
    ldr r2, =PIO_B
    bl lcd_wait
    ;R/W=0, RS=0, (enable=0)
    mov r3, #0b111
    ldrb r4, [r2]
    bic r4,r4,r3
    strb r4, [r2]

    ;set row
    mov r3, #&80
    orr r0, r0, r3

    strb r0, [r1]

    bl lcd_strobe

    pop {r0-r4, lr}
    mov pc, lr

fpga_data
    ;R0: connector number S1/S2/S3 / offset | const
    ;R1: bidrectional R/W for 8 bits for PIO_x data register // upper or lower set of pins on board connector (sync data with this register) (used as return register)
    
    push {r3}

    ldr r3, =ADR_FPGA
    add r3, r3, r0

    ;sync byte
    strb r1, [r3] ;read-only pins should not change
    ldrb r1, [r3]

    pop {r3}
    mov pc, lr


fpga_control
    ;set PIO_x control data register / set board connector pins as R/W - again for 1 byte / upper or lower pin set only.
    ;R0 - fpga address offset
    ;R1 - bits for each pin 0-> read 1-> write for 8 bits
    push {r3}

    ldr r3, =ADR_FPGA
    add r3, r3, r0

    ;set control bits
    strb r1, [r3]

    pop {r3}
    mov pc, lr

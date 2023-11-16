org &0
b main
;----   stack and global/constant variables ----
;here so that LDR Rn, =label can reach it (/stack) with offsets
;also if we need to use absolute addresses its easier as we can garuntee its some distance from 0x0, rather than being after 
;a lot of code we dont know the length of, and is most likely going to change.

ALIGN
PIO_A equ &10000000
PIO_B equ &10000004
HALT equ &10000020

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
ldr r0, =PIO_A
ldr r1, =PIO_B ; constant registers
; you better not change these :D

;disable leds - enabled on reset
ldrb r4, [r1]
mov r3, #0b10000
bic r4,r4,r3
strb r4, [r1]

bl lcd_backlight_enable

bl lcd_cls

ldr r11, =greet_topline
bl print_str

bl lcd_cursor_bottom_line

ldr r11, =greet_bottomline
bl print_str

main_keypoll
ldrb r4, [r1]
lsr r4, r4, #6


teq r4, #2
bne main_s1
ldr r11, =str_bottom
bl lcd_cls
bl print_str

main_s1
teq r4, #1
bne main_keypoll
ldr r11, =str_top
bl lcd_cls
bl print_str

b main_keypoll

;yes, this is unreachable. But is it safe/good practice? very much yes.
ldr r0, =HALT
mov r1, #1
strb r1,[r0]
;---- main END  ----


;---- function definitions ----

;---- ADDING LCD FUNCTIONS: ----
;-- call lcd_wait
;-- set your RS, R/W, (enable) flags, and Instr/data register in PIO_A
;-- call lcd_strobe

;yes, i dont need to save r3/r4 in pretty much all of these cases, but it's pragmatic s.t. i can reuse this code later on
;we can use either the stack or registers for arguements - if function f1 calls f2, then its f1's responsibility to sort out the args for f2.
;usually by saving registers to stack, then moving args into them before doing BL.


lcd_strobe ;strobe the enable flag
    ;vars r3, r4
    push {r3,r4}

    mov r3, #1
    ldrb r4, [r1]
    orr r4,r4,r3
    strb r4,[r1]

    ;disable
    ldrb r4, [r1]
    bic r4,r4,r3
    strb r4,[r1]

    pop {r3,r4}
    mov pc,lr


lcd_wait
    push {r3,r4}

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

    pop {r3,r4}
    mov pc,lr


print_str ; must be null-terminated
    ;ARGS: R11 - string pointer
    push{lr}

    print_str_loop
    ldrb r12, [r11]
    teq r12, #0
    beq print_str_end
    bl print_char
    add r11, r11, #1
    b print_str_loop

    print_str_end
    pop{lr}
    mov pc, lr

print_char
    ;ARGS: CONST R12 - ascii char to print
    ;vars: r3 r4
    push {r3,r4}

    push {lr}
    bl lcd_wait
    pop {lr}

    ;set flags to write data reg
    ldrb r4,[r1]
    mov r3, #0b010
    orr r4,r4,r3
    mov r3, #0b101
    bic r4,r4,r3
    strb r4,[r1]

    ;write char code - ROM code: A00
    strb r12, [r0]

    ;---- strobe enable
    push {lr}
    bl lcd_strobe
    pop {lr}

    pop {r3,r4}
    mov pc,lr


lcd_cls ;clear lcd
    push {r3,r4}

    push {lr}
    bl lcd_wait
    pop {lr}

    ;R/W=0, RS=0, (enable=0)
    mov r3, #0b111
    ldrb r4, [r1]
    bic r4,r4,r3
    strb r4, [r1]

    ;IR = 1 for clear instruction
    mov r3, #1
    strb r3, [r0]

    push {lr}
    bl lcd_strobe
    pop {lr}

    pop {r3,r4}
    mov pc, lr


lcd_backlight_enable
    push {r3,r4}

    mov r3, #0b00100000
    ldrb r4, [r1]
    orr r4,r4,r3
    strb r4, [r1]

    pop {r3,r4}
    mov pc, lr

lcd_cursor_bottom_line
    push {r3,r4,lr}

    bl lcd_wait

    ;R/W=0, RS=0 (enable=0)
    mov r3, #0b111
    ldrb r4, [r1]
    bic r4,r4,r3
    strb r4, [r1]

    ;cursor instruction
    mov r3, #0b11000000
    strb r3, [r0]

    bl lcd_strobe

    pop {r3,r4,lr}
    mov pc, lr
### static values / constants

literals:
decimal - defualt - #10
hex - &, $ or 0x - &ff
binary - 0b, :

label equ &value - attempts to calculate an immediate value, otherwise use pc offset to the label address value to load it
e.g.  ldr r0, =label
becomes
ldr r0, #n
or
ldr r0, [pc, #n]

if neither work then use 

label DEFW/DEFB &value

then try in succession
ldr r0, label
otherwise

adr/adrl r0, label
ldr r0, [r0]
adrl will work in (pretty much) every case but is the slowest
however CANT USE AN UNALIGNED DEFB


### Calling Functions
ALWAYS push/pop (save) any internal variable registers that are used. This is to stop bugs and massive fucking headache down the line ok.

### Swapping registers
Without using another register: swapping x and y:

x = x XOR y
y = x XOR y
x = x XOR y

### Binary Coded Decimal
max decimal value for a register is 4294967295 (unsigned)
using unpacked BCD you will require 10 bytes (or 3 words if its aligned)

to pop/push induvidual bytes:

ldrb rN, sp, #1
strb rN, [sp, #-1]!

### Condition flags
CMP and TST do SUBS and ANDS respectively;
there are signed and unsigned versions of conditions - e.g. HI - unsigned higher - GT - signed higher

note if you're doing cmp for boolean stuff - dont do cmp rN, #1 in cases where youre doing say,
and on PIO_B with a bitmask, as it wont =1, maybe 0b0100..
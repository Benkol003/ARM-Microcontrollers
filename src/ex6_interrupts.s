include ../lib/sys.s

ALIGN

main
svc 9
mov r0, #1
svc 8
mov r0, #0
loop
add r0, r0, #1
sub r0, r0, #1
b loop
svc 1
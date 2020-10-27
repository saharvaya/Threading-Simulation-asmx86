section .rodata

section .data
   extern BOARD_SIZE

section .bss
   global x_target
   global y_target
   extern temp_float
   x_target: resq  1 ; x target position (float)
   y_target: resq  1 ; y target position (float)

section .text
   align 16
   global createTarget
   global target_routine
   extern resume
   extern get_random_scaled
   extern scheduler_co

createTarget:
   push ebp
   mov ebp, esp
   pushad

   push dword [BOARD_SIZE]
   call get_random_scaled
   add esp, 4
   fld dword [temp_float]
   fstp dword [x_target]  ; assign psuedo-random drone x position

   push dword [BOARD_SIZE]
   call get_random_scaled
   add esp, 4
   fld qword [temp_float]
   fstp qword [y_target]  ; assign psuedo-random drone x position

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

target_routine:
   call createTarget
   mov ebx, scheduler_co
   call resume
   jmp target_routine

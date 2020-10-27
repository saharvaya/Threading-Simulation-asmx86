section .rodata
   err_arg_count: db "Insufficient arguemnt count! usage: ./ass3 <N> <T> <K> <β> <d> <seed>", 10, "N - number of drones", 10, "T - number of targest needed to destroy in order to win the game", 10, "K – how many drone steps between game board printings", 10, "β – angle of drone field-of-view", 10, "d – maximum distance that allows to destroy a target", 10, "seed - seed for initialization of LFSR shift register", 10, 0

   winner_format: db "Drone id %d: I am a winner", 10, 0
   target_format: db "%.2f,%.2f", 10, 0
   drone_format: db "%d,%.2f,%.2f,%.2f,%d", 10, 0
   string_format: db "%s", 0

section .data
   extern id
   extern x
   extern y
   extern alpha
   extern destroyed

section .bss
   extern x_target
   extern y_target
   extern drone_arr
   extern drone_count
   extern drone_sz
   extern drone

   extern temp_float

section .text
   align 16
   global printer_routine
   global print_err
   global print_board
   global print_target
   global print_winner
   extern resume
   extern scheduler_co
   extern radians_to_degrees

   extern printf

print_err:
   push ebp
   mov ebp, esp
   pushad

   push err_arg_count
   push string_format
   call printf
   add esp, 8

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

print_drone:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]

   mov edx, [destroyed]
   push dword [ebx + edx]

   mov edx, [alpha]
   fld dword [ebx + edx]
   sub esp, 8
   fstp qword [esp]

   mov edx, [y]
   fld dword [ebx + edx]
   sub esp, 8
   fstp qword [esp]

   mov edx, [x]
   fld dword [ebx + edx]
   sub esp, 8
   fstp qword [esp]

   mov edx, [id]
   push dword [ebx + edx]

   push drone_format
   call printf
   add esp, 36

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

print_target:
   push ebp
   mov ebp, esp
   pushad

   fld dword [y_target]
   sub esp, 8
   fstp qword [esp]
   fld dword [x_target]
   sub esp, 8
   fstp qword [esp]
   push target_format
   call printf
   add esp, 20

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller


print_board:
   push ebp
   mov ebp, esp
   pushad

   call print_target
   mov edi, dword 0
   print_drones:
      mov ebx, [drone_arr]
      mov eax, edi
      mov ecx, dword [drone_sz]
      mul ecx
      add ebx, eax
      push dword ebx
      call print_drone
      add esp, 4
      inc edi
      cmp edi, dword [drone_count]
      jne print_drones

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

print_winner:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]

   push ebx
   push winner_format
   call printf
   add esp, 8

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

printer_routine:
   call print_board
   mov ebx, scheduler_co
   call resume
   jmp printer_routine

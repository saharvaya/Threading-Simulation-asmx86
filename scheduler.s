section .rodata

section .data
   extern co_sz
   extern printer_co

   curr_step: dd 0

section .bss
   extern drone_count
   extern co_arr
   extern curr_id
   extern drone_steps

section .text
   align 16
   global scheduler_routine

   extern print_board
   extern resume
   extern endCo

scheduler_routine:
   mov esi, 0

   round_robin:
      xor eax, eax
      mov eax, esi
      mov cx, [drone_count]
      xor edx, edx
      div cx
      mov eax, [co_sz]
      mov [curr_id], dword edx   ; store current operating drone id
      mov ecx, edx
      mul ecx
      mov ebx, [co_arr]
      add ebx, eax
      call resume
      inc esi
      mov edi, dword [drone_steps]
      inc dword [curr_step]
      cmp dword [curr_step], edi
      je print_game_board
      jmp continue_round_robin

      print_game_board:
         mov ebx, printer_co
         call resume
         mov [curr_step], dword 0

      continue_round_robin:
         jmp round_robin

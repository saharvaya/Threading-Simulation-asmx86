%define arg_count 6

%macro parse_str 2
   push edx
   mov esi, %1    ; format
   mov edi, %2    ; read to
   push edi
   push esi
   push dword [edx]
   call sscanf
   add esp, 12
   pop edx
%endmacro

%macro initCo 1
   mov ebx, %1
   mov edx, [func]
   mov eax, [ebx + edx]
   mov [TEMP_SP], esp
   mov edx, [stk]
   mov esp, [ebx + edx]
   push eax
   pushfd
   pushad
   mov [ebx + edx], esp
   mov esp, [TEMP_SP]
%endmacro

section .rodata
   in_decimal: db "%d", 0
   in_float: db "%f", 0

   LFSR_BIT_RESOLUTION: EQU 16
   RANDOM_MASK: EQU 0x2D	 ; 101101b Fibbonaci LFSR taps

section .data
   global func
   global stk

   global BOARD_SIZE
   global scheduler_co
   global printer_co
   global target_co
   global co_sz

   extern id
   extern x
   extern y
   extern alpha
   extern destroyed
   extern drone_sz

   co_r:
      func: dd 0 ; pointer to co-routine function offset
      stk: dd 4 ; pointer to co-routine stack offset
   co_sz: dd 8

   scheduler_co:
      dd scheduler_routine
      dd scheduler_stk + STK_SZ

   printer_co:
      dd printer_routine
      dd printer_stk + STK_SZ

   target_co:
      dd target_routine
      dd target_stk + STK_SZ

   MAXINT: dd 0xFFFF
   BOARD_SIZE: dd 100

section .bss
   global drone_arr
   global drone_count
   global co_arr
   global temp_float
   global win_count
   global drone_steps
   global beta_angle
   global max_delta

   drone_arr: resd 1
   co_arr: resd 1
   co_count: resd 1
   drone_co_stks: resd 1

   ; program parsed arguments
   drone_count: resd 1
   win_count: resd 1
   drone_steps: resd 1
   beta_angle: resq 1
   max_delta: resq 1
   seed: resd 1

   TEMP_SP: resd 1 ; temporary stack pointer
   SP_MAIN: resd 1 ; stack pointer to main
   CURR_CO: resd 1

   STK_SZ: EQU 16 * 1024
   scheduler_stk: resb STK_SZ
   printer_stk: resb STK_SZ
   target_stk: resb STK_SZ

   temp_float: resd 1

section .text
      align 16
      global main
      global get_random_scaled
      global radians_to_degrees
      global degrees_to_radians
      global resume
      global endCo

      extern print_board

      extern createDrone
      extern createTarget

      extern scheduler_routine
      extern printer_routine
      extern target_routine
      extern drone_routine

      extern print_err
      extern printf
      extern sscanf
      extern malloc
      extern free

      extern stdin
      extern stderr

main:
   ;parse and store arguments
   mov ecx, [esp + 4] ; argc
   mov edx, [esp + 8] ; argv
   cmp ecx, dword arg_count + 1
   jl arg_err
   add edx, 4  ; ignore path
   parse_str in_decimal, drone_count
   add edx, 4
   parse_str in_decimal, win_count
   add edx, 4
   parse_str in_decimal, drone_steps
   add edx, 4
   parse_str in_float, beta_angle
   add edx, 4
   parse_str in_float, max_delta
   add edx, 4
   parse_str in_decimal, seed

   finit
   mov ebx, dword [drone_count]
   add ebx, 2
   mov dword [co_count], ebx

   call createTarget
   call init_drones
   call init_co_additional ; initiates target, printer, scheduler co-routines

   call startCo

   endCo:
      mov esp, [SP_MAIN]
      popad

   call free_mem_alloc
   jmp finish

   arg_err:
      call print_err

   finish:
      ffree
      mov eax, 1
      mov ebx, 0
      int 0x80
      nop

init_drones:
   push ebp
   mov ebp, esp
   pushad

   mov eax, dword [drone_count] ; allocate array size drone_count * drone_size to hold drones
   mov ecx, dword [drone_sz]
   mul ecx
   push eax
   call malloc
   add esp, 4
   mov dword [drone_arr], eax

   mov eax, dword [drone_count] ; allocate array size drone_count * co_size to allocate drone co-routines
   mov ecx, dword [co_sz]
   mul ecx
   push eax
   call malloc
   add esp, 4
   mov dword [co_arr], eax

   mov eax, STK_SZ
   mov ecx, dword [drone_count]
   mul ecx
   push eax
   call malloc
   add esp, 4
   mov [drone_co_stks], eax

   mov esi, 0  ; current index
   init_drone:
      mov ebx, [drone_arr]    ; init drones structs
      mov eax, esi
      mov ecx, dword [drone_sz]
      mul ecx
      add ebx, eax

      push ebx
      call createDrone
      add esp, 4

      mov ebx, [co_arr]    ; init drones co-routines
      mov eax, esi
      mov ecx, dword [co_sz]
      mul ecx
      add ebx, eax

      push esi
      push ebx
      call init_co_drone
      add esp, 8

      inc esi  ; increment drone index
      cmp esi, dword [drone_count]
      jne init_drone

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller


init_co_drone:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]
   mov esi, [ebp + 12]
   mov edx, [func]
   mov [ebx + edx], dword drone_routine

   mov eax, STK_SZ
   mov ecx, esi
   mul ecx
   add eax, [drone_co_stks]
   add eax, STK_SZ
   mov edx, [stk]
   mov [ebx + edx], eax

   mov [TEMP_SP], esp
   mov esp, eax
   push dword drone_routine
   pushfd
   pushad
   mov [ebx + edx], esp
   mov esp, [TEMP_SP]

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

init_co_additional:
   push ebp
   mov ebp, esp
   pushad

   initCo scheduler_co
   initCo printer_co
   initCo target_co

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

startCo:
   pushad
   mov [SP_MAIN], esp
   mov ebx, scheduler_co
   jmp do_resume

resume: ; save state of current co-routine
   pushfd
   pushad
   mov edx, [CURR_CO]
   mov edi, [stk]
   mov [edx + edi], esp ; save current ESP

   do_resume: ; load ESP for resumed co-routine
      mov edi, [stk]
      mov esp, [ebx + edi]
      mov [CURR_CO], ebx
      popad ; restore resumed co-routine state
      popfd
      ret ; "return" to resumed co-routine

scale:
   push ebp
   mov ebp, esp
   pushad

   fild dword [ebp + 8]    ; store current random number as FP
   fild dword [MAXINT]     ; store 0XFFF as FP
   fdivp                   ; store random/0xFFFF
   fild dword [ebp + 12]   ; store scale range as FP
   fmulp                   ; multiply random/0xFFFF by BOARD_SIZE to get location
   fstp dword [temp_float] ; store scaled location coordinate to temp_float

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret

get_random_scaled:
   push ebp
   mov ebp, esp
   pushad

   call random_word
   push eax
   push dword [ebp + 8]
   call scale
   add esp, 8

   popad; Restore caller state (registers)
   mov eax, temp_float
   pop ebp; Restore caller state
   ret

degrees_to_radians:
   push ebp
   mov ebp, esp
   pushad

   fld dword [temp_float]    ; store degrees as FP
   mov [temp_float], dword 180
   fldpi                   ; load pi
   fmulp                   ; degrees * pi
   fild dword [temp_float]
   fdivp                   ; degrees * pi / 180
   fstp dword [temp_float] ; store scaled location coordinate to temp_float

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret

radians_to_degrees:
   push ebp
   mov ebp, esp
   pushad

   fld dword [ebp + 8]    ; store degrees as FP
   mov [temp_float], dword 180
   fild dword [temp_float]
   fmulp                   ; degrees * 180
   fldpi                   ; load pi
   fdivp                   ; degrees * 180 / pi
   fstp dword [temp_float] ; store degree value in temp float

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret

random_word:
	mov ecx, LFSR_BIT_RESOLUTION ; this function creates random 16-bit word by calculation of 16 random bits
   next_bit:
	  call random_bit
     loop next_bit, ecx
   xor eax,eax
   mov ax, word [seed]
   ret

random_bit:
	mov al, RANDOM_MASK  ; 101101b Taps are in places 16, 14, 13, 11
	and al, [seed]    	; compute parity of bits (PF), clear CF
	jpe result_ok		   ; jump if even parity
	stc				      ; set carry flag to be 1
result_ok:
	rcr word [seed], 1 	 ; rotate with carry right newly generated bit (from CF) into pseudo-random state
   mov eax, dword [seed]
	ret

free_mem_alloc:
   push ebp
   mov ebp, esp
   pushad

   push dword [drone_arr]
   call free
   add esp, 4

   push dword [co_arr]
   call free
   add esp, 4

   push dword [drone_co_stks]
   call free
   add esp, 4

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

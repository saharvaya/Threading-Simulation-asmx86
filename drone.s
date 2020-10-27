; define boolean true and false
%define true 1
%define false 0

section .rodata

section .data
   global id
   global x
   global y
   global alpha
   global destroyed
   global drone_sz

   extern scheduler_co
   extern target_co
   extern BOARD_SIZE
   drone:
      id: dd 0
      x: dd 4 ; x position offset (float)
      y: dd 8 ; y position offset (float)
      alpha: dd 12 ; direction alpha angle offset (float)
      destroyed: dd 16  ; number of destroyed targets offset
   drone_sz: dd 20 ; 32 bytes allocated for each drone

section .bss
   global curr_id
   extern temp_float
   extern drone_arr
   extern x_target
   extern y_target
   extern win_count
   extern beta_angle
   extern max_delta

   curr_id: resd 1

section .text
   align 16
   global drone_routine
   global createDrone
   global checkWin

   extern resume
   extern endCo
   extern get_random_scaled
   extern degrees_to_radians
   extern radians_to_degrees
   extern print_winner

createDrone:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]

   mov edx, [id]
   inc esi
   mov [ebx + edx], dword esi

   push dword [BOARD_SIZE]
   call get_random_scaled
   add esp, 4
   fld dword [temp_float]
   mov edx, [x]
   fstp dword [ebx + edx]  ; assign psuedo-random drone x position

   push dword [BOARD_SIZE]
   call get_random_scaled
   add esp, 4
   fld dword [temp_float]
   mov edx, [y]
   fstp dword [ebx + edx]  ; assign psuedo-random drone x position

   push dword 360
   call get_random_scaled
   add esp, 4
   fld dword [temp_float]
   mov edx, [alpha]
   fstp dword [ebx + edx]  ; assign psuedo-random drone alpha angle

   mov edx, [destroyed]
   mov [ebx + edx], dword 0

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

calc_delta_alpha:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]

   push dword 120                ;  generate a random number in range [-60,60] degrees ∆α, with 16 bit resolution
   call get_random_scaled
   add esp, 4
   fld dword [temp_float]
   mov [temp_float], dword 60
   fild dword [temp_float]
   fsubp

   mov edx, [alpha]
   fld dword [ebx + edx]
   faddp

   mov [temp_float], dword 360
   fild dword [temp_float]
   fcomip
   jb wrap_degrees_down
   fldz
   fcomip
   ja wrap_degrees_up
   jmp store_degrees

   wrap_degrees_down:
      mov [temp_float], dword 360
      fild dword [temp_float]
      fsubp
      jmp store_degrees

   wrap_degrees_up:
      mov [temp_float], dword 360      ; not working correctly
      fild dword [temp_float]
      faddp

   store_degrees:
      fstp dword [ebx + edx]

   popad; Restore caller state (registers)
   pop ebp; Restore caller state
   ret; Back to caller

calc_delta_distance:
   push ebp
   mov ebp, esp
   pushad

   mov ebx, [ebp + 8]

   push dword 50               ; generate random number in range [0,50] ∆d, with 16 bit resolution
   call get_random_scaled
   add esp, 4

   mov ecx, dword [temp_float]   ; random ∆d in range [0,50]

   mov edx, [alpha]
   mov edi, [ebx + edx]
   mov [temp_float], dword edi
   call degrees_to_radians
   fld dword [temp_float]
   fld dword [temp_float]
   fcos
   mov [temp_float], dword ecx
   fld dword [temp_float]
   fmulp
   mov edx, [x]
   fld dword [ebx + edx]
   faddp
   fstp dword [ebx + edx]

   fsin
   mov [temp_float], dword ecx
   fld dword [temp_float]
   fmulp
   mov edx, [y]
   fld dword [ebx + edx]
   faddp
   fstp dword [ebx + edx]

   check_torus:
      mov [temp_float], dword 100
      fild dword [temp_float]
      mov edx, [x]
      fld dword [ebx + edx]
      fcomi
      fstp st0
      fstp st0
      ja fix_x_torus_above

      fldz
      mov edx, [x]
      fld dword [ebx + edx]
      fcomi
      fstp st0
      fstp st0
      jb fix_x_torus_below
      jmp check_torus_y

      fix_x_torus_above:
         fld dword [ebx + edx]
         mov [temp_float], dword 100
         fild dword [temp_float]
         fsubp
         fstp dword [ebx + edx]
         jmp check_torus_y

      fix_x_torus_below:
         fld dword [ebx + edx]
         mov [temp_float], dword 100
         fild dword [temp_float]
         faddp
         fstp dword [ebx + edx]

      check_torus_y:
         mov [temp_float], dword 100
         fild dword [temp_float]
         mov edx, [y]
         fld dword [ebx + edx]
         fcomi
         fstp st0
         fstp st0
         ja fix_y_torus_above

         fldz
         mov edx, [y]
         fld dword [ebx + edx]
         fcomi
         fstp st0
         fstp st0
         jb fix_y_torus_below
         jmp finish_torus

         fix_y_torus_above:
            fld dword [ebx + edx]
            mov [temp_float], dword 100
            fild dword [temp_float]
            fsubp
            fstp dword [ebx + edx]
            jmp finish_torus

         fix_y_torus_below:
            fld dword [ebx + edx]
            mov [temp_float], dword 100
            fild dword [temp_float]
            faddp
            fstp dword [ebx + edx]


   finish_torus:
      popad; Restore caller state (registers)
      pop ebp; Restore caller state
      ret; Back to caller

mayDestroy:
   push ebp
   mov ebp, esp

   sub esp, 12
   mov ebx, [ebp + 8]

   fld dword [y_target]
   mov edx, [y]
   fld dword [ebx + edx]
   fsubp
   fst dword [ebp - 4] ; ebp - 4 = (y2 - y1)

   fld dword [x_target]
   mov edx, [x]
   fld dword [ebx + edx]
   fsubp
   fst dword [ebp - 8] ; ebp - 8 = (x2 - x1)

   fpatan
   fstp dword [ebp - 12] ; ebp - 12 = arctan((y2 - y1)/(x2 - x1)) in radians
   push dword [ebp - 12]
   call radians_to_degrees
   add esp, 4

   fld dword [temp_float]
   fldz
   fcomip
   ja wrap_negative_angle
   jmp no_wrap_angle

   wrap_negative_angle:
      mov [temp_float], dword 360
      fild dword [temp_float]
      faddp

   no_wrap_angle:
      fstp dword [ebp - 12]   ; ebp - 12 = gamma = arctan((y2 - y1)/(x2 - x1)) in degrees

      mov edx, [alpha]
      fld dword [ebx + edx]
      fld dword [ebp - 12]
      fsubp
      fabs
      fld dword [beta_angle]
      fcomip
      fstp st0
      ja check_detection_distance
      mov eax, dword false
      jmp finish_may_destroy

   check_detection_distance:
      fld dword [max_delta]
      fld dword [ebp - 4]
      fld st0
      fmulp
      fld dword [ebp - 8]
      fld st0
      fmulp
      faddp
      fsqrt
      fcomip
      fstp st0
      jb can_destroy
      mov eax, dword false
      jmp finish_may_destroy

      can_destroy:
       mov eax, dword true

   finish_may_destroy:
   add esp, 12
   pop ebp; Restore caller state
   ret; Back to caller


drone_routine:
   mov ebx, [drone_arr]    ; init drones structs
   mov eax, dword [curr_id]
   mov ecx, dword [drone_sz]
   mul ecx
   add ebx, eax

   push ebx
   call calc_delta_alpha
   add esp, 4

   push ebx
   call calc_delta_distance
   add esp, 4

   push ebx
   call mayDestroy
   add esp, 4
   cmp eax, true
   je destroy
   jmp finish_drone_routine

   destroy:
      mov edx, [destroyed]
      mov ecx, dword [ebx + edx]
      inc ecx
      mov [ebx + edx], dword ecx
      cmp ecx, dword [win_count]
      jge win
      jmp continue_locating_targets

      win:
         mov edx, [id]
         push dword [ebx + edx]
         call print_winner
         add esp, 4
         jmp endCo

      continue_locating_targets:
         mov ebx, target_co
         call resume
         jmp drone_routine

   finish_drone_routine:
      mov ebx, scheduler_co
      call resume
      jmp drone_routine

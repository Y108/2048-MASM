includelib legacy_stdio_definitions.lib
includelib kernel32.lib
includelib ucrt.lib

option casemap: none

extern SetConsoleTitleA: proc
extern _getch: proc
extern printf: proc
extern SetConsoleCursorPosition: proc
extern GetStdHandle: proc

extern rand: proc
extern srand: proc
extern time: proc

; ,--------,--------,--------,--------,
; |        |		|     	 |        |
; |  XXXX  |  XXXX  |  XXXX  |  XXXX  |
; |        |        |        |        |
; |--------|--------|--------|--------|
; |        |		|     	 |        |
; |  XXXX  |  XXXX  |  XXXX  |  XXXX  |
; |        |        |        |        |
; |--------|--------|--------|--------|
; |        |		|     	 |        |
; |  XXXX  |  XXXX  |  XXXX  |  XXXX  |
; |        |        |        |        |
; |--------|--------|--------|--------|
; |        |		|     	 |        |
; |  XXXX  |  XXXX  |  XXXX  |  XXXX  |
; |        |        |        |        |
; '--------'--------'--------'--------'

; ctrl+x -> exit

.data

	namestr db "2048", 0
	
	Grid_top   db 10, 10, 10, 10, 10, 10, 9, 9, 9, 9, 9, " ,--------,--------,--------,--------,", 10, 0
	Grid_space db 9, 9, 9, 9, 9, " |        |        |        |        |", 10, 0
	Grid_mid   db 9, 9, 9, 9, 9, " |--------|--------|--------|--------|", 10, 0
	Grid_bot   db 9, 9, 9, 9, 9, " '--------'--------'--------'--------'", 10, 0
	Grid_num   db 9, 9, 9, 9, 9, " |  %4d  |  %4d  |  %4d  |  %4d  |", 10, 0

	exitstr db 10, 10, "                                                 Press CTRL + X to exit", 10, 0
	losestr db 10, 10, 10, "                                              The grid is full. You lost!", 0
	winstr db 10, 10, 10, "                                              You reached 2048. You won!", 0

	hConsole dq ?

	gameGrid dq 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 , 0
	winToggle db 0

	movDist_mainx dq ?
	movDist_normx dq ?
	startPos dq ?

.code

initRandom PROC
	sub rsp, 32

	xor rcx, rcx
	call time

	mov ecx, eax
	call srand

	add rsp, 32
	ret
initRandom ENDP

getRandom PROC
	sub rsp, 32

	call rand

	xor edx, edx
	mov ecx, 16
	div ecx

	xor rax, rax
	mov eax, edx

	add rsp, 32
	ret
getRandom ENDP

putRandom PROC
	sub rsp, 32
	mov rcx, 16

posTestNil:
	push rcx
	call getRandom
	pop rcx
	
	cmp qword ptr [gameGrid + rax*8], 0
	je putRand

	dec rcx
	jnz posTestNil

	xor rcx, rcx

checkEmpty:
	cmp qword ptr [gameGrid + rcx*8], 0
	je putRandLin
	inc rcx
	cmp rcx, 16
	jl checkEmpty
	mov rax, -1
	jmp putExit

putRandLin:
	mov [gameGrid + rcx*8], 2
	jmp putExit

putRand:
	mov [gameGrid + rax*8], 2

putExit:
	add rsp, 32
	ret
putRandom ENDP

printConsole PROC
	push rbx
	mov rbx, 0

	sub rsp, 32
	xor al, al
	mov rcx, hConsole			   
	xor rdx, rdx				   
	call SetConsoleCursorPosition

	lea rcx, Grid_top
	call printf
	add rsp, 32

print_loop:
	sub rsp, 32
	lea rcx, Grid_space
	call printf
	add rsp, 32

	push [gameGrid + rbx + 24]

	sub rsp, 32

	lea rcx, Grid_num
	mov rdx, [gameGrid + rbx]
	mov r8,  [gameGrid + rbx + 8]
	mov r9,  [gameGrid + rbx + 16]

	call printf
	add rsp, 8

	lea rcx, Grid_space
	call printf

	lea rcx, Grid_mid
	call printf
	add rsp, 32

	add rbx, 32
	cmp rbx, 96
	jne print_loop
	
	sub rsp, 32
	lea rcx, Grid_space
	call printf
	add rsp, 32

	push [gameGrid + 120]

	sub rsp, 32

	lea rcx, Grid_num
	mov rdx, [gameGrid + 96]
	mov r8,  [gameGrid + 104]
	mov r9,  [gameGrid + 112]

	call printf
	add rsp, 8

	lea rcx, Grid_space
	call printf

	lea rcx, Grid_bot
	call printf

	lea rcx, exitstr
	call printf

	add rsp, 32

	pop rbx
	ret
printConsole ENDP

readConsole PROC
	sub rsp, 32
	xor rax, rax
	call _getch

	cmp al, 224
	je keyPress

	jmp rKExit

keyPress:
	xor rax, rax
	call _getch

	cmp al, 24
	je rKExit

	cmp al, 72
	je upKey

	cmp al, 80
	je downKey

	cmp al, 77
	je rightKey

	cmp al, 75
	je leftKey

	jmp rKExit

upKey:
	mov [startPos], 96
	mov [movDist_mainx], -32
	mov [movDist_normx], 8
	jmp rKExit

downKey:
	mov [startPos], 0
	mov [movDist_mainx], 32
	mov [movDist_normx], 8
	jmp rKExit

rightKey:
	mov [startPos], 0
	mov [movDist_mainx], 8
	mov [movDist_normx], 32
	jmp rKExit

leftKey:
	mov [startPos], 24
	mov [movDist_mainx], -8
	mov [movDist_normx], 32
	jmp rKExit

rKExit:
	add rsp, 32
	ret
readConsole ENDP

movGrid PROC
    sub rsp, 32
	push r13
    push r14
    push r15
    push rsi

    mov r15, [movDist_mainx]
    mov r14, [movDist_normx]
    mov r10, [startPos]
    xor r13, r13

mainxLoop:
    mov rax, r10

    mov rcx, [gameGrid + rax]
    add rax, r15
    mov rdx, [gameGrid + rax]
    add rax, r15
    mov r8, [gameGrid + rax]
    add rax, r15
    mov r9, [gameGrid + rax]
	
    mov rsi, 3
comprQ1:
    test r9, r9
    jnz comprQ2
    mov r9, r8
    mov r8, rdx
    mov rdx, rcx
    mov rcx, 0

comprQ2:
    test r8, r8
    jnz comprQ3
    mov r8, rdx
    mov rdx, rcx
    mov rcx, 0

comprQ3:
    test rdx, rdx
    jnz comprQCon
    mov rdx, rcx
    mov rcx, 0

comprQCon:
    dec rsi
    jnz comprQ1

mergeVal1:
	test r9, r9
	jz mergeVal2
    cmp r9, r8
    jne mergeVal2
    shl r9, 1
	cmp r9, 2048
	jne mergeVal1sub
	mov [winToggle], 1
mergeVal1sub:
    xor r8, r8

mergeVal2:
	test r8, r8
	jz mergeVal3
    cmp r8, rdx
    jne mergeVal3
    shl r8, 1
	cmp r8, 2048
	jne mergeVal2sub
	mov [winToggle], 1
mergeVal2sub:
    xor rdx, rdx

mergeVal3:
	mov rsi, 3

	test rdx, rdx
	jz comprQ1Fin
    cmp rdx, rcx
    jne comprQ1Fin
    shl rdx, 1
	cmp rdx, 2048
	jne mergeVal3sub
	mov [winToggle], 1
mergeVal3sub:
    xor rcx, rcx

comprQ1Fin:
    test r9, r9
    jnz comprQ2Fin
    mov r9, r8
    mov r8, rdx
    mov rdx, rcx
    mov rcx, 0

comprQ2Fin:
    test r8, r8
    jnz comprQ3Fin
    mov r8, rdx
    mov rdx, rcx
    mov rcx, 0

comprQ3Fin:
    test rdx, rdx
    jnz comprQConFin
    mov rdx, rcx
    mov rcx, 0

comprQConFin:
    dec rsi
    jnz comprQ1Fin
	
    mov rax, r10

    mov [gameGrid + rax], rcx
    add rax, r15
    mov [gameGrid + rax], rdx 
    add rax, r15
    mov [gameGrid + rax], r8 
    add rax, r15
    mov [gameGrid + rax], r9

normxLoop:
    inc r13
    cmp r13, 4
    je movExit
    add r10, r14
    jmp mainxLoop

movExit:
	pop rsi
    pop r15
    pop r14
    pop r13
    add rsp, 32
    ret
movGrid ENDP

main PROC
	lea rcx, namestr
	call SetConsoleTitleA

	mov rcx, -11
	call GetStdHandle
	mov hConsole, rax

	call initRandom

main_loop:
	call putRandom
	cmp rax, -1
	je loseGame

	call printConsole

	call readConsole
	cmp rax, 24
	je exitGame

	call movGrid

	cmp [winToggle], 1
	je winGame

	jmp main_loop

winGame:
	lea r8, winstr
	jmp printFinal

loseGame:
	lea r8, losestr
	jmp printFinal

printFinal:
	sub rsp, 32

	push r8

	xor al, al
	mov rcx, hConsole			   
	xor rdx, rdx				   
	call SetConsoleCursorPosition

	pop r8

	mov rcx, r8
	xor rdx, rdx
	xor r8, r8
	xor r9, r9
	call printf

	mov rcx, hConsole
	mov rax, 0
	mov rdx, 26
	shl rdx, 16
	or rdx, rax
	call SetConsoleCursorPosition

	add rsp, 32

exitGame:
	sub rsp, 32

	call _getch

	add rsp, 32

	xor rax, rax
	ret
main ENDP

END

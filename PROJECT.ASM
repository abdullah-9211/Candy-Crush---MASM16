
; ========================================================================================================================================================================================================
; COAL Lab Semester Project
; Names: Abdullah Umar, Taha Ijaz
; Roll Numbers: 20I-0444, 20I-1880
; Section: CS-C
; Instructor: Ifrah Maqsood
; Software: MASM-16
; ========================================================================================================================================================================================================

.model small
.stack 0500h

; ========================================================================================================================================================================================================
; Macros
; ========================================================================================================================================================================================================

PUSH_ALL macro

	push ax
	push bx
	push cx
	push dx
	push si
	push di

endm

POP_ALL macro

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

endm

CLEAR_SCREEN macro
	call InitScreenMode
endm

CALL_SLEEP macro milliseconds

	PUSH_ALL
	mov cx,0	
	
	.while cx < milliseconds
		
		mov dx,1
		push dx
		call sleep
		inc cx
	
	.endw
	
	POP_ALL

endm

SET_CURSOR macro x,y

	PUSH_ALL
	mov ah,02h
	mov dl,x
	mov dh,y	
	int 010h
	POP_ALL

endm

DISPLAY_STRING macro stringOffset

	PUSH_ALL
	mov dx,stringOffset
	mov ah,09h
	int 021h
	POP_ALL

endm

DISPLAY_NUMBER macro number

	PUSH_ALL
	mov dx,number
	push dx
	call output
	POP_ALL

endm

WRITE_STR_FILE macro stringOffset

	PUSH_ALL
	mov dx,stringOffset
	
	sub sp,2
	push dx
	call StrLen
	pop cx
	
	mov ah,040h
	int 021h
	POP_ALL

endm

; ========================================================================================================================================================================================================
; Constants
; ========================================================================================================================================================================================================

; keywords
true = 1
false = 0
nullptr = 0

; candy types
CandyType equ <word>
CandyType_Empty = 0
CandyType_Square = 1
CandyType_Triangle = 2
CandyType_Pentagon = 3
CandyType_Diamond = 4
CandyType_Cross = 5
CandyType_Bomb = 6
CandyType_First = CandyType_Square
CandyType_Last = CandyType_Bomb

; candy colors
CandyColor_Square = 0eh ; yellow

; candy dimensions
candyWidth = 30
candyHeight = 12

; board square dimensions
boardSquareWidth = 50
boardSquareHeight = 20

; board dimensions
boardWidth = 7
boardHeight = 7

; random number generator sleep time (milliseconds)
randSleepTime = CandyType_Last * 10

; username size
usernameSize = 20

; max moves
maxMoves = 15

; scores
requiredScoreLevel1 = 50
requiredScoreLevel2 = 100
requiredScoreLevel3 = 150

; ========================================================================================================================================================================================================
; Structures
; ========================================================================================================================================================================================================

; coordinate

Coordinate struct

	x word 0
	y word 0

Coordinate ends

; candy

Candy struct

	topLeftCoord Coordinate <>
	shapeType CandyType CandyType_Empty
	rowNum word 0
	colNum word 0
	InCombo word false

Candy ends

; board square

BoardSquare struct

	topLeftCoord Coordinate <>
	currentCandy Candy <>
	IsSelected word false

BoardSquare ends

; ========================================================================================================================================================================================================
; Data
; ========================================================================================================================================================================================================

.data

; zero address
word nullptr

; random number generator
rand_seed word 0

; empty string
emptyString byte 20 dup(0),'$'

; board matrix
boardMatrix BoardSquare boardHeight dup(boardWidth dup(<>))
boardTopLeftCoord Coordinate <50, 30>

; candy pointers
selectedCandy word nullptr

; username
username byte usernameSize dup('$')
enterNameMsg byte "Enter Your Name: ",'$'

; rules
gameTitleMsg byte "CANDY CRUSH",'$'
gameRulesMsg byte "Rules of the Game",'$'
rule1Msg byte "1. You have a total of 15 moves to make",'$'
rule2Msg byte "2. Swap candies of the same colour to create combos",'$'
rule3Msg byte "3. A combo is created with 3 or more adjacent candies",'$'
rule4Msg byte "4. Swap a candy with a bomb to clear out all candies of its shape",'$'
rule5Msg byte "5. Reach the required score to advance to next level",'$'
pressEnterMsg byte "Press Enter to Continue!",'$'

; levels
level1Msg byte "LEVEL 1",'$'
level2Msg byte "LEVEL 2",'$'
level3Msg byte "LEVEL 3",'$'

; score
requiredScoreMsg byte "Required Score: ",'$'
currentScoreMsg byte "Current Score: ",'$'
currentScore word 0
level1Score word 0
level2Score word 0
level3Score word 0

; turns
movesLeftMsg byte "Moves Left: ",'$'
movesLeft word maxMoves

; level
currentLevel word 1

; results
levelFinished word false
levelPassed word false

level1PassedMsg byte "Well Done! You Passed Level 1!",'$'
level1FailedMsg byte "Game Over! Level 1 Failed!",'$'

level2PassedMsg byte "Well Done! You Passed Level 2!",'$'
level2FailedMsg byte "Game Over! Level 2 Failed!",'$'

level3PassedMsg byte "Well Done! You Passed Level 3!",'$'
level3FailedMsg byte "Game Over! Level 3 Failed!",'$'

; file-handling

highScore word 0
scoreStr byte 3 dup('$')
scoreFile byte "score.txt",0
level1fileMsg byte "Level 1: ",'$'
level2fileMsg byte "Level 2: ",'$'
level3fileMsg byte "Level 3: ",'$'
highscoreFileMsg byte "High Score: ",'$'
newline byte 13,'$'

; ========================================================================================================================================================================================================
; Code
; ========================================================================================================================================================================================================

; procedure design:
; tasks are divided into many procs
; parameters are passed to all procs through stack
; return values are also managed through stack
; must make space for return values before proc call
; must pop return values after proc call
; register values are retained after every proc call
; arrays and objects are always passed by pointer

.code

start:

jmp main

; ========================================================================================================================================================================================================
; Initialize
; ========================================================================================================================================================================================================

InitDataSegment proc

	PUSH_ALL
	mov ax,@data
	mov ds,ax
	POP_ALL
	ret

InitDataSegment endp

InitScreenMode proc

	; 640 x 200, 16 colors.
	PUSH_ALL
	mov ah,00h
	mov al,0eh
	int 010h
	POP_ALL
	ret

InitScreenMode endp

InitMouse proc

	PUSH_ALL
	mov ax,0
	int 033h
	POP_ALL
	ret

InitMouse endp

InitBoardMatrix proc

	PUSH_ALL
	mov si,offset boardMatrix
	mov cx,boardTopLeftCoord.x
	mov dx,boardTopLeftCoord.y
	
	; outer loop counter
	mov bx,0
	
	.while bx < boardHeight
	
		; inner loop counter
		mov ax,0
	
		.while ax < boardWidth
			
			; square coordinates
			
			mov (BoardSquare ptr [si]).topLeftCoord.x,cx
			mov (BoardSquare ptr [si]).topLeftCoord.y,dx
			
			; candy coordinates
			
			mov (BoardSquare ptr [si]).currentCandy.topLeftCoord.x,cx
			add (BoardSquare ptr [si]).currentCandy.topLeftCoord.x,(boardSquareWidth - candyWidth) / 2
			
			mov (BoardSquare ptr [si]).currentCandy.topLeftCoord.y,dx
			add (BoardSquare ptr [si]).currentCandy.topLeftCoord.y,(boardSquareHeight - candyHeight) / 2
			
			; candy row and column numbers
			
			mov (BoardSquare ptr [si]).currentCandy.rowNum,bx
			mov (BoardSquare ptr [si]).currentCandy.colNum,ax
			
			; draw square
			
			push si
			call DrawBoardSquare
			
			; next square
			
			add cx,boardSquareWidth
			add si,sizeof BoardSquare
			inc ax
		
		.endw
		
		; next row
		
		mov cx,boardTopLeftCoord.x
		add dx,boardSquareHeight
		inc bx
	
	.endw
	
	call HideMouseCursor
	
	sub sp,2
	call DropCandies
	add sp,2
	
	call CrushingAnimation
	call BalanceBoard
	call ShowMouseCursor
	
	POP_ALL
	ret

InitBoardMatrix endp

InitGame proc

	PUSH_ALL
	
	call InitDataSegment
	call InitScreenMode
	call InitMouse
	
	call RulesScreen
	CLEAR_SCREEN
	
	call InitBoardMatrix
	call DisplayMessages
	
	POP_ALL
	ret

InitGame endp

; ========================================================================================================================================================================================================
; Main
; ========================================================================================================================================================================================================

main proc

	PUSH_ALL
	call srand
	call GameLoop
	call exit
	POP_ALL
	ret

main endp

; ========================================================================================================================================================================================================
; Exit
; ========================================================================================================================================================================================================

exit proc

	PUSH_ALL
	SET_CURSOR 0,22
	mov ah,04ch
	int 021h
	POP_ALL
	ret

exit endp

; ========================================================================================================================================================================================================
; Game Loop
; ========================================================================================================================================================================================================

GameLoop proc

	PUSH_ALL
	call InitGame
	call ShowMouseCursor
	
	.while true
		
		.if word ptr levelFinished == true
			
			call DisplayResults
			
			.if word ptr levelPassed == false || word ptr currentLevel == 3				
				call SaveScores
				call exit
				
			.else
				
				inc word ptr currentLevel
				
				CALL_SLEEP 1000
				CLEAR_SCREEN
				CALL_SLEEP 500
				
				call ResetGame
				call InitBoardMatrix
				call DisplayMessages
				call ShowMouseCursor
				
			.endif
			
		.endif
	
		call MouseHandler
	
	.endw
	
	POP_ALL
	ret

GameLoop endp

; ========================================================================================================================================================================================================
; System Sleep
; ========================================================================================================================================================================================================

sleep proc
	
	; prototype: void sleep(word milliseconds)
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; convert to microseconds
	
	mov ax,[bp + 4]
	mov bx,1000
	mul bx
	
	; call sleep interrupt
	
	mov cx,dx
	mov dx,ax
	mov ah,086h
	int 015h
	
	; return

	POP_ALL
	pop bp
	ret 2

sleep endp

; ========================================================================================================================================================================================================
; Random Number Generator
; ========================================================================================================================================================================================================

srand proc

	PUSH_ALL
	mov ah,00h
	int 01ah
	mov rand_seed,dx
	POP_ALL
	ret

srand endp

rand proc

	push bp
	mov bp,sp
	PUSH_ALL
	
	; seed = seed * 25173 + 13849
	
	mov ax,rand_seed
	mov bx,25173
	mul bx
	add ax,13849
	mov rand_seed,ax
	
	; ax = seed / 2^5
	
	mov cx,0
	
	.while cx < 5
	
		shr ax,1
		inc cx
	
	.endw
	
	; bx = max - min + 1
	
	mov bx,[bp + 4]
	sub bx,[bp + 6]
	inc bx
	
	; dx = ax % bx + min
	
	mov dx,0
	div bx
	add dx,[bp + 6]
	mov [bp + 8],dx
	
	POP_ALL
	pop bp
	ret 4
	
rand endp

; ========================================================================================================================================================================================================
; Draw Candies
; ========================================================================================================================================================================================================

DrawEmptyCandy proc

	; prototype: void DrawSquareCandy(word candyPtr)

	push bp
	mov bp,sp
	PUSH_ALL
	
	mov ah,0ch ; specify pixel command
	mov al,00h ; specify black color
	
	; candy object address
	mov si,[bp + 4]
	
	; init coordinates
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; drawing loop
	
	; outer loop counter
	mov bx,0
	
	.while bx < candyHeight
	
		; inner loop counter
		push bx
		mov bx,0
		
		.while bx < candyWidth
		
			int 010h ; draw pixel
			inc cx ; move right
			inc bx ; inner loop counter
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		; outer loop counter
		pop bx
		inc bx
	
	.endw
	
	POP_ALL
	pop bp
	ret 2

DrawEmptyCandy endp

DrawSquareCandy proc

	; prototype: void DrawSquareCandy(word candyPtr)

	push bp
	mov bp,sp
	PUSH_ALL
	
	; specify pixel command
	mov ah,0ch
	mov al,CandyColor_Square
	
	; candy object address
	mov si,[bp + 4]
	
	; init coordinates
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; drawing loop
	
	; outer loop counter
	mov bx,0
	
	.while bx < candyHeight
	
		; inner loop counter
		push bx
		mov bx,0
		
		.while bx < candyWidth
		
			int 010h ; draw pixel
			inc cx ; move right
			inc bx ; inner loop counter
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		; outer loop counter
		pop bx
		inc bx
	
	.endw
	
	POP_ALL
	pop bp
	ret 2

DrawSquareCandy endp

DrawTriangleCandy proc
	
	; draws a filled triangle at top left coordinates held by passed candy object (through stack)

	push bp
	mov bp,sp
	sub sp,4 ; local variables (triangle edge points)
	push_all
	
	mov ah,0ch ; draw pixel command
	mov al,0ch ; specify red color
	
	; init coordinates
	
	mov si,[bp + 4] ; candy object address
	mov cx,(candy ptr [si]).topLeftCoord.x
	mov dx,(candy ptr [si]).topLeftCoord.y
	
	; init edge points
	
	mov [bp - 2],cx
	add word ptr [bp - 2],candyWidth / 2
	
	mov [bp - 4],cx
	add word ptr [bp - 4],candyWidth / 2
	
	mov bx,candyHeight ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		dec word ptr [bp - 2] ; left edge point
		inc word ptr [bp - 4] ; right edge point
		
		pop bx
		dec bx
	
	.endw
	
	pop_all
	add sp,4 ; pop local variables
	pop bp
	ret 2

DrawTriangleCandy endp

DrawPentagonCandy proc

	; draws a filled pentagon at topLeftCoord coordinates held by passed Candy object (through stack)

	push bp
	mov bp,sp
	sub sp,4 ; local variables (triangle edge points)
	PUSH_ALL
	
	mov ah,0ch ; draw pixel command
	mov al,0dh ; specify purple color
	
	; init coordinates
	
	mov si,[bp + 4] ; Candy object address
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; init edge points
	
	mov [bp - 2],cx
	add word ptr [bp - 2],candyWidth / 2
	
	mov [bp - 4],cx
	add word ptr [bp - 4],candyWidth / 2
	
	; draw triangle
	
	mov bx,candyHeight / 2 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		dec word ptr [bp - 2] ; left edge point
		inc word ptr [bp - 4] ; right edge point
		
		pop bx
		dec bx
	
	.endw
	
	; draw square
	
	mov cx,[bp - 2] ; x-coord = left-edge + 1, y-coord is already correct.
	inc cx
	
	mov bx,candyHeight / 2 ; init counter
	
	.while bx > 0
	
		push bx
		
		; counter = right edge - (left edge + 1)
		
		mov bx,[bp - 4]
		sub bx,[bp - 2]
		dec bx
		
		.while bx > 0
		
			int 010h
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,[bp - 2] ; move back to left-edge
		inc cx
		
		inc dx ; move down
		pop bx
		dec bx
	
	.endw
	
	POP_ALL
	add sp,4 ; pop local variables
	pop bp
	ret 2

DrawPentagonCandy endp

DrawDiamondCandy proc

	; draws a filled diamond at topLeftCoord coordinates held by passed Candy object (through stack)

	push bp
	mov bp,sp
	sub sp,4 ; local variables (triangle edge points)
	PUSH_ALL
	
	mov ah,0ch ; draw pixel command
	mov al,09h ; specify blue color
	
	; init coordinates
	
	mov si,[bp + 4] ; Candy object address
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; init edge points
	
	mov [bp - 2],cx
	add word ptr [bp - 2],candyWidth / 2
	
	mov [bp - 4],cx
	add word ptr [bp - 4],candyWidth / 2
	
	; draw triangle
	
	mov bx,candyHeight / 2 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		dec word ptr [bp - 2] ; left edge point
		inc word ptr [bp - 4] ; right edge point
		
		pop bx
		dec bx
	
	.endw
	
	; draw inverted triangle
	
	mov bx,candyHeight / 2 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		inc word ptr [bp - 2] ; left edge point
		dec word ptr [bp - 4] ; right edge point
		
		pop bx
		dec bx
	
	.endw
	
	POP_ALL
	add sp,4 ; pop local variables
	pop bp
	ret 2

DrawDiamondCandy endp

DrawCrossCandy proc

	; draws a filled cross at topLeftCoord coordinates held by passed Candy object (through stack)

	push bp
	mov bp,sp
	sub sp,4 ; local variables (triangle edge points)
	PUSH_ALL
	
	mov ah,0ch ; draw pixel command
	mov al,0ah ; specify green color
	
	; init coordinates
	
	mov si,[bp + 4] ; Candy object address
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; init edge points
	
	mov [bp - 2],cx
	add word ptr [bp - 2],candyWidth / 3
	
	mov [bp - 4],cx
	add word ptr [bp - 4],(candyWidth * 2) / 3
	
	; draw bar
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		pop bx
		dec bx
	
	.endw
	
	; draw rectangle
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			int 010h
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		pop bx
		dec bx
	
	.endw
	
	; draw bar
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		pop bx
		dec bx
	
	.endw
	
	POP_ALL
	add sp,4 ; pop local variables
	pop bp
	ret 2

DrawCrossCandy endp

DrawBombCandy proc

	; draws a filled colorful octagon at topLeftCoord coordinates held by passed Candy object (through stack)
	
	push bp
	mov bp,sp
	sub sp,4 ; local variables (edge points)
	PUSH_ALL
	
	mov ah,0ch ; draw pixel command
	mov al,01h ; specify inital color
	
	; init coordinates
	
	mov si,[bp + 4] ; Candy object address
	mov cx,(Candy ptr [si]).topLeftCoord.x
	mov dx,(Candy ptr [si]).topLeftCoord.y
	
	; init edge points
	
	mov [bp - 2],cx
	add word ptr [bp - 2],candyWidth / 3
	
	mov [bp - 4],cx
	add word ptr [bp - 4],(candyWidth * 2) / 3
	
	; draw upper
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		; increment color
		
		.if al == 0fh
			mov al,01h
		.else
			inc al
		.endif
		
		dec word ptr [bp - 2] ; left edge point
		inc word ptr [bp - 4] ; right edge point
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		pop bx
		dec bx
	
	.endw
	
	; draw rectangle
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
		
			inc cx ; move right
			dec bx
		
		.endw
		
		; increment color
		
		.if al == 0fh
			mov al,01h
		.else
			inc al
		.endif
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		pop bx
		dec bx
	
	.endw
	
	; draw lower
	
	mov bx,candyHeight / 3 ; init counter
	
	.while bx > 0
	
		push bx
		mov bx,candyWidth
		
		.while bx > 0
		
			; if coordinates are within edge points then draw
			
			.if cx > [bp - 2]
				.if cx < [bp - 4]
					int 010h
				.endif
			.endif
			
			inc cx ; move right
			dec bx
		
		.endw
		
		; increment color
		
		.if al == 0fh
			mov al,01h
		.else
			inc al
		.endif
		
		inc word ptr [bp - 2] ; left edge point
		dec word ptr [bp - 4] ; right edge point
		
		mov cx,(Candy ptr [si]).topLeftCoord.x ; move back to left
		inc dx ; move down
		
		pop bx
		dec bx
	
	.endw
	
	POP_ALL
	add sp,4 ; pop local variables
	pop bp
	ret 2

DrawBombCandy endp

DrawCandy proc

	; prototype: void DrawCandy(word candyPtr)

	push bp
	mov bp,sp
	PUSH_ALL
	
	mov si,[bp + 4]
	mov ax,(Candy ptr [si]).shapeType
	
	push si
	call DrawEmptyCandy
	
	.if ax == CandyType_Square
		push si
		call DrawSquareCandy
		
	.elseif ax == CandyType_Triangle
		push si
		call DrawTriangleCandy
		
	.elseif ax == CandyType_Pentagon
		push si
		call DrawPentagonCandy
		
	.elseif ax == CandyType_Diamond
		push si
		call DrawDiamondCandy
		
	.elseif ax == CandyType_Cross
		push si
		call DrawCrossCandy
		
	.elseif ax == CandyType_Bomb
		push si
		call DrawBombCandy
		
	.endif
	
	POP_ALL
	pop bp
	ret 2

DrawCandy endp

; ========================================================================================================================================================================================================
; Board
; ========================================================================================================================================================================================================

DrawBoardSquare proc

	; prototype: void DrawBoardSquare(word boardSquarePtr)

	push bp
	mov bp,sp
	PUSH_ALL
	
	; board square object address
	mov si,[bp + 4]
	
	mov ah,0ch ; specify pixel command
	mov bx,(BoardSquare ptr [si]).IsSelected
	
	.if bx == true	
		mov al,06h ; specify highlight color
	.else
		mov al,0fh ; specify white color
	.endif
	
	; init coordinates
	mov cx,(BoardSquare ptr [si]).topLeftCoord.x
	mov dx,(BoardSquare ptr [si]).topLeftCoord.y
	
	; top-left to top-right
	
	mov bx,0
	
	.while bx < boardSquareWidth
	
		int 010h
		inc cx
		inc bx
	
	.endw
	
	; top-right to bottom-right
	
	mov bx,0
	
	.while bx < boardSquareHeight
		
		int 010h
		inc dx
		inc bx
	
	.endw
	
	; bottom-right to bottom-left
	
	mov bx,0
	
	.while bx < boardSquareWidth
		
		int 010h
		dec cx
		inc bx
	
	.endw
	
	; bottom-left to top-left
	
	mov bx,0
	
	.while bx < boardSquareHeight
		
		int 010h
		dec dx
		inc bx
	
	.endw
	
	POP_ALL
	pop bp
	ret 2

DrawBoardSquare endp

BalanceBoard proc
	
	PUSH_ALL
	
	.repeat
	
		sub sp,2
		call FindAllCombos
		pop ax
		
		.if ax != 0
			call CrushingAnimation
		.endif
	
	.until ax == 0
	
	POP_ALL
	ret
	
BalanceBoard endp

CrushingAnimation proc

	PUSH_ALL
	call PopCombos
	
	sub sp,2
	call PushDown
	add sp,2

	sub sp,2
	call DropCandies
	add sp,2
	
	call LevelBlockage
	POP_ALL
	ret

CrushingAnimation endp

; ========================================================================================================================================================================================================
; Mouse
; ========================================================================================================================================================================================================

MouseHandler proc

	PUSH_ALL

	mov ax,03h
	int 033h
	
	.if bx & 001b
		
		push cx
		push dx
		call LmbPressed

	.elseif bx & 010b
	
		; deselect candy
		
		mov si,selectedCandy
		
		.if si != nullptr
			
			sub si,offset BoardSquare.currentCandy
			mov (BoardSquare ptr [si]).IsSelected,false
			call HideMouseCursor
			push si
			call DrawBoardSquare
			call ShowMouseCursor
			add si,offset BoardSquare.currentCandy
			mov word ptr selectedCandy,nullptr
			
		.endif
		
	.elseif bx & 100b
		call exit
		
	.endif

	POP_ALL
	ret

MouseHandler endp

ShowMouseCursor proc

	PUSH_ALL
	mov ax,1
	int 033h
	POP_ALL
	ret

ShowMouseCursor endp

HideMouseCursor proc

	PUSH_ALL
	mov ax,2
	int 033h
	POP_ALL
	ret

HideMouseCursor endp

LmbPressed proc

	; prototype: void LmbPressed(word CoordX, word CoordY)
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; candy selection
	
	; previously selected candy
	mov di,selectedCandy
	
	; currently selected candy
	sub sp,2
	push [bp + 6]
	push [bp + 4]
	call SelectCandy
	pop si
	
	; store currently selected candy
	mov selectedCandy,si
	
	; highlight board squares
	
	.if di == nullptr && si != nullptr
		
		sub si,offset BoardSquare.currentCandy
		mov (BoardSquare ptr [si]).IsSelected,true
		call HideMouseCursor
		push si
		call DrawBoardSquare
		call ShowMouseCursor
		add si,offset BoardSquare.currentCandy
		
	.elseif di != nullptr
		
		sub di,offset BoardSquare.currentCandy
		mov (BoardSquare ptr [di]).IsSelected,false
		call HideMouseCursor
		push di
		call DrawBoardSquare
		call ShowMouseCursor
		add di,offset BoardSquare.currentCandy
		
	.endif
	
	; swap candies
	sub sp,2
	push di
	push si
	call SwapCandies
	pop ax
	
	.if ax == true ; if swapped
	
		mov ax,(Candy ptr [di]).shapeType
		mov bx,(Candy ptr [si]).shapeType
		
		; total combo size
		mov cx,0
		
		; bomb combo (first candy is bomb, second is not)
		
		.if ax == CandyType_Bomb
		
			; set bomb in-combo
			mov (Candy ptr [di]).InCombo,true
			
			; find all instances of the candy which was swapped with bomb
			sub sp,2
			push (Candy ptr [si]).shapeType
			call FindBombCombos
			pop dx
			add cx,dx
		
		; bomb combo (second candy is bomb, first is not)
		
		.elseif bx == CandyType_Bomb
			
			; set bomb in-combo
			mov (Candy ptr [si]).InCombo,true
			
			; find all instances of the candy which was swapped with bomb
			sub sp,2
			push (Candy ptr [di]).shapeType
			call FindBombCombos
			pop dx
			add cx,dx
		
		; regular combo (both candies are not bomb)
		
		.endif
		
		; regular combos
	
		; candy 1 combos
	
		sub sp,2
		push di
		call FindCandyCombos
		pop dx
		add cx,dx
		
		; candy 2 combos
		
		sub sp,2
		push si
		call FindCandyCombos
		pop dx
		add cx,dx
	
		.if cx != 0 ; if combos are formed
			
			jmp LmbPressed_UpdateDisplay

		.else

			; swap back if no combos are formed
			
			mov (Candy ptr [di]).shapeType,bx
			mov (Candy ptr [si]).shapeType,ax
			
			; redraw
			
			CALL_SLEEP 100
			
			call HideMouseCursor
			
			push di
			call DrawCandy
			
			push si
			call DrawCandy
			
			call ShowMouseCursor
		
		.endif
		
	.else ; if not swapped
		
		.if si != nullptr ; highlight selected
			
			sub si,offset BoardSquare.currentCandy
			mov (BoardSquare ptr [si]).IsSelected,true
			call HideMouseCursor
			push si
			call DrawBoardSquare
			call ShowMouseCursor
			add si,offset BoardSquare.currentCandy
			
		.endif
	
	.endif
	
	jmp LmbPressed_Return
	
	LmbPressed_UpdateDisplay:
	
		; update board
		call HideMouseCursor
		call CrushingAnimation
		call BalanceBoard
		call ShowMouseCursor
		
		; update moves
		dec word ptr movesLeft
		call DisplayMessages
		
		; update result status
		
		.if word ptr movesLeft == 0
			
			mov ax,currentScore
			mov bx,0
			
			.if word ptr currentLevel == 1
				mov bx,requiredScoreLevel1
				mov level1Score,ax
				
			.elseif word ptr currentLevel == 2
				mov bx,requiredScoreLevel2
				mov level2Score,ax
				
			.elseif word ptr currentLevel == 3
				mov bx,requiredScoreLevel3
				mov level3Score,ax
				
			.endif
			
			.if ax >= bx
				mov word ptr levelPassed,true		
			.else
				mov word ptr levelPassed,false
			.endif
			
			mov word ptr levelFinished,true
			
		.endif
	
	LmbPressed_Return:
	
		CALL_SLEEP 100 ; to avoid instant re-clicks
		POP_ALL
		pop bp
		ret 4

LmbPressed endp

; ========================================================================================================================================================================================================
; Candy Selection
; ========================================================================================================================================================================================================

SelectCandy proc

	; prototype: word SelectCandy(word mouseCoordX, word mouseCoordY)
	; returns address of selected candy
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	mov si,offset boardMatrix
	mov cx,0
	
	.while cx < (boardHeight * boardWidth)
	
		; check if mouse coordinates are within range of candy of current board square
		
		mov bx,(BoardSquare ptr [si]).topLeftCoord.x
		
		.if [bp + 6] > bx
			
			add bx,boardSquareWidth
			
			.if [bp + 6] < bx
				
				mov bx,(BoardSquare ptr [si]).topLeftCoord.y
				
				.if [bp + 4] > bx
					
					add bx,boardSquareHeight
					
					.if [bp + 4] < bx
					
						mov bx,(BoardSquare ptr [si]).currentCandy.shapeType
						
						.if bx != CandyType_Empty
							
							add si,offset BoardSquare.currentCandy
							mov [bp + 8],si
							jmp SelectCandy_Return
						
						.endif
					.endif
				.endif
			.endif
		.endif
		
		add si,sizeof BoardSquare
		inc cx
	
	.endw
	
	mov word ptr [bp + 8],nullptr
	
	SelectCandy_Return:
	
		POP_ALL
		pop bp
		ret 4

SelectCandy endp

; ========================================================================================================================================================================================================
; Candy Swapping
; ========================================================================================================================================================================================================

SwapCandies proc
	
	; prototype: word SwapCandies(word candyPtr1, word candyPtr2)
	; returns true or false (swapped or not)
	
	push bp
	mov bp,sp
	PUSH_ALL

	mov word ptr [bp + 8],false
	mov di,[bp + 6]
	mov si,[bp + 4]

	.if di != nullptr && si != nullptr && di != si ; if two seperate candies are selected
		
		mov ax,(Candy ptr [di]).shapeType
		mov bx,(Candy ptr [si]).shapeType
		
		.if ax != bx ; candy types must be different
		
			; check candy adjacency
			
			sub sp,2
			push si
			push di
			call CheckCandiesAdjacency
			pop dx
			
			.if dx == true ; if candies are adjacent
			
				; swap candy shapes
				
				mov (Candy ptr [di]).shapeType,bx
				mov (Candy ptr [si]).shapeType,ax
			
				; redraw candies
				
				call HideMouseCursor
				
				push di
				call DrawCandy
				
				push si
				call DrawCandy
				
				call ShowMouseCursor
				
				; reset selection
				mov word ptr selectedCandy,nullptr
				
				; return true	
				mov word ptr [bp + 8],true
				
			.endif
		
		.endif
	
	.endif
	
	POP_ALL
	pop bp
	ret 4

SwapCandies endp

CheckCandiesAdjacency proc

	; word CheckCandiesAdjacency(word candyPtr1, word candyPtr2)
	; returns true or false

	push bp
	mov bp,sp
	PUSH_ALL
	
	mov di,[bp + 6]
	mov si,[bp + 4]
	
	.if di == nullptr || si == nullptr
	
		mov word ptr [bp + 8],false
		jmp CheckCandiesAdjacency_Return
	
	.endif
	
	; adjacency: 1 square difference (horizontal or vertical, no diagonal)
	
	mov ax,(Candy ptr [di]).topLeftCoord.x
	mov bx,(Candy ptr [si]).topLeftCoord.x
	sub ax,bx
	
	mov cx,(Candy ptr [di]).topLeftCoord.y
	mov dx,(Candy ptr [si]).topLeftCoord.y
	sub cx,dx
	
	; x-diff = -1,0,1 and y-diff = 0, or y-diff = -1,0,1 and x-diff = 0.
	.if ((ax == -boardSquareWidth || ax == 0 || ax == boardSquareWidth) && cx == 0) || ((cx == -boardSquareHeight || cx == 0 || cx == boardSquareHeight) && ax == 0)
		
		mov word ptr [bp + 8],true
		jmp CheckCandiesAdjacency_Return
	
	.endif
	
	mov word ptr [bp + 8],false
	
	CheckCandiesAdjacency_Return:
	
		POP_ALL
		pop bp
		ret 4

CheckCandiesAdjacency endp

; ========================================================================================================================================================================================================
; Candy Combos
; ========================================================================================================================================================================================================

FindRowCombos proc
	
	; prototype word FindRowCombos(word candyPtr)
	; returns combo size
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 6],1
	
	; candy object address
	mov si,[bp + 4]
	
	; candy shape type
	mov ax,(Candy ptr [si]).shapeType
	
	; right direction
	
	FindRowCombos_Right:
		
		mov cx,(Candy ptr [si]).colNum
		inc cx
		
		mov di,si
		add di,sizeof BoardSquare
		
		.while cx < boardWidth
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindRowCombos_Left
			.endif
			
			inc word ptr [bp + 6]
			add di,sizeof BoardSquare
			inc cx
			
		.endw
		
	; left direction
	
	FindRowCombos_Left:

		mov cx,(Candy ptr [si]).colNum
		dec cx
		
		mov di,si
		sub di,sizeof BoardSquare
		
		.while sword ptr cx >= 0
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindRowCombos_Mark
			.endif
			
			inc word ptr [bp + 6]
			sub di,sizeof BoardSquare
			dec cx
			
		.endw
	
	; mark combos
	
	FindRowCombos_Mark:
	
		.if word ptr [bp + 6] > 2
			
			mov cx,0
			add di,sizeof BoardSquare
			
			.while cx < [bp + 6]
				
				mov (Candy ptr [di]).InCombo,true
				add di,sizeof BoardSquare
				inc cx
				
			.endw
			
		.else
			mov word ptr [bp + 6],0
			
		.endif
	
	POP_ALL
	pop bp
	ret 2
	
FindRowCombos endp

FindColCombos proc
	
	; prototype word FindColCombos(word candyPtr)
	; returns combo size
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 6],1
	
	; candy object address
	mov si,[bp + 4]
	
	; candy shape type
	mov ax,(Candy ptr [si]).shapeType
	
	; down direction
	
	FindColCombos_Down:
		
		mov cx,(Candy ptr [si]).rowNum
		inc cx
		
		mov di,si
		add di,boardWidth * sizeof BoardSquare
		
		.while cx < boardHeight
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindColCombos_Up
			.endif
			
			inc word ptr [bp + 6]
			add di,boardWidth * sizeof BoardSquare
			inc cx
			
		.endw
	
	; up direction
	
	FindColCombos_Up:

		mov cx,(Candy ptr [si]).rowNum
		dec cx
		
		mov di,si
		sub di,boardWidth * sizeof BoardSquare
		
		.while sword ptr cx >= 0
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindColCombos_Mark
			.endif
			
			inc word ptr [bp + 6]
			sub di,boardWidth * sizeof BoardSquare
			dec cx
			
		.endw
		
	; mark combos
	
	FindColCombos_Mark:
	
		.if word ptr [bp + 6] > 2
			
			mov cx,0
			add di,boardWidth * sizeof BoardSquare
			
			.while cx < [bp + 6]
				
				mov (Candy ptr [di]).InCombo,true
				add di,boardWidth * sizeof BoardSquare
				inc cx
				
			.endw
			
		.else
			mov word ptr [bp + 6],0
			
		.endif
	
	POP_ALL
	pop bp
	ret 2
	
FindColCombos endp

FindLeftDiagonalCombos proc
	
	; prototype word FindLeftDiagonalCombos(word candyPtr)
	; returns combo size
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 6],1
	
	; candy object address
	mov si,[bp + 4]
	
	; candy shape type
	mov ax,(Candy ptr [si]).shapeType
	
	; down-right direction
	
	FindLeftDiagonalCombos_DownRight:
		
		mov cx,(Candy ptr [si]).rowNum
		inc cx
		
		mov dx,(Candy ptr [si]).colNum
		inc dx
		
		mov di,si
		add di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
		
		.while cx < boardHeight && dx < boardWidth
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindLeftDiagonalCombos_UpLeft
			.endif
			
			inc word ptr [bp + 6]
			add di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
			inc cx
			inc dx
			
		.endw
		
	; up-left direction
	
	FindLeftDiagonalCombos_UpLeft:

		mov cx,(Candy ptr [si]).rowNum
		dec cx
		
		mov dx,(Candy ptr [si]).colNum
		dec dx
		
		mov di,si
		sub di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
		
		.while sword ptr cx >= 0 && sword ptr dx >= 0
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindLeftDiagonalCombos_Mark
			.endif
			
			inc word ptr [bp + 6]
			sub di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
			dec cx
			dec dx
			
		.endw
	
	; mark combos
	
	FindLeftDiagonalCombos_Mark:
	
		.if word ptr [bp + 6] > 2
			
			mov cx,0
			add di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
			
			.while cx < [bp + 6]
				
				mov (Candy ptr [di]).InCombo,true
				add di,boardWidth * sizeof BoardSquare + sizeof BoardSquare
				inc cx
				
			.endw
			
		.else
			mov word ptr [bp + 6],0
			
		.endif
	
	POP_ALL
	pop bp
	ret 2
	
FindLeftDiagonalCombos endp

FindRightDiagonalCombos proc
	
	; prototype word FindRightDiagonalCombos(word candyPtr)
	; returns combo size
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 6],1
	
	; candy object address
	mov si,[bp + 4]
	
	; candy shape type
	mov ax,(Candy ptr [si]).shapeType
	
	; up-right direction
	
	FindRightDiagonalCombos_UpRight:
		
		mov cx,(Candy ptr [si]).rowNum
		dec cx
		
		mov dx,(Candy ptr [si]).colNum
		inc dx
		
		mov di,si
		sub di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
		
		.while sword ptr cx >= 0 && dx < boardWidth
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindRightDiagonalCombos_DownLeft
			.endif
			
			inc word ptr [bp + 6]
			sub di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
			dec cx
			inc dx
			
		.endw
	
	; down-left direction
	
	FindRightDiagonalCombos_DownLeft:

		mov cx,(Candy ptr [si]).rowNum
		inc cx
		
		mov dx,(Candy ptr [si]).colNum
		dec dx
		
		mov di,si
		add di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
		
		.while cx < boardHeight && sword ptr dx >= 0
			
			mov bx,(Candy ptr [di]).shapeType
			
			.if ax != bx
				jmp FindRightDiagonalCombos_Mark
			.endif
			
			inc word ptr [bp + 6]
			add di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
			inc cx
			dec dx
			
		.endw
	
	; mark combos
	
	FindRightDiagonalCombos_Mark:
	
		.if word ptr [bp + 6] > 2
			
			mov cx,0
			sub di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
			
			.while cx < [bp + 6]
				
				mov (Candy ptr [di]).InCombo,true
				sub di,boardWidth * sizeof BoardSquare - sizeof BoardSquare
				inc cx
				
			.endw
			
		.else
			mov word ptr [bp + 6],0
			
		.endif
	
	POP_ALL
	pop bp
	ret 2
	
FindRightDiagonalCombos endp

FindCandyCombos proc
	
	; prototype: word FindCandyCombos(word candyPtr)
	; returns combo size
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	mov word ptr [bp + 6],0
	mov si,[bp + 4]
	
	; ignore empty candy
	
	mov ax,(Candy ptr [si]).shapeType

	.if ax == CandyType_Empty
		jmp FindCandyCombos_Return
	.endif
	
	; find combos in all directions
	
	sub sp,2
	push si
	call FindRowCombos
	pop ax
	add [bp + 6],ax
	
	sub sp,2
	push si
	call FindColCombos
	pop ax
	add [bp + 6],ax
	
	comment @
	
	sub sp,2
	push si
	call FindLeftDiagonalCombos
	pop ax
	add [bp + 6],ax
	
	sub sp,2
	push si
	call FindRightDiagonalCombos
	pop ax
	add [bp + 6],ax
	
	@
	
	FindCandyCombos_Return:
	
		POP_ALL
		pop bp
		ret 2
	
FindCandyCombos endp

FindAllCombos proc

	; prototype: word FindAllCombos()
	; returns combo size

	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 4],0

	mov cx,0
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy

	.while cx < boardHeight * boardWidth

		sub sp,2
		push si
		call FindCandyCombos
		pop ax
		add [bp + 4],ax
		
		add si,sizeof BoardSquare
		inc cx

	.endw

	POP_ALL
	pop bp
	ret

FindAllCombos endp

FindBombCombos proc

	; prototype: word FindBombCombos(word candyShapeType)
	; returns combo size

	push bp
	mov bp,sp
	PUSH_ALL
	
	; combo size
	mov word ptr [bp + 6],0
	
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	mov cx,0
	
	.while cx < boardWidth * boardHeight
		
		mov ax,(Candy ptr [si]).shapeType
		
		.if ax == [bp + 4]
			
			mov (Candy ptr [si]).InCombo,true
			inc word ptr [bp + 6]
			
		.endif
		
		add si,sizeof BoardSquare
		inc cx
		
	.endw
	
	POP_ALL
	pop bp
	ret 2

FindBombCombos endp

PopCombos proc

	PUSH_ALL

	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	mov cx,0
	
	.while cx < boardWidth * boardHeight
		
		mov ax,(Candy ptr [si]).InCombo
		
		.if ax == true
			
			mov ax,(Candy ptr [si]).shapeType
			
			; remove candy if it is in a combo
			mov (Candy ptr [si]).shapeType,CandyType_Empty
			mov (Candy ptr [si]).InCombo,false
			
			; clear candy from board
			CALL_SLEEP 50
			
			push si
			call DrawCandy
			
			; update score
			inc word ptr currentScore
			call DisplayMessages
			
		.endif
		
		add si,sizeof BoardSquare
		inc cx
		
	.endw
	
	PopCombos_Return:
	
		POP_ALL
		ret

PopCombos endp

; ========================================================================================================================================================================================================
; Candy Push Down
; ========================================================================================================================================================================================================

PushDownColumn proc

	; prototype: word PushDownColumn(word colNum)
	; returns number of candies pushed down
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; pushed candy count
	mov word ptr[bp + 6],0
	
	; column start pointer: si = (start address) + (column index) * (size of board square)
	mov si,offset boardMatrix
	mov ax,[bp + 4]
	mov bx,sizeof BoardSquare
	mul bx
	add si,ax
	add si,offset BoardSquare.currentCandy
	
	; outer loop counter: ch
	mov ch,0
	
	.while ch < boardHeight

		mov ax,(Candy ptr [si]).shapeType
		
		.if ax == CandyType_Empty

			; increment pushed candy count
			.if ch > 0
			
				mov ax,(Candy ptr [si - boardWidth * sizeof BoardSquare]).shapeType
				
				.if ax != CandyType_Empty
					inc word ptr [bp + 6]
				.endif
			
			.endif

			; inner loop counter: cl = ch
			mov cl,ch
			
			; secondary pointer: di = si
			mov di,si

			.while cl > 0
				
				; swap if both are not empty
				
				mov ax,(Candy ptr [di - boardWidth * sizeof BoardSquare]).shapeType
				mov bx,(Candy ptr [di]).shapeType
				
				.if !(ax == CandyType_Empty && bx == CandyType_Empty)
				
					mov (Candy ptr [di - boardWidth * sizeof BoardSquare]).shapeType,bx
					mov (Candy ptr [di]).shapeType,ax
					
					; redraw current candy
					
					push di
					call DrawCandy
					
					; go to previous candy
					
					sub di,boardWidth * sizeof BoardSquare
					dec cl
					
					; redraw previous candy
					
					push di
					call DrawCandy
					
				.else
				
					; go to previous candy
					
					sub di,boardWidth * sizeof BoardSquare
					dec cl
				
				.endif
				
			.endw
		
		.endif
		
		add si,boardWidth * sizeof BoardSquare
		inc ch
	
	.endw
	
	POP_ALL
	pop bp
	ret 2

PushDownColumn endp

PushDown proc

	; prototype: word PushDown()
	; returns number of candies pushed down

	push bp
	mov bp,sp
	PUSH_ALL
	
	; pushed candy count
	mov word ptr [bp + 6],0
	
	; row start pointer: si
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	
	; loop counter
	mov cx,0
	
	.while cx < boardWidth
	
		mov ax,(Candy ptr [si]).shapeType
	
		sub sp,2
		push cx
		call PushDownColumn
		pop ax
		add [bp + 6],ax

		add si,sizeof BoardSquare
		inc cx
		
	.endw
	
	POP_ALL
	pop bp
	ret

PushDown endp

; ========================================================================================================================================================================================================
; Candy Drop
; ========================================================================================================================================================================================================

DropCandiesColumn proc

	; prototype: word DropCandiesColumn(word colNum)
	; returns number of candies dropped

	push bp
	mov bp,sp
	PUSH_ALL
	
	; dropped candy count
	mov word ptr [bp + 6],0
	
	; column start pointer: si = (start address) + (column index) * (size of board square)
	mov si,offset boardMatrix
	mov ax,[bp + 4]
	mov bx,sizeof BoardSquare
	mul bx
	add si,ax
	add si,offset BoardSquare.currentCandy
	
	; loop counter
	mov cx,0
	
	.while cx < boardHeight
		
		mov ax,(Candy ptr [si]).shapeType
		
		.if ax == CandyType_Empty
			
			CALL_SLEEP 50
			
			; return space
			sub sp,2
			
			; ax = (4 - currentLevel) * 3
			mov ax,4
			sub ax,currentLevel
			mov bx,3
			mul bx
			
			; lowerbound: ax * CandyType_First
			mov bx,CandyType_First
			mul bx
			push ax
			
			; ax = (4 - currentLevel) * 3
			mov ax,4
			sub ax,currentLevel
			mov bx,3
			mul bx
			
			; upperbound: ax * CandyType_Last
			mov bx,CandyType_Last
			mul bx
			push ax
			
			; bx = (4 - currentLevel) * 3
			mov ax,4
			sub ax,currentLevel
			mov bx,3
			mul bx
			mov bx,ax
			
			; shapeType = rand(lowerbound, upperbound) / bx
			call rand
			pop ax
			mov dx,0
			div bx
			mov (Candy ptr [si]).shapeType,ax
			
			; drop candy (by swapping)
			.if cx != 0
			
				mov di,si
				sub di,boardWidth * sizeof BoardSquare
			
				mov ax,(Candy ptr [di]).shapeType
				mov bx,(Candy ptr [si]).shapeType

				mov (Candy ptr [di]).shapeType,bx
				mov (Candy ptr [si]).shapeType,ax
				
				push si
				call DrawCandy
				
				push di
				call DrawCandy
			
			; no drop on the first candy
			.else
			
				push si
				call DrawCandy
			
			.endif
			
			; increment dropped candy count
			inc word ptr [bp + 6]
			
		.endif
		
		add si,boardWidth * sizeof BoardSquare
		inc cx
		
	.endw
	
	POP_ALL
	pop bp
	ret 2

DropCandiesColumn endp

DropCandies proc
	
	; prototype: word DropCandies()
	; returns number of candies dropped
	
	push bp
	mov bp,sp
	PUSH_ALL
	
	; dropped candy count
	mov word ptr [bp + 4],0
	
	; column start pointer: si
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	
	; loop counter
	mov cx,0
	
	.while cx < boardWidth
	
		mov ax,(Candy ptr [si]).shapeType
	
		.if ax == CandyType_Empty
	
			sub sp,2
			push cx
			call DropCandiesColumn
			pop ax
			add [bp + 4],ax
		
		.endif

		add si,sizeof BoardSquare
		inc cx
		
	.endw
	
	POP_ALL
	pop bp
	ret

DropCandies endp

; ========================================================================================================================================================================================================
; Blockage
; ========================================================================================================================================================================================================

LevelBlockage proc

	PUSH_ALL
	
	.if word ptr currentLevel == 2
		call Level2Blockage
	
	.elseif word ptr currentLevel == 3
		call Level3Blockage
	
	.endif
	
	POP_ALL
	ret

LevelBlockage endp

Level2Blockage proc

	PUSH_ALL
	
	; column start pointer: si
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	
	; row index: ch
	mov ch,0
	
	.while ch < boardHeight
	
		; col index: cl
		mov cl,0
	
		.while cl < boardWidth
			
			; corners
			.if (ch == 0 && cl == 0) || (ch == 0 && cl == boardWidth - 1) || (ch == boardHeight - 1 && cl == 0) || (ch == boardHeight - 1 && cl == boardWidth - 1)
				jmp Level2Blockage_ClearCandy
			.endif
			
			; corners second
			.if (ch == 1 && cl == 0) || (ch == 1 && cl == boardWidth - 1) || (ch == boardHeight - 2 && cl == 0) || (ch == boardHeight - 2 && cl == boardWidth - 1)
				jmp Level2Blockage_ClearCandy
			.endif
			
			; middle
			.if (ch == 0 && cl == boardWidth / 2) || (ch == boardHeight / 2 && cl == 0) || (ch == boardHeight / 2 && cl == boardWidth - 1) || (ch == boardHeight - 1 && cl == boardWidth / 2)
				jmp Level2Blockage_ClearCandy
			.endif
			
			Level2Blockage_ClearCandyEnd:
			
				inc cl
				add si,sizeof BoardSquare
			
		.endw
		
		inc ch
	
	.endw
	
	jmp Level2Blockage_Return
	
	Level2Blockage_ClearCandy:
		
		; remove candy if it is on a blockage square
		mov (Candy ptr [si]).shapeType,CandyType_Empty
	
		; clear candy from board
		CALL_SLEEP 20
		call HideMouseCursor
		push si
		call DrawCandy
		call ShowMouseCursor
		
		; jump back
		jmp Level2Blockage_ClearCandyEnd
	
	Level2Blockage_Return:
	
		POP_ALL
		ret

Level2Blockage endp

Level3Blockage proc

	PUSH_ALL
	
	; column start pointer: si
	mov si,offset boardMatrix
	add si,offset BoardSquare.currentCandy
	
	; row index: ch
	mov ch,0
	
	.while ch < boardHeight
	
		; col index: cl
		mov cl,0
	
		.while cl < boardWidth
			
			.if ch == boardHeight / 2 || cl == boardWidth / 2
				
				; remove candy if it is on a blockage square
				mov (Candy ptr [si]).shapeType,CandyType_Empty
			
				; clear candy from board
				CALL_SLEEP 20
				call HideMouseCursor
				push si
				call DrawCandy
				call ShowMouseCursor
				
			.endif
			
			inc cl
			add si,sizeof BoardSquare
			
		.endw
		
		inc ch
	
	.endw
	
	POP_ALL
	ret

Level3Blockage endp

; ========================================================================================================================================================================================================
; Reset Game
; ========================================================================================================================================================================================================

ResetGame proc

	PUSH_ALL
	
	mov si,offset boardMatrix
	mov cx,0
	
	.while cx < boardWidth * boardHeight
	
		push cx
		mov cx,0
		
		.while cx < sizeof BoardSquare
		
			mov byte ptr [si],0
			inc si
			inc cx
		
		.endw
		
		pop cx
		inc cx
	
	.endw
	
	mov word ptr selectedCandy,nullptr
	mov word ptr currentScore,0
	mov word ptr movesLeft,maxMoves
	mov word ptr levelFinished,false
	mov word ptr levelPassed,false
	
	POP_ALL
	ret

ResetGame endp

; ========================================================================================================================================================================================================
; File Handling
; ========================================================================================================================================================================================================

StrLen proc

	push bp
	mov bp,sp
	PUSH_ALL
	
	mov si,[bp + 4]
	mov word ptr [bp + 6],0
	
	.while true
		
		mov al,[si]
		
		.if al == '$'
			jmp StrLen_Return
		.endif
		
		inc word ptr [bp + 6]
		inc si
		
	.endw
	
	StrLen_Return:
	
		POP_ALL
		pop bp
		ret 2

StrLen endp

FindHighScore proc

	PUSH_ALL
	
	mov ax,level1Score
	mov bx,level2Score
	mov cx,level3Score
	
	.if ax > bx
		mov bx,ax		
	.endif
	
	.if bx > cx
		mov cx,bx
	.endif
	
	mov highScore,cx
	POP_ALL
	ret

FindHighScore endp

IntToStr proc

	push bp
	mov bp,sp
	PUSH_ALL

	; string offset
	mov si,[bp + 4]

	; digit count
	mov cx,0

	IntToStr_PushLoop:

		; num = num / 10
		; push num % 10
		; counter++

		mov dx,0
		mov ax,[bp + 6]
		mov bx,10
		div bx
		mov [bp + 6],ax
		push dx
		inc cx

		; repeat if num != 0

		cmp word ptr [bp + 6],0
		jne IntToStr_PushLoop

	IntToStr_PopLoop:

		pop dx
		add dx,'0'
		mov [si],dx
		inc si
		loop IntToStr_PopLoop

	IntToStr_Return:

		mov byte ptr [si],'$'
		POP_ALL
		pop bp
		ret 4

IntToStr endp

SaveScores proc

	PUSH_ALL
	
	; open file in read-write mode
	mov dx,offset scoreFile
	mov al,02h
	mov ah,03dh
	
	int 021h
	
	; *** required ***
	mov bx,ax
	
	; player name
	WRITE_STR_FILE offset username
	WRITE_STR_FILE offset newline
	
	; level 1 heading
	WRITE_STR_FILE offset level1fileMsg
	
	; level 1 score
	mov ax,level1Score
	push ax
	
	mov dx,offset scoreStr
	push dx
	
	call IntToStr
	WRITE_STR_FILE offset scoreStr
	WRITE_STR_FILE offset newline
	
	; level 2 heading
	WRITE_STR_FILE offset level2fileMsg
	
	; level 2 score
	mov ax,level2Score
	push ax
	
	mov dx,offset scoreStr
	push dx
	
	call IntToStr
	WRITE_STR_FILE offset scoreStr
	WRITE_STR_FILE offset newline
	
	; level 3 heading
	WRITE_STR_FILE offset level3fileMsg
	
	; level 3 score
	mov ax,level3Score
	push ax
	
	mov dx,offset scoreStr
	push dx
	
	call IntToStr
	WRITE_STR_FILE offset scoreStr
	WRITE_STR_FILE offset newline
	
	; high score heading
	WRITE_STR_FILE offset highscoreFileMsg
	
	; high score
	call FindHighScore
	push highScore
	
	mov dx,offset scoreStr
	push dx
	
	call IntToStr
	WRITE_STR_FILE offset scoreStr
	WRITE_STR_FILE offset newline
	
	; close file
	mov ah,03eh
	int 021h
	
	POP_ALL
	ret

SaveScores endp

; ========================================================================================================================================================================================================
; User Interaction
; ========================================================================================================================================================================================================

NameInput proc
	
	PUSH_ALL
	
	; username address
	mov si,offset username
	mov cx,0
	
	NameInput_Loop:
	
		; check if max username size is reached
		cmp cx,usernameSize
		je NameInput_Return
	
		; enter a character
		mov ah,01h
		int 021h
		
		; if enter or backspace is pressed
		.if al == 13 || al == 8
			jmp NameInput_Return
		.endif
		
		; store input and get next character
		mov [si],al
		inc si
		inc cx
		jmp NameInput_Loop
		
	NameInput_Return:
	
		.if username == '$'
		
			mov username + 0,'P'
			mov username + 1,'l'
			mov username + 2,'a'
			mov username + 3,'y'
			mov username + 4,'e'
			mov username + 5,'r'
		
		.else
			mov username + usernameSize,'$'
		
		.endif
	
		POP_ALL
		ret

NameInput endp

RulesScreen proc

	PUSH_ALL
	
	SET_CURSOR 35,2
	DISPLAY_STRING offset gameTitleMsg
	
	SET_CURSOR 10,5
	DISPLAY_STRING offset gameRulesMsg
	
	SET_CURSOR 5,9
	DISPLAY_STRING offset rule1Msg
	
	SET_CURSOR 5,11
	DISPLAY_STRING offset rule2Msg
	
	SET_CURSOR 5,13
	DISPLAY_STRING offset rule3Msg
	
	SET_CURSOR 5,15
	DISPLAY_STRING offset rule4Msg
	
	SET_CURSOR 5,17
	DISPLAY_STRING offset rule5Msg
	
	; SET_CURSOR 25,20
	; DISPLAY_STRING offset pressEnterMsg
	
	SET_CURSOR 21,21
	DISPLAY_STRING offset enterNameMsg
	call NameInput
	
	POP_ALL
	ret

RulesScreen endp

DisplayMessages proc

	PUSH_ALL
	
	; display level
	SET_CURSOR 55,5
	
	.if word ptr currentLevel == 1
		DISPLAY_STRING offset level1Msg
	
	.elseif word ptr currentLevel == 2
		DISPLAY_STRING offset level2Msg
		
	.elseif word ptr currentLevel == 3
		DISPLAY_STRING offset level3Msg
	
	.endif
	
	; display name
	SET_CURSOR 55,9
	DISPLAY_STRING offset emptyString
	SET_CURSOR 55,9
	DISPLAY_STRING offset username
	
	; display score
	SET_CURSOR 55,11
	DISPLAY_STRING offset emptyString
	SET_CURSOR 55,11
	DISPLAY_STRING offset currentScoreMsg
	DISPLAY_NUMBER word ptr currentScore
	
	; display score
	SET_CURSOR 55,13
	DISPLAY_STRING offset emptyString
	SET_CURSOR 55,13
	DISPLAY_STRING offset requiredScoreMsg
	
	.if word ptr currentLevel == 1
		DISPLAY_NUMBER requiredScoreLevel1
		
	.elseif word ptr currentLevel == 2
		DISPLAY_NUMBER requiredScoreLevel2
		
	.elseif word ptr currentLevel == 3
		DISPLAY_NUMBER requiredScoreLevel3
		
	.endif
	
	; display moves
	SET_CURSOR 55,15
	DISPLAY_STRING offset emptyString
	SET_CURSOR 55,15
	DISPLAY_STRING offset movesLeftMsg
	DISPLAY_NUMBER word ptr movesLeft
	
	POP_ALL
	ret

DisplayMessages endp

DisplayResults proc

	PUSH_ALL
	SET_CURSOR 13,2
	
	.if word ptr currentLevel == 1
	
		.if word ptr levelPassed == true
			DISPLAY_STRING offset level1PassedMsg	
		.else
			DISPLAY_STRING offset level1FailedMsg
		.endif
	
	.elseif word ptr currentLevel == 2
	
		.if word ptr levelPassed == true
			DISPLAY_STRING offset level2PassedMsg	
		.else
			DISPLAY_STRING offset level2FailedMsg
		.endif
	
	.elseif word ptr currentLevel == 3
	
		.if word ptr levelPassed == true
			DISPLAY_STRING offset level3PassedMsg	
		.else
			DISPLAY_STRING offset level3FailedMsg
		.endif
		
	.endif
	
	POP_ALL
	ret

DisplayResults endp

; ========================================================================================================================================================================================================
; Multi-Digit Output
; ========================================================================================================================================================================================================

output proc

	push bp
	mov bp,sp
	PUSH_ALL

	; digit count
	mov cx,0

	output_PushLoop:

		; num = num / 10
		; push num % 10
		; counter++

		mov dx,0
		mov ax,[bp + 4]
		mov bx,10
		div bx
		mov [bp + 4],ax
		push dx
		inc cx

		; repeat if num != 0

		cmp word ptr [bp + 4],0
		jne output_PushLoop

	output_PopLoop:

		pop dx
		add dx,'0'
		mov ah,02h
		int 021h
		loop output_PopLoop

	output_Return:

		POP_ALL
		pop bp
		ret 2

output endp

; ========================================================================================================================================================================================================

end start

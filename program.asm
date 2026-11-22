; ------------------------------------------------------------
; WOLF-86 - 3D Raycasting Maze Game
; Author:   Saif Nawaz
; Course:   EL-2003 COAL Lab, Fall 2026
; Language: 32-bit x86 assembly (MASM) + Irvine32 library
;
; First-person 3D raycasting maze game in the Windows console.
; Find the exit (E) before the 120-second timer runs out.
; One ray per screen column (80) is cast with the DDA method.
; All maths is integer fixed-point Q8 (value * 256), sin/cos
; from a 360-entry table. No FPU / SSE instructions are used.
; ------------------------------------------------------------

INCLUDE Irvine32.inc                        ; Irvine32 library procedures and Win32 prototypes

; ---------- constants (no memory used, just names for numbers) ----------
SCREEN_W = 80                               ; console width in characters
SCREEN_H = 24                               ; rows used by the 3D view
BUF_H    = SCREEN_H + 1                     ; rows in frameBuffer: 24 view rows + 1 HUD row
HUD_ROW  = SCREEN_H                         ; the HUD is the last row (row 24)
MAP_W    = 16                               ; map width in cells
MAP_H    = 16                               ; map height in cells
FOV      = 60                               ; field of view in degrees

; ---------- FIXMUL macro: Q8 fixed-point multiply ----------
; dest = (dest * src) / 256. Two Q8 numbers multiplied give a
; Q16 result, so SAR 8 brings it back to Q8 (SAR keeps the sign).
FIXMUL MACRO dest, src
    imul dest, src                          ;; dest = dest * src (signed)
    sar  dest, 8                            ;; dest = dest / 256, sign kept
ENDM

; ---------- Win32 function not declared in SmallWin.inc (lives in user32.lib) ----------
GetAsyncKeyState PROTO, vKey:DWORD          ; AX bit 15 = 1 if the key is held down right now
SetConsoleOutputCP PROTO, wCodePageID:DWORD ; (kernel32.lib) choose which character set the console shows

; ---------- procedure prototypes ----------
GetSin      PROTO                           ; EAX = angle in, EAX = sin*256 out
GetCos      PROTO                           ; EAX = angle in, EAX = cos*256 out
TitleScreen PROTO                           ; shows the title screen, EAX = key pressed
ResetGame   PROTO                           ; puts the player at the start, restarts the timer
GetElapsedSec PROTO                         ; EAX = seconds since the game started
GetRemainingSec PROTO                       ; EAX = seconds left (0 if time is up)
PutNumber   PROTO, dest:PTR BYTE, value:DWORD, digits:DWORD ; writes digits into memory
DrawHUD     PROTO                           ; fills the HUD row of frameBuffer
PrintTwoDigits PROTO                        ; EAX = 0..99, prints it with 2 digits
PrintTime   PROTO                           ; EAX = seconds, prints mm:ss
WinScreen   PROTO                           ; shows the "you escaped" screen
LoseScreen  PROTO                           ; shows the "time's up" screen
AskPlayAgain PROTO                          ; EAX = 1 for Y, 0 for N or Q
ClearBuffer PROTO                           ; fills frameBuffer with spaces
HideCursor  PROTO                           ; hides the blinking console cursor
DrawBuffer  PROTO                           ; copies frameBuffer to the console
GetMoveDelta PROTO                          ; returns EAX = dx, EDX = dy for one step forward
IsWall      PROTO, testX:SDWORD, testY:SDWORD     ; EAX = CELL_FREE / CELL_WALL / CELL_EXIT
ProbePoint  PROTO, newPos:SDWORD, delta:SDWORD    ; EAX = newPos pushed MARGIN further in move direction
TryMove     PROTO, moveDX:SDWORD, moveDY:SDWORD   ; moves the player if no wall is in the way
InitInput   PROTO                           ; gets the console input handle
KeyDown     PROTO, vKey:DWORD               ; EAX = 1 if key is held down now
KeyPressed  PROTO, vKey:DWORD, prevPtr:PTR BYTE   ; EAX = 1 only on the frame the key goes down
GetArrowChar PROTO                          ; AL = '>', 'v', '<' or '^' for the current angle
WrapAngle   PROTO                           ; EAX = angle in, EAX = same angle wrapped to 0..359
AnyKeyDown  PROTO                           ; EAX = 1 if any keyboard key is held
WaitKeysReleased PROTO                      ; waits until keys are let go, sets mWasDown/qWasDown
SetupAxis   PROTO, axisPos:SDWORD, axisDir:SDWORD ; DDA setup for one axis (EAX, EBX, ECX out)
CastRay     PROTO, rayAngle:DWORD           ; EAX = distance (Q8), EDX = hitSide, ECX = 1 if exit
GetWallColor PROTO, distance:DWORD, side:DWORD    ; EAX = wall colour for a distance
GetFloorChar PROTO                          ; ECX = row in, EAX = floor character for that row
GetWallHeight PROTO                         ; EAX = distance in, EAX = wall height in rows
DrawColumn  PROTO, column:DWORD, wallHeight:DWORD, wallColor:DWORD ; draws one screen column
RenderView  PROTO                           ; casts 80 rays and draws the 3D view
TurnPlayer  PROTO, turnAmount:SDWORD        ; adds turnAmount to angle, wraps to 0..359
HandleInput PROTO                           ; reads one key (no waiting) and acts on it
DrawMinimap PROTO                           ; copies map + direction arrow into the frame buffer
GameLoop    PROTO                           ; main loop, EAX = RESULT_QUIT / WIN / LOSE

; ---------- movement settings ----------
MOVE_SPEED = 32                             ; one step = 32/256 = 1/8 of a cell (Q8)
TURN_STEP  = 5                              ; degrees turned per frame while A/D is held
MARGIN     = 64                             ; keep 64/256 = 1/4 cell away from walls

; ---------- raycasting settings ----------
BIG_DIST   = 1000000                        ; "infinite" distance, used when a ray never crosses an axis
KEY_WAIT_TRIES = 200                        ; max 200 x 10 ms = 2 s waiting for keys to be released
CODE_PAGE_437  = 437                        ; old IBM PC character set (has the block characters)
FLOOR_BAND     = 3                          ; each floor shade covers 3 rows
WALL_CHAR      = 219                        ; code page 437 full block: every wall cell
DOOR_COLOR_A   = lightRed + (black * 16)    ; exit door colour 1 (bright red)
DOOR_COLOR_B   = yellow + (black * 16)      ; exit door colour 2 (yellow)
DEFAULT_ATTR   = lightGray + (black * 16)   ; normal colour: light gray text on black

; ---------- cell types returned by IsWall ----------
CELL_FREE = 0                               ; floor: can walk here
CELL_WALL = 1                               ; '#': blocks movement
CELL_EXIT = 2                               ; 'E': blocks movement, touching it wins

; ---------- game start values and results ----------
START_X     = 384                           ; 1.5 cells: centre of column 1
START_Y     = 384                           ; 1.5 cells: centre of row 1
START_ANGLE = 0                             ; facing east
RESULT_QUIT = 0                             ; GameLoop result: player pressed Q
RESULT_WIN  = 1                             ; GameLoop result: player touched the exit
RESULT_LOSE = 2                             ; GameLoop result: time ran out
MS_PER_DAY  = 86400000                      ; GetMseconds restarts from 0 at midnight
TIME_LIMIT  = 120                           ; seconds allowed to reach the exit

; ---------- HUD layout: where the numbers go inside the HUD row ----------
HUD_MIN_POS  = 5                            ; "TIME mm:ss": minutes start at column 5
HUD_SEC_POS  = 8                            ; seconds start at column 8
HUD_STEP_POS = 18                           ; "STEPS nnnnn": steps start at column 18

.data
; ---------- the maze: 16 rows x 16 columns, 1 byte per cell ----------
; '#' = wall, '.' = floor, 'E' = exit. Cell (row, col) is at gameMap + row*16 + col.
gameMap BYTE "################"             ; row 0  (outer wall)
        BYTE "#......#.......#"             ; row 1  (player starts at col 1)
        BYTE "#.##.#.#.#####.#"             ; row 2
        BYTE "#.#..#...#...#.#"             ; row 3
        BYTE "#.#.####.#.#.#.#"             ; row 4
        BYTE "#...#....#.#...#"             ; row 5
        BYTE "###.#.####.###.#"             ; row 6
        BYTE "#...#.#....#...#"             ; row 7
        BYTE "#.###.#.####.#.#"             ; row 8
        BYTE "#.#...#......#.#"             ; row 9
        BYTE "#.#.#######.##.#"             ; row 10
        BYTE "#...#.....#..#.#"             ; row 11
        BYTE "#.###.###.##.#.#"             ; row 12
        BYTE "#.....#......#.#"             ; row 13
        BYTE "#.#####.######E#"             ; row 14 (exit at col 14)
        BYTE "################"             ; row 15 (outer wall)

; ---------- player data (positions are Q8: value = cells * 256) ----------
posX      DWORD START_X                     ; X in Q8, set again by ResetGame
posY      DWORD START_Y                     ; Y in Q8, set again by ResetGame
angle     DWORD START_ANGLE                 ; facing direction in degrees (0..359), 0 = east
steps     DWORD 0                           ; number of steps the player has taken
startTime DWORD 0                           ; time (ms from GetMseconds) when the game started

; ---------- game state flags ----------
showMinimap BYTE 1                          ; 1 = minimap visible, 0 = hidden (M toggles)
quitFlag    BYTE 0                          ; becomes 1 when the player presses Q
wonFlag     BYTE 0                          ; becomes 1 when the player touches the exit
mWasDown    BYTE 0                          ; 1 if M was held last frame (for single press)
qWasDown    BYTE 0                          ; 1 if Q was held last frame (for single press)
inputHandle DWORD ?                         ; console input handle (set by InitInput)

; ---------- sine table: sinTable[d] = round(sin(d degrees) * 256) ----------
sinTable SDWORD    0,   4,   9,  13,  18,  22,  27,  31,  36,  40   ; 0-9 deg
         SDWORD   44,  49,  53,  58,  62,  66,  71,  75,  79,  83   ; 10-19 deg
         SDWORD   88,  92,  96, 100, 104, 108, 112, 116, 120, 124   ; 20-29 deg
         SDWORD  128, 132, 136, 139, 143, 147, 150, 154, 158, 161   ; 30-39 deg
         SDWORD  165, 168, 171, 175, 178, 181, 184, 187, 190, 193   ; 40-49 deg
         SDWORD  196, 199, 202, 204, 207, 210, 212, 215, 217, 219   ; 50-59 deg
         SDWORD  222, 224, 226, 228, 230, 232, 234, 236, 237, 239   ; 60-69 deg
         SDWORD  241, 242, 243, 245, 246, 247, 248, 249, 250, 251   ; 70-79 deg
         SDWORD  252, 253, 254, 254, 255, 255, 255, 256, 256, 256   ; 80-89 deg
         SDWORD  256, 256, 256, 256, 255, 255, 255, 254, 254, 253   ; 90-99 deg
         SDWORD  252, 251, 250, 249, 248, 247, 246, 245, 243, 242   ; 100-109 deg
         SDWORD  241, 239, 237, 236, 234, 232, 230, 228, 226, 224   ; 110-119 deg
         SDWORD  222, 219, 217, 215, 212, 210, 207, 204, 202, 199   ; 120-129 deg
         SDWORD  196, 193, 190, 187, 184, 181, 178, 175, 171, 168   ; 130-139 deg
         SDWORD  165, 161, 158, 154, 150, 147, 143, 139, 136, 132   ; 140-149 deg
         SDWORD  128, 124, 120, 116, 112, 108, 104, 100,  96,  92   ; 150-159 deg
         SDWORD   88,  83,  79,  75,  71,  66,  62,  58,  53,  49   ; 160-169 deg
         SDWORD   44,  40,  36,  31,  27,  22,  18,  13,   9,   4   ; 170-179 deg
         SDWORD    0,  -4,  -9, -13, -18, -22, -27, -31, -36, -40   ; 180-189 deg
         SDWORD  -44, -49, -53, -58, -62, -66, -71, -75, -79, -83   ; 190-199 deg
         SDWORD  -88, -92, -96,-100,-104,-108,-112,-116,-120,-124   ; 200-209 deg
         SDWORD -128,-132,-136,-139,-143,-147,-150,-154,-158,-161   ; 210-219 deg
         SDWORD -165,-168,-171,-175,-178,-181,-184,-187,-190,-193   ; 220-229 deg
         SDWORD -196,-199,-202,-204,-207,-210,-212,-215,-217,-219   ; 230-239 deg
         SDWORD -222,-224,-226,-228,-230,-232,-234,-236,-237,-239   ; 240-249 deg
         SDWORD -241,-242,-243,-245,-246,-247,-248,-249,-250,-251   ; 250-259 deg
         SDWORD -252,-253,-254,-254,-255,-255,-255,-256,-256,-256   ; 260-269 deg
         SDWORD -256,-256,-256,-256,-255,-255,-255,-254,-254,-253   ; 270-279 deg
         SDWORD -252,-251,-250,-249,-248,-247,-246,-245,-243,-242   ; 280-289 deg
         SDWORD -241,-239,-237,-236,-234,-232,-230,-228,-226,-224   ; 290-299 deg
         SDWORD -222,-219,-217,-215,-212,-210,-207,-204,-202,-199   ; 300-309 deg
         SDWORD -196,-193,-190,-187,-184,-181,-178,-175,-171,-168   ; 310-319 deg
         SDWORD -165,-161,-158,-154,-150,-147,-143,-139,-136,-132   ; 320-329 deg
         SDWORD -128,-124,-120,-116,-112,-108,-104,-100, -96, -92   ; 330-339 deg
         SDWORD  -88, -83, -79, -75, -71, -66, -62, -58, -53, -49   ; 340-349 deg
         SDWORD  -44, -40, -36, -31, -27, -22, -18, -13,  -9,  -4   ; 350-359 deg

; ---------- shading data ----------
; wall distance limits in Q8 (256 = 1 cell): closer than shadeDist1 = level 0, etc.
shadeDist1  DWORD 512                       ; under 2 cells  -> level 0 (darkest/solid)
shadeDist2  DWORD 1024                      ; under 4 cells  -> level 1
shadeDist3  DWORD 2048                      ; under 8 cells  -> level 2, else level 3
wallColors  BYTE lightCyan, cyan, lightBlue, blue  ; wall colours: nearest (brightest) first
floorShades BYTE '#', 'x', '-', '.'         ; floor: nearest rows first

; ---------- screen drawing data ----------
frameBuffer   BYTE SCREEN_W * BUF_H DUP(' ')      ; 80x25 = 2000 chars, cell (row,col) at row*80 + col
attrBuffer    WORD SCREEN_W * BUF_H DUP(DEFAULT_ATTR) ; colour of each cell, same layout (2 bytes each)
consoleHandle DWORD ?                       ; handle of the console output (set by HideCursor)
cursorInfo    CONSOLE_CURSOR_INFO <100, 0>  ; cursor size 100%, bVisible = 0 (hidden)
drawPos       COORD <0, 0>                  ; screen position (0,0) where drawing starts
charsWritten  DWORD ?                       ; Windows stores how many chars it wrote here

; ---------- title screen text ----------
titleLine1 BYTE "==============================", 0   ; top border
titleLine2 BYTE "           WOLF-86            ", 0   ; game name
titleLine3 BYTE "   A 3D Raycasting Maze Game  ", 0   ; subtitle
titleLine4 BYTE "==============================", 0   ; bottom border
ctrlHead   BYTE "CONTROLS:", 0                       ; controls heading
ctrlMove   BYTE "  W / S  - move forward / back", 0  ; movement keys
ctrlTurn   BYTE "  A / D  - turn left / right", 0    ; turning keys
ctrlMap    BYTE "  M      - show / hide minimap", 0  ; minimap key
ctrlQuit   BYTE "  Q      - quit", 0                 ; quit key
goalHead   BYTE "GOAL:", 0                           ; goal heading
goalText   BYTE "  Reach the exit (E) before time runs out!", 0 ; goal text
pressKey   BYTE "Press any key to start...", 0       ; prompt

; ---------- HUD text (numbers are filled in each frame) ----------
hudTemplate BYTE "TIME 00:00  STEPS 00000  W/S move  A/D turn  M map  Q quit"
HUD_LEN = ($ - hudTemplate)                 ; number of characters in the template

; ---------- end screen text ----------
winTitle   BYTE "*** YOU ESCAPED! ***", 0                 ; win heading
loseTitle  BYTE "*** TIME'S UP! ***", 0                   ; lose heading
loseText   BYTE "You did not reach the exit in time.", 0  ; lose message
timeMsg    BYTE "Time taken: ", 0                         ; label before mm:ss
stepsMsg   BYTE "Steps:      ", 0                         ; label before the step count
againMsg   BYTE "Play again? (Y/N)", 0                    ; question on both screens

.code
;-------------------------------------------------------------
; main
; Purpose:   Program entry. Title screen, then play games
;            until the player quits (Q) or says N to
;            "Play again?".
; Receives:  nothing
; Returns:   nothing (ends the program)
; Registers: none kept (program ends)
;-------------------------------------------------------------
main PROC
    INVOKE SetConsoleOutputCP, CODE_PAGE_437 ; show bytes 176..219 as block characters
    INVOKE HideCursor                       ; get console handle and hide the cursor
    INVOKE InitInput                        ; get console input handle (for flushing keys)
    INVOKE TitleScreen                      ; show the title screen, EAX = key pressed
    and    al, 11011111b                    ; make the key uppercase
    cmp    al, 'Q'                          ; Q on the title screen?
    je     QuitProgram                      ; yes: quit straight away
NewGame:
    INVOKE WaitKeysReleased                 ; the last key pressed can't trigger M or Q
    INVOKE ResetGame                        ; start position, angle, steps, timer
    mov    eax, lightGray + (black * 16)    ; normal colours (win/lose screens used green/red)
    call   SetTextColor                     ; Clrscr paints every cell with this colour
    call   Clrscr                           ; clean screen for the game
    INVOKE GameLoop                         ; play; EAX = how the game ended
    cmp    eax, RESULT_QUIT                 ; pressed Q?
    je     QuitProgram                      ; yes: end the program
    cmp    eax, RESULT_WIN                  ; reached the exit?
    jne    PlayerLost                       ; no: time ran out
    INVOKE WinScreen                        ; show the win screen
    jmp    AskAgain                         ; then ask about another game
PlayerLost:
    INVOKE LoseScreen                       ; show the lose screen
AskAgain:
    INVOKE AskPlayAgain                     ; EAX = 1 for Y, 0 for N/Q
    cmp    eax, 1                           ; play again?
    je     NewGame                          ; yes: start a new game
QuitProgram:
    mov    eax, lightGray + (black * 16)    ; normal colours for the console we leave behind
    call   SetTextColor                     ; apply them
    call   Clrscr                           ; leave a clean console behind
    INVOKE ExitProcess, 0                   ; end the program with exit code 0
main ENDP

;-------------------------------------------------------------
; GetSin
; Purpose:   Look up sin(angle) in the table.
; Receives:  EAX = angle in degrees (0..359)
; Returns:   EAX = sin(angle) * 256 (signed, -256..256)
; Registers: EAX only
;-------------------------------------------------------------
GetSin PROC
    mov  eax, sinTable[eax*4]               ; each entry is 4 bytes, so index = angle*4
    ret                                     ; return with the value in EAX
GetSin ENDP

;-------------------------------------------------------------
; GetCos
; Purpose:   Find cos(angle) using cos(a) = sin(a + 90).
; Receives:  EAX = angle in degrees (0..359)
; Returns:   EAX = cos(angle) * 256 (signed, -256..256)
; Registers: EAX only
;-------------------------------------------------------------
GetCos PROC
    add  eax, 90                            ; shift the angle by 90 degrees
    cmp  eax, 360                           ; did it go past 359?
    jb   AngleOK                            ; no: angle is already 0..359
    sub  eax, 360                           ; yes: wrap it back around (mod 360)
AngleOK:
    call GetSin                             ; EAX = sin(angle + 90) = cos(angle)
    ret                                     ; return with the value in EAX
GetCos ENDP

;-------------------------------------------------------------
; TitleScreen
; Purpose:   Clear the screen, show the game name, controls
;            and goal, then wait for a key press.
; Receives:  nothing
; Returns:   EAX = the key that was pressed (in AL)
; Registers: EAX (EDX saved by USES)
;-------------------------------------------------------------
TitleScreen PROC USES edx
    call Clrscr                             ; clear the console

    mov  eax, yellow + (black * 16)         ; yellow text on black background
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET titleLine1             ; top border
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET titleLine2             ; game name
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET titleLine3             ; subtitle
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET titleLine4             ; bottom border
    call WriteString                        ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line

    mov  eax, white + (black * 16)          ; white text on black background
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET ctrlHead               ; "CONTROLS:"
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET ctrlMove               ; W / S line
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET ctrlTurn               ; A / D line
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET ctrlMap                ; M line
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET ctrlQuit               ; Q line
    call WriteString                        ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line

    mov  edx, OFFSET goalHead               ; "GOAL:"
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET goalText               ; goal description
    call WriteString                        ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line

    mov  eax, lightGray + (black * 16)      ; normal grey text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET pressKey               ; "Press any key..."
    call WriteString                        ; print it
    call ReadChar                           ; wait for a key (key code goes to AL)
    movzx eax, al                           ; EAX = just the key code
    ret                                     ; back to caller
TitleScreen ENDP

;-------------------------------------------------------------
; ClearBuffer
; Purpose:   Fill the whole frameBuffer (view + HUD row) with
;            spaces and the whole attrBuffer with the normal
;            colour (light gray on black).
; Receives:  nothing
; Returns:   nothing
; Registers: none (EAX, ECX, EDI saved by USES)
;-------------------------------------------------------------
ClearBuffer PROC USES eax ecx edi
    cld                                     ; direction flag = 0, so EDI moves forward
    mov  al, ' '                            ; AL = the byte to store (a space)
    mov  ecx, SCREEN_W * BUF_H              ; ECX = how many bytes (2000)
    mov  edi, OFFSET frameBuffer            ; EDI = start of the buffer
    rep  stosb                              ; store AL at [EDI], EDI++, repeat ECX times
    mov  ax, DEFAULT_ATTR                   ; AX = the word to store (normal colour)
    mov  ecx, SCREEN_W * BUF_H              ; ECX = how many words (2000)
    mov  edi, OFFSET attrBuffer             ; EDI = start of the colour buffer
    rep  stosw                              ; store AX at [EDI], EDI += 2, repeat ECX times
    ret                                     ; back to caller
ClearBuffer ENDP

;-------------------------------------------------------------
; HideCursor
; Purpose:   Get the console output handle (saved in
;            consoleHandle) and hide the blinking cursor.
;            Must be called once before DrawBuffer.
; Receives:  nothing
; Returns:   consoleHandle is set
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
HideCursor PROC USES eax ecx edx
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE  ; ask Windows for the console output handle
    mov  consoleHandle, eax                 ; save it for later drawing
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo ; bVisible = 0 hides the cursor
    ret                                     ; back to caller
HideCursor ENDP

;-------------------------------------------------------------
; DrawBuffer
; Purpose:   Copy frameBuffer and attrBuffer to the console one
;            row at a time: for each of the 25 rows (24 view rows
;            + HUD row) write 80 chars, then their 80 colours,
;            to (0,row).
;            Nothing is cleared, only overwritten, so no flicker,
;            and each row starts at column 0 at any console width.
; Receives:  nothing (uses frameBuffer, attrBuffer, consoleHandle)
; Returns:   nothing
; Registers: none (EAX, EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawBuffer PROC USES eax ebx ecx edx esi edi
    mov  esi, OFFSET frameBuffer            ; ESI = start of row 0 of the characters
    mov  edi, OFFSET attrBuffer             ; EDI = start of row 0 of the colours
    mov  ebx, 0                             ; EBX = row number, start at 0
RowLoop:
    mov  drawPos.X, 0                       ; screen column 0
    mov  drawPos.Y, bx                      ; screen row = current row number
    INVOKE WriteConsoleOutputCharacter, ; write characters straight into the console
           consoleHandle,               ; where to write
           esi,                         ; what to write: frameBuffer + row*80
           SCREEN_W,                    ; how many characters (80, one row)
           drawPos,                     ; start at (0, row)
           ADDR charsWritten            ; Windows puts the count here
    INVOKE WriteConsoleOutputAttribute, ; write the colours of the same 80 cells
           consoleHandle,               ; where to write
           edi,                         ; what to write: attrBuffer + row*80 words
           SCREEN_W,                    ; how many colours (80, one row)
           drawPos,                     ; start at (0, row)
           ADDR charsWritten            ; Windows puts the count here
    add  edi, SCREEN_W * 2                  ; next row of colours (each colour is 2 bytes)
    add  esi, SCREEN_W                      ; move ESI to the start of the next row
    inc  ebx                                ; next row number
    cmp  ebx, BUF_H                         ; done all 25 rows?
    jb   RowLoop                            ; no: write the next row
    ret                                     ; back to caller
DrawBuffer ENDP

;-------------------------------------------------------------
; GetMoveDelta
; Purpose:   Work out how far one forward step moves the
;            player in X and in Y, for the current angle.
;            dx = cos(angle) * MOVE_SPEED / 256
;            dy = sin(angle) * MOVE_SPEED / 256
; Receives:  angle (global)
; Returns:   EAX = dx (Q8), EDX = dy (Q8)
; Registers: EAX, EDX
;-------------------------------------------------------------
GetMoveDelta PROC
    mov  eax, angle                         ; EAX = current angle
    call GetCos                             ; EAX = cos(angle) * 256
    FIXMUL eax, MOVE_SPEED                  ; EAX = cos * MOVE_SPEED / 256 -> dx in Q8
    push eax                                ; save dx on the stack
    mov  eax, angle                         ; EAX = current angle
    call GetSin                             ; EAX = sin(angle) * 256
    FIXMUL eax, MOVE_SPEED                  ; EAX = sin * MOVE_SPEED / 256 -> dy in Q8
    mov  edx, eax                           ; EDX = dy
    pop  eax                                ; EAX = dx again
    ret                                     ; back to caller
GetMoveDelta ENDP

;-------------------------------------------------------------
; IsWall
; Purpose:   Find out what kind of cell a Q8 position is in.
; Receives:  testX, testY = position in Q8 (cells * 256)
;            (a position outside the 16x16 map counts as a wall)
; Returns:   EAX = CELL_WALL ('#'), CELL_EXIT ('E') or
;                  CELL_FREE (anything else)
; Registers: EAX (EBX, ESI saved by USES)
;-------------------------------------------------------------
IsWall PROC USES ebx esi, testX:SDWORD, testY:SDWORD
    mov  eax, testY                         ; EAX = Y in Q8
    sar  eax, 8                             ; EAX = row (whole cells)
    cmp  eax, MAP_H - 1                     ; row above 15? (unsigned: a negative row is huge too)
    ja   OutsideMap                         ; yes: outside the map
    shl  eax, 4                             ; EAX = row * 16 (start of that map row)
    mov  ebx, testX                         ; EBX = X in Q8
    sar  ebx, 8                             ; EBX = column (whole cells)
    cmp  ebx, MAP_W - 1                     ; column above 15? (unsigned check)
    ja   OutsideMap                         ; yes: outside the map
    add  eax, ebx                           ; EAX = row*16 + col = index into gameMap (0..255)
    mov  esi, OFFSET gameMap                ; ESI = base address of the map
    mov  bl, [esi + eax]                    ; BL = map character (base-index addressing)
    mov  eax, CELL_WALL                     ; assume wall
    cmp  bl, '#'                            ; is it a wall?
    je   WallDone                           ; yes: return CELL_WALL
    mov  eax, CELL_EXIT                     ; assume exit
    cmp  bl, 'E'                            ; is it the exit?
    je   WallDone                           ; yes: return CELL_EXIT
    mov  eax, CELL_FREE                     ; otherwise free floor
    jmp  WallDone                           ; finished
OutsideMap:
    mov  eax, CELL_WALL                     ; outside the map: treat as a wall
WallDone:
    ret                                     ; back to caller
IsWall ENDP

;-------------------------------------------------------------
; ProbePoint
; Purpose:   Give the point to test for walls: the new position
;            plus MARGIN further in the direction of movement.
; Receives:  newPos = new X or Y (Q8), delta = movement (+ or -)
; Returns:   EAX = newPos + MARGIN (delta > 0) or
;                  newPos - MARGIN (delta < 0)
; Registers: EAX only
;-------------------------------------------------------------
ProbePoint PROC, newPos:SDWORD, delta:SDWORD
    mov  eax, newPos                        ; EAX = the new position
    cmp  delta, 0                           ; moving in the negative direction?
    jl   ProbeNeg                           ; yes
    add  eax, MARGIN                        ; no: look a bit further ahead (+)
    jmp  ProbeDone                          ; finished
ProbeNeg:
    sub  eax, MARGIN                        ; look a bit further ahead (-)
ProbeDone:
    ret                                     ; back to caller
ProbePoint ENDP

;-------------------------------------------------------------
; TryMove
; Purpose:   Move the player by (moveDX, moveDY) if no wall is
;            within MARGIN of the new position. X and Y are
;            checked separately so the player slides along
;            walls. steps++ if it moved. If a probe touches
;            the exit, wonFlag = 1 (the exit blocks like a wall).
; Receives:  moveDX, moveDY = movement in Q8
; Returns:   posX, posY, steps, wonFlag updated
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
TryMove PROC USES eax ecx edx, moveDX:SDWORD, moveDY:SDWORD
    mov  ecx, 0                             ; ECX = 1 once we really move
    cmp  moveDX, 0                          ; any X movement at all?
    je   TryY                               ; no: skip the X test
    mov  edx, posX                          ; EDX = current X
    add  edx, moveDX                        ; EDX = new X
    INVOKE ProbePoint, edx, moveDX          ; EAX = new X + margin ahead
    INVOKE IsWall, eax, posY                ; that point with OLD Y: what cell?
    cmp  eax, CELL_EXIT                     ; touching the exit?
    jne  XNotExit                           ; no
    mov  wonFlag, 1                         ; yes: the player wins
XNotExit:
    cmp  eax, CELL_FREE                     ; free floor?
    jne  TryY                               ; wall or exit: do not move in X
    mov  posX, edx                          ; free: accept the new X
    mov  ecx, 1                             ; remember that we moved
TryY:
    cmp  moveDY, 0                          ; any Y movement at all?
    je   MoveDone                           ; no: skip the Y test
    mov  edx, posY                          ; EDX = current Y
    add  edx, moveDY                        ; EDX = new Y
    INVOKE ProbePoint, edx, moveDY          ; EAX = new Y + margin ahead
    INVOKE IsWall, posX, eax                ; (maybe new) X with that Y: what cell?
    cmp  eax, CELL_EXIT                     ; touching the exit?
    jne  YNotExit                           ; no
    mov  wonFlag, 1                         ; yes: the player wins
YNotExit:
    cmp  eax, CELL_FREE                     ; free floor?
    jne  MoveDone                           ; wall or exit: do not move in Y
    mov  posY, edx                          ; free: accept the new Y
    mov  ecx, 1                             ; remember that we moved
MoveDone:
    cmp  ecx, 0                             ; did we move at all?
    je   NoStep                             ; no: steps stay the same
    inc  steps                              ; yes: count one step
NoStep:
    ret                                     ; back to caller
TryMove ENDP

;-------------------------------------------------------------
; TurnPlayer
; Purpose:   Add turnAmount to angle and keep it in 0..359.
; Receives:  turnAmount = degrees to turn (+ right, - left)
; Returns:   angle updated
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
TurnPlayer PROC USES eax, turnAmount:SDWORD
    mov  eax, angle                         ; EAX = current angle
    add  eax, turnAmount                    ; turn
    call WrapAngle                          ; keep it in 0..359
    mov  angle, eax                         ; save the new angle
    ret                                     ; back to caller
TurnPlayer ENDP

;-------------------------------------------------------------
; WrapAngle
; Purpose:   Bring an angle back into 0..359.
; Receives:  EAX = angle, between -360 and 719
; Returns:   EAX = same direction, now 0..359
; Registers: EAX only
;-------------------------------------------------------------
WrapAngle PROC
    cmp  eax, 0                             ; below 0? (signed compare)
    jge  WrapNotNegative                    ; no
    add  eax, 360                           ; yes: e.g. -5 becomes 355
WrapNotNegative:
    cmp  eax, 360                           ; 360 or more?
    jl   WrapDone                           ; no: already fine
    sub  eax, 360                           ; yes: e.g. 365 becomes 5
WrapDone:
    ret                                     ; back to caller
WrapAngle ENDP

;-------------------------------------------------------------
; AnyKeyDown
; Purpose:   Check every keyboard key code (8..254) to see if
;            any key is still held down.
; Receives:  nothing
; Returns:   EAX = 1 if some key is held, 0 if none
; Registers: EAX (ECX saved by USES)
;-------------------------------------------------------------
AnyKeyDown PROC USES ecx
    mov  ecx, 8                             ; codes 1..7 are mouse buttons, start at 8
CheckNextKey:
    INVOKE KeyDown, ecx                     ; EAX = 1 if this key is held
    cmp  eax, 0                             ; held?
    jne  FoundKey                           ; yes: stop looking
    inc  ecx                                ; next key code
    cmp  ecx, 255                           ; checked all of them?
    jb   CheckNextKey                       ; no: keep checking
    mov  eax, 0                             ; no key is held
    ret                                     ; back to caller
FoundKey:
    mov  eax, 1                             ; a key is held
    ret                                     ; back to caller
AnyKeyDown ENDP

;-------------------------------------------------------------
; WaitKeysReleased
; Purpose:   After the title screen, wait (max 2 s) until no
;            key is held, then set mWasDown/qWasDown from the
;            real key state. So the key that closed the title
;            screen can never count as an M or Q press.
; Receives:  nothing
; Returns:   mWasDown, qWasDown set
; Registers: none (EAX, ECX saved by USES)
;-------------------------------------------------------------
WaitKeysReleased PROC USES eax ecx
    mov  ecx, KEY_WAIT_TRIES                ; give up after this many tries
WaitLoop:
    call AnyKeyDown                         ; EAX = 1 if something is still held
    cmp  eax, 0                             ; all keys up?
    je   KeysReleased                       ; yes: done waiting
    mov  eax, 10                            ; 10 milliseconds
    call Delay                              ; wait a little and look again
    loop WaitLoop                           ; ECX--, try again until ECX = 0
KeysReleased:
    INVOKE KeyDown, 'M'                     ; is M held right now?
    mov  mWasDown, al                       ; if yes, the game won't see it as a new press
    INVOKE KeyDown, 'Q'                     ; is Q held right now?
    mov  qWasDown, al                       ; same for Q
    ret                                     ; back to caller
WaitKeysReleased ENDP

;-------------------------------------------------------------
; InitInput
; Purpose:   Get the console input handle (used to throw away
;            waiting key events each frame).
; Receives:  nothing
; Returns:   inputHandle is set
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
InitInput PROC USES eax ecx edx
    INVOKE GetStdHandle, STD_INPUT_HANDLE   ; ask Windows for the console input handle
    mov  inputHandle, eax                   ; save it
    ret                                     ; back to caller
InitInput ENDP

;-------------------------------------------------------------
; KeyDown
; Purpose:   Check if a key is being held down right now.
; Receives:  vKey = virtual key code ('W', 'A', ... are the
;            same as their uppercase ASCII codes)
; Returns:   EAX = 1 if held, 0 if not
; Registers: EAX (ECX, EDX saved by USES)
;-------------------------------------------------------------
KeyDown PROC USES ecx edx, vKey:DWORD
    INVOKE GetAsyncKeyState, vKey           ; AX = key state
    test ax, 8000h                          ; bit 15 set = key is down
    jz   KeyIsUp                            ; bit is 0: key is up
    mov  eax, 1                             ; key is down: return 1
    jmp  KeyDownDone                        ; finished
KeyIsUp:
    mov  eax, 0                             ; key is up: return 0
KeyDownDone:
    ret                                     ; back to caller
KeyDown ENDP

;-------------------------------------------------------------
; KeyPressed
; Purpose:   Report a key only on the frame it goes DOWN
;            (held key = one press, not one per frame).
; Receives:  vKey    = virtual key code
;            prevPtr = address of a BYTE holding last frame's
;                      state (1 = was down); it is updated
; Returns:   EAX = 1 if the key is down now AND was up before
; Registers: EAX (ECX, ESI saved by USES)
;-------------------------------------------------------------
KeyPressed PROC USES ecx esi, vKey:DWORD, prevPtr:PTR BYTE
    INVOKE KeyDown, vKey                    ; EAX = 1 if down now
    mov  esi, prevPtr                       ; ESI = address of the "was down" byte
    movzx ecx, BYTE PTR [esi]               ; ECX = last frame's state
    mov  [esi], al                          ; save this frame's state for next time
    cmp  ecx, 0                             ; was it up last frame?
    je   PressDone                          ; yes: EAX (0 or 1) is the answer
    mov  eax, 0                             ; it was already down: not a new press
PressDone:
    ret                                     ; back to caller
KeyPressed ENDP

;-------------------------------------------------------------
; HandleInput
; Purpose:   Check the keys every frame. Held keys: A/D turn,
;            W/S move (they can combine, e.g. W+A). Single
;            presses: M toggles minimap, Q quits. Old console
;            key events are thrown away so they don't pile up.
; Receives:  nothing
; Returns:   posX/posY/angle/showMinimap/quitFlag may change
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
HandleInput PROC USES eax ecx edx
    INVOKE FlushConsoleInputBuffer, inputHandle ; drop waiting key events
    INVOKE KeyDown, 'A'                     ; A held?
    cmp  eax, 0                             ; 0 = not held
    je   CheckD                             ; skip turning left
    INVOKE TurnPlayer, -TURN_STEP           ; turn left 5 degrees
CheckD:
    INVOKE KeyDown, 'D'                     ; D held?
    cmp  eax, 0                             ; 0 = not held
    je   CheckW                             ; skip turning right
    INVOKE TurnPlayer, TURN_STEP            ; turn right 5 degrees
CheckW:
    INVOKE KeyDown, 'W'                     ; W held?
    cmp  eax, 0                             ; 0 = not held
    je   CheckS                             ; skip moving forward
    call GetMoveDelta                       ; EAX = dx, EDX = dy
    INVOKE TryMove, eax, edx                ; move forward if possible
CheckS:
    INVOKE KeyDown, 'S'                     ; S held?
    cmp  eax, 0                             ; 0 = not held
    je   CheckM                             ; skip moving back
    call GetMoveDelta                       ; EAX = dx, EDX = dy
    neg  eax                                ; reverse X direction
    neg  edx                                ; reverse Y direction
    INVOKE TryMove, eax, edx                ; move backward if possible
CheckM:
    INVOKE KeyPressed, 'M', ADDR mWasDown   ; M newly pressed?
    cmp  eax, 0                             ; 0 = no new press
    je   CheckQ                             ; skip the toggle
    xor  showMinimap, 1                     ; 1 -> 0 or 0 -> 1
CheckQ:
    INVOKE KeyPressed, 'Q', ADDR qWasDown   ; Q newly pressed?
    cmp  eax, 0                             ; 0 = no new press
    je   InputDone                          ; keep playing
    mov  quitFlag, 1                        ; tell the game loop to stop
InputDone:
    ret                                     ; back to caller
HandleInput ENDP

;-------------------------------------------------------------
; GetArrowChar
; Purpose:   Pick the minimap arrow for the player's angle,
;            using 90-degree ranges centred on each direction.
;            315..44 -> '>'   45..134 -> 'v'
;            135..224 -> '<'  225..314 -> '^'
; Receives:  angle (global, 0..359)
; Returns:   EAX = arrow character (in AL)
; Registers: EAX only
;-------------------------------------------------------------
GetArrowChar PROC
    mov  eax, angle                         ; EAX = current angle
    cmp  eax, 45                            ; below 45?
    jb   ArrowRight                         ; yes: facing east
    cmp  eax, 135                           ; below 135?
    jb   ArrowDown                          ; yes: facing south (screen down)
    cmp  eax, 225                           ; below 225?
    jb   ArrowLeft                          ; yes: facing west
    cmp  eax, 315                           ; below 315?
    jb   ArrowUp                            ; yes: facing north (screen up)
ArrowRight:
    mov  eax, '>'                           ; 315..359 or 0..44
    ret                                     ; back to caller
ArrowDown:
    mov  eax, 'v'                           ; 45..134
    ret                                     ; back to caller
ArrowLeft:
    mov  eax, '<'                           ; 135..224
    ret                                     ; back to caller
ArrowUp:
    mov  eax, '^'                           ; 225..314
    ret                                     ; back to caller
GetArrowChar ENDP

;-------------------------------------------------------------
; DrawMinimap
; Purpose:   If showMinimap = 1, copy the 16x16 map into the
;            top-left of frameBuffer and put a direction arrow
;            on the player's cell.
; Receives:  nothing (uses gameMap, posX, posY)
; Returns:   nothing
; Registers: none (EAX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawMinimap PROC USES eax ecx edx esi edi
    cmp  showMinimap, 0                     ; is the minimap hidden?
    je   MapDone                            ; yes: draw nothing
    cld                                     ; copy forwards
    mov  esi, OFFSET gameMap                ; ESI = source (map row 0)
    mov  edi, OFFSET frameBuffer            ; EDI = destination (screen row 0, col 0)
    mov  edx, MAP_H                         ; EDX = 16 rows to copy
CopyRow:
    mov  ecx, MAP_W                         ; ECX = 16 bytes in one map row
    rep  movsb                              ; copy [ESI] -> [EDI], 16 times (both move on)
    add  edi, SCREEN_W - MAP_W              ; skip the other 64 screen columns to the next row
    dec  edx                                ; one row done
    jnz  CopyRow                            ; more rows left: copy the next
    mov  ecx, posY                          ; ECX = Y in Q8
    sar  ecx, 8                             ; ECX = player row
    imul ecx, SCREEN_W                      ; ECX = row * 80 (start of that screen row)
    mov  edx, posX                          ; EDX = X in Q8
    sar  edx, 8                             ; EDX = player column
    add  ecx, edx                           ; ECX = row*80 + col
    call GetArrowChar                       ; AL = arrow for the facing direction
    mov  frameBuffer[ecx], al               ; draw the arrow on the player's cell
MapDone:
    ret                                     ; back to caller
DrawMinimap ENDP

;-------------------------------------------------------------
; SetupAxis
; Purpose:   DDA setup for ONE axis (call once for X, once
;            for Y). All values are Q8.
;            deltaDist = ray length to cross one whole cell
;                        on this axis = 256*256 / |dir|
;            step      = +1 or -1 (which way we move in cells)
;            sideDist  = ray length from the player to the
;                        FIRST grid line on this axis
; Receives:  axisPos = player position on this axis (Q8)
;            axisDir = ray direction on this axis (cos or
;                      sin value, -256..256)
; Returns:   EAX = deltaDist, EBX = sideDist, ECX = step
; Registers: EAX, EBX, ECX (EDX, ESI saved by USES)
;-------------------------------------------------------------
SetupAxis PROC USES edx esi, axisPos:SDWORD, axisDir:SDWORD
    mov  esi, axisDir                       ; ESI = direction on this axis
    cmp  esi, 0                             ; ray exactly parallel to this axis?
    jne  DirNotZero                         ; no: normal case
    mov  eax, BIG_DIST                      ; never crosses a line: "infinite" deltaDist
    mov  ebx, BIG_DIST                      ; and the first line is "infinitely" far
    mov  ecx, 1                             ; step not used, any value is fine
    ret                                     ; back to caller (no divide by zero)
DirNotZero:
    mov  ecx, 1                             ; assume moving + (right / down)
    cmp  esi, 0                             ; is the direction negative?
    jg   DirPositive                        ; no: keep step = +1
    neg  esi                                ; ESI = |dir|
    mov  ecx, -1                            ; moving - (left / up)
DirPositive:
    mov  eax, 65536                         ; 256 * 256 (1.0 in Q8, divided by a Q8 number)
    mov  edx, 0                             ; clear EDX before DIV
    div  esi                                ; EAX = deltaDist = 65536 / |dir|
    mov  edx, axisPos                       ; EDX = position in Q8
    and  edx, 255                           ; EDX = how far into the current cell (0..255)
    cmp  ecx, 1                             ; moving + ?
    jne  HaveGap                            ; no: gap back to the cell's start = EDX
    neg  edx                                ; moving +: gap forward = 256 - EDX
    add  edx, 256                           ; EDX = gap to the next grid line (Q8)
HaveGap:
    mov  ebx, eax                           ; EBX = deltaDist
    FIXMUL ebx, edx                         ; EBX = deltaDist * gap / 256 -> sideDist (no overflow)
    ret                                     ; back to caller
SetupAxis ENDP

;-------------------------------------------------------------
; CastRay
; Purpose:   Send one ray from the player and find the
;            distance to the first wall, using DDA (jump from
;            grid line to grid line, one cell at a time).
; Receives:  rayAngle = ray direction in degrees (0..359)
; Returns:   EAX = distance to the wall (Q8), fisheye-
;            corrected, at least 1
;            EDX = hitSide (0 = hit an X gridline,
;                           1 = hit a Y gridline)
;            ECX = 1 if the cell hit is the exit 'E', else 0
; Registers: EAX, ECX, EDX (EBX, ESI, EDI saved by USES)
;-------------------------------------------------------------
CastRay PROC USES ebx esi edi, rayAngle:DWORD
    LOCAL mapX:SDWORD, mapY:SDWORD          ; the cell the ray is in now
    LOCAL stepX:SDWORD, stepY:SDWORD        ; +1 or -1 per axis
    LOCAL deltaX:SDWORD, deltaY:SDWORD      ; ray length to cross one cell, per axis
    LOCAL sideX:SDWORD, sideY:SDWORD        ; ray length to the next X / Y grid line
    LOCAL hitSide:DWORD                     ; 0 = last step was in X, 1 = in Y
    LOCAL hitExit:DWORD                     ; 1 if the ray stopped on the exit

    mov  hitExit, 0                         ; assume a normal wall until we know

    ; ----- block 1: ray direction from the tables -----
    mov  eax, rayAngle                      ; EAX = ray angle
    call GetCos                             ; EAX = cos * 256
    mov  edi, eax                           ; EDI = dirX
    mov  eax, rayAngle                      ; EAX = ray angle
    call GetSin                             ; EAX = sin * 256
    mov  esi, eax                           ; ESI = dirY

    ; ----- block 2: starting cell and DDA setup per axis -----
    mov  eax, posX                          ; EAX = player X (Q8)
    sar  eax, 8                             ; whole cells
    mov  mapX, eax                          ; start cell column
    mov  eax, posY                          ; EAX = player Y (Q8)
    sar  eax, 8                             ; whole cells
    mov  mapY, eax                          ; start cell row
    INVOKE SetupAxis, posX, edi             ; X axis: EAX = delta, EBX = side, ECX = step
    mov  deltaX, eax                        ; save deltaDist X
    mov  sideX, ebx                         ; save sideDist X
    mov  stepX, ecx                         ; save step X
    INVOKE SetupAxis, posY, esi             ; Y axis: same outputs
    mov  deltaY, eax                        ; save deltaDist Y
    mov  sideY, ebx                         ; save sideDist Y
    mov  stepY, ecx                         ; save step Y

    ; ----- block 3: step cell by cell until a wall or the exit -----
    ; (the map has walls all round, so this always ends;
    ;  the bounds check is an extra safety net)
DDALoop:
    mov  eax, sideX                         ; EAX = distance to next X line
    cmp  eax, sideY                         ; is the X line closer than the Y line?
    jge  StepInY                            ; no: the Y line comes first
    mov  eax, deltaX                        ; yes: cross the X line
    add  sideX, eax                         ; next X line is one deltaX further
    mov  eax, stepX                         ; +1 or -1
    add  mapX, eax                          ; move one cell left/right
    mov  hitSide, 0                         ; we crossed an X line
    jmp  CheckCell                          ; look at the new cell
StepInY:
    mov  eax, deltaY                        ; cross the Y line
    add  sideY, eax                         ; next Y line is one deltaY further
    mov  eax, stepY                         ; +1 or -1
    add  mapY, eax                          ; move one cell up/down
    mov  hitSide, 1                         ; we crossed a Y line
CheckCell:
    cmp  mapX, MAP_W - 1                    ; column outside 0..15? (unsigned check)
    ja   RayHit                             ; yes: stop, never read past the map
    cmp  mapY, MAP_H - 1                    ; row outside 0..15? (unsigned check)
    ja   RayHit                             ; yes: stop, never read past the map
    mov  eax, mapY                          ; EAX = row
    shl  eax, 4                             ; row * 16
    add  eax, mapX                          ; row*16 + col
    cmp  gameMap[eax], '#'                  ; is this cell a wall?
    je   RayHit                             ; yes: stop
    cmp  gameMap[eax], 'E'                  ; is it the exit door?
    jne  DDALoop                            ; no: keep stepping
    mov  hitExit, 1                         ; yes: the exit also stops the ray
RayHit:

    ; ----- block 4: distance along the ray to the wall -----
    ; sideX/sideY is already one cell past the hit line,
    ; so take one delta back off.
    cmp  hitSide, 0                         ; hit on an X line?
    jne  HitOnY                             ; no: Y line
    mov  eax, sideX                         ; distance to the X line after the wall
    sub  eax, deltaX                        ; minus one cell = distance to the wall
    jmp  HaveRayDist                        ; done
HitOnY:
    mov  eax, sideY                         ; distance to the Y line after the wall
    sub  eax, deltaY                        ; minus one cell = distance to the wall
HaveRayDist:
    mov  ebx, eax                           ; EBX = distance along the ray (Q8)

    ; ----- block 5: fisheye correction -----
    ; distance straight ahead = ray distance * cos(rayAngle - angle)
    mov  eax, rayAngle                      ; EAX = ray angle
    sub  eax, angle                         ; angle between this ray and the view centre
    call WrapAngle                          ; keep it 0..359 for the table
    call GetCos                             ; EAX = cos(difference) * 256
    FIXMUL eax, ebx                         ; EAX = cos * dist / 256 = straight-ahead distance (Q8)

    ; ----- block 6: never return 0 or less (we divide by it later) -----
    cmp  eax, 1                             ; at least 1?
    jge  DistOK                             ; yes
    mov  eax, 1                             ; no: use 1
DistOK:
    mov  edx, hitSide                       ; EDX = which kind of gridline we hit
    mov  ecx, hitExit                       ; ECX = 1 if it was the exit
    ret                                     ; back to caller (EAX = distance, EDX = side, ECX = exit)
CastRay ENDP

;-------------------------------------------------------------
; GetWallColor
; Purpose:   Pick the wall colour for a distance. Closer walls
;            are brighter. Y-side walls use one level darker so
;            corners and edges show up.
;            level: 0 = light cyan, 1 = cyan, 2 = light blue,
;                   3 = blue
; Receives:  distance = wall distance (Q8)
;            side     = hitSide from CastRay (0 or 1)
; Returns:   EAX = colour attribute (in AL)
; Registers: EAX only
;-------------------------------------------------------------
GetWallColor PROC, distance:DWORD, side:DWORD
    mov  eax, distance                      ; EAX = distance
    cmp  eax, shadeDist1                    ; under 2 cells?
    jb   Level0                             ; yes
    cmp  eax, shadeDist2                    ; under 4 cells?
    jb   Level1                             ; yes
    cmp  eax, shadeDist3                    ; under 8 cells?
    jb   Level2                             ; yes
    mov  eax, 3                             ; far: level 3
    jmp  AddSide                            ; go apply side shading
Level0:
    mov  eax, 0                             ; level 0
    jmp  AddSide                            ; go apply side shading
Level1:
    mov  eax, 1                             ; level 1
    jmp  AddSide                            ; go apply side shading
Level2:
    mov  eax, 2                             ; level 2
AddSide:
    add  eax, side                          ; Y-side: one level darker (+1)
    cmp  eax, 3                             ; past the darkest level?
    jbe  HaveLevel                          ; no
    mov  eax, 3                             ; yes: stay at the darkest
HaveLevel:
    movzx eax, wallColors[eax]              ; EAX = colour for this level
    ret                                     ; back to caller
GetWallColor ENDP

;-------------------------------------------------------------
; GetFloorChar
; Purpose:   Pick the floor character for a screen row.
;            Rows near the bottom are close to the player and
;            get a dense character; higher rows are further.
;            level = (rows from bottom) / 3, max 3
;            '#' (bottom 3 rows), 'x', '-', '.'
; Receives:  ECX = screen row (0..23)
; Returns:   EAX = floor character (in AL)
; Registers: EAX (EDX saved by USES)
;-------------------------------------------------------------
GetFloorChar PROC USES edx
    mov  eax, SCREEN_H - 1                  ; EAX = 23 (bottom row)
    sub  eax, ecx                           ; EAX = rows from the bottom (0 = bottom)
    mov  edx, 0                             ; clear EDX before DIV
    push ecx                                ; keep the row number safe
    mov  ecx, FLOOR_BAND                    ; divide by 3
    div  ecx                                ; EAX = level
    pop  ecx                                ; ECX = row number again
    cmp  eax, 3                             ; past the last level?
    jbe  FloorLevelOK                       ; no
    mov  eax, 3                             ; yes: use the last level
FloorLevelOK:
    movzx eax, floorShades[eax]             ; EAX = floor character
    ret                                     ; back to caller
GetFloorChar ENDP

;-------------------------------------------------------------
; GetWallHeight
; Purpose:   Turn a distance into a wall height on screen.
;            height = (SCREEN_H * 256) / distance, max SCREEN_H
;            (1 cell away = 256 -> full 24 rows).
; Receives:  EAX = distance (Q8, at least 1)
; Returns:   EAX = wall height in rows (0..24)
; Registers: EAX (ECX, EDX saved by USES)
;-------------------------------------------------------------
GetWallHeight PROC USES ecx edx
    mov  ecx, eax                           ; ECX = distance
    mov  eax, SCREEN_H * 256                ; EAX = 6144
    mov  edx, 0                             ; clear EDX before DIV
    div  ecx                                ; EAX = 6144 / distance
    cmp  eax, SCREEN_H                      ; taller than the screen?
    jbe  HeightOK                           ; no
    mov  eax, SCREEN_H                      ; yes: limit to 24 rows
HeightOK:
    ret                                     ; back to caller
GetWallHeight ENDP

;-------------------------------------------------------------
; DrawColumn
; Purpose:   Fill one screen column, top to bottom:
;            ceiling, wall (solid block in wallColor), floor.
;            The wall is centred vertically. Writes both the
;            character (frameBuffer) and the colour (attrBuffer).
; Receives:  column     = screen x (0..79)
;            wallHeight = wall size in rows (0..24)
;            wallColor  = colour attribute of the wall
; Returns:   nothing (frameBuffer, attrBuffer changed)
; Registers: none (EAX, EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawColumn PROC USES eax ebx ecx edx esi edi, column:DWORD, wallHeight:DWORD, wallColor:DWORD
    mov  ebx, SCREEN_H                      ; EBX = 24
    sub  ebx, wallHeight                    ; rows not used by the wall
    shr  ebx, 1                             ; half above: EBX = first wall row
    mov  edx, ebx                           ; EDX = first wall row
    add  edx, wallHeight                    ; EDX = first floor row
    mov  edi, OFFSET frameBuffer            ; EDI = row 0 of the character buffer
    add  edi, column                        ; move to this column
    mov  esi, column                        ; ESI = column
    shl  esi, 1                             ; column * 2 (each colour is a WORD)
    add  esi, OFFSET attrBuffer             ; ESI = this column in row 0 of the colours
    mov  ecx, 0                             ; ECX = row, start at 0
ColumnRow:
    cmp  ecx, ebx                           ; above the wall?
    jb   PutCeiling                         ; yes: ceiling
    cmp  ecx, edx                           ; still inside the wall?
    jb   PutWall                            ; yes: wall
    call GetFloorChar                       ; otherwise floor: AL = shade for row ECX
    mov  [edi], al                          ; write the floor character
    mov  WORD PTR [esi], DEFAULT_ATTR       ; normal colour
    jmp  NextRow                            ; done with this row
PutCeiling:
    mov  BYTE PTR [edi], ' '                ; empty ceiling
    mov  WORD PTR [esi], DEFAULT_ATTR       ; normal colour
    jmp  NextRow                            ; done with this row
PutWall:
    mov  BYTE PTR [edi], WALL_CHAR          ; solid block
    mov  eax, wallColor                     ; AX = wall colour
    mov  [esi], ax                          ; store the colour
NextRow:
    add  edi, SCREEN_W                      ; down one row of characters (80 bytes)
    add  esi, SCREEN_W * 2                  ; down one row of colours (160 bytes)
    inc  ecx                                ; next row number
    cmp  ecx, SCREEN_H                      ; all 24 rows done?
    jb   ColumnRow                          ; no: next row
    ret                                     ; back to caller
DrawColumn ENDP

;-------------------------------------------------------------
; RenderView
; Purpose:   Draw the 3D view: one ray per screen column.
;            rayAngle = angle - FOV/2 + x*FOV/SCREEN_W
; Receives:  nothing (uses angle, posX, posY)
; Returns:   nothing (frameBuffer, attrBuffer filled)
; Registers: none (EAX, EBX, ECX, EDX saved by USES)
;-------------------------------------------------------------
RenderView PROC USES eax ebx ecx edx
    mov  ebx, 0                             ; EBX = column x, start at 0
ViewColumn:
    mov  eax, ebx                           ; EAX = x
    imul eax, FOV                           ; EAX = x * 60
    mov  edx, 0                             ; clear EDX before DIV (x*60 is positive)
    mov  ecx, SCREEN_W                      ; divide by 80
    div  ecx                                ; EAX = x * 60 / 80 (0..59 degrees)
    add  eax, angle                         ; + player angle
    sub  eax, FOV / 2                       ; - 30: start at the left edge of the view
    call WrapAngle                          ; keep it 0..359
    INVOKE CastRay, eax                     ; EAX = distance, EDX = hitSide, ECX = exit?
    push eax                                ; keep the distance for the height
    cmp  ecx, 1                             ; did the ray hit the exit door?
    je   ExitColumn                         ; yes: use the door colour
    INVOKE GetWallColor, eax, edx           ; no: EAX = wall colour for this distance
    mov  ecx, eax                           ; ECX = wall colour
    jmp  HaveWallColor                      ; colour chosen
ExitColumn:
    mov  ecx, DOOR_COLOR_A                  ; ECX = door colour
HaveWallColor:
    pop  eax                                ; EAX = distance again
    call GetWallHeight                      ; EAX = wall height in rows
    INVOKE DrawColumn, ebx, eax, ecx        ; draw this column
    inc  ebx                                ; next column
    cmp  ebx, SCREEN_W                      ; all 80 columns done?
    jb   ViewColumn                         ; no: next column
    ret                                     ; back to caller
RenderView ENDP

;-------------------------------------------------------------
; ResetGame
; Purpose:   Get ready for a new game: player back at the
;            start, steps 0, flags cleared, timer started.
; Receives:  nothing
; Returns:   posX, posY, angle, steps, quitFlag, wonFlag,
;            startTime set
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
ResetGame PROC USES eax
    mov  posX, START_X                      ; back to the start cell (X)
    mov  posY, START_Y                      ; back to the start cell (Y)
    mov  angle, START_ANGLE                 ; face east again
    mov  steps, 0                           ; no steps yet
    mov  quitFlag, 0                        ; not quitting
    mov  wonFlag, 0                         ; not won yet
    call GetMseconds                        ; EAX = milliseconds since midnight
    mov  startTime, eax                     ; the timer starts now
    ret                                     ; back to caller
ResetGame ENDP

;-------------------------------------------------------------
; GetElapsedSec
; Purpose:   How many whole seconds since the game started.
; Receives:  nothing (uses startTime)
; Returns:   EAX = elapsed seconds
; Registers: EAX (ECX, EDX saved by USES)
;-------------------------------------------------------------
GetElapsedSec PROC USES ecx edx
    call GetMseconds                        ; EAX = milliseconds since midnight now
    sub  eax, startTime                     ; EAX = milliseconds since the start
    jns  NoMidnight                         ; result not negative: normal case
    add  eax, MS_PER_DAY                    ; negative: midnight passed, add one day
NoMidnight:
    mov  edx, 0                             ; clear EDX before DIV
    mov  ecx, 1000                          ; 1000 ms in a second
    div  ecx                                ; EAX = whole seconds
    ret                                     ; back to caller
GetElapsedSec ENDP

;-------------------------------------------------------------
; GetRemainingSec
; Purpose:   How many seconds are left before time runs out.
; Receives:  nothing (uses TIME_LIMIT, startTime)
; Returns:   EAX = TIME_LIMIT - elapsed, never below 0
; Registers: EAX (EBX saved by USES)
;-------------------------------------------------------------
GetRemainingSec PROC USES ebx
    call GetElapsedSec                      ; EAX = seconds used
    mov  ebx, TIME_LIMIT                    ; EBX = seconds allowed
    sub  ebx, eax                           ; EBX = seconds left
    jge  TimeLeftOK                         ; 0 or more: fine (signed check)
    mov  ebx, 0                             ; below 0: show 0
TimeLeftOK:
    mov  eax, ebx                           ; return the value in EAX
    ret                                     ; back to caller
GetRemainingSec ENDP

;-------------------------------------------------------------
; PutNumber
; Purpose:   Write a number as decimal digits into memory,
;            with leading zeros (e.g. 7 with 2 digits = "07").
;            Digits are made from right to left: value mod 10
;            is the last digit, then divide by 10, repeat.
; Receives:  dest   = address of the first digit
;            value  = number to write
;            digits = how many digits to write
; Returns:   nothing (memory at dest changed)
; Registers: none (EAX, EBX, ECX, EDX, EDI saved by USES)
;-------------------------------------------------------------
PutNumber PROC USES eax ebx ecx edx edi, dest:PTR BYTE, value:DWORD, digits:DWORD
    mov  edi, dest                          ; EDI = first digit position
    add  edi, digits                        ; move past the last digit
    dec  edi                                ; EDI = last digit position
    mov  eax, value                         ; EAX = number to write
    mov  ebx, 10                            ; we divide by 10
    mov  ecx, digits                        ; ECX = digits to write
DigitLoop:
    mov  edx, 0                             ; clear EDX before DIV
    div  ebx                                ; EAX = value / 10, EDX = last digit
    add  dl, '0'                            ; turn 0..9 into '0'..'9'
    mov  [edi], dl                          ; store the digit
    dec  edi                                ; move one place to the left
    loop DigitLoop                          ; ECX--, repeat for every digit
    ret                                     ; back to caller
PutNumber ENDP

;-------------------------------------------------------------
; DrawHUD
; Purpose:   Fill the HUD row (row 24) of frameBuffer:
;            "TIME mm:ss  STEPS nnnnn  W/S move ..."
;            Copy the template, then write the numbers in.
; Receives:  nothing (uses steps and the timer)
; Returns:   nothing (frameBuffer HUD row changed)
; Registers: none (EAX, EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawHUD PROC USES eax ebx ecx edx esi edi
    cld                                     ; copy forwards
    mov  esi, OFFSET hudTemplate            ; ESI = template text
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W ; EDI = start of the HUD row
    mov  ecx, HUD_LEN                       ; ECX = template length
    rep  movsb                              ; copy the template into the HUD row
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W ; EDI = start of the HUD row again
    call GetRemainingSec                    ; EAX = seconds left
    mov  edx, 0                             ; clear EDX before DIV
    mov  ebx, 60                            ; 60 seconds in a minute
    div  ebx                                ; EAX = minutes, EDX = seconds
    mov  ecx, edi                           ; ECX = HUD row start
    add  ecx, HUD_MIN_POS                   ; ECX = where the minutes go
    INVOKE PutNumber, ecx, eax, 2           ; write mm
    mov  ecx, edi                           ; ECX = HUD row start
    add  ecx, HUD_SEC_POS                   ; ECX = where the seconds go
    INVOKE PutNumber, ecx, edx, 2           ; write ss
    mov  ecx, edi                           ; ECX = HUD row start
    add  ecx, HUD_STEP_POS                  ; ECX = where the steps go
    INVOKE PutNumber, ecx, steps, 5         ; write the step count (5 digits)
    ret                                     ; back to caller
DrawHUD ENDP

;-------------------------------------------------------------
; PrintTwoDigits
; Purpose:   Print a number 0..99 on the console with two
;            digits (adds a leading 0 below 10, e.g. "07").
; Receives:  EAX = number (0..99)
; Returns:   nothing
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
PrintTwoDigits PROC USES eax
    cmp  eax, 10                            ; one digit only?
    jae  TwoDigits                          ; no: print as it is
    push eax                                ; keep the number
    mov  al, '0'                            ; leading zero
    call WriteChar                          ; print it
    pop  eax                                ; number again
TwoDigits:
    call WriteDec                           ; print the number
    ret                                     ; back to caller
PrintTwoDigits ENDP

;-------------------------------------------------------------
; PrintTime
; Purpose:   Print a number of seconds as mm:ss.
; Receives:  EAX = seconds
; Returns:   nothing
; Registers: none (EAX, EBX, EDX saved by USES)
;-------------------------------------------------------------
PrintTime PROC USES eax ebx edx
    mov  edx, 0                             ; clear EDX before DIV
    mov  ebx, 60                            ; 60 seconds in a minute
    div  ebx                                ; EAX = minutes, EDX = seconds
    call PrintTwoDigits                     ; print mm
    mov  al, ':'                            ; separator
    call WriteChar                          ; print it
    mov  eax, edx                           ; EAX = seconds
    call PrintTwoDigits                     ; print ss
    ret                                     ; back to caller
PrintTime ENDP

;-------------------------------------------------------------
; WinScreen
; Purpose:   Clear the screen and show the win message, the
;            time taken (mm:ss) and the number of steps.
; Receives:  nothing (uses timer and steps)
; Returns:   nothing
; Registers: none (EAX, EDX saved by USES)
;-------------------------------------------------------------
WinScreen PROC USES eax edx
    call Clrscr                             ; clear the console
    mov  eax, lightGreen + (black * 16)     ; green text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET winTitle               ; "*** YOU ESCAPED! ***"
    call WriteString                        ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line
    mov  eax, white + (black * 16)          ; white text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET timeMsg                ; "Time taken: "
    call WriteString                        ; print it
    call GetElapsedSec                      ; EAX = seconds used
    call PrintTime                          ; print mm:ss
    call Crlf                               ; next line
    mov  edx, OFFSET stepsMsg               ; "Steps: "
    call WriteString                        ; print it
    mov  eax, steps                         ; EAX = step count
    call WriteDec                           ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line
    ret                                     ; back to caller
WinScreen ENDP

;-------------------------------------------------------------
; LoseScreen
; Purpose:   Clear the screen and show the time's-up message
;            and the number of steps.
; Receives:  nothing (uses steps)
; Returns:   nothing
; Registers: none (EAX, EDX saved by USES)
;-------------------------------------------------------------
LoseScreen PROC USES eax edx
    call Clrscr                             ; clear the console
    mov  eax, lightRed + (black * 16)       ; red text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET loseTitle              ; "*** TIME'S UP! ***"
    call WriteString                        ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line
    mov  eax, white + (black * 16)          ; white text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET loseText               ; "You did not reach the exit in time."
    call WriteString                        ; print it
    call Crlf                               ; next line
    mov  edx, OFFSET stepsMsg               ; "Steps: "
    call WriteString                        ; print it
    mov  eax, steps                         ; EAX = step count
    call WriteDec                           ; print it
    call Crlf                               ; next line
    call Crlf                               ; blank line
    ret                                     ; back to caller
LoseScreen ENDP

;-------------------------------------------------------------
; AskPlayAgain
; Purpose:   Ask "Play again? (Y/N)" and wait for Y, N or Q
;            (other keys are ignored).
; Receives:  nothing
; Returns:   EAX = 1 for Y, 0 for N or Q
; Registers: EAX (ECX, EDX saved by USES)
;-------------------------------------------------------------
AskPlayAgain PROC USES ecx edx
    INVOKE FlushConsoleInputBuffer, inputHandle ; forget keys pressed during the game
    mov  eax, lightGray + (black * 16)      ; normal grey text
    call SetTextColor                       ; apply the colour
    mov  edx, OFFSET againMsg               ; "Play again? (Y/N)"
    call WriteString                        ; print it
AskLoop:
    call ReadChar                           ; wait for a key, AL = key
    and  al, 11011111b                      ; make it uppercase
    cmp  al, 'Y'                            ; yes?
    je   AnswerYes                          ; play again
    cmp  al, 'N'                            ; no?
    je   AnswerNo                           ; stop
    cmp  al, 'Q'                            ; quit?
    je   AnswerNo                           ; stop
    jmp  AskLoop                            ; any other key: ask again
AnswerYes:
    mov  eax, 1                             ; return 1
    ret                                     ; back to caller
AnswerNo:
    mov  eax, 0                             ; return 0
    ret                                     ; back to caller
AskPlayAgain ENDP

;-------------------------------------------------------------
; GameLoop
; Purpose:   Run frames until the game ends:
;            input -> check quit/win/time -> clear -> 3D view
;            -> minimap -> HUD -> draw -> wait 30 ms.
; Receives:  nothing
; Returns:   EAX = RESULT_QUIT, RESULT_WIN or RESULT_LOSE
; Registers: EAX
;-------------------------------------------------------------
GameLoop PROC
FrameLoop:
    call HandleInput                        ; read keys, move/turn the player
    cmp  quitFlag, 1                        ; did the player press Q?
    je   GameQuit                           ; yes
    cmp  wonFlag, 1                         ; did the player touch the exit?
    je   GameWon                            ; yes
    call GetRemainingSec                    ; EAX = seconds left
    cmp  eax, 0                             ; time up?
    je   GameLost                           ; yes
    call ClearBuffer                        ; blank frame
    call RenderView                         ; 3D walls into the buffer
    call DrawMinimap                        ; map + player on top (only if switched on)
    call DrawHUD                            ; time, steps, controls on the last row
    call DrawBuffer                         ; show the frame on screen
    mov  eax, 30                            ; 30 milliseconds
    call Delay                              ; wait before the next frame
    jmp  FrameLoop                          ; next frame
GameQuit:
    mov  eax, RESULT_QUIT                   ; ended by Q
    ret                                     ; back to caller
GameWon:
    mov  eax, RESULT_WIN                    ; ended by reaching the exit
    ret                                     ; back to caller
GameLost:
    mov  eax, RESULT_LOSE                   ; ended by the timer
    ret                                     ; back to caller
GameLoop ENDP

END main                                    ; program starts at main

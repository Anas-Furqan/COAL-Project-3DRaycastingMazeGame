; ------------------------------------------------------------
; WOLF-86 - COAL Lab Project
; First-person 3D raycasting maze game in the Windows console
; Phase 1: constants, map, player data, sine table, title screen
; ------------------------------------------------------------

INCLUDE Irvine32.inc                        ; Irvine32 library procedures and Win32 prototypes

; ---------- constants (no memory used, just names for numbers) ----------
SCREEN_W = 80                               ; console width in characters
SCREEN_H = 24                               ; console height in characters (rows)
MAP_W    = 16                               ; map width in cells
MAP_H    = 16                               ; map height in cells
FOV      = 60                               ; field of view in degrees

; ---------- procedure prototypes ----------
GetSin      PROTO                           ; EAX = angle in, EAX = sin*256 out
GetCos      PROTO                           ; EAX = angle in, EAX = cos*256 out
TitleScreen PROTO                           ; shows the title screen
ClearBuffer PROTO                           ; fills frameBuffer with spaces
HideCursor  PROTO                           ; hides the blinking console cursor
DrawBuffer  PROTO                           ; copies frameBuffer to the console
GetMoveDelta PROTO                          ; returns EAX = dx, EDX = dy for one step forward
IsWall      PROTO, testX:SDWORD, testY:SDWORD     ; EAX = 1 if (testX,testY) is inside a wall
TryMove     PROTO, moveDX:SDWORD, moveDY:SDWORD   ; moves the player if no wall is in the way
TurnPlayer  PROTO, turnAmount:SDWORD        ; adds turnAmount to angle, wraps to 0..359
HandleInput PROTO                           ; reads one key (no waiting) and acts on it
DrawMinimap PROTO                           ; copies map + 'P' into the frame buffer
GameLoop    PROTO                           ; main loop of the game

; ---------- movement settings ----------
MOVE_SPEED = 32                             ; one step = 32/256 = 1/8 of a cell (Q8)
TURN_STEP  = 5                              ; degrees turned per A/D key press

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
posX      DWORD 384                         ; X = 1.5 cells (1*256 + 128), centre of column 1
posY      DWORD 384                         ; Y = 1.5 cells (1*256 + 128), centre of row 1
angle     DWORD 0                           ; facing direction in degrees (0..359), 0 = east
steps     DWORD 0                           ; number of steps the player has taken
startTime DWORD 0                           ; time (ms from GetMSeconds) when the game started

; ---------- game state flags ----------
showMinimap BYTE 1                          ; 1 = minimap visible, 0 = hidden (M toggles)
quitFlag    BYTE 0                          ; becomes 1 when the player presses Q

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

; ---------- screen drawing data ----------
frameBuffer   BYTE SCREEN_W * SCREEN_H DUP(' ')   ; 80x24 = 1920 chars, cell (row,col) at row*80 + col
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

.code
;-------------------------------------------------------------
; main
; Purpose:   Program entry. Shows the title screen, runs the
;            game loop until the player quits, then exits.
; Receives:  nothing
; Returns:   nothing (ends the program)
; Registers: none kept (program ends)
;-------------------------------------------------------------
main PROC
    INVOKE HideCursor                       ; get console handle and hide the cursor
    INVOKE TitleScreen                      ; show the title screen and wait for a key
    call   Clrscr                           ; wipe the title text off the screen
    INVOKE GameLoop                         ; play until quitFlag is set
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
; Returns:   nothing
; Registers: none (EAX, EDX saved by USES)
;-------------------------------------------------------------
TitleScreen PROC USES eax edx
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
    call ReadChar                           ; wait for a key (key code goes to AL, ignored)
    ret                                     ; back to caller
TitleScreen ENDP

;-------------------------------------------------------------
; ClearBuffer
; Purpose:   Fill the whole frameBuffer with spaces.
; Receives:  nothing
; Returns:   nothing
; Registers: none (EAX, ECX, EDI saved by USES)
;-------------------------------------------------------------
ClearBuffer PROC USES eax ecx edi
    cld                                     ; direction flag = 0, so EDI moves forward
    mov  al, ' '                            ; AL = the byte to store (a space)
    mov  ecx, SCREEN_W * SCREEN_H           ; ECX = how many bytes (1920)
    mov  edi, OFFSET frameBuffer            ; EDI = start of the buffer
    rep  stosb                              ; store AL at [EDI], EDI++, repeat ECX times
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
; Purpose:   Copy the frameBuffer to the console one row at a
;            time: 24 calls, each writing 80 chars to (0,row).
;            Nothing is cleared, only overwritten, so no flicker,
;            and each row starts at column 0 at any console width.
; Receives:  nothing (uses frameBuffer and consoleHandle)
; Returns:   nothing
; Registers: none (EAX, EBX, ECX, EDX, ESI saved by USES)
;-------------------------------------------------------------
DrawBuffer PROC USES eax ebx ecx edx esi
    mov  esi, OFFSET frameBuffer            ; ESI = start of row 0 in the buffer
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
    add  esi, SCREEN_W                      ; move ESI to the start of the next row
    inc  ebx                                ; next row number
    cmp  ebx, SCREEN_H                      ; done all 24 rows?
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
    imul eax, MOVE_SPEED                    ; EAX = cos * 256 * MOVE_SPEED
    sar  eax, 8                             ; divide by 256 (keeps the sign) -> dx in Q8
    push eax                                ; save dx on the stack
    mov  eax, angle                         ; EAX = current angle
    call GetSin                             ; EAX = sin(angle) * 256
    imul eax, MOVE_SPEED                    ; EAX = sin * 256 * MOVE_SPEED
    sar  eax, 8                             ; divide by 256 (keeps the sign) -> dy in Q8
    mov  edx, eax                           ; EDX = dy
    pop  eax                                ; EAX = dx again
    ret                                     ; back to caller
GetMoveDelta ENDP

;-------------------------------------------------------------
; IsWall
; Purpose:   Check if a Q8 position is inside a wall cell.
; Receives:  testX, testY = position in Q8 (cells * 256)
; Returns:   EAX = 1 if that cell is '#', else 0
; Registers: EAX (EBX saved by USES)
;-------------------------------------------------------------
IsWall PROC USES ebx, testX:SDWORD, testY:SDWORD
    mov  eax, testY                         ; EAX = Y in Q8
    sar  eax, 8                             ; EAX = row (whole cells)
    shl  eax, 4                             ; EAX = row * 16 (start of that map row)
    mov  ebx, testX                         ; EBX = X in Q8
    sar  ebx, 8                             ; EBX = column (whole cells)
    add  eax, ebx                           ; EAX = row*16 + col = index into gameMap
    cmp  gameMap[eax], '#'                  ; is that cell a wall?
    je   HitWall                            ; yes
    mov  eax, 0                             ; no: return 0
    jmp  WallDone                           ; skip the "wall" part
HitWall:
    mov  eax, 1                             ; return 1 (wall)
WallDone:
    ret                                     ; back to caller
IsWall ENDP

;-------------------------------------------------------------
; TryMove
; Purpose:   Move the player by (moveDX, moveDY) if no wall is
;            in the way. X and Y are checked separately so the
;            player slides along walls. steps++ if it moved.
; Receives:  moveDX, moveDY = movement in Q8
; Returns:   posX, posY, steps updated
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
TryMove PROC USES eax ecx edx, moveDX:SDWORD, moveDY:SDWORD
    mov  ecx, 0                             ; ECX = 1 once we really move
    cmp  moveDX, 0                          ; any X movement at all?
    je   TryY                               ; no: skip the X test
    mov  edx, posX                          ; EDX = current X
    add  edx, moveDX                        ; EDX = new X
    INVOKE IsWall, edx, posY                ; new X with OLD Y: wall?
    cmp  eax, 0                             ; 0 means free
    jne  TryY                               ; wall: do not move in X
    mov  posX, edx                          ; free: accept the new X
    mov  ecx, 1                             ; remember that we moved
TryY:
    cmp  moveDY, 0                          ; any Y movement at all?
    je   MoveDone                           ; no: skip the Y test
    mov  edx, posY                          ; EDX = current Y
    add  edx, moveDY                        ; EDX = new Y
    INVOKE IsWall, posX, edx                ; (maybe new) X with new Y: wall?
    cmp  eax, 0                             ; 0 means free
    jne  MoveDone                           ; wall: do not move in Y
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
    cmp  eax, 0                             ; went below 0? (signed compare)
    jge  NotNegative                        ; no
    add  eax, 360                           ; yes: e.g. -5 becomes 355
NotNegative:
    cmp  eax, 360                           ; reached 360 or more?
    jl   AngleInRange                       ; no
    sub  eax, 360                           ; yes: e.g. 360 becomes 0
AngleInRange:
    mov  angle, eax                         ; save the new angle
    ret                                     ; back to caller
TurnPlayer ENDP

;-------------------------------------------------------------
; HandleInput
; Purpose:   Read one key without waiting and act on it:
;            W/S move, A/D turn, M toggles minimap, Q quits.
; Receives:  nothing
; Returns:   posX/posY/angle/showMinimap/quitFlag may change
; Registers: none (EAX, EBX, EDX saved by USES)
;-------------------------------------------------------------
HandleInput PROC USES eax ebx edx
    call ReadKey                            ; AL = key; ZF = 1 if no key (also changes EBX, EDX)
    jz   InputDone                          ; no key this frame
    and  al, 11011111b                      ; clear bit 5: turns 'a'..'z' into 'A'..'Z'
    cmp  al, 'W'                            ; forward?
    jne  NotW                               ; no
    call GetMoveDelta                       ; EAX = dx, EDX = dy
    INVOKE TryMove, eax, edx                ; move forward if possible
    jmp  InputDone                          ; finished
NotW:
    cmp  al, 'S'                            ; backward?
    jne  NotS                               ; no
    call GetMoveDelta                       ; EAX = dx, EDX = dy
    neg  eax                                ; reverse X direction
    neg  edx                                ; reverse Y direction
    INVOKE TryMove, eax, edx                ; move backward if possible
    jmp  InputDone                          ; finished
NotS:
    cmp  al, 'A'                            ; turn left?
    jne  NotA                               ; no
    INVOKE TurnPlayer, -TURN_STEP           ; angle - 5
    jmp  InputDone                          ; finished
NotA:
    cmp  al, 'D'                            ; turn right?
    jne  NotD                               ; no
    INVOKE TurnPlayer, TURN_STEP            ; angle + 5
    jmp  InputDone                          ; finished
NotD:
    cmp  al, 'M'                            ; minimap toggle?
    jne  NotM                               ; no
    xor  showMinimap, 1                     ; 1 -> 0 or 0 -> 1
    jmp  InputDone                          ; finished
NotM:
    cmp  al, 'Q'                            ; quit?
    jne  InputDone                          ; no: ignore this key
    mov  quitFlag, 1                        ; tell the game loop to stop
InputDone:
    ret                                     ; back to caller
HandleInput ENDP

;-------------------------------------------------------------
; DrawMinimap
; Purpose:   If showMinimap = 1, copy the 16x16 map into the
;            top-left of frameBuffer and put 'P' on the
;            player's cell.
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
    mov  eax, posY                          ; EAX = Y in Q8
    sar  eax, 8                             ; EAX = player row
    imul eax, SCREEN_W                      ; EAX = row * 80 (start of that screen row)
    mov  edx, posX                          ; EDX = X in Q8
    sar  edx, 8                             ; EDX = player column
    add  eax, edx                           ; EAX = row*80 + col
    mov  frameBuffer[eax], 'P'              ; mark the player
MapDone:
    ret                                     ; back to caller
DrawMinimap ENDP

;-------------------------------------------------------------
; GameLoop
; Purpose:   Run frames until the player presses Q:
;            input -> clear -> minimap -> draw -> wait 30 ms.
; Receives:  nothing
; Returns:   nothing
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
GameLoop PROC USES eax
FrameLoop:
    call HandleInput                        ; read keys, move/turn the player
    cmp  quitFlag, 1                        ; did the player press Q?
    je   LoopDone                           ; yes: leave the loop
    call ClearBuffer                        ; blank frame
    call DrawMinimap                        ; map + player into the buffer
    call DrawBuffer                         ; show the frame on screen
    mov  eax, 30                            ; 30 milliseconds
    call Delay                              ; wait before the next frame
    jmp  FrameLoop                          ; next frame
LoopDone:
    ret                                     ; back to caller
GameLoop ENDP

END main                                    ; program starts at main

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

; ---------- Win32 function not declared in SmallWin.inc (lives in user32.lib) ----------
GetAsyncKeyState PROTO, vKey:DWORD          ; AX bit 15 = 1 if the key is held down right now

; ---------- procedure prototypes ----------
GetSin      PROTO                           ; EAX = angle in, EAX = sin*256 out
GetCos      PROTO                           ; EAX = angle in, EAX = cos*256 out
TitleScreen PROTO                           ; shows the title screen
ClearBuffer PROTO                           ; fills frameBuffer with spaces
HideCursor  PROTO                           ; hides the blinking console cursor
DrawBuffer  PROTO                           ; copies frameBuffer to the console
GetMoveDelta PROTO                          ; returns EAX = dx, EDX = dy for one step forward
IsWall      PROTO, testX:SDWORD, testY:SDWORD     ; EAX = 1 if (testX,testY) is inside a wall
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
CastRay     PROTO, rayAngle:DWORD           ; EAX = corrected distance to the first wall (Q8)
GetWallHeight PROTO                         ; EAX = distance in, EAX = wall height in rows
DrawColumn  PROTO, column:DWORD, wallHeight:DWORD ; draws one screen column (sky, wall, floor)
RenderView  PROTO                           ; casts 80 rays and draws the 3D view
TurnPlayer  PROTO, turnAmount:SDWORD        ; adds turnAmount to angle, wraps to 0..359
HandleInput PROTO                           ; reads one key (no waiting) and acts on it
DrawMinimap PROTO                           ; copies map + 'P' into the frame buffer
GameLoop    PROTO                           ; main loop of the game

; ---------- movement settings ----------
MOVE_SPEED = 32                             ; one step = 32/256 = 1/8 of a cell (Q8)
TURN_STEP  = 5                              ; degrees turned per frame while A/D is held
MARGIN     = 64                             ; keep 64/256 = 1/4 cell away from walls

; ---------- raycasting settings ----------
BIG_DIST   = 1000000                        ; "infinite" distance, used when a ray never crosses an axis
KEY_WAIT_TRIES = 200                        ; max 200 x 10 ms = 2 s waiting for keys to be released

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
    INVOKE InitInput                        ; get console input handle (for flushing keys)
    INVOKE TitleScreen                      ; show the title screen and wait for a key
    INVOKE WaitKeysReleased                 ; make sure the closing key can't trigger M or Q
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
;            walls. steps++ if it moved.
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
    INVOKE ProbePoint, edx, moveDX          ; EAX = new X + margin ahead
    INVOKE IsWall, eax, posY                ; that point with OLD Y: wall?
    cmp  eax, 0                             ; 0 means free
    jne  TryY                               ; wall: do not move in X
    mov  posX, edx                          ; free: accept the new X
    mov  ecx, 1                             ; remember that we moved
TryY:
    cmp  moveDY, 0                          ; any Y movement at all?
    je   MoveDone                           ; no: skip the Y test
    mov  edx, posY                          ; EDX = current Y
    add  edx, moveDY                        ; EDX = new Y
    INVOKE ProbePoint, edx, moveDY          ; EAX = new Y + margin ahead
    INVOKE IsWall, posX, eax                ; (maybe new) X with that Y: wall?
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
    imul ebx, edx                           ; EBX = deltaDist * gap (max 16384*256, no overflow)
    sar  ebx, 8                             ; /256 back to Q8 -> sideDist
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
; Registers: EAX (EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
CastRay PROC USES ebx ecx edx esi edi, rayAngle:DWORD
    LOCAL mapX:SDWORD, mapY:SDWORD          ; the cell the ray is in now
    LOCAL stepX:SDWORD, stepY:SDWORD        ; +1 or -1 per axis
    LOCAL deltaX:SDWORD, deltaY:SDWORD      ; ray length to cross one cell, per axis
    LOCAL sideX:SDWORD, sideY:SDWORD        ; ray length to the next X / Y grid line
    LOCAL hitSide:DWORD                     ; 0 = last step was in X, 1 = in Y

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

    ; ----- block 3: step cell by cell until a wall -----
    ; (the map has walls all round, so this always ends)
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
    mov  eax, mapY                          ; EAX = row
    shl  eax, 4                             ; row * 16
    add  eax, mapX                          ; row*16 + col
    cmp  gameMap[eax], '#'                  ; is this cell a wall?
    jne  DDALoop                            ; no: keep stepping

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
    imul eax, ebx                           ; EAX = cos * dist (max ~256*6000, no overflow)
    sar  eax, 8                             ; /256 back to Q8

    ; ----- block 6: never return 0 or less (we divide by it later) -----
    cmp  eax, 1                             ; at least 1?
    jge  DistOK                             ; yes
    mov  eax, 1                             ; no: use 1
DistOK:
    ret                                     ; back to caller (distance in EAX)
CastRay ENDP

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
;            ' ' (ceiling), '#' (wall), '.' (floor).
;            The wall is centred vertically.
; Receives:  column = screen x (0..79)
;            wallHeight = wall size in rows (0..24)
; Returns:   nothing (frameBuffer changed)
; Registers: none (EAX, EBX, ECX, EDX, EDI saved by USES)
;-------------------------------------------------------------
DrawColumn PROC USES eax ebx ecx edx edi, column:DWORD, wallHeight:DWORD
    mov  ebx, SCREEN_H                      ; EBX = 24
    sub  ebx, wallHeight                    ; rows not used by the wall
    shr  ebx, 1                             ; half above: EBX = first wall row
    mov  edx, ebx                           ; EDX = first wall row
    add  edx, wallHeight                    ; EDX = first floor row
    mov  edi, OFFSET frameBuffer            ; EDI = row 0 of the buffer
    add  edi, column                        ; move to this column
    mov  ecx, 0                             ; ECX = row, start at 0
ColumnRow:
    mov  al, ' '                            ; assume ceiling
    cmp  ecx, ebx                           ; above the wall?
    jb   PutChar                            ; yes: ceiling
    mov  al, '#'                            ; assume wall
    cmp  ecx, edx                           ; still inside the wall?
    jb   PutChar                            ; yes: wall
    mov  al, '.'                            ; otherwise floor
PutChar:
    mov  [edi], al                          ; write the character
    add  edi, SCREEN_W                      ; down one row (80 bytes)
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
; Returns:   nothing (frameBuffer filled)
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
    INVOKE CastRay, eax                     ; EAX = distance to the wall
    call GetWallHeight                      ; EAX = wall height in rows
    INVOKE DrawColumn, ebx, eax             ; draw this column
    inc  ebx                                ; next column
    cmp  ebx, SCREEN_W                      ; all 80 columns done?
    jb   ViewColumn                         ; no: next column
    ret                                     ; back to caller
RenderView ENDP

;-------------------------------------------------------------
; GameLoop
; Purpose:   Run frames until the player presses Q:
;            input -> clear -> 3D view -> minimap -> draw ->
;            wait 30 ms.
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
    call RenderView                         ; 3D walls into the buffer
    call DrawMinimap                        ; map + player on top (only if switched on)
    call DrawBuffer                         ; show the frame on screen
    mov  eax, 30                            ; 30 milliseconds
    call Delay                              ; wait before the next frame
    jmp  FrameLoop                          ; next frame
LoopDone:
    ret                                     ; back to caller
GameLoop ENDP

END main                                    ; program starts at main

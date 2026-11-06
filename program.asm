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
; Purpose:   Program entry. Shows the title screen, then exits.
; Receives:  nothing
; Returns:   nothing (ends the program)
; Registers: none kept (program ends)
;-------------------------------------------------------------
main PROC
    INVOKE TitleScreen                      ; show the title screen and wait for a key
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

END main                                    ; program starts at main

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

; ---------- colour attributes = palette slot (background slot 0 = near-black sky) ----------
C_SKY        = 0                            ; sky / background
C_WALL_3     = 1                            ; wall, far
C_WALL_2     = 2                            ; wall
C_WALL_1     = 3                            ; wall
C_WALL_0     = 4                            ; wall, near
C_FLOOR_FAR  = 5                            ; floor, far
C_FLOOR_MID  = 6                            ; floor, middle
C_TEXT       = 7                            ; normal text (light gray, unchanged)
C_FLOOR_NEAR = 8                            ; floor near, stars
C_MAP_WALL   = 9                            ; minimap walls and borders
C_DOOR_A     = 10                           ; door colour 1 (red-orange)
C_DOOR_B     = 11                           ; door colour 2, accent text (yellow-orange)
C_GOLD       = 12                           ; keys, player arrow, win banner
C_DANGER     = 13                           ; timer under 20 s, lose banner
C_OUTLINE    = 14                           ; wall outline (top/bottom row), darkest mortar
C_WHITE      = 15                           ; white (unchanged)

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

; ---------- console palette (kernel32.lib, not in SmallWin.inc) ----------
; Same layout as the Windows CONSOLE_SCREEN_BUFFER_INFOEX structure (96 bytes).
; ColorTable holds the 16 palette colours as COLORREF = 00BBGGRRh.
CSBI_EX STRUCT
  cbSize               DWORD ?              ; size of this structure (must be set before the call)
  dwSize               COORD <>             ; buffer size in cells
  dwCursorPosition     COORD <>             ; cursor position
  wAttributes          WORD ?               ; current text colour
  srWindow             SMALL_RECT <>        ; visible window rectangle
  dwMaximumWindowSize  COORD <>             ; largest possible window
  wPopupAttributes     WORD ?               ; colour of pop-up windows
  bFullscreenSupported DWORD ?              ; full-screen flag
  ColorTable           DWORD 16 DUP(?)      ; the 16 palette colours
CSBI_EX ENDS
GetConsoleScreenBufferInfoEx PROTO, hConsole:DWORD, lpInfo:PTR CSBI_EX ; EAX = 0 on failure
SetConsoleScreenBufferInfoEx PROTO, hConsole:DWORD, lpInfo:PTR CSBI_EX ; EAX = 0 on failure

; ---------- procedure prototypes ----------
GetSin      PROTO                           ; EAX = angle in, EAX = sin*256 out
GetCos      PROTO                           ; EAX = angle in, EAX = cos*256 out
TitleScreen PROTO                           ; shows the title screen, EAX = key pressed
PrintArt    PROTO, artPtr:PTR BYTE, colorPtr:PTR BYTE, lines:DWORD, row:DWORD, col:DWORD ; coloured text lines, '#' = block
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
LoadPalette PROTO                           ; saves the console palette, installs the blue/orange theme
RestorePalette PROTO                        ; puts the saved palette back
SetPalette  PROTO, infoPtr:PTR CSBI_EX      ; EAX = 1 if the palette in *infoPtr was applied
SetRoleColor PROTO                          ; EAX = colour role in, sets the console text colour
ApplyRoles  PROTO                           ; turns the roles in attrBuffer into real colours
DrawBuffer  PROTO                           ; copies frameBuffer to the console
GetMoveDelta PROTO                          ; returns EAX = dx, EDX = dy for one step forward
IsWall      PROTO, testX:SDWORD, testY:SDWORD     ; EAX = CELL_FREE / CELL_WALL / CELL_EXIT
ProbePoint  PROTO, newPos:SDWORD, delta:SDWORD    ; EAX = newPos pushed MARGIN further in move direction
TryMove     PROTO, moveDX:SDWORD, moveDY:SDWORD   ; moves the player if no wall is in the way
HandleCell  PROTO, cellType:DWORD, testX:SDWORD, testY:SDWORD ; exit / key touched by a probe
CollectKey  PROTO, testX:SDWORD, testY:SDWORD     ; removes the key there, keys++, message
TouchExit   PROTO                           ; win with 3 keys, else "door locked" message
ShowMessage PROTO, msgPtr:PTR BYTE, msgAttr:DWORD ; show a HUD message for 2 seconds
MsSince     PROTO, since:DWORD              ; EAX = ms since an earlier GetMseconds value
DrawMessage PROTO                           ; writes the active message into the HUD row
InitInput   PROTO                           ; gets the console input handle
KeyDown     PROTO, vKey:DWORD               ; EAX = 1 if key is held down now
KeyPressed  PROTO, vKey:DWORD, prevPtr:PTR BYTE   ; EAX = 1 only on the frame the key goes down
GetArrowChar PROTO                          ; AL = '>', 'v', '<' or '^' for the current angle
WrapAngle   PROTO                           ; EAX = angle in, EAX = same angle wrapped to 0..359
UpdateBlink PROTO                           ; blinkOn = 0 or 1, flips every 500 ms
AnyKeyDown  PROTO                           ; EAX = 1 if any keyboard key is held
WaitKeysReleased PROTO                      ; waits until keys are let go, sets mWasDown/qWasDown
SetupAxis   PROTO, axisPos:SDWORD, axisDir:SDWORD ; DDA setup for one axis (EAX, EBX, ECX out)
CastRay     PROTO, rayAngle:DWORD           ; EAX = distance (Q8), EDX = hitSide, ECX = hit type
GetWallLevel PROTO, distance:DWORD, side:DWORD    ; EAX = wall shade level 0..3 for a distance
GetFloorColor PROTO                         ; ECX = row in, EAX = floor colour for that row
GetWallHeight PROTO                         ; EAX = distance in, EAX = real wall height in rows
DrawColumn  PROTO, column:DWORD             ; draws one screen column from the column arrays
GetColumnColor PROTO, column:DWORD          ; EAX = colour of a column's wall slice
CastAllRays PROTO                           ; casts the 80 rays into the column arrays
IsEdgeColumn PROTO, column:DWORD            ; EAX = 1 if the column is an edge between walls
IsStar      PROTO, rayAngle:DWORD           ; ECX = row in, EAX = 1 if a star is at this ceiling cell
RenderView  PROTO                           ; casts 80 rays and draws the 3D view
TurnPlayer  PROTO, turnAmount:SDWORD        ; adds turnAmount to angle, wraps to 0..359
HandleInput PROTO                           ; reads one key (no waiting) and acts on it
DrawMinimap PROTO                           ; coloured map + border + direction arrow into the frame
DrawMapBorder PROTO                         ; box around the minimap
GetMapLook  PROTO                           ; EAX = map char in, EAX = screen char, EBX = colour out
PutCell     PROTO, row:DWORD, col:DWORD, cellChar:DWORD, cellAttr:DWORD ; one char + colour into the frame
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
STAR_CHAR      = '.'                        ; a star in the night sky
STAR_ATTR      = C_FLOOR_NEAR               ; stars: slot 8 (C_FLOOR_NEAR), dim
STAR_MOD       = 37                         ; star if (rayAngle*7 + row*13) mod 37 = 0
EDGE_LOW       = 20                         ; wallX below this = near a cell corner
EDGE_HIGH      = 236                        ; wallX above this = near a cell corner

; ---------- title / end screen layout (row, column on the console) ----------
ART_LINES   = 5                             ; block letters are 5 rows tall
BOX_LINES   = 10                            ; controls box: top, 8 text lines, bottom
LOGO_ROW    = 1                             ; logo rows 1..5
LOGO_COL    = 19                            ; (80 - 41) / 2: logo centred
SUB_ROW     = 7                             ; subtitle row
SUB_COL     = 19                            ; (80 - 41) / 2: subtitle centred
BOX_ROW     = 9                             ; controls box rows 9..18
BOX_COL     = 17                            ; (80 - 46) / 2: box centred
PRESS_ROW   = 21                            ; blinking prompt row
PRESS_COL   = 33                            ; (80 - 13) / 2: prompt centred
TITLE_DELAY = 50                            ; ms between title screen redraws
BANNER_ROW  = 2                             ; end screen banner rows 2..6
WIN_COL     = 16                            ; (80 - 47) / 2: "ESCAPED!" centred
LOSE_COL    = 19                            ; (80 - 41) / 2: "TIME UP" centred
INFO_ROW    = 9                             ; first line of time / steps
INFO_COL    = 19                            ; column of the info lines
ASK_ROW     = 13                            ; row of "Play again? (Y/N)"

; ---------- minimap look ----------
MAP_BOX       = MAP_H + 1                   ; border row/column on the far side (17)
BOX_TL        = 218                         ; code page 437 box corners and lines
BOX_TR        = 191                         ; top-right corner
BOX_BL        = 192                         ; bottom-left corner
BOX_BR        = 217                         ; bottom-right corner
BOX_H         = 196                         ; horizontal line
BOX_V         = 179                         ; vertical line
BORDER_ATTR   = C_MAP_WALL                  ; border: slot 9 (C_MAP_WALL)
MAP_WALL_ATTR = C_MAP_WALL                  ; walls: slot 9 (C_MAP_WALL)
MAP_EXIT_ATTR = C_DOOR_A                    ; exit: slot 10 (C_DOOR_A, red-orange)
MAP_KEY_ATTR  = C_GOLD                      ; keys: slot 12 (C_GOLD)
PLAYER_ATTR   = C_GOLD                      ; player arrow: slot 12 (C_GOLD)
DOOR_COLOR_A   = C_DOOR_A                   ; exit door colour 1: slot 10 (red-orange)
DOOR_COLOR_B   = C_DOOR_B                   ; exit door colour 2: slot 11 (yellow-orange)
KEY_COLOR_A    = C_GOLD                     ; key pillar colour 1: slot 12 (gold)
EDGE_ATTR      = C_SKY                      ; edge lines between walls: background colour
OUTLINE_ATTR   = C_OUTLINE                  ; first and last row of a wall slice
KEY_COLOR_B    = C_WHITE                    ; key pillar colour 2: slot 15 (white)
HIT_WALL       = 0                          ; CastRay hit type: normal wall
HIT_EXIT       = 1                          ; CastRay hit type: exit door
HIT_KEY        = 2                          ; CastRay hit type: key
DEFAULT_ATTR   = C_TEXT                     ; normal colour: slot 7 text on slot 0 background

; ---------- cell types returned by IsWall ----------
CELL_FREE = 0                               ; floor: can walk here
CELL_WALL = 1                               ; '#': blocks movement
CELL_EXIT = 2                               ; 'E': blocks movement, touching it with 3 keys wins
CELL_KEY  = 3                               ; 'K': blocks movement, touching it collects the key
KEYS_NEEDED   = 3                           ; keys needed to open the exit door
MSG_MS        = 2000                        ; HUD messages stay for 2 seconds
KEY_MSG_DIGIT = 11                          ; position of n in "KEY FOUND! n/3"
KEY_MSG_ATTR  = C_DOOR_B                    ; "KEY FOUND" message: slot 11 (accent)
LOCKED_ATTR   = C_DOOR_B                    ; "DOOR LOCKED" message: slot 11 (accent)

; ---------- game start values and results ----------
START_X     = 384                           ; 1.5 cells: centre of column 1
START_Y     = 384                           ; 1.5 cells: centre of row 1
START_ANGLE = 0                             ; facing east
RESULT_QUIT = 0                             ; GameLoop result: player pressed Q
RESULT_WIN  = 1                             ; GameLoop result: player touched the exit
RESULT_LOSE = 2                             ; GameLoop result: time ran out
MS_PER_DAY  = 86400000                      ; GetMseconds restarts from 0 at midnight
BLINK_MS    = 500                           ; blinking things change colour every 500 ms
TIME_LIMIT  = 180                           ; seconds allowed to find the keys and escape

; ---------- HUD layout: where the numbers go inside the HUD row ----------
HUD_MIN_POS  = 5                            ; "TIME mm:ss": minutes start at column 5
HUD_SEC_POS  = 8                            ; seconds start at column 8
HUD_STEP_POS = 18                           ; "STEPS nnnnn": steps start at column 18
HUD_KEY_POS  = 30                           ; "KEYS n/3": the key count is at column 30
HUD_MSG_POS  = 35                           ; messages replace the controls text from column 35
HUD_TIME_LEN = 10                           ; "TIME mm:ss" is 10 characters
LOW_TIME     = 20                           ; timer turns red below 20 seconds
TIMER_ATTR     = C_WHITE                    ; timer colour: slot 15 (white)
TIMER_LOW_ATTR = C_DANGER                   ; timer under 20 s: slot 13 (danger)
KEYS_ATTR      = C_GOLD                     ; "KEYS n/3": slot 12 (gold)
HUD_KEYS_COL   = 25                         ; "KEYS n/3" starts at column 25
HUD_KEYS_LEN   = 8                          ; "KEYS n/3" is 8 characters

; ---------- theme colours: COLORREF = 00BBGGRRh (web #RRGGBB written backwards) ----------
RGB_SKY        = 001A0E0Ah                  ; slot 0  sky / background   #0A0E1A
RGB_WALL_3     = 006E2A2Ah                  ; slot 1  wall level 3 (far) #2A2A6E blue-violet
RGB_WALL_2     = 00B04F3Fh                  ; slot 2  wall level 2       #3F4FB0
RGB_WALL_1     = 00E07F5Bh                  ; slot 3  wall level 1       #5B7FE0
RGB_WALL_0     = 00FFB48Ah                  ; slot 4  wall level 0 (near)#8AB4FF
RGB_FLOOR_FAR  = 001D1614h                  ; slot 5  floor far          #14161D
RGB_FLOOR_MID  = 002A211Eh                  ; slot 6  floor mid          #1E212A
RGB_FLOOR_NEAR = 003A2F2Bh                  ; slot 8  floor near / stars #2B2F3A
RGB_MAP_WALL   = 007A4034h                  ; slot 9  minimap walls      #34407A
RGB_DOOR_A     = 002B6AFFh                  ; slot 10 door A             #FF6A2B red-orange
RGB_DOOR_B     = 0047B3FFh                  ; slot 11 door B / accent    #FFB347 yellow-orange
RGB_GOLD       = 004AD5FFh                  ; slot 12 keys / gold        #FFD54A
RGB_DANGER     = 003D4DFFh                  ; slot 13 danger (timer<20s) #FF4D3D
RGB_OUTLINE    = 00451F1Ah                  ; slot 14 wall outline       #1A1F45
PAL_KEEP_TEXT  = 7                          ; slot 7 (light gray text) keeps its colour
PAL_KEEP_WHITE = 15                         ; slot 15 (white) keeps its colour
PAL_SLOTS      = 16                         ; the console has 16 colour slots
FORCE_FALLBACK = 0                          ; debug: 1 = pretend the palette call failed


.data
; ---------- console palette ----------
themeColors DWORD RGB_SKY, RGB_WALL_3, RGB_WALL_2, RGB_WALL_1    ; slots 0-3
            DWORD RGB_WALL_0, RGB_FLOOR_FAR, RGB_FLOOR_MID, 0    ; slots 4-7 (7 is kept)
            DWORD RGB_FLOOR_NEAR, RGB_MAP_WALL, RGB_DOOR_A, RGB_DOOR_B ; slots 8-11
            DWORD RGB_GOLD, RGB_DANGER, RGB_OUTLINE, 0           ; slots 12-15 (15 is kept)
origInfo    CSBI_EX <>                      ; the console settings found at start (restored at exit)
themeInfo   CSBI_EX <>                      ; the same settings with the theme colours
paletteOK   DWORD 0                         ; 1 if the theme palette was installed

; ---------- role -> console colour tables (index = role C_SKY .. C_WHITE) ----------
; The game always draws with roles. roleColors (the active table) turns a
; role into the real console colour: with the custom palette the role
; number IS the palette slot; without it, standard colours that keep the
; blue / orange look are used instead.
customRoles   BYTE 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ; custom palette: role = slot
fallbackRoles BYTE black, gray, gray, blue          ; sky, wall far, wall, wall
              BYTE lightBlue, black, black, lightGray ; wall near, floor far, floor mid, text
              BYTE gray, blue, lightRed, yellow     ; floor near/stars, map walls, door A, door B/accent
              BYTE yellow, lightRed, gray, white    ; gold, danger, outline, white
roleColors    BYTE PAL_SLOTS DUP(?)                 ; the active table (filled by LoadPalette)
; ---------- the maze: 16 rows x 16 columns, 1 byte per cell ----------
; '#' = wall, '.' = floor, 'E' = exit, 'K' = key. Cell (row, col) is at
; map + row*16 + col. originalMap is never changed; ResetGame copies it
; into gameMap, the copy the game plays on (collected keys become '.').
originalMap BYTE "################"         ; row 0  (outer wall)
            BYTE "#......#.......#"         ; row 1  (player starts at col 1)
            BYTE "#.##.#.#.#####.#"         ; row 2
            BYTE "#.#..#...#..K#.#"         ; row 3  (key at col 12)
            BYTE "#.#.####.#.#.#.#"         ; row 4
            BYTE "#...#....#.#...#"         ; row 5
            BYTE "###.#.####.###.#"         ; row 6
            BYTE "#...#.#....#...#"         ; row 7
            BYTE "#.###.#.####.#.#"         ; row 8
            BYTE "#.#...#......#.#"         ; row 9
            BYTE "#.#.#######.##.#"         ; row 10
            BYTE "#...#.....#..#.#"         ; row 11
            BYTE "#.###.###.##.#.#"         ; row 12
            BYTE "#.....#......#.#"         ; row 13
            BYTE "#K#####K######E#"         ; row 14 (keys at cols 1 and 7, exit at col 14)
            BYTE "################"         ; row 15 (outer wall)
gameMap     BYTE MAP_W * MAP_H DUP('#')   ; working copy of the map (filled by ResetGame)

; ---------- player data (positions are Q8: value = cells * 256) ----------
posX      DWORD START_X                     ; X in Q8, set again by ResetGame
posY      DWORD START_Y                     ; Y in Q8, set again by ResetGame
angle     DWORD START_ANGLE                 ; facing direction in degrees (0..359), 0 = east
steps     DWORD 0                           ; number of steps the player has taken
keys      DWORD 0                           ; keys collected so far (0..3)
msgText   DWORD 0                           ; address of the HUD message, 0 = no message
msgColor  DWORD 0                           ; colour of the HUD message
msgStart  DWORD 0                           ; GetMseconds value when the message started
startTime DWORD 0                           ; time (ms from GetMseconds) when the game started

; ---------- game state flags ----------
showMinimap BYTE 1                          ; 1 = minimap visible, 0 = hidden (M toggles)
quitFlag    BYTE 0                          ; becomes 1 when the player presses Q
wonFlag     BYTE 0                          ; becomes 1 when the player touches the exit
mWasDown    BYTE 0                          ; 1 if M was held last frame (for single press)
qWasDown    BYTE 0                          ; 1 if Q was held last frame (for single press)
inputHandle DWORD ?                         ; console input handle (set by InitInput)
blinkOn     DWORD 0                         ; 0 / 1, flips every 500 ms (door, keys, title text)

; ---------- per-column ray results (filled by CastAllRays, used by DrawColumn) ----------
colAngle    WORD  SCREEN_W DUP(0)           ; ray angle of each column
colDist     DWORD SCREEN_W DUP(0)           ; fisheye-corrected distance (Q8)
hitSideCol  BYTE  SCREEN_W DUP(0)           ; 0 = X-side hit, 1 = Y-side hit
colType     BYTE  SCREEN_W DUP(0)           ; HIT_WALL / HIT_EXIT / HIT_KEY
hitCellCol  BYTE  SCREEN_W DUP(0)           ; map cell number that was hit
colWallX    BYTE  SCREEN_W DUP(0)           ; where along the wall (0..255)
rayCell     DWORD 0                         ; CastRay output: cell number of the hit
rayWallX    DWORD 0                         ; CastRay output: wallX of the hit

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
wallColors  BYTE C_WALL_0, C_WALL_1, C_WALL_2, C_WALL_3, C_OUTLINE ; wall shades near->far, then outline (darkest)
floorColors BYTE C_FLOOR_NEAR, C_FLOOR_MID, C_FLOOR_FAR, C_FLOOR_FAR ; floor: nearest rows first

; ---------- screen drawing data ----------
frameBuffer   BYTE SCREEN_W * BUF_H DUP(' ')      ; 80x25 = 2000 chars, cell (row,col) at row*80 + col
attrBuffer    WORD SCREEN_W * BUF_H DUP(DEFAULT_ATTR) ; colour of each cell, same layout (2 bytes each)
consoleHandle DWORD ?                       ; handle of the console output (set by HideCursor)
cursorInfo    CONSOLE_CURSOR_INFO <100, 0>  ; cursor size 100%, bVisible = 0 (hidden)
drawPos       COORD <0, 0>                  ; screen position (0,0) where drawing starts
charsWritten  DWORD ?                       ; Windows stores how many chars it wrote here

; ---------- title screen ----------
; ---------- WOLF-86 in block letters ('#' is printed as a solid block) ----------
logoArt BYTE "#   #  ###  #     #####        ###   ### ", 0
        BYTE "#   # #   # #     #           #   # #    ", 0
        BYTE "# # # #   # #     ####   ###   ###  #### ", 0
        BYTE "## ## #   # #     #           #   # #   #", 0
        BYTE "#   #  ###  ##### #            ###   ### ", 0
; ---------- ESCAPED! in block letters ('#' is printed as a solid block) ----------
winArt BYTE "#####  ####  ####  ###  ####  ##### ####    #  ", 0
       BYTE "#     #     #     #   # #   # #     #   #   #  ", 0
       BYTE "####   ###  #     ##### ####  ####  #   #   #  ", 0
       BYTE "#         # #     #   # #     #     #   #      ", 0
       BYTE "##### ####   #### #   # #     ##### ####    #  ", 0
; ---------- TIME UP in block letters ('#' is printed as a solid block) ----------
loseArt BYTE "##### ##### #   # #####       #   # #### ", 0
        BYTE "  #     #   ## ## #           #   # #   #", 0
        BYTE "  #     #   # # # ####        #   # #### ", 0
        BYTE "  #     #   #   # #           #   # #    ", 0
        BYTE "  #   ##### #   # #####        ###  #    ", 0
logoColors BYTE C_WALL_0, C_WALL_0, C_WALL_1, C_WALL_2, C_WALL_3 ; logo: light blue (top) to deep blue (bottom)
winColors  BYTE 5 DUP(C_GOLD)                              ; win banner: gold
loseColors BYTE 5 DUP(C_DANGER)                            ; lose banner: danger red
subText    BYTE "A 3D RAYCASTING MAZE GAME IN x86 ASSEMBLY", 0 ; line under the logo
; ---------- controls box (code page 437 double-line box) ----------
ctrlBox BYTE 201, 44 DUP(205), 187, 0
        BYTE 186, "  CONTROLS                                  ", 186, 0
        BYTE 186, "  W / S   move forward / back               ", 186, 0
        BYTE 186, "  A / D   turn left / right                 ", 186, 0
        BYTE 186, "  M       show / hide minimap               ", 186, 0
        BYTE 186, "  Q       quit                              ", 186, 0
        BYTE 186, "                                            ", 186, 0
        BYTE 186, "  GOAL: find the 3 keys (K), then reach the ", 186, 0
        BYTE 186, "        exit (E) before the timer runs out! ", 186, 0
        BYTE 200, 44 DUP(205), 188, 0
boxColors  BYTE C_MAP_WALL, 8 DUP(C_WHITE), C_MAP_WALL     ; box border slot 9, text white
pressKey   BYTE "PRESS ANY KEY", 0                         ; blinking prompt

; ---------- HUD text (numbers are filled in each frame) ----------
hudTemplate BYTE "TIME 00:00  STEPS 00000  KEYS 0/3  W/S move  A/D turn  M map  Q quit"
HUD_LEN = ($ - hudTemplate)                 ; number of characters in the template
keyMsg     BYTE "KEY FOUND! 0/3", 0                    ; the 0 is replaced by the key count
lockedMsg  BYTE "DOOR LOCKED - FIND 3 KEYS", 0         ; shown when touching the door too early

; ---------- end screen text ----------
loseText   BYTE "You did not escape in time.", 0          ; lose message
timeMsg    BYTE "Time taken: ", 0                         ; label before mm:ss
stepsMsg   BYTE "Steps:      ", 0                         ; label before the step count
keysMsg    BYTE "Keys:       ", 0                         ; label before the key count
keysOf     BYTE "/3", 0                                   ; after the key count
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
    INVOKE LoadPalette                      ; blue/orange theme (keeps standard colours if it fails)
    INVOKE InitInput                        ; get console input handle (for flushing keys)
    INVOKE TitleScreen                      ; show the title screen, EAX = key pressed
    and    al, 11011111b                    ; make the key uppercase
    cmp    al, 'Q'                          ; Q on the title screen?
    je     QuitProgram                      ; yes: quit straight away
NewGame:
    INVOKE WaitKeysReleased                 ; the last key pressed can't trigger M or Q
    INVOKE ResetGame                        ; start position, angle, steps, timer
    mov    eax, DEFAULT_ATTR                ; normal colours (win/lose screens used gold/red)
    call   SetRoleColor                    ; Clrscr paints every cell with this colour
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
    mov    eax, DEFAULT_ATTR                ; normal colours for the console we leave behind
    call   SetRoleColor                    ; apply them
    INVOKE RestorePalette                   ; give the console its own colours back
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
; Purpose:   Clear the screen and show the block-letter logo,
;            a subtitle and the controls box, then blink
;            "PRESS ANY KEY" until a key is pressed (ReadKey
;            does not wait, so the loop keeps blinking).
; Receives:  nothing
; Returns:   EAX = the key that was pressed (in AL)
; Registers: EAX (EDX saved by USES)
;-------------------------------------------------------------
TitleScreen PROC USES edx
    call Clrscr                             ; clear the console
    INVOKE PrintArt, ADDR logoArt, ADDR logoColors, ART_LINES, LOGO_ROW, LOGO_COL ; big logo
    mov  eax, C_DOOR_B                      ; subtitle colour: orange accent
    call SetRoleColor                      ; apply it
    mov  dh, SUB_ROW                        ; row of the subtitle
    mov  dl, SUB_COL                        ; column of the subtitle
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET subText                ; subtitle text
    call WriteString                        ; print it
    INVOKE PrintArt, ADDR ctrlBox, ADDR boxColors, BOX_LINES, BOX_ROW, BOX_COL ; controls box
TitleWait:
    call UpdateBlink                        ; blinkOn = 0 or 1 from the clock
    mov  eax, C_DOOR_B                      ; bright prompt: orange accent
    cmp  blinkOn, 0                         ; first half of the blink?
    je   PromptColor                        ; yes: keep orange
    mov  eax, C_FLOOR_NEAR                  ; no: dim
PromptColor:
    call SetRoleColor                      ; apply the prompt colour
    mov  dh, PRESS_ROW                      ; row of the prompt
    mov  dl, PRESS_COL                      ; column of the prompt
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET pressKey               ; "PRESS ANY KEY"
    call WriteString                        ; print it in this frame's colour
    mov  eax, TITLE_DELAY                   ; 50 ms
    call Delay                              ; short wait so the CPU is not busy
    call ReadKey                            ; key waiting? (does not wait) ZF = 1 if none
    jz   TitleWait                          ; no key: keep blinking
    movzx eax, al                           ; EAX = just the key code
    push eax                                ; keep the key
    mov  eax, DEFAULT_ATTR                  ; back to normal colours
    call SetRoleColor                      ; apply them
    pop  eax                                ; EAX = key again
    ret                                     ; back to caller
TitleScreen ENDP

;-------------------------------------------------------------
; PrintArt
; Purpose:   Print several 0-terminated text lines, one under
;            the other, starting at (row, col). Each line has
;            its own colour. A '#' is printed as a solid block
;            (219), so block letters can be typed with '#'.
; Receives:  artPtr   = address of the first line
;            colorPtr = address of one colour byte per line
;            lines    = number of lines
;            row, col = screen position of the first line
; Returns:   nothing (console changed)
; Registers: none (EAX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
PrintArt PROC USES eax ecx edx esi edi, artPtr:PTR BYTE, colorPtr:PTR BYTE, lines:DWORD, row:DWORD, col:DWORD
    mov  esi, artPtr                        ; ESI = next character to print
    mov  edi, colorPtr                      ; EDI = colour of the current line
    mov  ecx, lines                         ; ECX = lines left
ArtLine:
    movzx eax, BYTE PTR [edi]               ; EAX = colour of this line
    call SetRoleColor                      ; apply it
    inc  edi                                ; next line's colour
    mov  eax, row                           ; EAX = row of this line
    mov  dh, al                             ; DH = row
    mov  eax, col                           ; EAX = column
    mov  dl, al                             ; DL = column
    call Gotoxy                             ; move the cursor to the line start
ArtChar:
    mov  al, [esi]                          ; AL = next character
    inc  esi                                ; move past it
    cmp  al, 0                              ; end of this line?
    je   ArtLineDone                        ; yes
    cmp  al, '#'                            ; block-letter marker?
    jne  ArtPut                             ; no: print as it is
    mov  al, WALL_CHAR                      ; yes: print a solid block instead
ArtPut:
    call WriteChar                          ; print the character
    jmp  ArtChar                            ; next character
ArtLineDone:
    inc  row                                ; next line goes one row lower
    loop ArtLine                            ; ECX--, repeat for every line
    ret                                     ; back to caller
PrintArt ENDP

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
; LoadPalette
; Purpose:   Read the console settings (GetConsoleScreenBufferInfoEx)
;            and keep them in origInfo. Then copy them to
;            themeInfo, replace the palette colours with the
;            blue/orange theme (slots 7 and 15 stay as they
;            were) and apply it. If the console does not allow
;            this (e.g. Windows Terminal), nothing changes and
;            the game runs with the standard colours.
;            Finally the matching role table (customRoles or
;            fallbackRoles) is copied into roleColors.
; Receives:  nothing (consoleHandle must be set by HideCursor)
; Returns:   origInfo, themeInfo, paletteOK = 1 on success,
;            roleColors filled
; Registers: none (EAX, ECX, ESI, EDI saved by USES)
;-------------------------------------------------------------
LoadPalette PROC USES eax ecx esi edi
IF FORCE_FALLBACK                           ; debug build: skip the palette completely
    jmp  PaletteDone                        ; paletteOK stays 0 -> standard colours
ENDIF
    mov  origInfo.cbSize, SIZEOF CSBI_EX    ; Windows checks the structure size
    INVOKE GetConsoleScreenBufferInfoEx, consoleHandle, ADDR origInfo ; read the settings
    cmp  eax, 0                             ; did it fail?
    je   PaletteDone                        ; yes: keep the standard colours
    cld                                     ; copy forwards
    mov  esi, OFFSET origInfo               ; ESI = the original settings
    mov  edi, OFFSET themeInfo              ; EDI = the copy we change
    mov  ecx, SIZEOF CSBI_EX                ; ECX = 96 bytes
    rep  movsb                              ; copy them
    mov  ecx, 0                             ; ECX = slot number 0..15
SlotLoop:
    cmp  ecx, PAL_KEEP_TEXT                 ; slot 7 (normal text)?
    je   NextSlot                           ; yes: keep it
    cmp  ecx, PAL_KEEP_WHITE                ; slot 15 (white)?
    je   NextSlot                           ; yes: keep it
    mov  eax, themeColors[ecx*4]            ; EAX = theme colour for this slot (4 bytes each)
    mov  themeInfo.ColorTable[ecx*4], eax   ; put it into the palette
NextSlot:
    inc  ecx                                ; next slot
    cmp  ecx, PAL_SLOTS                     ; all 16 done?
    jb   SlotLoop                           ; no: continue
    INVOKE SetPalette, ADDR themeInfo       ; apply the theme, EAX = 1 if it worked
    mov  paletteOK, eax                     ; remember (restore only if we changed it)
PaletteDone:
    mov  esi, OFFSET customRoles            ; assume the theme palette is active
    cmp  paletteOK, 0                       ; did it work?
    jne  HaveRoles                          ; yes: role = palette slot
    mov  esi, OFFSET fallbackRoles          ; no: standard colours with the same look
HaveRoles:
    cld                                     ; copy forwards
    mov  edi, OFFSET roleColors             ; EDI = the active table
    mov  ecx, PAL_SLOTS                     ; 16 roles
    rep  movsb                              ; copy the chosen table
    ret                                     ; back to caller
LoadPalette ENDP

;-------------------------------------------------------------
; SetRoleColor
; Purpose:   Set the console text colour for a colour ROLE:
;            the role is looked up in roleColors, then
;            SetTextColor is called with the real colour.
; Receives:  EAX = role (C_SKY .. C_WHITE, background 0)
; Returns:   nothing (console text colour changed)
; Registers: none (EAX, EBX saved by USES)
;-------------------------------------------------------------
SetRoleColor PROC USES eax ebx
    and  eax, 0Fh                           ; only the foreground role (background is role 0)
    mov  ebx, OFFSET roleColors             ; EBX = the active role table
    xlat                                    ; AL = [EBX + AL] = real console colour
    call SetTextColor                       ; apply it
    ret                                     ; back to caller
SetRoleColor ENDP

;-------------------------------------------------------------
; ApplyRoles
; Purpose:   Turn every colour in attrBuffer from a ROLE into the
;            real console colour (roleColors), just before the
;            frame is drawn. Background stays 0 (the sky).
; Receives:  nothing (uses attrBuffer, roleColors)
; Returns:   attrBuffer changed
; Registers: none (EAX, EBX, ECX, ESI saved by USES)
;-------------------------------------------------------------
ApplyRoles PROC USES eax ebx ecx esi
    mov  ebx, OFFSET roleColors             ; EBX = table for XLAT
    mov  esi, OFFSET attrBuffer             ; ESI = first colour
    mov  ecx, SCREEN_W * BUF_H              ; ECX = 2000 cells
RoleLoop:
    mov  ax, [esi]                          ; AX = role of this cell
    and  al, 0Fh                            ; foreground role only
    xlat                                    ; AL = [EBX + AL] = real colour
    mov  [esi], ax                          ; store it back
    add  esi, 2                             ; next cell (2 bytes each)
    loop RoleLoop                           ; ECX--, repeat for all cells
    ret                                     ; back to caller
ApplyRoles ENDP

;-------------------------------------------------------------
; RestorePalette
; Purpose:   Put the console colours back the way they were
;            when the program started (only if LoadPalette
;            changed them).
; Receives:  nothing (uses paletteOK, origInfo)
; Returns:   nothing
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
RestorePalette PROC USES eax
    cmp  paletteOK, 0                       ; did we change the palette?
    je   RestoreDone                        ; no: nothing to undo
    INVOKE SetPalette, ADDR origInfo        ; yes: original colours back
RestoreDone:
    ret                                     ; back to caller
RestorePalette ENDP

;-------------------------------------------------------------
; SetPalette
; Purpose:   Apply a CSBI_EX structure with
;            SetConsoleScreenBufferInfoEx. Windows reads the
;            window rectangle one cell smaller than it returned
;            it, so Right and Bottom are increased by 1 for the
;            call (and put back afterwards) to stop the window
;            from shrinking.
; Receives:  infoPtr = address of the CSBI_EX to apply
; Returns:   EAX = 1 if it worked, 0 if not
; Registers: EAX (EBX saved by USES)
;-------------------------------------------------------------
SetPalette PROC USES ebx, infoPtr:PTR CSBI_EX
    mov  ebx, infoPtr                       ; EBX = address of the structure
    inc  (CSBI_EX PTR [ebx]).srWindow.Right ; window width fix
    inc  (CSBI_EX PTR [ebx]).srWindow.Bottom ; window height fix
    INVOKE SetConsoleScreenBufferInfoEx, consoleHandle, ebx ; apply palette and settings
    dec  (CSBI_EX PTR [ebx]).srWindow.Right ; undo the fix in memory
    dec  (CSBI_EX PTR [ebx]).srWindow.Bottom ; (DEC does not change EAX)
    cmp  eax, 0                             ; did Windows accept it?
    je   SetDone                            ; no: return 0
    mov  eax, 1                             ; yes: return 1
SetDone:
    ret                                     ; back to caller
SetPalette ENDP

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
; Returns:   EAX = CELL_WALL ('#'), CELL_EXIT ('E'),
;                  CELL_KEY ('K') or CELL_FREE (anything else)
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
    mov  eax, CELL_KEY                      ; assume key
    cmp  bl, 'K'                            ; is it a key?
    je   WallDone                           ; yes: return CELL_KEY
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
;            walls. steps++ if it moved. A probe touching the
;            exit or a key is handled by HandleCell (exit and
;            keys block like walls).
; Receives:  moveDX, moveDY = movement in Q8
; Returns:   posX, posY, steps (and via HandleCell: keys,
;            wonFlag, message) updated
; Registers: none (EAX, ECX, EDX, ESI saved by USES)
;-------------------------------------------------------------
TryMove PROC USES eax ecx edx esi, moveDX:SDWORD, moveDY:SDWORD
    mov  ecx, 0                             ; ECX = 1 once we really move
    cmp  moveDX, 0                          ; any X movement at all?
    je   TryY                               ; no: skip the X test
    mov  edx, posX                          ; EDX = current X
    add  edx, moveDX                        ; EDX = new X
    INVOKE ProbePoint, edx, moveDX          ; EAX = new X + margin ahead
    mov  esi, eax                           ; ESI = probe X
    INVOKE IsWall, esi, posY                ; that point with OLD Y: what cell?
    INVOKE HandleCell, eax, esi, posY       ; exit or key touched? (EAX kept)
    cmp  eax, CELL_FREE                     ; free floor?
    jne  TryY                               ; wall, exit or key: do not move in X
    mov  posX, edx                          ; free: accept the new X
    mov  ecx, 1                             ; remember that we moved
TryY:
    cmp  moveDY, 0                          ; any Y movement at all?
    je   MoveDone                           ; no: skip the Y test
    mov  edx, posY                          ; EDX = current Y
    add  edx, moveDY                        ; EDX = new Y
    INVOKE ProbePoint, edx, moveDY          ; EAX = new Y + margin ahead
    mov  esi, eax                           ; ESI = probe Y
    INVOKE IsWall, posX, esi                ; (maybe new) X with that Y: what cell?
    INVOKE HandleCell, eax, posX, esi       ; exit or key touched? (EAX kept)
    cmp  eax, CELL_FREE                     ; free floor?
    jne  MoveDone                           ; wall, exit or key: do not move in Y
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
; HandleCell
; Purpose:   React to the cell a movement probe touched:
;            exit -> TouchExit, key -> CollectKey.
;            Other cells need nothing here.
; Receives:  cellType     = result of IsWall
;            testX, testY = the probe point (Q8)
; Returns:   nothing (keys, gameMap, wonFlag, message may change)
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
HandleCell PROC USES eax, cellType:DWORD, testX:SDWORD, testY:SDWORD
    cmp  cellType, CELL_EXIT                ; touching the exit door?
    jne  NotExitCell                        ; no
    call TouchExit                          ; yes: win or "door locked"
    jmp  CellDone                           ; finished
NotExitCell:
    cmp  cellType, CELL_KEY                 ; touching a key?
    jne  CellDone                           ; no: nothing to do
    INVOKE CollectKey, testX, testY         ; yes: pick it up
CellDone:
    ret                                     ; back to caller
HandleCell ENDP

;-------------------------------------------------------------
; CollectKey
; Purpose:   Pick up the key at a Q8 position: the map cell
;            becomes floor, keys++, and the HUD shows
;            "KEY FOUND! n/3" for 2 seconds.
; Receives:  testX, testY = a point inside the key cell (Q8)
; Returns:   gameMap, keys, keyMsg, message updated
; Registers: none (EAX, EBX saved by USES)
;-------------------------------------------------------------
CollectKey PROC USES eax ebx, testX:SDWORD, testY:SDWORD
    mov  eax, testY                         ; EAX = Y in Q8
    sar  eax, 8                             ; row (IsWall already checked it is inside the map)
    shl  eax, 4                             ; row * 16
    mov  ebx, testX                         ; EBX = X in Q8
    sar  ebx, 8                             ; column
    add  eax, ebx                           ; EAX = row*16 + col
    mov  gameMap[eax], '.'                  ; the key is gone: plain floor now
    inc  keys                               ; one more key
    mov  eax, keys                          ; EAX = keys collected (1..3)
    add  al, '0'                            ; turn it into a digit character
    mov  keyMsg[KEY_MSG_DIGIT], al          ; put it into "KEY FOUND! n/3"
    INVOKE ShowMessage, ADDR keyMsg, KEY_MSG_ATTR ; show it in the HUD
    ret                                     ; back to caller
CollectKey ENDP

;-------------------------------------------------------------
; TouchExit
; Purpose:   The player touched the exit door. With all 3 keys
;            the player wins; otherwise the HUD shows
;            "DOOR LOCKED - FIND 3 KEYS" for 2 seconds.
; Receives:  nothing (uses keys)
; Returns:   wonFlag = 1 or message set
; Registers: none
;-------------------------------------------------------------
TouchExit PROC
    cmp  keys, KEYS_NEEDED                  ; all keys collected? (unsigned count)
    jb   DoorLocked                         ; no: the door stays locked
    mov  wonFlag, 1                         ; yes: the player escapes
    ret                                     ; back to caller
DoorLocked:
    INVOKE ShowMessage, ADDR lockedMsg, LOCKED_ATTR ; tell the player why
    ret                                     ; back to caller
TouchExit ENDP

;-------------------------------------------------------------
; ShowMessage
; Purpose:   Start showing a message in the HUD for MSG_MS
;            (2000) milliseconds.
; Receives:  msgPtr  = address of a 0-terminated message
;            msgAttr = its colour
; Returns:   msgText, msgColor, msgStart set
; Registers: none (EAX saved by USES)
;-------------------------------------------------------------
ShowMessage PROC USES eax, msgPtr:PTR BYTE, msgAttr:DWORD
    mov  eax, msgPtr                        ; EAX = message address
    mov  msgText, eax                       ; remember which message
    mov  eax, msgAttr                       ; EAX = colour
    mov  msgColor, eax                      ; remember its colour
    call GetMseconds                        ; EAX = time now
    mov  msgStart, eax                      ; the message starts now
    ret                                     ; back to caller
ShowMessage ENDP

;-------------------------------------------------------------
; MsSince
; Purpose:   Milliseconds since an earlier GetMseconds value.
;            GetMseconds restarts at 0 at midnight, so a
;            negative difference gets one day added.
; Receives:  since = earlier GetMseconds value
; Returns:   EAX = milliseconds passed
; Registers: EAX only
;-------------------------------------------------------------
MsSince PROC, since:DWORD
    call GetMseconds                        ; EAX = milliseconds since midnight now
    sub  eax, since                         ; EAX = milliseconds since then
    jns  SinceOK                            ; not negative: normal case
    add  eax, MS_PER_DAY                    ; negative: midnight passed, add one day
SinceOK:
    ret                                     ; back to caller
MsSince ENDP

;-------------------------------------------------------------
; DrawMessage
; Purpose:   If a message is active (shown for less than 2 s),
;            write it over the controls text in the HUD, in its
;            colour. When the time is over, clear it.
; Receives:  nothing (uses msgText, msgColor, msgStart)
; Returns:   nothing (HUD row of the frame changed, msgText may
;            become 0)
; Registers: none (EAX, ECX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawMessage PROC USES eax ecx esi edi
    cmp  msgText, 0                         ; any message?
    je   MsgDone                            ; no: keep the controls text
    INVOKE MsSince, msgStart                ; EAX = how long it has been shown
    cmp  eax, MSG_MS                        ; 2 seconds or more?
    jb   MsgShow                            ; no: show it
    mov  msgText, 0                         ; yes: the message is over
    jmp  MsgDone                            ; keep the controls text
MsgShow:
    cld                                     ; string instructions go forwards
    mov  al, ' '                            ; blank out the message area first
    mov  ecx, SCREEN_W - HUD_MSG_POS        ; ECX = cells from the message column to the end
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W + HUD_MSG_POS ; EDI = message area
    rep  stosb                              ; fill it with spaces
    mov  eax, msgColor                      ; AX = message colour
    mov  ecx, SCREEN_W - HUD_MSG_POS        ; ECX = same number of cells
    mov  edi, OFFSET attrBuffer + (HUD_ROW * SCREEN_W + HUD_MSG_POS) * 2 ; EDI = their colours
    rep  stosw                              ; colour the whole area
    mov  esi, msgText                       ; ESI = message text
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W + HUD_MSG_POS ; EDI = message area
MsgCopy:
    lodsb                                   ; AL = [ESI], ESI++
    cmp  al, 0                              ; end of the message?
    je   MsgDone                            ; yes: finished
    stosb                                   ; [EDI] = AL, EDI++
    jmp  MsgCopy                            ; next character
MsgDone:
    ret                                     ; back to caller
DrawMessage ENDP

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
; PutCell
; Purpose:   Write one character and its colour into the frame
;            (frameBuffer and attrBuffer) at (row, col).
; Receives:  row, col  = screen position (row 0..24, col 0..79)
;            cellChar  = character (low byte used)
;            cellAttr  = colour attribute (low word used)
; Returns:   nothing (frameBuffer, attrBuffer changed)
; Registers: none (EAX, EBX saved by USES)
;-------------------------------------------------------------
PutCell PROC USES eax ebx, row:DWORD, col:DWORD, cellChar:DWORD, cellAttr:DWORD
    mov  eax, row                           ; EAX = row
    imul eax, SCREEN_W                      ; EAX = row * 80
    add  eax, col                           ; EAX = row*80 + col = cell number
    mov  ebx, cellChar                      ; BL = character
    mov  frameBuffer[eax], bl               ; store it (indexed addressing)
    mov  ebx, cellAttr                      ; BX = colour
    mov  attrBuffer[eax*2], bx              ; store it (scaled index: 2 bytes per colour)
    ret                                     ; back to caller
PutCell ENDP

;-------------------------------------------------------------
; GetMapLook
; Purpose:   Choose how one map cell looks on the minimap.
;            '#' -> blue-gray block, 'E' -> orange E,
;            'K' -> gold K, anything else -> dark space.
; Receives:  EAX = map character (in AL)
; Returns:   EAX = screen character, EBX = colour attribute
; Registers: EAX, EBX
;-------------------------------------------------------------
GetMapLook PROC
    cmp  al, '#'                            ; wall?
    je   LookWall                           ; yes
    cmp  al, 'E'                            ; exit?
    je   LookExit                           ; yes
    cmp  al, 'K'                            ; key?
    je   LookKey                            ; yes
    mov  eax, ' '                           ; floor: empty
    mov  ebx, DEFAULT_ATTR                  ; on the dark background
    ret                                     ; back to caller
LookWall:
    mov  eax, WALL_CHAR                     ; solid block
    mov  ebx, MAP_WALL_ATTR                 ; blue-gray
    ret                                     ; back to caller
LookExit:
    mov  eax, 'E'                           ; letter E
    mov  ebx, MAP_EXIT_ATTR                 ; orange
    ret                                     ; back to caller
LookKey:
    mov  eax, 'K'                           ; letter K
    mov  ebx, MAP_KEY_ATTR                  ; gold
    ret                                     ; back to caller
GetMapLook ENDP

;-------------------------------------------------------------
; DrawMapBorder
; Purpose:   Draw a single-line box around the minimap:
;            rows 0 and 17, columns 0 and 17 of the screen.
; Receives:  nothing
; Returns:   nothing (frameBuffer, attrBuffer changed)
; Registers: none (ECX saved by USES)
;-------------------------------------------------------------
DrawMapBorder PROC USES ecx
    INVOKE PutCell, 0, 0, BOX_TL, BORDER_ATTR             ; top-left corner
    INVOKE PutCell, 0, MAP_BOX, BOX_TR, BORDER_ATTR       ; top-right corner
    INVOKE PutCell, MAP_BOX, 0, BOX_BL, BORDER_ATTR       ; bottom-left corner
    INVOKE PutCell, MAP_BOX, MAP_BOX, BOX_BR, BORDER_ATTR ; bottom-right corner
    mov  ecx, 1                             ; ECX = 1..16 along each side
BorderLoop:
    INVOKE PutCell, 0, ecx, BOX_H, BORDER_ATTR       ; top edge
    INVOKE PutCell, MAP_BOX, ecx, BOX_H, BORDER_ATTR ; bottom edge
    INVOKE PutCell, ecx, 0, BOX_V, BORDER_ATTR       ; left edge
    INVOKE PutCell, ecx, MAP_BOX, BOX_V, BORDER_ATTR ; right edge
    inc  ecx                                ; next position
    cmp  ecx, MAP_BOX                       ; done 1..16?
    jb   BorderLoop                         ; no: continue
    ret                                     ; back to caller
DrawMapBorder ENDP

;-------------------------------------------------------------
; DrawMinimap
; Purpose:   If showMinimap = 1, draw the 16x16 map in colour
;            inside a border at the top-left of the frame, and a
;            gold direction arrow on the player's cell.
;            Map cell (r, c) goes to screen (r+1, c+1).
; Receives:  nothing (uses gameMap, posX, posY)
; Returns:   nothing (frameBuffer, attrBuffer changed)
; Registers: none (EAX, EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawMinimap PROC USES eax ebx ecx edx esi edi
    cmp  showMinimap, 0                     ; is the minimap hidden?
    je   MapDone                            ; yes: draw nothing
    call DrawMapBorder                      ; the box around the map
    mov  edx, 0                             ; EDX = map row
MapRow:
    mov  ecx, 0                             ; ECX = map column
MapCol:
    mov  eax, edx                           ; EAX = row
    shl  eax, 4                             ; row * 16
    add  eax, ecx                           ; row*16 + col
    movzx eax, gameMap[eax]                 ; AL = map character
    call GetMapLook                         ; EAX = screen char, EBX = colour
    mov  esi, edx                           ; ESI = row
    inc  esi                                ; +1 for the border
    mov  edi, ecx                           ; EDI = column
    inc  edi                                ; +1 for the border
    INVOKE PutCell, esi, edi, eax, ebx      ; draw the cell
    inc  ecx                                ; next column
    cmp  ecx, MAP_W                         ; all 16 columns?
    jb   MapCol                             ; no: continue
    inc  edx                                ; next row
    cmp  edx, MAP_H                         ; all 16 rows?
    jb   MapRow                             ; no: continue
    mov  esi, posY                          ; ESI = Y in Q8
    sar  esi, 8                             ; player row
    inc  esi                                ; +1 for the border
    mov  edi, posX                          ; EDI = X in Q8
    sar  edi, 8                             ; player column
    inc  edi                                ; +1 for the border
    call GetArrowChar                       ; EAX = arrow for the facing direction
    INVOKE PutCell, esi, edi, eax, PLAYER_ATTR ; gold arrow
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
;            ECX = HIT_WALL, HIT_EXIT or HIT_KEY (what stopped the ray)
;            rayCell  = map cell number of the hit (row*16 + col)
;            rayWallX = where along that wall the ray hit (0..255)
; Registers: EAX, ECX, EDX (EBX, ESI, EDI saved by USES)
;-------------------------------------------------------------
CastRay PROC USES ebx esi edi, rayAngle:DWORD
    LOCAL mapX:SDWORD, mapY:SDWORD          ; the cell the ray is in now
    LOCAL stepX:SDWORD, stepY:SDWORD        ; +1 or -1 per axis
    LOCAL deltaX:SDWORD, deltaY:SDWORD      ; ray length to cross one cell, per axis
    LOCAL sideX:SDWORD, sideY:SDWORD        ; ray length to the next X / Y grid line
    LOCAL hitSide:DWORD                     ; 0 = last step was in X, 1 = in Y
    LOCAL hitType:DWORD                     ; what stopped the ray: HIT_WALL / HIT_EXIT / HIT_KEY

    mov  hitType, HIT_WALL                  ; assume a normal wall until we know

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
    cmp  gameMap[eax], 'K'                  ; is it a key?
    je   RayKey                             ; yes: keys also stop the ray
    cmp  gameMap[eax], 'E'                  ; is it the exit door?
    jne  DDALoop                            ; no: keep stepping
    mov  hitType, HIT_EXIT                  ; yes: the exit also stops the ray
    jmp  RayHit                             ; go work out the distance
RayKey:
    mov  hitType, HIT_KEY                   ; the ray stopped on a key
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

    ; ----- block 4b: which cell, and where along its wall -----
    ; wallX = fractional part of the hit point: on an X-side hit
    ; it runs along Y (posY + dist*dirY), on a Y-side hit along X.
    mov  eax, mapY                          ; EAX = row of the hit cell
    shl  eax, 4                             ; row * 16
    add  eax, mapX                          ; + column = cell number
    and  eax, 0FFh                          ; keep it 0..255
    mov  rayCell, eax                       ; report the hit cell
    mov  eax, ebx                           ; EAX = distance along the ray
    cmp  hitSide, 0                         ; hit on an X line?
    jne  WallXFromX                         ; no: Y line
    FIXMUL eax, esi                         ; EAX = dist * dirY / 256
    add  eax, posY                          ; hit point Y (Q8)
    jmp  HaveWallX                          ; done
WallXFromX:
    FIXMUL eax, edi                         ; EAX = dist * dirX / 256
    add  eax, posX                          ; hit point X (Q8)
HaveWallX:
    and  eax, 255                           ; fractional part = position along the wall
    mov  rayWallX, eax                      ; report it

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
    mov  ecx, hitType                       ; ECX = what was hit
    ret                                     ; back to caller (EAX = distance, EDX = side, ECX = hit type)
CastRay ENDP

;-------------------------------------------------------------
; GetWallLevel
; Purpose:   Pick the wall shade level for a distance. Closer
;            walls are brighter. Y-side walls use one level
;            darker so corners and edges show up.
;            level 0 (near, brightest) .. 3 (far, darkest)
; Receives:  distance = wall distance (Q8)
;            side     = hitSide from CastRay (0 or 1)
; Returns:   EAX = level 0..3 (index into wallColors)
; Registers: EAX only
;-------------------------------------------------------------
GetWallLevel PROC, distance:DWORD, side:DWORD
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
    ret                                     ; back to caller
GetWallLevel ENDP

;-------------------------------------------------------------
; GetFloorColor
; Purpose:   Pick the floor colour for a screen row. Rows near
;            the bottom are close to the player and are bright;
;            higher rows are further away and darker.
;            level = (rows from bottom) / 3, max 3
;            slot 8 (bottom 3 rows), slot 6, slot 5, slot 5
; Receives:  ECX = screen row (0..23)
; Returns:   EAX = floor colour attribute (in AL)
; Registers: EAX (EDX saved by USES)
;-------------------------------------------------------------
GetFloorColor PROC USES edx
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
    movzx eax, floorColors[eax]             ; EAX = floor colour
    ret                                     ; back to caller
GetFloorColor ENDP

;-------------------------------------------------------------
; GetWallHeight
; Purpose:   Turn a distance into the real wall height in rows:
;            height = (SCREEN_H * 256) / distance
;            (1 cell away = 256 -> 24 rows). Not limited to the
;            screen: DrawColumn only draws the rows that fit.
; Receives:  EAX = distance (Q8, at least 1)
; Returns:   EAX = wall height in rows (1..6144)
; Registers: EAX (ECX, EDX saved by USES)
;-------------------------------------------------------------
GetWallHeight PROC USES ecx edx
    mov  ecx, eax                           ; ECX = distance
    mov  eax, SCREEN_H * 256                ; EAX = 6144
    mov  edx, 0                             ; clear EDX before DIV
    div  ecx                                ; EAX = 6144 / distance
    cmp  eax, 1                             ; at least one row?
    jae  HeightOK                           ; yes
    mov  eax, 1                             ; no: use 1 (no zero-height walls)
HeightOK:
    ret                                     ; back to caller
GetWallHeight ENDP

;-------------------------------------------------------------
; DrawColumn
; Purpose:   Fill one screen column, top to bottom:
;            sky (with stars), wall slice, floor. Uses the
;            results CastAllRays stored for this column.
;            The wall is centred vertically; rows outside the
;            screen are simply not drawn (wallTop can be < 0).
;            Edge columns (IsEdgeColumn) draw the whole slice in
;            the edge colour, so walls are clearly separated.
;            Plain wall slices get a dark outline on their first
;            and last row (crisp silhouette).
; Receives:  column = screen x (0..79)
; Returns:   nothing (frameBuffer, attrBuffer changed)
; Registers: none (EAX, EBX, ECX, EDX, ESI, EDI saved by USES)
;-------------------------------------------------------------
DrawColumn PROC USES eax ebx ecx edx esi edi, column:DWORD
    LOCAL wallTop:SDWORD                    ; first wall row (may be negative)
    LOCAL wallBottom:SDWORD                 ; first floor row (may be past the screen)
    LOCAL wallColor:DWORD                   ; colour of the wall slice
    LOCAL rayAng:DWORD                      ; ray angle of this column (for the stars)
    LOCAL plainWall:DWORD                   ; 1 = normal wall slice (gets outline), 0 = edge/door/key

    ; ----- block 1: wall height and position -----
    mov  ebx, column                        ; EBX = column number
    movzx eax, colAngle[ebx*2]              ; ray angle (WORD array, scaled index)
    mov  rayAng, eax                        ; keep it for IsStar
    mov  eax, colDist[ebx*4]                ; EAX = distance (DWORD array)
    call GetWallHeight                      ; EAX = real wall height in rows
    mov  edx, SCREEN_H                      ; EDX = 24
    sub  edx, eax                           ; 24 - height (negative for tall walls)
    sar  edx, 1                             ; half above the wall (signed divide by 2)
    mov  wallTop, edx                       ; first wall row
    add  edx, eax                           ; + height
    mov  wallBottom, edx                    ; first floor row

    ; ----- block 2: wall colour, and is it a plain wall? -----
    INVOKE GetColumnColor, ebx              ; EAX = colour for this column's slice
    mov  wallColor, eax                     ; keep it
    mov  plainWall, 0                       ; assume edge, door or key
    cmp  colType[ebx], HIT_WALL             ; normal wall?
    jne  KindDone                           ; no: door or key, keep it solid
    INVOKE IsEdgeColumn, ebx                ; EAX = 1 for an edge column
    cmp  eax, 0                             ; edge?
    jne  KindDone                           ; yes: the edge line stays solid
    mov  plainWall, 1                       ; plain wall: outline rows
KindDone:

    ; ----- block 3: draw the 24 rows -----
    mov  edi, OFFSET frameBuffer            ; EDI = row 0 of the character buffer
    add  edi, ebx                           ; move to this column
    mov  esi, ebx                           ; ESI = column
    shl  esi, 1                             ; column * 2 (each colour is a WORD)
    add  esi, OFFSET attrBuffer             ; ESI = this column in row 0 of the colours
    mov  ecx, 0                             ; ECX = row, start at 0
ColumnRow:
    cmp  ecx, wallTop                       ; above the wall? (signed: wallTop can be < 0)
    jl   PutCeiling                         ; yes: sky
    cmp  ecx, wallBottom                    ; still inside the wall? (signed)
    jl   PutWall                            ; yes: wall
    mov  BYTE PTR [edi], WALL_CHAR          ; otherwise floor: solid block
    call GetFloorColor                      ; EAX = floor colour for row ECX
    mov  [esi], ax                          ; store the colour
    jmp  NextRow                            ; done with this row
PutCeiling:
    mov  BYTE PTR [edi], ' '                ; assume empty dark sky
    mov  WORD PTR [esi], DEFAULT_ATTR       ; normal colour
    INVOKE IsStar, rayAng                   ; EAX = 1 if a star belongs here
    cmp  eax, 0                             ; no star?
    je   NextRow                            ; then the row is done
    mov  BYTE PTR [edi], STAR_CHAR          ; star character
    mov  WORD PTR [esi], STAR_ATTR          ; dim star colour
    jmp  NextRow                            ; done with this row
PutWall:
    mov  BYTE PTR [edi], WALL_CHAR          ; solid block
    mov  eax, wallColor                     ; AX = slice colour
    cmp  plainWall, 0                       ; edge, door or key?
    je   StoreWall                          ; yes: one solid colour
    cmp  ecx, wallTop                       ; first row of the slice?
    je   PutOutline                         ; yes: outline
    mov  edx, wallBottom                    ; EDX = first floor row
    dec  edx                                ; EDX = last wall row
    cmp  ecx, edx                           ; last row of the slice?
    je   PutOutline                         ; yes: outline
    jmp  StoreWall                          ; inside the slice: wall colour
PutOutline:
    mov  eax, OUTLINE_ATTR                  ; dark outline against sky and floor
StoreWall:
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
; GetColumnColor
; Purpose:   Colour of one column's wall slice:
;            edge column -> edge colour (black outline),
;            exit door   -> blinking red-orange / yellow-orange,
;            key         -> blinking gold / white,
;            wall        -> shade for distance and side.
; Receives:  column = screen x (0..79), uses the column arrays
; Returns:   EAX = colour role
; Registers: EAX (EBX saved by USES)
;-------------------------------------------------------------
GetColumnColor PROC USES ebx, column:DWORD
    INVOKE IsEdgeColumn, column             ; EAX = 1 at an edge between walls
    cmp  eax, 0                             ; edge?
    je   NotEdge                            ; no
    mov  eax, EDGE_ATTR                     ; yes: dark outline line
    ret                                     ; back to caller
NotEdge:
    mov  ebx, column                        ; EBX = column
    cmp  colType[ebx], HIT_EXIT             ; did the ray hit the exit door?
    je   DoorColor                          ; yes
    cmp  colType[ebx], HIT_KEY              ; did it hit a key?
    je   KeyColor                           ; yes
    movzx eax, hitSideCol[ebx]              ; EAX = side (0 or 1)
    INVOKE GetWallLevel, colDist[ebx*4], eax ; EAX = shade level 0..3
    movzx eax, wallColors[eax]              ; EAX = wall colour for that level
    ret                                     ; back to caller
DoorColor:
    mov  eax, DOOR_COLOR_A                  ; door colour 1 (red-orange)
    cmp  blinkOn, 0                         ; first half of the blink?
    je   ColorDone                          ; yes: keep colour 1
    mov  eax, DOOR_COLOR_B                  ; no: door colour 2 (yellow-orange)
    ret                                     ; back to caller
KeyColor:
    mov  eax, KEY_COLOR_A                   ; key colour 1 (gold)
    cmp  blinkOn, 0                         ; first half of the blink?
    je   ColorDone                          ; yes: keep colour 1
    mov  eax, KEY_COLOR_B                   ; no: key colour 2 (white)
ColorDone:
    ret                                     ; back to caller
GetColumnColor ENDP

;-------------------------------------------------------------
; UpdateBlink
; Purpose:   Set blinkOn from the clock: (ms / 500) AND 1, so it
;            is 0 for 500 ms, then 1 for 500 ms, and so on.
; Receives:  nothing
; Returns:   blinkOn = 0 or 1
; Registers: none (EAX, ECX, EDX saved by USES)
;-------------------------------------------------------------
UpdateBlink PROC USES eax ecx edx
    call GetMseconds                        ; EAX = milliseconds since midnight
    mov  edx, 0                             ; clear EDX before DIV
    mov  ecx, BLINK_MS                      ; divide by 500
    div  ecx                                ; EAX = number of half seconds
    and  eax, 1                             ; keep only the lowest bit: 0 or 1
    mov  blinkOn, eax                       ; save the blink phase
    ret                                     ; back to caller
UpdateBlink ENDP

;-------------------------------------------------------------
; IsStar
; Purpose:   Decide if a ceiling cell shows a star. Stars are
;            tied to the ray angle, so they move with the view:
;            star if (rayAngle*7 + row*13) mod 37 = 0.
; Receives:  rayAngle = ray angle (0..359), ECX = row (0..23)
; Returns:   EAX = 1 for a star, 0 for empty sky
; Registers: EAX (EBX, EDX saved by USES)
;-------------------------------------------------------------
IsStar PROC USES ebx edx, rayAngle:DWORD
    mov  eax, rayAngle                      ; EAX = ray angle
    imul eax, 7                             ; EAX = rayAngle * 7
    mov  ebx, ecx                           ; EBX = row
    imul ebx, 13                            ; EBX = row * 13
    add  eax, ebx                           ; EAX = rayAngle*7 + row*13 (always positive)
    mov  edx, 0                             ; clear EDX before DIV
    mov  ebx, STAR_MOD                      ; divide by 37
    div  ebx                                ; EDX = remainder (mod 37)
    mov  eax, 0                             ; assume no star
    cmp  edx, 0                             ; remainder 0?
    jne  StarDone                           ; no: empty sky
    mov  eax, 1                             ; yes: a star
StarDone:
    ret                                     ; back to caller
IsStar ENDP

;-------------------------------------------------------------
; CastAllRays
; Purpose:   Pass 1 of the 3D view: cast one ray per screen
;            column and store the results in the column arrays
;            (colAngle, colDist, hitSideCol, colType,
;            hitCellCol, colWallX).
;            rayAngle = angle - FOV/2 + x*FOV/SCREEN_W
; Receives:  nothing (uses angle, posX, posY)
; Returns:   column arrays filled
; Registers: none (EAX, EBX, ECX, EDX saved by USES)
;-------------------------------------------------------------
CastAllRays PROC USES eax ebx ecx edx
    mov  ebx, 0                             ; EBX = column x, start at 0
CastColumn:
    mov  eax, ebx                           ; EAX = x
    imul eax, FOV                           ; EAX = x * 60
    mov  edx, 0                             ; clear EDX before DIV (x*60 is positive)
    mov  ecx, SCREEN_W                      ; divide by 80
    div  ecx                                ; EAX = x * 60 / 80 (0..59 degrees)
    add  eax, angle                         ; + player angle
    sub  eax, FOV / 2                       ; - 30: start at the left edge of the view
    call WrapAngle                          ; keep it 0..359
    mov  colAngle[ebx*2], ax                ; store the ray angle (WORD, scaled index)
    INVOKE CastRay, eax                     ; EAX = distance, EDX = hitSide, ECX = hit type
    mov  colDist[ebx*4], eax                ; store the distance (DWORD, scaled index)
    mov  hitSideCol[ebx], dl                ; store the side
    mov  colType[ebx], cl                   ; store what was hit
    mov  eax, rayCell                       ; EAX = map cell number of the hit
    mov  hitCellCol[ebx], al                ; store it
    mov  eax, rayWallX                      ; EAX = where along the wall (0..255)
    mov  colWallX[ebx], al                  ; store it
    inc  ebx                                ; next column
    cmp  ebx, SCREEN_W                      ; all 80 columns done?
    jb   CastColumn                         ; no: next column
    ret                                     ; back to caller
CastAllRays ENDP

;-------------------------------------------------------------
; IsEdgeColumn
; Purpose:   Decide if a column is an edge between walls:
;            - it hit a different map cell than the column to
;              its left, or a different side of the cell, or
;            - the ray hit close to a cell corner
;              (wallX < 20 or wallX > 236).
; Receives:  column = screen x (0..79), uses the column arrays
; Returns:   EAX = 1 for an edge, 0 if not
; Registers: EAX (EBX, ESI saved by USES)
;-------------------------------------------------------------
IsEdgeColumn PROC USES ebx esi, column:DWORD
    mov  ebx, column                        ; EBX = column
    movzx eax, colWallX[ebx]                ; EAX = wallX of this column
    cmp  eax, EDGE_LOW                      ; close to the cell's start?
    jb   EdgeYes                            ; yes: corner line
    cmp  eax, EDGE_HIGH                     ; close to the cell's end?
    ja   EdgeYes                            ; yes: corner line
    cmp  ebx, 0                             ; first column has no left neighbour
    je   EdgeNo                             ; so it is not an edge
    mov  esi, OFFSET hitCellCol             ; ESI = base of the cell array
    mov  al, [esi + ebx]                    ; AL = this column's cell (base-index)
    cmp  al, [esi + ebx - 1]                ; same cell as the column to the left?
    jne  EdgeYes                            ; no: a new wall starts here
    mov  esi, OFFSET hitSideCol             ; ESI = base of the side array
    mov  al, [esi + ebx]                    ; AL = this column's side
    cmp  al, [esi + ebx - 1]                ; same side as the column to the left?
    jne  EdgeYes                            ; no: a corner of the block
EdgeNo:
    mov  eax, 0                             ; not an edge
    ret                                     ; back to caller
EdgeYes:
    mov  eax, 1                             ; edge
    ret                                     ; back to caller
IsEdgeColumn ENDP

;-------------------------------------------------------------
; RenderView
; Purpose:   Draw the 3D view in two passes: cast all 80 rays
;            first (so each column can look at its neighbour
;            for edges), then draw the 80 columns.
; Receives:  nothing (uses angle, posX, posY)
; Returns:   nothing (frameBuffer, attrBuffer filled)
; Registers: none (EBX saved by USES)
;-------------------------------------------------------------
RenderView PROC USES ebx
    call CastAllRays                        ; pass 1: fill the column arrays
    mov  ebx, 0                             ; EBX = column x
DrawNext:
    INVOKE DrawColumn, ebx                  ; pass 2: draw this column
    inc  ebx                                ; next column
    cmp  ebx, SCREEN_W                      ; all 80 columns done?
    jb   DrawNext                           ; no: next column
    ret                                     ; back to caller
RenderView ENDP

;-------------------------------------------------------------
; ResetGame
; Purpose:   Get ready for a new game: fresh copy of the map
;            (keys back in place), player back at the start,
;            steps and keys 0, flags cleared, timer started.
; Receives:  nothing
; Returns:   gameMap, posX, posY, angle, steps, keys, quitFlag,
;            wonFlag, msgText, startTime set
; Registers: none (EAX, ECX, ESI, EDI saved by USES)
;-------------------------------------------------------------
ResetGame PROC USES eax ecx esi edi
    cld                                     ; copy forwards
    mov  esi, OFFSET originalMap            ; ESI = the untouched map
    mov  edi, OFFSET gameMap                ; EDI = the map the game plays on
    mov  ecx, MAP_W * MAP_H                 ; ECX = 256 bytes
    rep  movsb                              ; copy [ESI] -> [EDI], 256 times
    mov  posX, START_X                      ; back to the start cell (X)
    mov  posY, START_Y                      ; back to the start cell (Y)
    mov  angle, START_ANGLE                 ; face east again
    mov  steps, 0                           ; no steps yet
    mov  quitFlag, 0                        ; not quitting
    mov  wonFlag, 0                         ; not won yet
    mov  keys, 0                            ; no keys yet
    mov  msgText, 0                         ; no HUD message
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
    INVOKE MsSince, startTime               ; EAX = milliseconds since the start
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
;            The timer is white (danger red under 20 s),
;            "KEYS n/3" is gold, labels keep the normal gray.
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
    mov  ecx, edi                           ; ECX = HUD row start
    add  ecx, HUD_KEY_POS                   ; ECX = where the key count goes
    INVOKE PutNumber, ecx, keys, 1          ; write the key count (1 digit)
    call DrawMessage                        ; "KEY FOUND" / "DOOR LOCKED" over the controls
    call GetRemainingSec                    ; EAX = seconds left
    mov  edx, TIMER_ATTR                    ; assume plenty of time: bright white
    cmp  eax, LOW_TIME                      ; under 20 seconds left?
    jae  HaveTimerColor                     ; no: keep white
    mov  edx, TIMER_LOW_ATTR                ; yes: danger red warning
HaveTimerColor:
    mov  eax, edx                           ; AX = timer colour
    mov  edi, OFFSET attrBuffer + HUD_ROW * SCREEN_W * 2 ; EDI = colours of the HUD row
    mov  ecx, HUD_TIME_LEN                  ; ECX = "TIME mm:ss" = 10 cells
    rep  stosw                              ; colour the timer (labels stay light gray)
    mov  eax, KEYS_ATTR                     ; AX = gold
    mov  edi, OFFSET attrBuffer + (HUD_ROW * SCREEN_W + HUD_KEYS_COL) * 2 ; EDI = "KEYS n/3" colours
    mov  ecx, HUD_KEYS_LEN                  ; ECX = 8 cells
    rep  stosw                              ; colour "KEYS n/3"
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
; Purpose:   Clear the screen and show a gold block-letter
;            "ESCAPED!" banner, the time taken (mm:ss), the
;            number of steps and the keys collected. Leaves the cursor where
;            AskPlayAgain should print its question.
; Receives:  nothing (uses timer and steps)
; Returns:   nothing
; Registers: none (EAX, EDX saved by USES)
;-------------------------------------------------------------
WinScreen PROC USES eax edx
    call Clrscr                             ; clear the console
    INVOKE PrintArt, ADDR winArt, ADDR winColors, ART_LINES, BANNER_ROW, WIN_COL ; gold banner
    mov  eax, C_WHITE                       ; white text
    call SetRoleColor                      ; apply the colour
    mov  dh, INFO_ROW                       ; first info line
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET timeMsg                ; "Time taken: "
    call WriteString                        ; print it
    call GetElapsedSec                      ; EAX = seconds used
    call PrintTime                          ; print mm:ss
    mov  dh, INFO_ROW + 1                   ; second info line
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET stepsMsg               ; "Steps: "
    call WriteString                        ; print it
    mov  eax, steps                         ; EAX = step count
    call WriteDec                           ; print it
    mov  dh, INFO_ROW + 2                   ; third info line
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET keysMsg                ; "Keys: "
    call WriteString                        ; print it
    mov  eax, keys                          ; EAX = keys collected
    call WriteDec                           ; print it
    mov  edx, OFFSET keysOf                 ; "/3"
    call WriteString                        ; print it
    mov  dh, ASK_ROW                        ; row for "Play again?"
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; leave the cursor there
    ret                                     ; back to caller
WinScreen ENDP

;-------------------------------------------------------------
; LoseScreen
; Purpose:   Clear the screen and show a danger-red block-letter
;            "TIME UP" banner and the number of steps. Leaves
;            the cursor where AskPlayAgain should print.
; Receives:  nothing (uses steps)
; Returns:   nothing
; Registers: none (EAX, EDX saved by USES)
;-------------------------------------------------------------
LoseScreen PROC USES eax edx
    call Clrscr                             ; clear the console
    INVOKE PrintArt, ADDR loseArt, ADDR loseColors, ART_LINES, BANNER_ROW, LOSE_COL ; red banner
    mov  eax, C_WHITE                       ; white text
    call SetRoleColor                      ; apply the colour
    mov  dh, INFO_ROW                       ; first info line
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET loseText               ; "You did not reach the exit in time."
    call WriteString                        ; print it
    mov  dh, INFO_ROW + 1                   ; second info line
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; move the cursor there
    mov  edx, OFFSET stepsMsg               ; "Steps: "
    call WriteString                        ; print it
    mov  eax, steps                         ; EAX = step count
    call WriteDec                           ; print it
    mov  dh, ASK_ROW                        ; row for "Play again?"
    mov  dl, INFO_COL                       ; info column
    call Gotoxy                             ; leave the cursor there
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
    mov  eax, DEFAULT_ATTR                  ; normal grey text
    call SetRoleColor                      ; apply the colour
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
    call UpdateBlink                        ; blink phase for this frame
    call ClearBuffer                        ; blank frame
    call RenderView                         ; 3D walls into the buffer
    call DrawMinimap                        ; map + player on top (only if switched on)
    call DrawHUD                            ; time, steps, controls on the last row
    call ApplyRoles                         ; roles -> real console colours
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

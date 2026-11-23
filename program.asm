; WOLF-86 - 3D Raycasting Maze Game (EL-2003 COAL Lab, Fall 2026)

INCLUDE Irvine32.inc

VIEW_COLS       = 100
VIEW_ROWS_CELLS = 30
SCREEN_W = VIEW_COLS
SCREEN_H = VIEW_ROWS_CELLS
BUF_H    = SCREEN_H + 1
HUD_ROW  = SCREEN_H
MAP_W    = 16
MAP_H    = 16
FOV      = 66

C_SKY        = 0
C_BRICK_0    = 1
C_BRICK_1    = 2
C_BRICK_2    = 3
C_BRICK_3    = 4
C_OUTLINE    = 5
C_STONE_0    = 6
C_TEXT       = 7
C_STONE_1    = 8
C_STONE_2    = 9
C_STONE_3    = 10
C_FLOOR_NEAR = 11
C_FLOOR_FAR  = 12
C_DOOR_A     = 13
C_GOLD       = 14
C_WHITE      = 15
C_WALL_0     = C_BRICK_0
C_WALL_1     = C_BRICK_1
C_WALL_2     = C_BRICK_2
C_WALL_3     = C_BRICK_3
C_MAP_WALL   = C_BRICK_3
C_DOOR_B     = C_GOLD
C_DANGER     = C_DOOR_A

FIXMUL MACRO dest, src
    imul dest, src
    sar  dest, 8
ENDM

GetAsyncKeyState PROTO, vKey:DWORD
SetConsoleOutputCP PROTO, wCodePageID:DWORD

CSBI_EX STRUCT
  cbSize               DWORD ?
  dwSize               COORD <>
  dwCursorPosition     COORD <>
  wAttributes          WORD ?
  srWindow             SMALL_RECT <>
  dwMaximumWindowSize  COORD <>
  wPopupAttributes     WORD ?
  bFullscreenSupported DWORD ?
  ColorTable           DWORD 16 DUP(?)
CSBI_EX ENDS
GetConsoleScreenBufferInfoEx PROTO, hConsole:DWORD, lpInfo:PTR CSBI_EX
SetConsoleScreenBufferInfoEx PROTO, hConsole:DWORD, lpInfo:PTR CSBI_EX

GetConsoleWindow PROTO
GetWindowLongA   PROTO, hWnd:DWORD, nIndex:SDWORD
SetWindowLongA   PROTO, hWnd:DWORD, nIndex:SDWORD, dwNewLong:DWORD
GWL_STYLE      = -16
GetModuleFileNameA PROTO, hModule:DWORD, lpFilename:PTR BYTE, nSize:DWORD
GetClassNameA    PROTO, hWnd:DWORD, lpClassName:PTR BYTE, nMaxCount:DWORD
WS_MAXIMIZEBOX = 00010000h
WS_SIZEBOX     = 00040000h

GetSin      PROTO
GetCos      PROTO
TitleScreen PROTO
PrintArt    PROTO, artPtr:PTR BYTE, colorPtr:PTR BYTE, lines:DWORD, row:DWORD, col:DWORD
ResetGame   PROTO
GetElapsedSec PROTO
GetRemainingSec PROTO
PutNumber   PROTO, dest:PTR BYTE, value:DWORD, digits:DWORD
DrawHUD     PROTO
PrintTwoDigits PROTO
PrintTime   PROTO
WinScreen   PROTO
LoseScreen  PROTO
AskPlayAgain PROTO
ClearBuffer PROTO
HideCursor  PROTO
SetupWindow PROTO
OpenLog     PROTO
CloseLog    PROTO
LogText     PROTO, textPtr:PTR BYTE
LogNum      PROTO, textPtr:PTR BYTE, value:DWORD
LogCall     PROTO, textPtr:PTR BYTE, retVal:DWORD, errVal:DWORD
LogInfo     PROTO, infoPtr:PTR CSBI_EX
LoadPalette PROTO
RestorePalette PROTO
SetPalette  PROTO, infoPtr:PTR CSBI_EX
TryConhostPalette PROTO
IsPseudoConsole PROTO
SetPaletteVT PROTO
PutHex2     PROTO, dest:PTR BYTE, value:DWORD
SetRoleColor PROTO
ComposeFrame PROTO
WriteConsoleOutputA PROTO, hConsole:DWORD, lpBuffer:PTR DWORD, dwBufferSize:COORD, dwBufferCoord:COORD, lpWriteRegion:PTR SMALL_RECT
GetMoveDelta PROTO
IsWall      PROTO, testX:SDWORD, testY:SDWORD
BoxCheck    PROTO, testX:SDWORD, testY:SDWORD
CenterAssist PROTO
CenterNudge PROTO, axisPos:SDWORD
GetTurnSpeed PROTO
TryMove     PROTO, moveDX:SDWORD, moveDY:SDWORD
HandleCell  PROTO, cellType:DWORD, testX:SDWORD, testY:SDWORD
CollectKey  PROTO, testX:SDWORD, testY:SDWORD
TouchExit   PROTO
ShowMessage PROTO, msgPtr:PTR BYTE, msgAttr:DWORD
MsSince     PROTO, since:DWORD
DrawMessage PROTO
InitInput   PROTO
KeyDown     PROTO, vKey:DWORD
KeyPressed  PROTO, vKey:DWORD, prevPtr:PTR BYTE
GetArrowChar PROTO
WrapAngle   PROTO
UpdateBlink PROTO
AnyKeyDown  PROTO
WaitKeysReleased PROTO
SetupAxis   PROTO, axisPos:SDWORD, axisDir:SDWORD
CastRay     PROTO, rayDirX:SDWORD, rayDirY:SDWORD
GetWallLevel PROTO, distance:DWORD, side:DWORD
GetFloorPixel PROTO, column:DWORD
GetWallHeight PROTO
DrawPixelColumn PROTO, column:DWORD
GetColumnKind PROTO, column:DWORD
GetWallPixel PROTO, kind:DWORD, level:DWORD, wallX:DWORD, texRow:DWORD, lineH:DWORD
CastAllRays PROTO
IsEdgeColumn PROTO, column:DWORD
IsStar      PROTO, rayAngle:DWORD
RenderView  PROTO
TurnPlayer  PROTO, turnAmount:SDWORD
HandleInput PROTO
DrawMinimap PROTO
DrawMapBorder PROTO
GetMapLook  PROTO
PutCell     PROTO, row:DWORD, col:DWORD, cellChar:DWORD, cellAttr:DWORD
GameLoop    PROTO

MOVE_SPEED = 32
PLAYER_R   = 80
CELL_SIZE  = 256
NUDGE_MAX  = 4
TURN_RAMP_LEN = 10

BIG_DIST   = 1000000
KEY_WAIT_TRIES = 200
CODE_PAGE_437  = 437
PIX_W          = VIEW_COLS
MIN_WALL_DIST  = 64
CONTACT_ROWS   = 2
FLOOR_SHADOW   = 2
SHADOW_ATTR    = C_FLOOR_FAR
PIX_H          = VIEW_ROWS_CELLS * 2
HORIZON        = PIX_H / 2
HALF_BLOCK     = 223
FLOOR_BANDS    = 5
KIND_EDGE      = 0
KIND_DOOR      = 1
KIND_KEY       = 2
KIND_BRICK     = 3
KIND_STONE     = 4
WALL_CHAR      = 219
STAR_CHAR      = '.'
STAR_ATTR      = C_STONE_3
STAR_MOD       = 61
PLANE_LEN      = 166
TEX_ROWS       = 32
BRICK_ROW_H    = 8
BRICK_W        = 64
BRICK_SHIFT    = 32
JOINT_W        = 6
STONE_ROW_H    = 16
STONE_W        = 128
STONE_SHIFT    = 64
SEAM_W         = 4

ART_LINES   = 5
BOX_LINES   = 10
TITLE_TOP   = (BUF_H - 22) / 2
LOGO_ROW    = TITLE_TOP
LOGO_COL    = (SCREEN_W - 41) / 2
SUB_ROW     = TITLE_TOP + 6
SUB_COL     = (SCREEN_W - 41) / 2
BOX_ROW     = TITLE_TOP + 8
BOX_COL     = (SCREEN_W - 46) / 2
PRESS_ROW   = TITLE_TOP + 20
PRESS_COL   = (SCREEN_W - 13) / 2
TITLE_DELAY = 50
BANNER_ROW  = TITLE_TOP + 2
WIN_COL     = (SCREEN_W - 47) / 2
LOSE_COL    = (SCREEN_W - 41) / 2
INFO_ROW    = BANNER_ROW + 7
INFO_COL    = LOSE_COL
ASK_ROW     = INFO_ROW + 4

MAP_BOX       = MAP_H + 1
BOX_TL        = 218
BOX_TR        = 191
BOX_BL        = 192
BOX_BR        = 217
BOX_H         = 196
BOX_V         = 179
BORDER_ATTR   = C_MAP_WALL
MAP_WALL_ATTR = C_MAP_WALL
MAP_STONE_ATTR = C_STONE_2
MAP_EXIT_ATTR = C_DOOR_A
MAP_KEY_ATTR  = C_GOLD
PLAYER_ATTR   = C_GOLD
DOOR_COLOR_A   = C_DOOR_A
DOOR_COLOR_B   = C_DOOR_B
KEY_COLOR_A    = C_GOLD
EDGE_ATTR      = C_SKY
OUTLINE_ATTR   = C_OUTLINE
KEY_COLOR_B    = C_WHITE
HIT_WALL       = 0
HIT_EXIT       = 1
HIT_KEY        = 2
DEFAULT_ATTR   = C_TEXT

CELL_FREE = 0
CELL_WALL = 1
CELL_EXIT = 2
CELL_KEY  = 3
KEYS_NEEDED   = 3
MSG_MS        = 2000
KEY_MSG_DIGIT = 11
KEY_MSG_ATTR  = C_DOOR_B
LOCKED_ATTR   = C_DOOR_B

START_X     = 384
START_Y     = 384
START_ANGLE = 0
RESULT_QUIT = 0
RESULT_WIN  = 1
RESULT_LOSE = 2
MS_PER_DAY  = 86400000
BLINK_MS    = 500
TIME_LIMIT  = 180

HUD_MIN_POS  = 5
HUD_SEC_POS  = 8
HUD_STEP_POS = 18
HUD_KEY_POS  = 30
HUD_MSG_POS  = 35
HUD_TIME_LEN = 10
LOW_TIME     = 20
TIMER_ATTR     = C_WHITE
TIMER_LOW_ATTR = C_DANGER
KEYS_ATTR      = C_GOLD
HUD_KEYS_COL   = 25
HUD_KEYS_LEN   = 8

RGB_SKY        = 001A0E0Ah
RGB_BRICK_0    = 00FFC6A9h
RGB_BRICK_1    = 00F09C7Ch
RGB_BRICK_2    = 00D0725Ah
RGB_BRICK_3    = 00A85444h
RGB_OUTLINE    = 00451F1Ah
RGB_STONE_0    = 00B88F8Ah
RGB_STONE_1    = 009C736Fh
RGB_STONE_2    = 00805A56h
RGB_STONE_3    = 0066423Eh
RGB_FLOOR_NEAR = 0044342Eh
RGB_FLOOR_FAR  = 001E1714h
RGB_DOOR_A     = 002B6AFFh
RGB_GOLD       = 004AC9FFh
PAL_KEEP_TEXT  = 7
PAL_KEEP_WHITE = 15
PAL_SLOTS      = 16
PAL_TRIES      = 2
PAL_MODE_NONE  = 0
PAL_MODE_CONHOST = 1
PAL_MODE_VT    = 2
VT_PROCESSING  = 0004h
VT_IDX_POS     = 4
VT_RED_POS     = 11
VT_GREEN_POS   = 14
VT_BLUE_POS    = 17
FORCE_FALLBACK = 0
DEBUG_LOG      = 0

.data
themeColors DWORD RGB_SKY, RGB_BRICK_0, RGB_BRICK_1, RGB_BRICK_2
            DWORD RGB_BRICK_3, RGB_OUTLINE, RGB_STONE_0, 0
            DWORD RGB_STONE_1, RGB_STONE_2, RGB_STONE_3, RGB_FLOOR_NEAR
            DWORD RGB_FLOOR_FAR, RGB_DOOR_A, RGB_GOLD, 0
origInfo    CSBI_EX <>
themeInfo   CSBI_EX <>
paletteOK   DWORD 0
paletteMode DWORD PAL_MODE_NONE
origOutMode DWORD 0
classText   BYTE 64 DUP(0)
pseudoName  BYTE "PseudoConsoleWindow", 0
ansiOrder   BYTE 0, 4, 2, 6, 1, 5, 3, 7, 8, 12, 10, 14, 9, 13, 11, 15
hexDigits   BYTE "0123456789abcdef"
vtTemplate  BYTE 27, "]4;00;rgb:00/00/00", 27, 5Ch
VT_LEN = ($ - vtTemplate)
vtBuf       BYTE VT_LEN DUP(0)
vtReset     BYTE 27, "]104", 27, 5Ch
VT_RESET_LEN = ($ - vtReset)
vtWritten   DWORD 0
tinyRect    SMALL_RECT <0, 0, 0, 0>
gameRect    SMALL_RECT <0, 0, SCREEN_W - 1, BUF_H - 1>
gameSize    COORD <SCREEN_W, BUF_H>
windowOK    DWORD 0
checkInfo   CSBI_EX <>

logHandle   DWORD 0
logPath     BYTE 260 DUP(0)
logName     BYTE "wolf_debug.log", 0
logNumText  BYTE "0000000000", 0
logRetText  BYTE " ret=", 0
logErrText  BYTE " err=", 0
logCrLf     BYTE 13, 10, 0
logClass    BYTE 64 DUP(0)
lgStart     BYTE "WOLF-86 startup log", 13, 10, 0
lgClass     BYTE "console window class: ", 0
lgGet       BYTE "GetConsoleScreenBufferInfoEx (start)", 0
lgSizeX     BYTE "  dwSize.X = ", 0
lgSizeY     BYTE "  dwSize.Y = ", 0
lgWinL      BYTE "  srWindow.Left = ", 0
lgWinT      BYTE "  srWindow.Top = ", 0
lgWinR      BYTE "  srWindow.Right = ", 0
lgWinB      BYTE "  srWindow.Bottom = ", 0
lgCol0      BYTE "  ColorTable[0] = ", 0
lgCol1      BYTE "  ColorTable[1] = ", 0
lgCol2      BYTE "  ColorTable[2] = ", 0
lgSetEx     BYTE "SetConsoleScreenBufferInfoEx", 0
lgReadBack  BYTE "GetConsoleScreenBufferInfoEx (read back)", 0
lgMatch     BYTE "palette read back matches theme (1 = yes): ", 0
lgWinTiny   BYTE "SetConsoleWindowInfo (tiny)", 0
lgBufSize   BYTE "SetConsoleScreenBufferSize", 0
lgWinGame   BYTE "SetConsoleWindowInfo (game size)", 0
lgAfter     BYTE "GetConsoleScreenBufferInfoEx (after resize)", 0
lgPalOK     BYTE "paletteOK (1 = custom table, 0 = fallback table): ", 0
lgMode      BYTE "paletteMode (0 none, 1 conhost, 2 VT / Windows Terminal): ", 0
lgWinOK     BYTE "windowOK: ", 0

customRoles   BYTE 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
fallbackRoles BYTE black, lightBlue, lightBlue, blue
              BYTE blue, gray, lightGray, lightGray
              BYTE lightGray, gray, gray, gray
              BYTE black, lightRed, yellow, white
roleColors    BYTE PAL_SLOTS DUP(?)
originalMap BYTE "%%%%%%%%%%%%%%%%"
            BYTE "%......#.......%"
            BYTE "%.##.#.#.%%%%%.%"
            BYTE "%.#..#...%..K%.%"
            BYTE "%.#.####.%.#.%.%"
            BYTE "%...#....%.#...%"
            BYTE "%%%.#.####.###.%"
            BYTE "%...#.#....#...%"
            BYTE "%.###.#.####.#.%"
            BYTE "%.#...#......#.%"
            BYTE "%.#.%%%%%%%.##.%"
            BYTE "%...%.....#..#.%"
            BYTE "%.###.###.##.#.%"
            BYTE "%.....#......#.%"
            BYTE "%K#####K######E%"
            BYTE "%%%%%%%%%%%%%%%%"
gameMap     BYTE MAP_W * MAP_H DUP('#')

posX      DWORD START_X
posY      DWORD START_Y
angle     DWORD START_ANGLE
steps     DWORD 0
keys      DWORD 0
msgText   DWORD 0
msgColor  DWORD 0
msgStart  DWORD 0
startTime DWORD 0

showMinimap BYTE 1
quitFlag    BYTE 0
wonFlag     BYTE 0
mWasDown    BYTE 0
qWasDown    BYTE 0
inputHandle DWORD ?
boxHitX     SDWORD 0
boxHitY     SDWORD 0
turnHold    DWORD 0
turnRamp    BYTE 2, 2, 2, 3, 3, 3, 4, 4, 4, 5
blinkOn     DWORD 0

colAngle    WORD  SCREEN_W DUP(0)
colDist     DWORD SCREEN_W DUP(0)
hitSideCol  BYTE  SCREEN_W DUP(0)
colType     BYTE  SCREEN_W DUP(0)
hitCellCol  BYTE  SCREEN_W DUP(0)
colWallX    BYTE  SCREEN_W DUP(0)
rayCell     DWORD 0
rayWallX    DWORD 0

sinTable SDWORD    0,   4,   9,  13,  18,  22,  27,  31,  36,  40
         SDWORD   44,  49,  53,  58,  62,  66,  71,  75,  79,  83
         SDWORD   88,  92,  96, 100, 104, 108, 112, 116, 120, 124
         SDWORD  128, 132, 136, 139, 143, 147, 150, 154, 158, 161
         SDWORD  165, 168, 171, 175, 178, 181, 184, 187, 190, 193
         SDWORD  196, 199, 202, 204, 207, 210, 212, 215, 217, 219
         SDWORD  222, 224, 226, 228, 230, 232, 234, 236, 237, 239
         SDWORD  241, 242, 243, 245, 246, 247, 248, 249, 250, 251
         SDWORD  252, 253, 254, 254, 255, 255, 255, 256, 256, 256
         SDWORD  256, 256, 256, 256, 255, 255, 255, 254, 254, 253
         SDWORD  252, 251, 250, 249, 248, 247, 246, 245, 243, 242
         SDWORD  241, 239, 237, 236, 234, 232, 230, 228, 226, 224
         SDWORD  222, 219, 217, 215, 212, 210, 207, 204, 202, 199
         SDWORD  196, 193, 190, 187, 184, 181, 178, 175, 171, 168
         SDWORD  165, 161, 158, 154, 150, 147, 143, 139, 136, 132
         SDWORD  128, 124, 120, 116, 112, 108, 104, 100,  96,  92
         SDWORD   88,  83,  79,  75,  71,  66,  62,  58,  53,  49
         SDWORD   44,  40,  36,  31,  27,  22,  18,  13,   9,   4
         SDWORD    0,  -4,  -9, -13, -18, -22, -27, -31, -36, -40
         SDWORD  -44, -49, -53, -58, -62, -66, -71, -75, -79, -83
         SDWORD  -88, -92, -96,-100,-104,-108,-112,-116,-120,-124
         SDWORD -128,-132,-136,-139,-143,-147,-150,-154,-158,-161
         SDWORD -165,-168,-171,-175,-178,-181,-184,-187,-190,-193
         SDWORD -196,-199,-202,-204,-207,-210,-212,-215,-217,-219
         SDWORD -222,-224,-226,-228,-230,-232,-234,-236,-237,-239
         SDWORD -241,-242,-243,-245,-246,-247,-248,-249,-250,-251
         SDWORD -252,-253,-254,-254,-255,-255,-255,-256,-256,-256
         SDWORD -256,-256,-256,-256,-255,-255,-255,-254,-254,-253
         SDWORD -252,-251,-250,-249,-248,-247,-246,-245,-243,-242
         SDWORD -241,-239,-237,-236,-234,-232,-230,-228,-226,-224
         SDWORD -222,-219,-217,-215,-212,-210,-207,-204,-202,-199
         SDWORD -196,-193,-190,-187,-184,-181,-178,-175,-171,-168
         SDWORD -165,-161,-158,-154,-150,-147,-143,-139,-136,-132
         SDWORD -128,-124,-120,-116,-112,-108,-104,-100, -96, -92
         SDWORD  -88, -83, -79, -75, -71, -66, -62, -58, -53, -49
         SDWORD  -44, -40, -36, -31, -27, -22, -18, -13,  -9,  -4

shadeDist1  DWORD 512
shadeDist2  DWORD 1024
shadeDist3  DWORD 2048
brickColors BYTE C_BRICK_0, C_BRICK_1, C_BRICK_2, C_BRICK_3, C_OUTLINE, C_OUTLINE
stoneColors BYTE C_STONE_0, C_STONE_1, C_STONE_2, C_STONE_3, C_OUTLINE, C_OUTLINE

frameBuffer   BYTE SCREEN_W * BUF_H DUP(0)
attrBuffer    WORD SCREEN_W * BUF_H DUP(DEFAULT_ATTR)
pixBuf        BYTE PIX_W * PIX_H DUP(0)
charBuf       DWORD SCREEN_W * BUF_H DUP(0)
writeRect     SMALL_RECT <>
consoleHandle DWORD ?
cursorInfo    CONSOLE_CURSOR_INFO <100, 0>
drawPos       COORD <0, 0>

logoArt BYTE "#   #  ###  #     #####        ###   ### ", 0
        BYTE "#   # #   # #     #           #   # #    ", 0
        BYTE "# # # #   # #     ####   ###   ###  #### ", 0
        BYTE "## ## #   # #     #           #   # #   #", 0
        BYTE "#   #  ###  ##### #            ###   ### ", 0
winArt BYTE "#####  ####  ####  ###  ####  ##### ####    #  ", 0
       BYTE "#     #     #     #   # #   # #     #   #   #  ", 0
       BYTE "####   ###  #     ##### ####  ####  #   #   #  ", 0
       BYTE "#         # #     #   # #     #     #   #      ", 0
       BYTE "##### ####   #### #   # #     ##### ####    #  ", 0
loseArt BYTE "##### ##### #   # #####       #   # #### ", 0
        BYTE "  #     #   ## ## #           #   # #   #", 0
        BYTE "  #     #   # # # ####        #   # #### ", 0
        BYTE "  #     #   #   # #           #   # #    ", 0
        BYTE "  #   ##### #   # #####        ###  #    ", 0
logoColors BYTE C_WALL_0, C_WALL_0, C_WALL_1, C_WALL_2, C_WALL_3
winColors  BYTE 5 DUP(C_GOLD)
loseColors BYTE 5 DUP(C_DANGER)
subText    BYTE "A 3D RAYCASTING MAZE GAME IN x86 ASSEMBLY", 0
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
boxColors  BYTE C_MAP_WALL, 8 DUP(C_WHITE), C_MAP_WALL
pressKey   BYTE "PRESS ANY KEY", 0

hudTemplate BYTE "TIME 00:00  STEPS 00000  KEYS 0/3  W/S move  A/D turn  M map  Q quit"
HUD_LEN = ($ - hudTemplate)
keyMsg     BYTE "KEY FOUND! 0/3", 0
lockedMsg  BYTE "DOOR LOCKED - FIND 3 KEYS", 0

loseText   BYTE "You did not escape in time.", 0
timeMsg    BYTE "Time taken: ", 0
stepsMsg   BYTE "Steps:      ", 0
keysMsg    BYTE "Keys:       ", 0
keysOf     BYTE "/3", 0
againMsg   BYTE "Play again? (Y/N)", 0

.code

; Program entry: setup, title screen, game loop, win/lose, play again
main PROC
    INVOKE SetConsoleOutputCP, CODE_PAGE_437
    INVOKE HideCursor
IF DEBUG_LOG
    INVOKE OpenLog
ENDIF
    INVOKE SetupWindow
    INVOKE LoadPalette
IF DEBUG_LOG
    INVOKE CloseLog
ENDIF
    INVOKE InitInput
    INVOKE TitleScreen
    and    al, 11011111b
    cmp    al, 'Q'
    je     QuitProgram
NewGame:
    INVOKE WaitKeysReleased
    INVOKE ResetGame
    mov    eax, DEFAULT_ATTR
    call   SetRoleColor
    call   Clrscr
    INVOKE GameLoop
    cmp    eax, RESULT_QUIT
    je     QuitProgram
    cmp    eax, RESULT_WIN
    jne    PlayerLost
    INVOKE WinScreen
    jmp    AskAgain
PlayerLost:
    INVOKE LoseScreen
AskAgain:
    INVOKE AskPlayAgain
    cmp    eax, 1
    je     NewGame
QuitProgram:
    mov    eax, DEFAULT_ATTR
    call   SetRoleColor
    INVOKE RestorePalette
    call   Clrscr
    INVOKE ExitProcess, 0
main ENDP

; sin(angle) * 256 from the lookup table
GetSin PROC
    mov  eax, sinTable[eax*4]
    ret
GetSin ENDP

; cos(angle) * 256 using cos(a) = sin(a + 90)
GetCos PROC
    add  eax, 90
    cmp  eax, 360
    jb   AngleOK
    sub  eax, 360
AngleOK:
    call GetSin
    ret
GetCos ENDP

; Title screen: logo, controls box, blinking PRESS ANY KEY
TitleScreen PROC USES edx
    call Clrscr
    INVOKE PrintArt, ADDR logoArt, ADDR logoColors, ART_LINES, LOGO_ROW, LOGO_COL
    mov  eax, C_DOOR_B
    call SetRoleColor
    mov  dh, SUB_ROW
    mov  dl, SUB_COL
    call Gotoxy
    mov  edx, OFFSET subText
    call WriteString
    INVOKE PrintArt, ADDR ctrlBox, ADDR boxColors, BOX_LINES, BOX_ROW, BOX_COL
TitleWait:
    call UpdateBlink
    mov  eax, C_DOOR_B
    cmp  blinkOn, 0
    je   PromptColor
    mov  eax, C_FLOOR_NEAR
PromptColor:
    call SetRoleColor
    mov  dh, PRESS_ROW
    mov  dl, PRESS_COL
    call Gotoxy
    mov  edx, OFFSET pressKey
    call WriteString
    mov  eax, TITLE_DELAY
    call Delay
    call ReadKey
    jz   TitleWait
    movzx eax, al
    push eax
    mov  eax, DEFAULT_ATTR
    call SetRoleColor
    pop  eax
    ret
TitleScreen ENDP

; Print coloured text/block-art lines at (row, col)
PrintArt PROC USES eax ecx edx esi edi, artPtr:PTR BYTE, colorPtr:PTR BYTE, lines:DWORD, row:DWORD, col:DWORD
    mov  esi, artPtr
    mov  edi, colorPtr
    mov  ecx, lines
ArtLine:
    movzx eax, BYTE PTR [edi]
    call SetRoleColor
    inc  edi
    mov  eax, row
    mov  dh, al
    mov  eax, col
    mov  dl, al
    call Gotoxy
ArtChar:
    mov  al, [esi]
    inc  esi
    cmp  al, 0
    je   ArtLineDone
    cmp  al, '#'
    jne  ArtPut
    mov  al, WALL_CHAR
ArtPut:
    call WriteChar
    jmp  ArtChar
ArtLineDone:
    inc  row
    loop ArtLine
    ret
PrintArt ENDP

; Clear the text overlay (frameBuffer, attrBuffer)
ClearBuffer PROC USES eax ecx edi
    cld
    mov  al, 0
    mov  ecx, SCREEN_W * BUF_H
    mov  edi, OFFSET frameBuffer
    rep  stosb
    mov  ax, DEFAULT_ATTR
    mov  ecx, SCREEN_W * BUF_H
    mov  edi, OFFSET attrBuffer
    rep  stosw
    ret
ClearBuffer ENDP

; Get the console handle and hide the cursor
HideCursor PROC USES eax ecx edx
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE
    mov  consoleHandle, eax
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo
    ret
HideCursor ENDP

; Resize the console buffer and window to the game size
SetupWindow PROC USES eax ebx ecx
    INVOKE SetConsoleWindowInfo, consoleHandle, 1, ADDR tinyRect
IF DEBUG_LOG
    mov  ecx, eax
    INVOKE GetLastError
    INVOKE LogCall, ADDR lgWinTiny, ecx, eax
ENDIF
    INVOKE SetConsoleScreenBufferSize, consoleHandle, gameSize
IF DEBUG_LOG
    push eax
    mov  ecx, eax
    INVOKE GetLastError
    INVOKE LogCall, ADDR lgBufSize, ecx, eax
    pop  eax
ENDIF
    cmp  eax, 0
    je   WindowDone
    INVOKE SetConsoleWindowInfo, consoleHandle, 1, ADDR gameRect
IF DEBUG_LOG
    push eax
    mov  ecx, eax
    INVOKE GetLastError
    INVOKE LogCall, ADDR lgWinGame, ecx, eax
    pop  eax
ENDIF
    cmp  eax, 0
    je   WindowDone
    mov  windowOK, 1
    INVOKE GetConsoleWindow
    cmp  eax, 0
    je   WindowDone
    mov  ebx, eax
    INVOKE GetWindowLongA, ebx, GWL_STYLE
    and  eax, NOT (WS_MAXIMIZEBOX OR WS_SIZEBOX)
    INVOKE SetWindowLongA, ebx, GWL_STYLE, eax
WindowDone:
IF DEBUG_LOG
    mov  checkInfo.cbSize, SIZEOF CSBI_EX
    INVOKE GetConsoleScreenBufferInfoEx, consoleHandle, ADDR checkInfo
    mov  ecx, eax
    INVOKE GetLastError
    INVOKE LogCall, ADDR lgAfter, ecx, eax
    INVOKE LogInfo, ADDR checkInfo
    INVOKE LogNum, ADDR lgWinOK, windowOK
ENDIF
    ret
SetupWindow ENDP

IF DEBUG_LOG

; Debug: create wolf_debug.log
OpenLog PROC USES eax ecx edx edi
    INVOKE GetModuleFileNameA, 0, ADDR logPath, 200
    mov  edi, OFFSET logPath
    add  edi, eax
FindSlash:
    cmp  edi, OFFSET logPath
    je   PathReady
    dec  edi
    cmp  BYTE PTR [edi], '\'
    jne  FindSlash
    inc  edi
PathReady:
    INVOKE Str_copy, ADDR logName, edi
    mov  edx, OFFSET logPath
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   OpenDone
    mov  logHandle, eax
    INVOKE LogText, ADDR lgStart
    INVOKE GetConsoleWindow
    INVOKE GetClassNameA, eax, ADDR logClass, 63
    INVOKE LogText, ADDR lgClass
    INVOKE LogText, ADDR logClass
    INVOKE LogText, ADDR logCrLf
OpenDone:
    ret
OpenLog ENDP

; Debug: close the log file
CloseLog PROC USES eax
    mov  eax, logHandle
    cmp  eax, 0
    je   CloseDone
    call CloseFile
    mov  logHandle, 0
CloseDone:
    ret
CloseLog ENDP

; Debug: write a text to the log
LogText PROC USES eax ecx edx, textPtr:PTR BYTE
    cmp  logHandle, 0
    je   TextDone
    INVOKE Str_length, textPtr
    mov  ecx, eax
    mov  edx, textPtr
    mov  eax, logHandle
    call WriteToFile
TextDone:
    ret
LogText ENDP

; Debug: write a label and a number to the log
LogNum PROC, textPtr:PTR BYTE, value:DWORD
    INVOKE LogText, textPtr
    INVOKE PutNumber, ADDR logNumText, value, 10
    INVOKE LogText, ADDR logNumText
    INVOKE LogText, ADDR logCrLf
    ret
LogNum ENDP

; Debug: write a call's return value and error code
LogCall PROC, textPtr:PTR BYTE, retVal:DWORD, errVal:DWORD
    INVOKE LogText, textPtr
    INVOKE LogText, ADDR logRetText
    INVOKE PutNumber, ADDR logNumText, retVal, 10
    INVOKE LogText, ADDR logNumText
    INVOKE LogNum, ADDR logErrText, errVal
    ret
LogCall ENDP

; Debug: write console size, window and colours
LogInfo PROC USES eax ebx, infoPtr:PTR CSBI_EX
    mov  ebx, infoPtr
    movzx eax, (CSBI_EX PTR [ebx]).dwSize.X
    INVOKE LogNum, ADDR lgSizeX, eax
    movzx eax, (CSBI_EX PTR [ebx]).dwSize.Y
    INVOKE LogNum, ADDR lgSizeY, eax
    movzx eax, (CSBI_EX PTR [ebx]).srWindow.Left
    INVOKE LogNum, ADDR lgWinL, eax
    movzx eax, (CSBI_EX PTR [ebx]).srWindow.Top
    INVOKE LogNum, ADDR lgWinT, eax
    movzx eax, (CSBI_EX PTR [ebx]).srWindow.Right
    INVOKE LogNum, ADDR lgWinR, eax
    movzx eax, (CSBI_EX PTR [ebx]).srWindow.Bottom
    INVOKE LogNum, ADDR lgWinB, eax
    INVOKE LogNum, ADDR lgCol0, (CSBI_EX PTR [ebx]).ColorTable[0]
    INVOKE LogNum, ADDR lgCol1, (CSBI_EX PTR [ebx]).ColorTable[4]
    INVOKE LogNum, ADDR lgCol2, (CSBI_EX PTR [ebx]).ColorTable[8]
    ret
LogInfo ENDP
ENDIF

; Install the blue/orange colour theme (or use the fallback colours)
LoadPalette PROC USES eax ecx esi edi
IF FORCE_FALLBACK
    jmp  PaletteDone
ENDIF
    call IsPseudoConsole
    cmp  eax, 0
    je   ConhostPalette
    call SetPaletteVT
    cmp  eax, 0
    je   PaletteDone
    mov  paletteMode, PAL_MODE_VT
    mov  paletteOK, 1
    jmp  PaletteDone
ConhostPalette:
    mov  origInfo.cbSize, SIZEOF CSBI_EX
    INVOKE GetConsoleScreenBufferInfoEx, consoleHandle, ADDR origInfo
    cmp  eax, 0
    je   PaletteDone
    mov  ecx, PAL_TRIES
TryLoop:
    call TryConhostPalette
    cmp  eax, 0
    jne  ConhostOK
    loop TryLoop
    jmp  PaletteDone
ConhostOK:
    mov  paletteMode, PAL_MODE_CONHOST
    mov  paletteOK, 1
PaletteDone:
    INVOKE SetConsoleCursorInfo, consoleHandle, ADDR cursorInfo
    mov  esi, OFFSET customRoles
    cmp  paletteOK, 0
    jne  HaveRoles
    mov  esi, OFFSET fallbackRoles
HaveRoles:
    cld
    mov  edi, OFFSET roleColors
    mov  ecx, PAL_SLOTS
    rep  movsb
IF DEBUG_LOG
    INVOKE LogNum, ADDR lgMode, paletteMode
    INVOKE LogNum, ADDR lgPalOK, paletteOK
ENDIF
    ret
LoadPalette ENDP

; Set the theme in the classic console and verify it
TryConhostPalette PROC USES ecx esi edi
    mov  themeInfo.cbSize, SIZEOF CSBI_EX
    INVOKE GetConsoleScreenBufferInfoEx, consoleHandle, ADDR themeInfo
    cmp  eax, 0
    je   TryFail
    mov  ecx, 0
SlotLoop:
    cmp  ecx, PAL_KEEP_TEXT
    je   NextSlot
    cmp  ecx, PAL_KEEP_WHITE
    je   NextSlot
    mov  eax, themeColors[ecx*4]
    mov  themeInfo.ColorTable[ecx*4], eax
NextSlot:
    inc  ecx
    cmp  ecx, PAL_SLOTS
    jb   SlotLoop
    INVOKE SetPalette, ADDR themeInfo
    cmp  eax, 0
    je   TryFail
    mov  checkInfo.cbSize, SIZEOF CSBI_EX
    INVOKE GetConsoleScreenBufferInfoEx, consoleHandle, ADDR checkInfo
    cmp  eax, 0
    je   TryFail
    cld
    mov  esi, OFFSET themeInfo.ColorTable
    mov  edi, OFFSET checkInfo.ColorTable
    mov  ecx, PAL_SLOTS
    repe cmpsd
    jne  TryFail
    mov  eax, 1
    ret
TryFail:
    mov  eax, 0
    ret
TryConhostPalette ENDP

; Check if the game runs in Windows Terminal
IsPseudoConsole PROC USES ecx edx
    mov  classText, 0
    INVOKE GetConsoleWindow
    INVOKE GetClassNameA, eax, ADDR classText, 63
    INVOKE Str_compare, ADDR classText, ADDR pseudoName
    mov  eax, 0
    jne  PseudoDone
    mov  eax, 1
PseudoDone:
    ret
IsPseudoConsole ENDP

; Set the theme colours in Windows Terminal (VT codes)
SetPaletteVT PROC USES ebx ecx edx esi edi
    INVOKE GetConsoleMode, consoleHandle, ADDR origOutMode
    mov  eax, origOutMode
    or   eax, VT_PROCESSING
    INVOKE SetConsoleMode, consoleHandle, eax
    cmp  eax, 0
    je   VTFail
    mov  ebx, 0
VTSlot:
    cmp  ebx, PAL_KEEP_TEXT
    je   VTNext
    cmp  ebx, PAL_KEEP_WHITE
    je   VTNext
    cld
    mov  esi, OFFSET vtTemplate
    mov  edi, OFFSET vtBuf
    mov  ecx, VT_LEN
    rep  movsb
    movzx eax, ansiOrder[ebx]
    INVOKE PutNumber, ADDR vtBuf + VT_IDX_POS, eax, 2
    mov  edx, themeColors[ebx*4]
    movzx eax, dl
    INVOKE PutHex2, ADDR vtBuf + VT_RED_POS, eax
    movzx eax, dh
    INVOKE PutHex2, ADDR vtBuf + VT_GREEN_POS, eax
    shr  edx, 16
    movzx eax, dl
    INVOKE PutHex2, ADDR vtBuf + VT_BLUE_POS, eax
    INVOKE WriteConsoleA, consoleHandle, ADDR vtBuf, VT_LEN, ADDR vtWritten, 0
VTNext:
    inc  ebx
    cmp  ebx, PAL_SLOTS
    jb   VTSlot
    mov  eax, 1
    ret
VTFail:
    mov  eax, 0
    ret
SetPaletteVT ENDP

; Write a byte as two hex digits
PutHex2 PROC USES eax edi, dest:PTR BYTE, value:DWORD
    mov  edi, dest
    mov  eax, value
    shr  eax, 4
    and  eax, 0Fh
    mov  al, hexDigits[eax]
    mov  [edi], al
    mov  eax, value
    and  eax, 0Fh
    mov  al, hexDigits[eax]
    mov  [edi + 1], al
    ret
PutHex2 ENDP

; Set the text colour for a colour role
SetRoleColor PROC USES eax ebx
    and  eax, 0Fh
    mov  ebx, OFFSET roleColors
    xlat
    call SetTextColor
    ret
SetRoleColor ENDP

; Put the original console colours back
RestorePalette PROC USES eax ecx edx
    cmp  paletteMode, PAL_MODE_CONHOST
    jne  RestoreVT
    INVOKE SetPalette, ADDR origInfo
    jmp  RestoreDone
RestoreVT:
    cmp  paletteMode, PAL_MODE_VT
    jne  RestoreDone
    INVOKE WriteConsoleA, consoleHandle, ADDR vtReset, VT_RESET_LEN, ADDR vtWritten, 0
    INVOKE SetConsoleMode, consoleHandle, origOutMode
RestoreDone:
    ret
RestorePalette ENDP

; Apply a palette with SetConsoleScreenBufferInfoEx
SetPalette PROC USES ebx, infoPtr:PTR CSBI_EX
    mov  ebx, infoPtr
    inc  (CSBI_EX PTR [ebx]).srWindow.Right
    inc  (CSBI_EX PTR [ebx]).srWindow.Bottom
    INVOKE SetConsoleScreenBufferInfoEx, consoleHandle, ebx
IF DEBUG_LOG
    push eax
    push ecx
    mov  ecx, eax
    INVOKE GetLastError
    INVOKE LogCall, ADDR lgSetEx, ecx, eax
    pop  ecx
    pop  eax
ENDIF
    dec  (CSBI_EX PTR [ebx]).srWindow.Right
    dec  (CSBI_EX PTR [ebx]).srWindow.Bottom
    cmp  eax, 0
    je   SetDone
    mov  eax, 1
SetDone:
    ret
SetPalette ENDP

; Pack pixels + text into CHAR_INFO cells and draw the frame in one call
ComposeFrame PROC USES eax ebx ecx edx esi edi
    LOCAL row:DWORD
    mov  ebx, OFFSET roleColors
    mov  edi, OFFSET charBuf
    mov  esi, 0
    mov  row, 0
ComposeRow:
    mov  ecx, 0
ComposeCell:
    movzx eax, frameBuffer[esi]
    cmp  eax, 0
    jne  TextCell
    cmp  row, SCREEN_H
    jae  BlankCell
    mov  edx, row
    shl  edx, 1
    imul edx, PIX_W
    add  edx, ecx
    mov  al, pixBuf[edx + PIX_W]
    xlat
    shl  eax, 4
    push eax
    mov  al, pixBuf[edx]
    xlat
    and  eax, 0Fh
    pop  edx
    or   eax, edx
    shl  eax, 16
    mov  ax, HALF_BLOCK
    jmp  StoreCell
BlankCell:
    mov  eax, ' '
TextCell:
    mov  edx, eax
    mov  ax, attrBuffer[esi*2]
    and  eax, 0Fh
    xlat
    shl  eax, 16
    mov  ax, dx
StoreCell:
    mov  [edi], eax
    add  edi, 4
    inc  esi
    inc  ecx
    cmp  ecx, SCREEN_W
    jb   ComposeCell
    inc  row
    cmp  row, BUF_H
    jb   ComposeRow
    mov  writeRect.Left, 0
    mov  writeRect.Top, 0
    mov  writeRect.Right, SCREEN_W - 1
    mov  writeRect.Bottom, BUF_H - 1
    INVOKE WriteConsoleOutputA, consoleHandle, ADDR charBuf, gameSize, drawPos, ADDR writeRect
    ret
ComposeFrame ENDP

; One forward step in X and Y for the current angle
GetMoveDelta PROC
    mov  eax, angle
    call GetCos
    FIXMUL eax, MOVE_SPEED
    push eax
    mov  eax, angle
    call GetSin
    FIXMUL eax, MOVE_SPEED
    mov  edx, eax
    pop  eax
    ret
GetMoveDelta ENDP

; What kind of cell is at a position (free / wall / exit / key)
IsWall PROC USES ebx esi, testX:SDWORD, testY:SDWORD
    mov  eax, testY
    sar  eax, 8
    cmp  eax, MAP_H - 1
    ja   OutsideMap
    shl  eax, 4
    mov  ebx, testX
    sar  ebx, 8
    cmp  ebx, MAP_W - 1
    ja   OutsideMap
    add  eax, ebx
    mov  esi, OFFSET gameMap
    mov  bl, [esi + eax]
    mov  eax, CELL_WALL
    cmp  bl, '#'
    je   WallDone
    cmp  bl, '%'
    je   WallDone
    mov  eax, CELL_EXIT
    cmp  bl, 'E'
    je   WallDone
    mov  eax, CELL_KEY
    cmp  bl, 'K'
    je   WallDone
    mov  eax, CELL_FREE
    jmp  WallDone
OutsideMap:
    mov  eax, CELL_WALL
WallDone:
    ret
IsWall ENDP

; Test the 4 corners of the player's collision box
BoxCheck PROC USES ebx ecx edx esi edi, testX:SDWORD, testY:SDWORD
    mov  ebx, CELL_FREE
    mov  esi, -PLAYER_R
BoxX:
    mov  edi, -PLAYER_R
BoxY:
    mov  ecx, testX
    add  ecx, esi
    mov  edx, testY
    add  edx, edi
    INVOKE IsWall, ecx, edx
    cmp  eax, CELL_FREE
    je   NextCorner
    cmp  ebx, CELL_FREE
    je   TakeCorner
    cmp  eax, CELL_WALL
    je   NextCorner
TakeCorner:
    mov  ebx, eax
    mov  boxHitX, ecx
    mov  boxHitY, edx
NextCorner:
    add  edi, PLAYER_R * 2
    cmp  edi, PLAYER_R
    jle  BoxY
    add  esi, PLAYER_R * 2
    cmp  esi, PLAYER_R
    jle  BoxX
    mov  eax, ebx
    ret
BoxCheck ENDP

; Move the player if the collision box stays free (X and Y separately)
TryMove PROC USES eax ecx edx, moveDX:SDWORD, moveDY:SDWORD
    mov  ecx, 0
    cmp  moveDX, 0
    je   TryY
    mov  edx, posX
    add  edx, moveDX
    INVOKE BoxCheck, edx, posY
    INVOKE HandleCell, eax, boxHitX, boxHitY
    cmp  eax, CELL_FREE
    jne  TryY
    mov  posX, edx
    mov  ecx, 1
TryY:
    cmp  moveDY, 0
    je   MoveDone
    mov  edx, posY
    add  edx, moveDY
    INVOKE BoxCheck, posX, edx
    INVOKE HandleCell, eax, boxHitX, boxHitY
    cmp  eax, CELL_FREE
    jne  MoveDone
    mov  posY, edx
    mov  ecx, 1
MoveDone:
    cmp  ecx, 0
    je   NoStep
    inc  steps
NoStep:
    ret
TryMove ENDP

; Pull the player to the middle of a corridor while moving
CenterAssist PROC USES eax ebx ecx edx
    mov  eax, angle
    call GetCos
    mov  ebx, eax
    cmp  ebx, 0
    jge  CosAbs
    neg  ebx
CosAbs:
    mov  eax, angle
    call GetSin
    cmp  eax, 0
    jge  SinAbs
    neg  eax
SinAbs:
    cmp  ebx, eax
    jb   AlongY
    mov  ecx, posY
    sub  ecx, CELL_SIZE
    INVOKE IsWall, posX, ecx
    cmp  eax, CELL_FREE
    je   AssistDone
    mov  ecx, posY
    add  ecx, CELL_SIZE
    INVOKE IsWall, posX, ecx
    cmp  eax, CELL_FREE
    je   AssistDone
    INVOKE CenterNudge, posY
    add  posY, eax
    jmp  AssistDone
AlongY:
    mov  ecx, posX
    sub  ecx, CELL_SIZE
    INVOKE IsWall, ecx, posY
    cmp  eax, CELL_FREE
    je   AssistDone
    mov  ecx, posX
    add  ecx, CELL_SIZE
    INVOKE IsWall, ecx, posY
    cmp  eax, CELL_FREE
    je   AssistDone
    INVOKE CenterNudge, posX
    add  posX, eax
AssistDone:
    ret
CenterAssist ENDP

; Small step towards the centre of the current cell
CenterNudge PROC, axisPos:SDWORD
    mov  eax, axisPos
    and  eax, NOT (CELL_SIZE - 1)
    add  eax, CELL_SIZE / 2
    sub  eax, axisPos
    sar  eax, 3
    cmp  eax, NUDGE_MAX
    jle  NudgeNotBig
    mov  eax, NUDGE_MAX
NudgeNotBig:
    cmp  eax, -NUDGE_MAX
    jge  NudgeDone
    mov  eax, -NUDGE_MAX
NudgeDone:
    ret
CenterNudge ENDP

; Turn speed: faster the longer A/D is held
GetTurnSpeed PROC
    mov  eax, turnHold
    dec  eax
    cmp  eax, TURN_RAMP_LEN - 1
    jbe  RampIndexOK
    mov  eax, TURN_RAMP_LEN - 1
RampIndexOK:
    movzx eax, turnRamp[eax]
    ret
GetTurnSpeed ENDP

; Handle a touched exit or key cell
HandleCell PROC USES eax, cellType:DWORD, testX:SDWORD, testY:SDWORD
    cmp  cellType, CELL_EXIT
    jne  NotExitCell
    call TouchExit
    jmp  CellDone
NotExitCell:
    cmp  cellType, CELL_KEY
    jne  CellDone
    INVOKE CollectKey, testX, testY
CellDone:
    ret
HandleCell ENDP

; Pick up a key: cell becomes floor, keys + 1
CollectKey PROC USES eax ebx, testX:SDWORD, testY:SDWORD
    mov  eax, testY
    sar  eax, 8
    shl  eax, 4
    mov  ebx, testX
    sar  ebx, 8
    add  eax, ebx
    mov  gameMap[eax], '.'
    inc  keys
    mov  eax, keys
    add  al, '0'
    mov  keyMsg[KEY_MSG_DIGIT], al
    INVOKE ShowMessage, ADDR keyMsg, KEY_MSG_ATTR
    ret
CollectKey ENDP

; Exit door: win with 3 keys, otherwise DOOR LOCKED
TouchExit PROC
    cmp  keys, KEYS_NEEDED
    jb   DoorLocked
    mov  wonFlag, 1
    ret
DoorLocked:
    INVOKE ShowMessage, ADDR lockedMsg, LOCKED_ATTR
    ret
TouchExit ENDP

; Start a 2-second HUD message
ShowMessage PROC USES eax, msgPtr:PTR BYTE, msgAttr:DWORD
    mov  eax, msgPtr
    mov  msgText, eax
    mov  eax, msgAttr
    mov  msgColor, eax
    call GetMseconds
    mov  msgStart, eax
    ret
ShowMessage ENDP

; Milliseconds since an earlier time
MsSince PROC, since:DWORD
    call GetMseconds
    sub  eax, since
    jns  SinceOK
    add  eax, MS_PER_DAY
SinceOK:
    ret
MsSince ENDP

; Draw the active HUD message
DrawMessage PROC USES eax ecx esi edi
    cmp  msgText, 0
    je   MsgDone
    INVOKE MsSince, msgStart
    cmp  eax, MSG_MS
    jb   MsgShow
    mov  msgText, 0
    jmp  MsgDone
MsgShow:
    cld
    mov  al, ' '
    mov  ecx, SCREEN_W - HUD_MSG_POS
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W + HUD_MSG_POS
    rep  stosb
    mov  eax, msgColor
    mov  ecx, SCREEN_W - HUD_MSG_POS
    mov  edi, OFFSET attrBuffer + (HUD_ROW * SCREEN_W + HUD_MSG_POS) * 2
    rep  stosw
    mov  esi, msgText
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W + HUD_MSG_POS
MsgCopy:
    lodsb
    cmp  al, 0
    je   MsgDone
    stosb
    jmp  MsgCopy
MsgDone:
    ret
DrawMessage ENDP

; Rotate the player: add degrees to the angle
TurnPlayer PROC USES eax, turnAmount:SDWORD
    mov  eax, angle
    add  eax, turnAmount
    call WrapAngle
    mov  angle, eax
    ret
TurnPlayer ENDP

; Keep an angle in 0..359
WrapAngle PROC
    cmp  eax, 0
    jge  WrapNotNegative
    add  eax, 360
WrapNotNegative:
    cmp  eax, 360
    jl   WrapDone
    sub  eax, 360
WrapDone:
    ret
WrapAngle ENDP

; Check if any key is held
AnyKeyDown PROC USES ecx
    mov  ecx, 8
CheckNextKey:
    INVOKE KeyDown, ecx
    cmp  eax, 0
    jne  FoundKey
    inc  ecx
    cmp  ecx, 255
    jb   CheckNextKey
    mov  eax, 0
    ret
FoundKey:
    mov  eax, 1
    ret
AnyKeyDown ENDP

; Wait until all keys are released
WaitKeysReleased PROC USES eax ecx
    mov  ecx, KEY_WAIT_TRIES
WaitLoop:
    call AnyKeyDown
    cmp  eax, 0
    je   KeysReleased
    mov  eax, 10
    call Delay
    loop WaitLoop
KeysReleased:
    INVOKE KeyDown, 'M'
    mov  mWasDown, al
    INVOKE KeyDown, 'Q'
    mov  qWasDown, al
    ret
WaitKeysReleased ENDP

; Get the console input handle
InitInput PROC USES eax ecx edx
    INVOKE GetStdHandle, STD_INPUT_HANDLE
    mov  inputHandle, eax
    ret
InitInput ENDP

; Is a key held right now (GetAsyncKeyState)
KeyDown PROC USES ecx edx, vKey:DWORD
    INVOKE GetAsyncKeyState, vKey
    test ax, 8000h
    jz   KeyIsUp
    mov  eax, 1
    jmp  KeyDownDone
KeyIsUp:
    mov  eax, 0
KeyDownDone:
    ret
KeyDown ENDP

; Report a key only on a new press
KeyPressed PROC USES ecx esi, vKey:DWORD, prevPtr:PTR BYTE
    INVOKE KeyDown, vKey
    mov  esi, prevPtr
    movzx ecx, BYTE PTR [esi]
    mov  [esi], al
    cmp  ecx, 0
    je   PressDone
    mov  eax, 0
PressDone:
    ret
KeyPressed ENDP

; Read the keys each frame: turn, move, minimap, quit
HandleInput PROC USES eax ebx ecx edx
    INVOKE FlushConsoleInputBuffer, inputHandle
    INVOKE KeyDown, 'A'
    mov  ebx, eax
    INVOKE KeyDown, 'D'
    or   eax, ebx
    jnz  TurnHeld
    mov  turnHold, 0
    jmp  CheckA
TurnHeld:
    cmp  turnHold, TURN_RAMP_LEN
    jae  CheckA
    inc  turnHold
CheckA:
    INVOKE KeyDown, 'A'
    cmp  eax, 0
    je   CheckD
    call GetTurnSpeed
    neg  eax
    INVOKE TurnPlayer, eax
CheckD:
    INVOKE KeyDown, 'D'
    cmp  eax, 0
    je   CheckW
    call GetTurnSpeed
    INVOKE TurnPlayer, eax
CheckW:
    INVOKE KeyDown, 'W'
    cmp  eax, 0
    je   CheckS
    call GetMoveDelta
    INVOKE TryMove, eax, edx
    call CenterAssist
CheckS:
    INVOKE KeyDown, 'S'
    cmp  eax, 0
    je   CheckM
    call GetMoveDelta
    neg  eax
    neg  edx
    INVOKE TryMove, eax, edx
    call CenterAssist
CheckM:
    INVOKE KeyPressed, 'M', ADDR mWasDown
    cmp  eax, 0
    je   CheckQ
    xor  showMinimap, 1
CheckQ:
    INVOKE KeyPressed, 'Q', ADDR qWasDown
    cmp  eax, 0
    je   InputDone
    mov  quitFlag, 1
InputDone:
    ret
HandleInput ENDP

; Minimap arrow for the player's direction
GetArrowChar PROC
    mov  eax, angle
    cmp  eax, 45
    jb   ArrowRight
    cmp  eax, 135
    jb   ArrowDown
    cmp  eax, 225
    jb   ArrowLeft
    cmp  eax, 315
    jb   ArrowUp
ArrowRight:
    mov  eax, '>'
    ret
ArrowDown:
    mov  eax, 'v'
    ret
ArrowLeft:
    mov  eax, '<'
    ret
ArrowUp:
    mov  eax, '^'
    ret
GetArrowChar ENDP

; Write one character and colour into the text overlay
PutCell PROC USES eax ebx, row:DWORD, col:DWORD, cellChar:DWORD, cellAttr:DWORD
    mov  eax, row
    imul eax, SCREEN_W
    add  eax, col
    mov  ebx, cellChar
    mov  frameBuffer[eax], bl
    mov  ebx, cellAttr
    mov  attrBuffer[eax*2], bx
    ret
PutCell ENDP

; Minimap character and colour for a map cell
GetMapLook PROC
    cmp  al, '#'
    je   LookWall
    cmp  al, '%'
    je   LookStone
    cmp  al, 'E'
    je   LookExit
    cmp  al, 'K'
    je   LookKey
    mov  eax, ' '
    mov  ebx, DEFAULT_ATTR
    ret
LookWall:
    mov  eax, WALL_CHAR
    mov  ebx, MAP_WALL_ATTR
    ret
LookStone:
    mov  eax, WALL_CHAR
    mov  ebx, MAP_STONE_ATTR
    ret
LookExit:
    mov  eax, 'E'
    mov  ebx, MAP_EXIT_ATTR
    ret
LookKey:
    mov  eax, 'K'
    mov  ebx, MAP_KEY_ATTR
    ret
GetMapLook ENDP

; Draw the border around the minimap
DrawMapBorder PROC USES ecx
    INVOKE PutCell, 0, 0, BOX_TL, BORDER_ATTR
    INVOKE PutCell, 0, MAP_BOX, BOX_TR, BORDER_ATTR
    INVOKE PutCell, MAP_BOX, 0, BOX_BL, BORDER_ATTR
    INVOKE PutCell, MAP_BOX, MAP_BOX, BOX_BR, BORDER_ATTR
    mov  ecx, 1
BorderLoop:
    INVOKE PutCell, 0, ecx, BOX_H, BORDER_ATTR
    INVOKE PutCell, MAP_BOX, ecx, BOX_H, BORDER_ATTR
    INVOKE PutCell, ecx, 0, BOX_V, BORDER_ATTR
    INVOKE PutCell, ecx, MAP_BOX, BOX_V, BORDER_ATTR
    inc  ecx
    cmp  ecx, MAP_BOX
    jb   BorderLoop
    ret
DrawMapBorder ENDP

; Draw the coloured minimap and player arrow
DrawMinimap PROC USES eax ebx ecx edx esi edi
    cmp  showMinimap, 0
    je   MapDone
    call DrawMapBorder
    mov  edx, 0
MapRow:
    mov  ecx, 0
MapCol:
    mov  eax, edx
    shl  eax, 4
    add  eax, ecx
    movzx eax, gameMap[eax]
    call GetMapLook
    mov  esi, edx
    inc  esi
    mov  edi, ecx
    inc  edi
    INVOKE PutCell, esi, edi, eax, ebx
    inc  ecx
    cmp  ecx, MAP_W
    jb   MapCol
    inc  edx
    cmp  edx, MAP_H
    jb   MapRow
    mov  esi, posY
    sar  esi, 8
    inc  esi
    mov  edi, posX
    sar  edi, 8
    inc  edi
    call GetArrowChar
    INVOKE PutCell, esi, edi, eax, PLAYER_ATTR
MapDone:
    ret
DrawMinimap ENDP

; DDA setup for one axis: step, deltaDist, sideDist
SetupAxis PROC USES edx esi, axisPos:SDWORD, axisDir:SDWORD
    mov  esi, axisDir
    cmp  esi, 0
    jne  DirNotZero
    mov  eax, BIG_DIST
    mov  ebx, BIG_DIST
    mov  ecx, 1
    ret
DirNotZero:
    mov  ecx, 1
    cmp  esi, 0
    jg   DirPositive
    neg  esi
    mov  ecx, -1
DirPositive:
    mov  eax, 65536
    mov  edx, 0
    div  esi
    mov  edx, axisPos
    and  edx, 255
    cmp  ecx, 1
    jne  HaveGap
    neg  edx
    add  edx, 256
HaveGap:
    mov  ebx, eax
    FIXMUL ebx, edx
    ret
SetupAxis ENDP

; Cast one ray with DDA and return the distance to the wall
CastRay PROC USES ebx esi edi, rayDirX:SDWORD, rayDirY:SDWORD
    LOCAL mapX:SDWORD, mapY:SDWORD
    LOCAL stepX:SDWORD, stepY:SDWORD
    LOCAL deltaX:SDWORD, deltaY:SDWORD
    LOCAL sideX:SDWORD, sideY:SDWORD
    LOCAL hitSide:DWORD
    LOCAL hitType:DWORD

    mov  hitType, HIT_WALL

    mov  edi, rayDirX
    mov  esi, rayDirY

    mov  eax, posX
    sar  eax, 8
    mov  mapX, eax
    mov  eax, posY
    sar  eax, 8
    mov  mapY, eax
    INVOKE SetupAxis, posX, edi
    mov  deltaX, eax
    mov  sideX, ebx
    mov  stepX, ecx
    INVOKE SetupAxis, posY, esi
    mov  deltaY, eax
    mov  sideY, ebx
    mov  stepY, ecx

DDALoop:
    mov  eax, sideX
    cmp  eax, sideY
    jge  StepInY
    mov  eax, deltaX
    add  sideX, eax
    mov  eax, stepX
    add  mapX, eax
    mov  hitSide, 0
    jmp  CheckCell
StepInY:
    mov  eax, deltaY
    add  sideY, eax
    mov  eax, stepY
    add  mapY, eax
    mov  hitSide, 1
CheckCell:
    cmp  mapX, MAP_W - 1
    ja   RayHit
    cmp  mapY, MAP_H - 1
    ja   RayHit
    mov  eax, mapY
    shl  eax, 4
    add  eax, mapX
    cmp  gameMap[eax], '#'
    je   RayHit
    cmp  gameMap[eax], '%'
    je   RayHit
    cmp  gameMap[eax], 'K'
    je   RayKey
    cmp  gameMap[eax], 'E'
    jne  DDALoop
    mov  hitType, HIT_EXIT
    jmp  RayHit
RayKey:
    mov  hitType, HIT_KEY
RayHit:

    cmp  hitSide, 0
    jne  HitOnY
    mov  eax, sideX
    sub  eax, deltaX
    jmp  HaveRayDist
HitOnY:
    mov  eax, sideY
    sub  eax, deltaY
HaveRayDist:
    mov  ebx, eax

    mov  eax, mapY
    shl  eax, 4
    add  eax, mapX
    and  eax, 0FFh
    mov  rayCell, eax
    mov  eax, ebx
    cmp  hitSide, 0
    jne  WallXFromX
    FIXMUL eax, esi
    add  eax, posY
    jmp  HaveWallX
WallXFromX:
    FIXMUL eax, edi
    add  eax, posX
HaveWallX:
    and  eax, 255
    mov  rayWallX, eax

    mov  eax, ebx

    cmp  eax, 1
    jge  DistOK
    mov  eax, 1
DistOK:
    mov  edx, hitSide
    mov  ecx, hitType
    ret
CastRay ENDP

; Wall shade level from the distance
GetWallLevel PROC, distance:DWORD, side:DWORD
    mov  eax, distance
    cmp  eax, shadeDist1
    jb   Level0
    cmp  eax, shadeDist2
    jb   Level1
    cmp  eax, shadeDist3
    jb   Level2
    mov  eax, 3
    jmp  AddSide
Level0:
    mov  eax, 0
    jmp  AddSide
Level1:
    mov  eax, 1
    jmp  AddSide
Level2:
    mov  eax, 2
AddSide:
    add  eax, side
    cmp  eax, 3
    jbe  HaveLevel
    mov  eax, 3
HaveLevel:
    ret
GetWallLevel ENDP

; Colour of one floor pixel (dithered gradient)
GetFloorPixel PROC USES edx, column:DWORD
    mov  eax, PIX_H - 1
    sub  eax, ecx
    imul eax, FLOOR_BANDS
    mov  edx, 0
    push ecx
    mov  ecx, HORIZON
    div  ecx
    pop  ecx
    mov  edx, column
    add  edx, ecx
    cmp  eax, 0
    je   FloorNear
    cmp  eax, 1
    jne  FloorBand2
    test edx, 3
    jz   FloorFar
    jmp  FloorNear
FloorBand2:
    cmp  eax, 2
    jne  FloorBand3
    test edx, 1
    jz   FloorFar
    jmp  FloorNear
FloorBand3:
    cmp  eax, 3
    jne  FloorFar
    test edx, 3
    jz   FloorNear
FloorFar:
    mov  eax, C_FLOOR_FAR
    ret
FloorNear:
    mov  eax, C_FLOOR_NEAR
    ret
GetFloorPixel ENDP

; Wall height in pixels from the distance
GetWallHeight PROC USES ecx edx
    mov  ecx, eax
    mov  eax, PIX_H * 256
    mov  edx, 0
    div  ecx
    cmp  eax, 2
    jae  HeightOK
    mov  eax, 2
HeightOK:
    ret
GetWallHeight ENDP

; Draw one column of the 3D view: sky, wall, floor
DrawPixelColumn PROC USES eax ebx ecx edx edi, column:DWORD
    LOCAL wallTop:SDWORD
    LOCAL wallBottom:SDWORD
    LOCAL lineH:DWORD
    LOCAL kind:DWORD
    LOCAL level:DWORD
    LOCAL wallX:DWORD
    LOCAL rayAng:DWORD

    mov  ebx, column
    movzx eax, colAngle[ebx*2]
    mov  rayAng, eax
    movzx eax, colWallX[ebx]
    mov  wallX, eax
    mov  eax, colDist[ebx*4]
    cmp  eax, MIN_WALL_DIST
    jae  DistForHeightOK
    mov  eax, MIN_WALL_DIST
DistForHeightOK:
    call GetWallHeight
    mov  lineH, eax
    sar  eax, 1
    mov  edx, HORIZON
    sub  edx, eax
    mov  wallTop, edx
    mov  edx, HORIZON
    add  edx, eax
    mov  wallBottom, edx

    INVOKE GetColumnKind, ebx
    mov  kind, eax
    movzx eax, hitSideCol[ebx]
    INVOKE GetWallLevel, colDist[ebx*4], eax
    mov  level, eax

    mov  edi, OFFSET pixBuf
    add  edi, ebx
    mov  ecx, 0
PixelRow:
    cmp  ecx, wallTop
    jl   PixSky
    cmp  ecx, wallBottom
    jl   PixWall
    mov  edx, wallBottom
    add  edx, FLOOR_SHADOW
    cmp  ecx, edx
    jge  PixFloor
    mov  eax, SHADOW_ATTR
    jmp  PixStore
PixFloor:
    INVOKE GetFloorPixel, ebx
    jmp  PixStore
PixSky:
    mov  eax, C_SKY
    INVOKE IsStar, rayAng
    cmp  eax, 0
    mov  eax, C_SKY
    je   PixStore
    mov  eax, STAR_ATTR
    jmp  PixStore
PixWall:
    mov  edx, ecx
    sub  edx, wallTop
    INVOKE GetWallPixel, kind, level, wallX, edx, lineH
PixStore:
    mov  [edi], al
    add  edi, PIX_W
    inc  ecx
    cmp  ecx, PIX_H
    jb   PixelRow
    ret
DrawPixelColumn ENDP

; What a column shows: edge, door, key, brick or stone
GetColumnKind PROC USES ebx, column:DWORD
    INVOKE IsEdgeColumn, column
    cmp  eax, 0
    mov  eax, KIND_EDGE
    jne  KindDone
    mov  ebx, column
    mov  eax, KIND_DOOR
    cmp  colType[ebx], HIT_EXIT
    je   KindDone
    mov  eax, KIND_KEY
    cmp  colType[ebx], HIT_KEY
    je   KindDone
    movzx ebx, hitCellCol[ebx]
    mov  eax, KIND_STONE
    cmp  gameMap[ebx], '%'
    je   KindDone
    mov  eax, KIND_BRICK
KindDone:
    ret
GetColumnKind ENDP

; Colour of one wall pixel (texture, shade, outline)
GetWallPixel PROC USES ecx edx, kind:DWORD, level:DWORD, wallX:DWORD, texRow:DWORD, lineH:DWORD
    cmp  kind, KIND_EDGE
    jne  NotEdgePix
    mov  eax, EDGE_ATTR
    ret
NotEdgePix:
    cmp  texRow, 0
    je   OutlinePix
    mov  eax, lineH
    dec  eax
    cmp  texRow, eax
    je   OutlinePix
    cmp  kind, KIND_DOOR
    je   DoorPix
    cmp  kind, KIND_KEY
    je   KeyPix
    mov  edx, lineH
    shr  edx, 2
    cmp  texRow, edx
    jae  NotTopLight
    cmp  level, 0
    je   NotTopLight
    dec  level
NotTopLight:
    mov  edx, lineH
    sub  edx, CONTACT_ROWS + 1
    cmp  texRow, edx
    jl   NotBottomShade
    cmp  level, 3
    jae  NotBottomShade
    inc  level
NotBottomShade:
    mov  eax, texRow
    imul eax, TEX_ROWS
    mov  edx, 0
    div  lineH
    mov  ecx, eax
    cmp  kind, KIND_STONE
    je   StonePix
    and  eax, BRICK_ROW_H - 1
    cmp  eax, 0
    je   BrickMortar
    mov  eax, 0
    test ecx, BRICK_ROW_H
    jz   HaveBrickShift
    mov  eax, BRICK_SHIFT
HaveBrickShift:
    add  eax, wallX
    and  eax, BRICK_W - 1
    cmp  eax, JOINT_W
    jb   BrickMortar
    mov  eax, level
    movzx eax, brickColors[eax]
    ret
BrickMortar:
    mov  eax, level
    movzx eax, brickColors[eax + 2]
    ret
StonePix:
    and  eax, STONE_ROW_H - 1
    cmp  eax, 0
    je   StoneSeam
    mov  eax, 0
    test ecx, STONE_ROW_H
    jz   HaveStoneShift
    mov  eax, STONE_SHIFT
HaveStoneShift:
    add  eax, wallX
    mov  edx, eax
    and  eax, STONE_W - 1
    cmp  eax, SEAM_W
    jb   StoneSeam
    shr  edx, 7
    shr  ecx, 4
    add  edx, ecx
    and  edx, 1
    mov  eax, level
    add  eax, edx
    cmp  eax, 3
    jbe  StoneShadeOK
    mov  eax, 3
StoneShadeOK:
    movzx eax, stoneColors[eax]
    ret
StoneSeam:
    mov  eax, level
    movzx eax, stoneColors[eax + 2]
    ret
OutlinePix:
    mov  eax, OUTLINE_ATTR
    ret
DoorPix:
    mov  eax, DOOR_COLOR_A
    cmp  blinkOn, 0
    je   PixDone
    mov  eax, DOOR_COLOR_B
    ret
KeyPix:
    mov  eax, KEY_COLOR_A
    cmp  blinkOn, 0
    je   PixDone
    mov  eax, KEY_COLOR_B
PixDone:
    ret
GetWallPixel ENDP

; Blink state from the clock (every 500 ms)
UpdateBlink PROC USES eax ecx edx
    call GetMseconds
    mov  edx, 0
    mov  ecx, BLINK_MS
    div  ecx
    and  eax, 1
    mov  blinkOn, eax
    ret
UpdateBlink ENDP

; Is this sky pixel a star
IsStar PROC USES ebx edx, rayAngle:DWORD
    mov  eax, rayAngle
    imul eax, 7
    mov  ebx, ecx
    imul ebx, 13
    add  eax, ebx
    mov  edx, 0
    mov  ebx, STAR_MOD
    div  ebx
    mov  eax, 0
    cmp  edx, 0
    jne  StarDone
    mov  eax, 1
StarDone:
    ret
IsStar ENDP

; Cast one ray per screen column and store the results
CastAllRays PROC USES eax ebx ecx edx esi edi
    LOCAL dirX:SDWORD, dirY:SDWORD
    LOCAL planeX:SDWORD, planeY:SDWORD
    mov  eax, angle
    call GetCos
    mov  dirX, eax
    mov  planeY, eax
    mov  eax, angle
    call GetSin
    mov  dirY, eax
    neg  eax
    FIXMUL eax, PLANE_LEN
    mov  planeX, eax
    mov  eax, planeY
    FIXMUL eax, PLANE_LEN
    mov  planeY, eax
    mov  ebx, 0
CastColumn:
    mov  eax, ebx
    shl  eax, 1
    sub  eax, SCREEN_W - 1
    shl  eax, 8
    cdq
    mov  ecx, SCREEN_W - 1
    idiv ecx
    mov  ecx, eax
    mov  edi, planeX
    FIXMUL edi, ecx
    add  edi, dirX
    mov  esi, planeY
    FIXMUL esi, ecx
    add  esi, dirY
    mov  eax, ebx
    imul eax, FOV
    mov  edx, 0
    mov  ecx, SCREEN_W
    div  ecx
    add  eax, angle
    sub  eax, FOV / 2
    call WrapAngle
    mov  colAngle[ebx*2], ax
    INVOKE CastRay, edi, esi
    mov  colDist[ebx*4], eax
    mov  hitSideCol[ebx], dl
    mov  colType[ebx], cl
    mov  eax, rayCell
    mov  hitCellCol[ebx], al
    mov  eax, rayWallX
    mov  colWallX[ebx], al
    inc  ebx
    cmp  ebx, SCREEN_W
    jb   CastColumn
    ret
CastAllRays ENDP

; Is this column an edge between two walls
IsEdgeColumn PROC USES ebx esi, column:DWORD
    mov  ebx, column
    cmp  ebx, 0
    je   EdgeNo
    mov  esi, OFFSET hitCellCol
    mov  al, [esi + ebx]
    cmp  al, [esi + ebx - 1]
    jne  EdgeYes
    mov  esi, OFFSET hitSideCol
    mov  al, [esi + ebx]
    cmp  al, [esi + ebx - 1]
    jne  EdgeYes
EdgeNo:
    mov  eax, 0
    ret
EdgeYes:
    mov  eax, 1
    ret
IsEdgeColumn ENDP

; Draw the 3D view: cast all rays, then draw all columns
RenderView PROC USES ebx
    call CastAllRays
    mov  ebx, 0
DrawNext:
    INVOKE DrawPixelColumn, ebx
    inc  ebx
    cmp  ebx, PIX_W
    jb   DrawNext
    ret
RenderView ENDP

; Start a new game: restore the map, reset player, keys and timer
ResetGame PROC USES eax ecx esi edi
    cld
    mov  esi, OFFSET originalMap
    mov  edi, OFFSET gameMap
    mov  ecx, MAP_W * MAP_H
    rep  movsb
    mov  posX, START_X
    mov  posY, START_Y
    mov  angle, START_ANGLE
    mov  steps, 0
    mov  quitFlag, 0
    mov  wonFlag, 0
    mov  keys, 0
    mov  msgText, 0
    call GetMseconds
    mov  startTime, eax
    ret
ResetGame ENDP

; Seconds since the game started
GetElapsedSec PROC USES ecx edx
    INVOKE MsSince, startTime
    mov  edx, 0
    mov  ecx, 1000
    div  ecx
    ret
GetElapsedSec ENDP

; Seconds left on the timer
GetRemainingSec PROC USES ebx
    call GetElapsedSec
    mov  ebx, TIME_LIMIT
    sub  ebx, eax
    jge  TimeLeftOK
    mov  ebx, 0
TimeLeftOK:
    mov  eax, ebx
    ret
GetRemainingSec ENDP

; Write a number as digits into memory
PutNumber PROC USES eax ebx ecx edx edi, dest:PTR BYTE, value:DWORD, digits:DWORD
    mov  edi, dest
    add  edi, digits
    dec  edi
    mov  eax, value
    mov  ebx, 10
    mov  ecx, digits
DigitLoop:
    mov  edx, 0
    div  ebx
    add  dl, '0'
    mov  [edi], dl
    dec  edi
    loop DigitLoop
    ret
PutNumber ENDP

; Fill the HUD row: time, steps, keys, controls
DrawHUD PROC USES eax ebx ecx edx esi edi
    cld
    mov  esi, OFFSET hudTemplate
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W
    mov  ecx, HUD_LEN
    rep  movsb
    mov  edi, OFFSET frameBuffer + HUD_ROW * SCREEN_W
    call GetRemainingSec
    mov  edx, 0
    mov  ebx, 60
    div  ebx
    mov  ecx, edi
    add  ecx, HUD_MIN_POS
    INVOKE PutNumber, ecx, eax, 2
    mov  ecx, edi
    add  ecx, HUD_SEC_POS
    INVOKE PutNumber, ecx, edx, 2
    mov  ecx, edi
    add  ecx, HUD_STEP_POS
    INVOKE PutNumber, ecx, steps, 5
    mov  ecx, edi
    add  ecx, HUD_KEY_POS
    INVOKE PutNumber, ecx, keys, 1
    call DrawMessage
    call GetRemainingSec
    mov  edx, TIMER_ATTR
    cmp  eax, LOW_TIME
    jae  HaveTimerColor
    mov  edx, TIMER_LOW_ATTR
HaveTimerColor:
    mov  eax, edx
    mov  edi, OFFSET attrBuffer + HUD_ROW * SCREEN_W * 2
    mov  ecx, HUD_TIME_LEN
    rep  stosw
    mov  eax, KEYS_ATTR
    mov  edi, OFFSET attrBuffer + (HUD_ROW * SCREEN_W + HUD_KEYS_COL) * 2
    mov  ecx, HUD_KEYS_LEN
    rep  stosw
    ret
DrawHUD ENDP

; Print a number with two digits
PrintTwoDigits PROC USES eax
    cmp  eax, 10
    jae  TwoDigits
    push eax
    mov  al, '0'
    call WriteChar
    pop  eax
TwoDigits:
    call WriteDec
    ret
PrintTwoDigits ENDP

; Print seconds as mm:ss
PrintTime PROC USES eax ebx edx
    mov  edx, 0
    mov  ebx, 60
    div  ebx
    call PrintTwoDigits
    mov  al, ':'
    call WriteChar
    mov  eax, edx
    call PrintTwoDigits
    ret
PrintTime ENDP

; Win screen: ESCAPED!, time, steps, keys
WinScreen PROC USES eax edx
    call Clrscr
    INVOKE PrintArt, ADDR winArt, ADDR winColors, ART_LINES, BANNER_ROW, WIN_COL
    mov  eax, C_WHITE
    call SetRoleColor
    mov  dh, INFO_ROW
    mov  dl, INFO_COL
    call Gotoxy
    mov  edx, OFFSET timeMsg
    call WriteString
    call GetElapsedSec
    call PrintTime
    mov  dh, INFO_ROW + 1
    mov  dl, INFO_COL
    call Gotoxy
    mov  edx, OFFSET stepsMsg
    call WriteString
    mov  eax, steps
    call WriteDec
    mov  dh, INFO_ROW + 2
    mov  dl, INFO_COL
    call Gotoxy
    mov  edx, OFFSET keysMsg
    call WriteString
    mov  eax, keys
    call WriteDec
    mov  edx, OFFSET keysOf
    call WriteString
    mov  dh, ASK_ROW
    mov  dl, INFO_COL
    call Gotoxy
    ret
WinScreen ENDP

; Lose screen: TIME UP, steps
LoseScreen PROC USES eax edx
    call Clrscr
    INVOKE PrintArt, ADDR loseArt, ADDR loseColors, ART_LINES, BANNER_ROW, LOSE_COL
    mov  eax, C_WHITE
    call SetRoleColor
    mov  dh, INFO_ROW
    mov  dl, INFO_COL
    call Gotoxy
    mov  edx, OFFSET loseText
    call WriteString
    mov  dh, INFO_ROW + 1
    mov  dl, INFO_COL
    call Gotoxy
    mov  edx, OFFSET stepsMsg
    call WriteString
    mov  eax, steps
    call WriteDec
    mov  dh, ASK_ROW
    mov  dl, INFO_COL
    call Gotoxy
    ret
LoseScreen ENDP

; Ask Play again? (Y/N)
AskPlayAgain PROC USES ecx edx
    INVOKE FlushConsoleInputBuffer, inputHandle
    mov  eax, DEFAULT_ATTR
    call SetRoleColor
    mov  edx, OFFSET againMsg
    call WriteString
AskLoop:
    call ReadChar
    and  al, 11011111b
    cmp  al, 'Y'
    je   AnswerYes
    cmp  al, 'N'
    je   AnswerNo
    cmp  al, 'Q'
    je   AnswerNo
    jmp  AskLoop
AnswerYes:
    mov  eax, 1
    ret
AnswerNo:
    mov  eax, 0
    ret
AskPlayAgain ENDP

; One frame after another until win, lose or quit
GameLoop PROC
FrameLoop:
    call HandleInput
    cmp  quitFlag, 1
    je   GameQuit
    cmp  wonFlag, 1
    je   GameWon
    call GetRemainingSec
    cmp  eax, 0
    je   GameLost
    call UpdateBlink
    call ClearBuffer
    call RenderView
    call DrawMinimap
    call DrawHUD
    call ComposeFrame
    mov  eax, 30
    call Delay
    jmp  FrameLoop
GameQuit:
    mov  eax, RESULT_QUIT
    ret
GameWon:
    mov  eax, RESULT_WIN
    ret
GameLost:
    mov  eax, RESULT_LOSE
    ret
GameLoop ENDP

END main
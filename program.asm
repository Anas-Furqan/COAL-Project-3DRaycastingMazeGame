; ------------------------------------------------------------
; WOLF-86 - COAL Lab Project
; First-person 3D raycasting maze game (setup test version)
; ------------------------------------------------------------

INCLUDE Irvine32.inc                        ; Irvine32 library procedures and Win32 prototypes

.data
setupMsg BYTE "WOLF-86 setup OK", 0         ; message to print, ends with a 0 byte

.code
;-------------------------------------------------------------
; main
; Purpose:   Print the setup message and wait for a key press.
; Receives:  nothing
; Returns:   nothing (exits the program)
; Registers: EDX, EAX (used by Irvine32 calls)
;-------------------------------------------------------------
main PROC
    mov  edx, OFFSET setupMsg               ; EDX = address of the message
    call WriteString                        ; print the message
    call Crlf                               ; move cursor to next line
    call ReadChar                           ; wait until the user presses a key
    INVOKE ExitProcess, 0                   ; end the program with exit code 0
main ENDP

END main                                    ; program starts at main

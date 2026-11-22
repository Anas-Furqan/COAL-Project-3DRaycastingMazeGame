WOLF-86 - 3D Raycasting Maze Game
EL-2003 COAL Lab, Fall 2026 - Saif Nawaz
=================================================================

WHAT IT IS
----------
WOLF-86 is a first-person 3D maze game for the Windows console,
written in 32-bit x86 assembly (MASM) with the Irvine32 library.
The 3D view is drawn with raycasting: for each of the 80 screen
columns one ray is sent into a 16x16 maze using the DDA algorithm,
and the wall distance decides how tall that column of wall is.
All maths is integer fixed-point (Q8: value * 256); sine and cosine
come from a 360-entry lookup table. No FPU or SSE instructions.

HOW TO RUN (Visual Studio 2022)
-------------------------------
1. Install the Irvine32 library in C:\Irvine
   (Irvine32.inc, Irvine32.lib, SmallWin.inc, ...).
2. Open "COAL Project.slnx" (or the .vcxproj) in Visual Studio 2022.
3. The project is already set up; check these if you make a new one:
   - Build Dependencies > Build Customizations: "masm" ticked
   - Properties > Microsoft Macro Assembler > General >
     Include Paths: C:\Irvine
   - Properties > Linker > General > Additional Library
     Directories: C:\Irvine
   - Properties > Linker > Input > Additional Dependencies:
     Irvine32.lib;kernel32.lib;user32.lib
   - Properties > Linker > System > SubSystem: Console
4. Select configuration "Debug" and platform "x86" (Win32).
5. Press F5 (or Ctrl+F5) to build and run.

   Command line (Developer PowerShell):
   msbuild "COAL Project.slnx" /p:Configuration=Debug /p:Platform=x86
   then run Debug\COAL Project.exe

The console window should be at least 80 x 25 characters.

CONTROLS
--------
  W / S   move forward / backward (hold)
  A / D   turn left / right (hold; can be combined with W/S)
  M       show / hide the minimap
  Q       quit (in the game, on the title, win and lose screens)
  Y / N   play again or not (after a game)

GOAL
----
You start in the top-left corner of the maze. Find the exit door
(E on the minimap, a double-line wall in the 3D view) and walk into
it before the 120-second timer runs out. The HUD on the bottom row
shows the time left (mm:ss) and your step count. The win screen
shows your time and steps; if the time runs out you lose.

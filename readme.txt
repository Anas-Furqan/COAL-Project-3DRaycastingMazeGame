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

Everything is drawn in colour: every frame has a character buffer and
a colour buffer (80 x 25 each) that are written to the console row by
row. The game installs its own 16-colour console palette (a blue /
orange theme) and puts the original colours back when it exits; if
the console does not allow this, it runs with the standard colours.
Walls are solid blocks in four blue shades by distance (one side of
each wall a shade darker). Every wall has a dark outline at its top
and bottom, a black line where one wall or cell ends and the next
begins, and a brick texture (mortar lines, offset joints) when it is
close enough. Rays use the camera-plane method, so every one of the
80 columns gets its own ray and walls never bend. The sky is near-black with dim
stars that move as you turn, and the floor fades from slate (near)
to almost black (far). The exit door blinks red-orange/yellow-orange,
keys blink gold/white, and the HUD key count is gold.

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
You start in the top-left corner of the maze. Three keys (K on the
minimap, blinking yellow/white pillars in the 3D view) are hidden in
the maze. Walk into a key to pick it up ("KEY FOUND! n/3"). The exit
door (red E on the minimap, blinking red/yellow in the 3D view) stays
locked until you have all 3 keys ("DOOR LOCKED - FIND 3 KEYS").
With 3 keys, walk into the door before the 180-second timer runs out.

The HUD on the bottom row shows the time left (mm:ss, turns red under
20 seconds), your step count and KEYS n/3. The win screen shows your
time, steps and keys; if the time runs out you lose. Playing again
puts all keys back.

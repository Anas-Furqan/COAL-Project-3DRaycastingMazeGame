# WOLF-86 — COAL Lab Project
First-person 3D raycasting maze game in x86 Assembly (MASM, 32-bit) using Irvine32, in the Windows console.

## Rules
- MASM 32-bit only, Irvine32 library + Win32 functions available via Irvine32.inc / SmallWin.inc. No FPU/SSE, no C runtime.
- All math is integer fixed-point scaled by 256 (Q8). Angles are 0–359 degrees, sine/cosine from a 360-entry SDWORD lookup table scaled by 256.
- Code lives in program.asm. Keep procedures short (one job each), with clear PROC headers: purpose, receives, returns, registers changed.
- Comment almost every line in simple English. The student must explain every line in a viva, so prefer clear code over clever code.
- Preserve registers with USES or PUSH/POP. Use PROTO/INVOKE where parameters are passed.
- After every change: build with msbuild (see below) and fix all errors and warnings before finishing.
- Never run the game executable yourself; the student tests it with F5.

## Build
Run from the VS Developer PowerShell: msbuild "COAL Project.slnx" /p:Configuration=Debug /p:Platform=x86

## Git
- Commit after every small working step.
- Commit messages: one short line, lowercase, max ~50 chars (e.g. "add map array and title screen").
- No Co-Authored-By trailer, no "Generated with" line, no description body. Never mention Claude or AI in commits.

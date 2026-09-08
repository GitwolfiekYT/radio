#SingleInstance Force
#NoEnv
#MaxThreadsPerHotkey 1
SendMode Input
SetWorkingDir %A_ScriptDir%

; F6 is the only hotkey.  Each press asks the Python controller to toggle
; recording; it does not depend on a cmd.exe window receiving keystrokes.
$F6::
    KeyWait, F6, T0.05
    Run, py.exe -3 metrocop.py toggle, %A_ScriptDir%, Hide
    KeyWait, F6
return

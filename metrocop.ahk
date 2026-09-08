#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 3

; Only F6 is used by this script.  It toggles recording in radio.bat;
; no Soundpad shortcuts are sent.
radioTitle := "METROCOP RADIO CONSOLE"

return

$F6::
    ; Do not pass F6 through to VRChat or generate commands from key repeat.
    KeyWait, F6, T0.01

    ; Start the permanent controller if it was closed.  Waiting for its window
    ; avoids losing the first trigger press while cmd.exe is opening.
    if !WinExist(radioTitle)
    {
        radioCommand := ComSpec . " /k call """ . A_ScriptDir . "\radio.bat"""
        Run, %radioCommand%, %A_ScriptDir%
        WinWait, %radioTitle%,, 3
    }

    if WinExist(radioTitle)
        ControlSend,, r, %radioTitle%

    ; Wait for release so holding a controller trigger cannot toggle twice.
    KeyWait, F6
return

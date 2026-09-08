#SingleInstance Force
#Persistent
#MaxThreadsPerHotkey 1
SendMode Input
SetWorkingDir %A_ScriptDir%
SetTitleMatchMode, 3

; Run this script as Administrator.
; AHK does NOT record, stop FFmpeg, process audio, create files, or show ToolTips.
; It only sends one R key to the permanent radio console.

canLevel        := 0
trashLevel      := 0
tapB            := 0
tapY            := 0
lastTapB        := 0
lastTapY        := 0
chatterActive   := 0
radioSendLocked := false
radioTitle       := "METROCOP RADIO CONSOLE"

; Start the permanent BAT console once if it is not already open.
if !WinExist(radioTitle)
{
    radioCommand := ComSpec . " /k call """ . A_ScriptDir . "\radio.bat"""
    Run, %radioCommand%, %A_ScriptDir%
}

return

; ============ B / F1: Yes / No / Knocked / Death ============
F1::
    if (A_TickCount - lastTapB > 550)
        tapB := 1
    else
        tapB++
    lastTapB := A_TickCount
    SetTimer, FireB, -550
return

FireB:
    if (tapB = 1)
        Send, ^!1
    else if (tapB = 2)
        Send, ^!2
    else if (tapB = 3)
        Send, ^!3
    else if (tapB >= 4)
        Send, ^!4
return

; ============ A / F2: Pick up that can, cycle 1-2-3 ============
F2::
    canLevel := (canLevel >= 3) ? 1 : canLevel + 1
    if (canLevel = 1)
        Send, ^!5
    else if (canLevel = 2)
        Send, ^!6
    else
        Send, ^!7
return

; ============ X / F3: Trash can, cycle 1-2 ============
F3::
    trashLevel := (trashLevel >= 2) ? 1 : trashLevel + 1
    if (trashLevel = 1)
        Send, ^!8
    else
        Send, ^!9
return

; ============ Y / F4: Go / Judgment ============
F4::
    if (A_TickCount - lastTapY > 450)
        tapY := 1
    else
        tapY++
    lastTapY := A_TickCount
    SetTimer, FireY, -450
return

FireY:
    if (tapY = 1)
        Send, ^!0
    else
        Send, ^+j
return

; ============ + / F5: Reset cycles ============
F5::
    canLevel := 0
    trashLevel := 0
return

; ============ ZR / F6: SEND ONE COMMAND TO BAT ============
$F6::
    ; One physical trigger press may emit many F6 events.
    ; This lock blocks the duplicate burst for one second.
    if (radioSendLocked)
        return

    radioSendLocked := true
    SetTimer, UnlockRadioSend, -1000

    ; No window activation: the game keeps focus.
    ; The permanent BAT console receives the R command in the background.
    ControlSend,, r, %radioTitle%

    ; If the console was closed manually, open it again.
    if !WinExist(radioTitle)
    {
        radioCommand := ComSpec . " /k call """ . A_ScriptDir . "\radio.bat"""
        Run, %radioCommand%, %A_ScriptDir%
    }

    ; Prevent keyboard auto-repeat from generating another command until F6 is released.
    KeyWait, F6
return

UnlockRadioSend:
    radioSendLocked := false
return

; ============ HOME / F9: Ambient radio chatter ============
Home::
F9::
    Send, ^!m
    chatterActive := 1
return

; ============ R / F7: Soundpad panic stop only ============
F7::
    Send, ^!s
    chatterActive := 0
return

; ============ STICK / F8: CP VIOLATION ============
F8::
    Send, ^!v
return

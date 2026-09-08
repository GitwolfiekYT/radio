@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001
title METROCOP RADIO CONSOLE
cd /d "%~dp0"

REM This is the only radio console. Do not close it.
REM AHK sends the single R key to this exact console.

set "MIC_NAME=Microphone (WO Mic Device)"
set "COUNTER_FILE=radio_counter.txt"
set "STATE=IDLE"
set "CURRENT_ID="
set "CURRENT_INPUT="

echo ============================================================
echo   METROCOP RADIO CONSOLE
 echo  Console is permanent. AHK only sends R to this window.
echo   F6 first press  = start recording
echo   F6 second press = stop, convert, play
echo ============================================================
echo.

:LOOP
call :DRAIN_KEYS
if /I "!STATE!"=="IDLE" (
    echo [READY] Waiting for F6 command from AHK...
) else (
    echo [RECORDING !CURRENT_ID!] Waiting for F6 command from AHK...
)

REM choice waits only for R. The batch never exits and never opens another control console.
choice /c R /n /m ""
goto RADIO_BUTTON

:RADIO_BUTTON
if /I "!STATE!"=="IDLE" goto START_RECORDING
if /I "!STATE!"=="RECORDING" goto STOP_AND_PROCESS

echo [ERROR] Unknown state: !STATE!
set "STATE=IDLE"
goto LOOP

:START_RECORDING
if not exist "%COUNTER_FILE%" echo 1>"%COUNTER_FILE%"
set /p NUMBER=<"%COUNTER_FILE%"
set /a NEXT=NUMBER+1
>"%COUNTER_FILE%" echo !NEXT!

set "CURRENT_ID=0000!NUMBER!"
set "CURRENT_ID=!CURRENT_ID:~-4!"
set "CURRENT_INPUT=input_!CURRENT_ID!.pcm"
set "STATE=RECORDING"

echo.
echo ============================================================
echo [START] Recording !CURRENT_ID!
echo [START] Speak into WO Mic. Press F6 once to stop.
echo ============================================================

REM -nostdin is essential: only this batch may read console keys.
REM /b keeps FFmpeg in this same console: no hidden windows and no extra control scripts.
start "" /b ffmpeg -nostdin -y -f dshow -rtbufsize 64M -i "audio=%MIC_NAME%" -f s16le -ac 1 -ar 44100 "!CURRENT_INPUT!"

timeout /t 1 /nobreak
goto LOOP

:STOP_AND_PROCESS
set "STATE=PROCESSING"
echo.
echo ============================================================
echo [STOP] Stopping recording !CURRENT_ID!...
echo ============================================================

REM Stop only the FFmpeg whose command line contains THIS unique input file.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-CimInstance Win32_Process -Filter \"Name='ffmpeg.exe'\" ^| Where-Object {$_.CommandLine -like '*!CURRENT_INPUT!*'}; foreach($x in $p){Stop-Process -Id $x.ProcessId -Force}"

timeout /t 1 /nobreak

if not exist "!CURRENT_INPUT!" goto PROCESS_ERROR
for %%A in ("!CURRENT_INPUT!") do set "INPUT_SIZE=%%~zA"
if !INPUT_SIZE! LSS 4000 goto PROCESS_ERROR

set "CURRENT_OUTPUT=output_metrocop_!CURRENT_ID!.wav"
echo.
echo [PROCESS] FFmpeg conversion log:

ffmpeg -y -i on2.wav -f s16le -ar 44100 -ac 1 -i "!CURRENT_INPUT!" -i off2.wav -filter_complex "[0:a]aformat=sample_rates=44100:channel_layouts=mono[on];[1:a]asetrate=44100*0.8165,atempo=1.2247,aresample=44100,highpass=f=650,lowpass=f=3200,equalizer=f=1800:width_type=h:w=400:g=12,equalizer=f=900:width_type=h:w=200:g=6,volume=8dB,alimiter=limit=0.5,acompressor=threshold=-14dB:ratio=12:attack=10:release=100,volume=4dB,loudnorm,aformat=sample_rates=44100:channel_layouts=mono[voice];[2:a]aformat=sample_rates=44100:channel_layouts=mono[off];[on][voice][off]concat=n=3:v=0:a=1[out]" -map "[out]" "!CURRENT_OUTPUT!"

if errorlevel 1 goto PROCESS_ERROR
if not exist "!CURRENT_OUTPUT!" goto PROCESS_ERROR

echo.
echo [OK] Created !CURRENT_OUTPUT!
call :KEEP_LAST_10 "input_*.pcm"
call :KEEP_LAST_10 "output_metrocop_*.wav"

echo [PLAY] Playing processed audio now:
REM ffplay is deliberately run in THIS console. Any playback error is visible here.
ffplay -nodisp -autoexit -loglevel info "!CURRENT_OUTPUT!"

echo [PLAY] Finished.
set "STATE=IDLE"
set "CURRENT_ID="
set "CURRENT_INPUT="
call :DRAIN_KEYS

goto LOOP

:PROCESS_ERROR
echo.
echo [ERROR] The source was kept: !CURRENT_INPUT!
echo [ERROR] Check FFmpeg output above and make sure on2.wav/off2.wav exist.
set "STATE=IDLE"
set "CURRENT_ID="
set "CURRENT_INPUT="
call :DRAIN_KEYS
goto LOOP

:DRAIN_KEYS
REM Clears duplicated R events left by a controller after a start/stop action.
powershell -NoProfile -ExecutionPolicy Bypass -Command "while([Console]::KeyAvailable){[Console]::ReadKey($true) ^| Out-Null}"
exit /b

:KEEP_LAST_10
set "PATTERN=%~1"
set /a KEEP_INDEX=0
for /f "delims=" %%F in ('dir /b /a-d /o-n "%PATTERN%"') do (
    set /a KEEP_INDEX+=1
    if !KEEP_INDEX! GTR 10 (
        echo [CLEANUP] Removing old file: %%F
        del "%%F"
    )
)
exit /b

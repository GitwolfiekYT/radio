@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title METROCOP RADIO CONSOLE
cd /d "%~dp0"

REM F6 in metrocop.ahk sends an R to this single, permanent console.
REM Keep all files beside this script so it can be moved as one folder.
set "MIC_NAME=Microphone (WO Mic Device)"
set "RAW_RECORDING=recording.pcm"
set "INPUT_FILE=input.wav"
set "VOICE_FILE=output_metrocop.wav"
set "FINAL_FILE=radio_message.wav"
set "HISTORY_DIR=recordings"
set "MAX_HISTORY_INDEX=10"
set "STATE=IDLE"

if not exist "%HISTORY_DIR%" md "%HISTORY_DIR%"

echo ============================================================
echo             METROCOP RADIO - F6 TO TOGGLE
echo   First F6: record from "%MIC_NAME%"
echo   Second F6: stop, process, add radio sounds, and play
echo ============================================================

:WAIT_FOR_COMMAND
if /I "!STATE!"=="IDLE" (
    echo.
    echo [READY] Press F6 to start recording.
) else (
    echo [RECORDING] Speak, then press F6 to stop.
)
choice /c R /n >nul

if /I "!STATE!"=="IDLE" goto START_RECORDING
if /I "!STATE!"=="RECORDING" goto STOP_AND_PROCESS
echo [ERROR] Invalid controller state. Resetting.
set "STATE=IDLE"
goto WAIT_FOR_COMMAND

:START_RECORDING
del /q "%RAW_RECORDING%" 2>nul
set "STATE=RECORDING"
echo [START] Recording. Speak into WO Mic, then press F6.

REM Raw PCM remains valid even when FFmpeg is stopped from the controller.
REM It is converted to input.wav after recording has stopped cleanly enough.
start "METROCOP FFmpeg recording" /b ffmpeg -nostdin -hide_banner -loglevel warning -y -f dshow -rtbufsize 64M -i "audio=%MIC_NAME%" -f s16le -ac 1 -ar 44100 "%RAW_RECORDING%"
timeout /t 1 /nobreak >nul
goto WAIT_FOR_COMMAND

:STOP_AND_PROCESS
set "STATE=PROCESSING"
echo [STOP] Finalising recording...

REM Stop only the recorder created by this script, never another FFmpeg process.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-CimInstance Win32_Process -Filter \"Name='ffmpeg.exe'\" ^| Where-Object { $_.CommandLine -like '*%RAW_RECORDING%*' }; $p ^| ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 1 /nobreak >nul

if not exist "%RAW_RECORDING%" goto PROCESS_ERROR
for %%A in ("%RAW_RECORDING%") do set "RAW_SIZE=%%~zA"
if !RAW_SIZE! LSS 4000 goto PROCESS_ERROR

REM Assemble the captured microphone data as the requested input.wav first.
ffmpeg -y -hide_banner -loglevel warning -f s16le -ar 44100 -ac 1 -i "%RAW_RECORDING%" "%INPUT_FILE%"
if errorlevel 1 goto PROCESS_ERROR

REM Keep this voice-conversion filter exactly as supplied.
ffmpeg -y -i input.wav -af "asetrate=44100*0.8165,atempo=1.2247,aresample=44100,highpass=f=650,lowpass=f=3200,equalizer=f=1800:width_type=h:w=400:g=12,equalizer=f=900:width_type=h:w=200:g=6,volume=8dB,alimiter=limit=0.5,acompressor=threshold=-14dB:ratio=12:attack=10:release=100,volume=4dB,loudnorm" output_metrocop.wav
if errorlevel 1 goto PROCESS_ERROR

if not exist "on2.wav" goto SOUNDS_MISSING
if not exist "off2.wav" goto SOUNDS_MISSING

REM Normalize the three sources, then concatenate on2 + converted voice + off2.
ffmpeg -y -hide_banner -loglevel warning -i "on2.wav" -i "%VOICE_FILE%" -i "off2.wav" -filter_complex "[0:a]aresample=44100,aformat=channel_layouts=mono[on];[1:a]aresample=44100,aformat=channel_layouts=mono[voice];[2:a]aresample=44100,aformat=channel_layouts=mono[off];[on][voice][off]concat=n=3:v=0:a=1[out]" -map "[out]" "%FINAL_FILE%"
if errorlevel 1 goto PROCESS_ERROR

move /y "%FINAL_FILE%" "%VOICE_FILE%" >nul
call :ARCHIVE
echo [PLAY] Playing output_metrocop.wav on the Windows default device...
ffplay -nodisp -autoexit -hide_banner -loglevel warning "%VOICE_FILE%"
echo [DONE] Ready for the next message.
set "STATE=IDLE"
goto WAIT_FOR_COMMAND

:SOUNDS_MISSING
echo [ERROR] on2.wav and off2.wav must be next to radio.bat.
goto PROCESS_ERROR

:PROCESS_ERROR
echo [ERROR] Processing failed. The captured files were kept for diagnosis.
set "STATE=IDLE"
goto WAIT_FOR_COMMAND

:ARCHIVE
REM Retain 11 complete message pairs, numbered 0 (oldest) through 10 (newest).
REM Once full, delete 0, shift 1 to 0 through 10 to 9, then add the new 10.
if exist "%HISTORY_DIR%\%MAX_HISTORY_INDEX%_input.wav" (
    del /q "%HISTORY_DIR%\0_input.wav" "%HISTORY_DIR%\0_metrocop.wav" 2>nul
    for /l %%N in (1,1,%MAX_HISTORY_INDEX%) do (
        set /a PREVIOUS=%%N-1
        if exist "%HISTORY_DIR%\%%N_input.wav" move /y "%HISTORY_DIR%\%%N_input.wav" "%HISTORY_DIR%\!PREVIOUS!_input.wav" >nul
        if exist "%HISTORY_DIR%\%%N_metrocop.wav" move /y "%HISTORY_DIR%\%%N_metrocop.wav" "%HISTORY_DIR%\!PREVIOUS!_metrocop.wav" >nul
    )
    set "ARCHIVE_INDEX=%MAX_HISTORY_INDEX%"
) else (
    REM History is contiguous until it reaches the maximum index.
    set "ARCHIVE_INDEX=0"
    for /l %%N in (0,1,%MAX_HISTORY_INDEX%) do (
        if exist "%HISTORY_DIR%\%%N_input.wav" set /a ARCHIVE_INDEX=%%N+1
    )
)
copy /y "%INPUT_FILE%" "%HISTORY_DIR%\!ARCHIVE_INDEX!_input.wav" >nul
copy /y "%VOICE_FILE%" "%HISTORY_DIR%\!ARCHIVE_INDEX!_metrocop.wav" >nul
echo [SAVED] %HISTORY_DIR%\!ARCHIVE_INDEX!_metrocop.wav
exit /b

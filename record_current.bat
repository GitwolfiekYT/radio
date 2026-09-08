@echo off
title METROCOP RECORDING off.
cd /d "%~dp0"
echo ================================================
echo   RECORDING METROCOP RADIO off.
echo   Speak now. Stop with F6 again.
echo ================================================
ffmpeg -y -f dshow -rtbufsize 64M -i "audio=Microphone (WO Mic Device)" -f s16le -ac 1 -ar 44100 "input_off..pcm"
echo.
echo [RECORDER STOPPED]
pause
